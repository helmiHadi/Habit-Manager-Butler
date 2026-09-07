import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import '../../../core/database/database_helper.dart';
import '../../../core/ai/ai_agent_service.dart';
import '../../../core/cloud/cloud_sync_service.dart';
import '../models/app_usage_model.dart';
import 'dart:math';
// Import your generated Serverpod client below if needed
// import 'package:your_app_client/your_app_client.dart';

class AppUsageProvider extends ChangeNotifier {
  final dynamic client; // Replace dynamic with Client if fully typed
  
  static const String myPackageName = 'com.example.screen_time_app';
  static const _channel = MethodChannel('com.butler.app/blocker');
  List<AppUsageModel> _appUsages = [];
  bool _isLoading = false;
  bool _showSystemApps = false;
  String _currentRoast = "Nice try. Get back to work.";
  String _roastLevel = 'Snarky';
  String _analyticsVerdict = "Waiting for your data...";
  bool _isMonthlyView = false;
  String _appRole = 'standalone';
  bool _isRoleLocked = false;
  String? _pairingCode;
  List<String> _pairedChildren = [];
  Timer? _timer;

  // ─── Payload diff-check (prevents MethodChannel spam) ────────────────────
  // Stores the sorted, canonical form of the last blocklist we successfully
  // sent to the Kotlin layer.  We compare against this before every native
  // call; if the payload is identical we skip the channel entirely.
  Set<String> _lastSentBlockedApps = {};


  bool get isMonthlyView => _isMonthlyView;
  String get appRole => _appRole;
  bool get isRoleLocked => _isRoleLocked;
  String? get pairingCode => _pairingCode;

  /// Ordered, deduplicated list of child pairing codes this Parent has connected to.
  List<String> get pairedChildren => List.unmodifiable(_pairedChildren);

  /// Adds [code] to the persisted paired-children list (deduplicates automatically).
  Future<void> addPairedChild(String code) async {
    if (code.isEmpty) return;
    if (!_pairedChildren.contains(code)) {
      _pairedChildren = [..._pairedChildren, code];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('paired_children', _pairedChildren);
      print('=== 👨‍👧 PARENT: Added child code=$code. Total paired: ${_pairedChildren.length} ===');
      notifyListeners();
    }
  }

  /// Removes [code] from the persisted paired-children list.
  Future<void> removePairedChild(String code) async {
    if (!_pairedChildren.contains(code)) return;
    _pairedChildren = _pairedChildren.where((c) => c != code).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('paired_children', _pairedChildren);
    print('=== 👨‍👧 PARENT: Removed child code=$code. Remaining: ${_pairedChildren.length} ===');
    notifyListeners();
  }
  
  // ─── Unified role + code setter (STRICT ORDERING) ────────────────────────
  //
  // For CHILD:
  //   1. Save the pairing code to state + SharedPreferences
  //   2. Fetch system apps via Isolate
  //   3. Push the full app list to the cloud using that exact code
  //   4. Start fast-polling listener ONLY after push succeeds
  //
  // For PARENT:
  //   1. Save the pairing code to state + SharedPreferences
  //   2. Save the role to state + SharedPreferences
  //   (Navigation is handled by the caller after this returns)
  // ──────────────────────────────────────────────────────────────────────────

  /// Legacy alias — kept for callers that only need to update the code
  /// without triggering role-specific pipeline logic.
  Future<void> setPairingCode(String code) async {
    _pairingCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pairing_code', code);
    notifyListeners();
  }

  /// Single entry-point for role assignment. Always call this instead of
  /// setPairingCode + setAppRole separately.
  ///
  /// [role]  – 'child' | 'parent' | 'standalone'
  /// [code]  – The pairing code relevant to this role.
  ///           For Child: the code this device generated.
  ///           For Parent: the code typed in from the child's screen.
  Future<void> setRole(String role, String code) async {
    final prefs = await SharedPreferences.getInstance();

    // ── STEP 1: Save pairing code ─────────────────────────────────────────
    print('=== [1/4] 🔑 CODE SAVED: role=$role, code=$code ===');
    _pairingCode = code;
    _appRole = role;
    await prefs.setString('pairing_code', code);
    await prefs.setString('app_role', role);
    notifyListeners();

    if (role == 'child') {
      // ── GHOST BLOCK PREVENTION ────────────────────────────────────────────
      // Wipe any locally-saved Parent blocks so they do NOT bleed into Child
      // mode enforcement.
      await prefs.setStringList('blocked_apps', []);
      await prefs.setStringList('manually_blocked_apps', []);
      _channel.invokeMethod('stopService');
      print('=== 🧹 ROLE SWITCH: Cleared local Parent blocks. Service stopped. ===');

      // ── STEP 2: Fetch apps via Isolate ────────────────────────────────────
      print('=== [2/4] 📦 APPS FETCHING: Spawning background Isolate... ===');
      List<Map<String, dynamic>> allApps = [];
      try {
        final token = RootIsolateToken.instance!;
        allApps = await Isolate.run(() async {
          BackgroundIsolateBinaryMessenger.ensureInitialized(token);
          final apps = await InstalledApps.getInstalledApps(
            excludeSystemApps: false, // Include ALL system apps for parent view
            withIcon: false,          // Skip icons to keep payload small
          );
          return apps.map((app) => {
            'packageName': app.packageName,
            'appName': app.name,
          }).toList();
        });
        print('=== [2/4] 📦 APPS FETCHED: ${allApps.length} apps ready. ===');
      } catch (e) {
        print('=== [2/4] ⚠️ APPS FETCH ERROR: $e ===');
      }

      // ── STEP 3: Push app list using the exact pairing code ────────────────
      print('=== [3/4] ☁️  APPS PUSHING: Sending ${allApps.length} apps to cloud on code=$code ===');
      try {
        await CloudSyncService(client).pushAppListToCloud(allApps, code);
        print('=== [3/4] ☁️  APPS PUSHED: Cloud upload complete. ===');
      } catch (e) {
        print('=== [3/4] ☁️  APPS PUSH ERROR: $e ===');
      }

      // ── STEP 4: Start polling ONLY after push succeeds ────────────────────
      print('=== [4/4] 📡 POLLING STARTED: Listening on code=$code ===');
      _listenToCloudAsChild(code);

    } else if (role == 'parent') {
      // ── Save code to the persistent paired-children list ──────────────────
      await addPairedChild(code);
      print('=== [1/1] 🔑 PARENT READY: pairingCode=$code saved & added to pairedChildren. Navigate to RemoteScheduleScreen. ===');
    }
  }

  /// Kept for UI callers that still use setAppRole directly (role card taps
  /// that don't yet have a code). Delegates to setRole when a code is known.
  Future<void> setAppRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    // Reuse the already-persisted pairing code if available.
    final existingCode = _pairingCode ?? prefs.getString('pairing_code') ?? '';
    await setRole(role, existingCode);
  }

  void _listenToCloudAsChild(String pairingCode) {
    CloudSyncService(client).listenToCloudConfig(pairingCode).listen((config) async {
      print('=== 📡 CHILD RECEIVER: Config arrived ===');

      final prefs = await SharedPreferences.getInstance();

      // ── Role lock ──────────────────────────────────────────────────────────
      if (config.containsKey('isRoleLocked')) {
        _isRoleLocked = config['isRoleLocked'] as bool? ?? false;
        await prefs.setBool('is_role_locked', _isRoleLocked);
        notifyListeners();
      }

      // ── BULK format (Phase 58): { "bulkConfig": [ {...}, {...}, ... ] } ────
      // Parent pushes ALL modified apps in one JSON blob to avoid the
      // server's single-slot "last write wins" overwrite problem.
      if (config.containsKey('bulkConfig')) {
        final rawList = config['bulkConfig'];
        if (rawList is List) {
          for (final entry in rawList) {
            if (entry is Map<String, dynamic>) {
              await _applyPerAppConfig(entry, prefs);
            }
          }
          // Recompute blocklist and push to native once after all entries.
          final remoteBlocked = _appUsages
              .where((a) => a.isBlocked && a.packageName != myPackageName)
              .map((a) => a.packageName)
              .toList();
          await prefs.setStringList('remote_blocked_apps', remoteBlocked);
          await _applyRemoteBlocklistToNative(remoteBlocked);
          notifyListeners();
        }
        return;
      }

      // ── LEGACY single-app format: { "targetApp": "com.x", ... } ──────────
      if (config.containsKey('targetApp')) {
        await _applyPerAppConfig(config, prefs);
        final remoteBlocked = _appUsages
            .where((a) => a.isBlocked && a.packageName != myPackageName)
            .map((a) => a.packageName)
            .toList();
        await prefs.setStringList('remote_blocked_apps', remoteBlocked);
        await _applyRemoteBlocklistToNative(remoteBlocked);
        notifyListeners();
      }
    });
  }

  /// Applies one per-app config map to [_appUsages] + [SharedPreferences].
  /// Shared between the legacy single-app path and the new bulk path.
  Future<void> _applyPerAppConfig(
    Map<String, dynamic> cfg,
    SharedPreferences prefs,
  ) async {
    final targetApp = cfg['targetApp'] as String?;
    if (targetApp == null) return;
    final index = _appUsages.indexWhere((a) => a.packageName == targetApp);
    if (index == -1) return;

    if (cfg.containsKey('isManuallyBlocked')) {
      _appUsages[index].isManuallyBlocked =
          cfg['isManuallyBlocked'] as bool? ?? false;
    }
    if (cfg.containsKey('maxDailyMinutes')) {
      final maxMins = cfg['maxDailyMinutes'] as int?;
      _appUsages[index].maxDailyMinutes = maxMins;
      if (maxMins != null) {
        await prefs.setInt('max_limit_$targetApp', maxMins);
      } else {
        await prefs.remove('max_limit_$targetApp');
      }
    }
    if (cfg.containsKey('allowedDays')) {
      final raw = cfg['allowedDays'];
      if (raw is List) {
        _appUsages[index].allowedDays =
            raw.map((e) => int.tryParse(e.toString()) ?? 1).toList();
      }
    }
    if (cfg.containsKey('startTime')) {
      final raw = cfg['startTime'] as String?;
      _appUsages[index].startTime = raw != null ? _parseTimeOfDay(raw) : null;
    }
    if (cfg.containsKey('endTime')) {
      final raw = cfg['endTime'] as String?;
      _appUsages[index].endTime = raw != null ? _parseTimeOfDay(raw) : null;
    }

    _appUsages[index].isBlocked = _shouldBeBlockedNow(_appUsages[index]);
    print('=== 📡 CHILD: Applied config for $targetApp '
        '(blocked=${_appUsages[index].isBlocked}) ===');
  }

  /// Parses "HH:MM" string into a [TimeOfDay]. Returns null on invalid input.
  static TimeOfDay? _parseTimeOfDay(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// Sends the child's authoritative remote blocklist directly to the
  /// Kotlin background service, completely replacing whatever was there before.
  ///
  /// ── DIFF-CHECK ──────────────────────────────────────────────────────────
  /// Compares [remoteBlocked] against the last list we sent.  If they are
  /// identical (same packages, regardless of order) the MethodChannel is NOT
  /// called, preventing thousands of redundant calls during fast polling.
  Future<void> _applyRemoteBlocklistToNative(List<String> remoteBlocked) async {
    // ── DIFF-CHECK ─────────────────────────────────────────────────────────
    // Use sorted JSON string comparison for structural equality.
    // Set == works for primitive strings but jsonEncode(sorted) is more
    // explicit and handles any future edge-cases (e.g. duplicates, null).
    final sortedIncoming = List<String>.from(remoteBlocked)..sort();
    final incomingJson   = jsonEncode(sortedIncoming);

    final sortedLast = _lastSentBlockedApps.toList()..sort();
    final lastJson   = jsonEncode(sortedLast);

    if (incomingJson == lastJson) {
      print('=== ⏭️  NATIVE SYNC SKIPPED: Blocklist unchanged (${remoteBlocked.length} apps). ===');
      return;
    }

    // Payload changed — update cache and push to Kotlin.
    _lastSentBlockedApps = remoteBlocked.toSet();
    print('=== 📡 NATIVE SYNC: Blocklist changed → ${remoteBlocked.length} package(s). ===');

    final prefs = await SharedPreferences.getInstance();
    List<String> cachedRoasts = prefs.getStringList('cached_roasts') ?? [];
    if (cachedRoasts.isEmpty) cachedRoasts = ['Get back to work.'];

    if (remoteBlocked.isNotEmpty) {
      // Hot-update the running service first (zero-delay, no restart).
      try {
        await _channel.invokeMethod('updateBlockedApps', {
          'blockedApps': remoteBlocked,
        });
        print('=== 📡 NATIVE SYNC: updateBlockedApps succeeded. ===');
      } catch (e) {
        // Service not running yet — do a full start.
        print('=== 📡 NATIVE SYNC: updateBlockedApps failed ($e), falling back to startService. ===');
        _channel.invokeMethod('startService', {
          'blockedApps': remoteBlocked,
          'roasts': cachedRoasts,
        });
      }
    } else {
      // Nothing is blocked remotely — stop the service to clear all overlays.
      _channel.invokeMethod('stopService');
      // Invalidate cache so the next non-empty list always passes the diff check.
      _lastSentBlockedApps = {};
      print('=== 📡 NATIVE SYNC: Remote blocklist empty → service stopped. ===');
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveTodayUsage(int totalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDateKey(DateTime.now());
    await prefs.setInt('usage_$key', totalMinutes);
  }

  Future<int?> getYesterdayUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getDateKey(DateTime.now().subtract(const Duration(days: 1)));
    return prefs.getInt('usage_$key');
  }

  void toggleAnalyticsView(bool isMonthly) {
    if (_isMonthlyView == isMonthly) return;
    _isMonthlyView = isMonthly;
    fetchAnalyticsVerdict();
    notifyListeners();
  }

  AppUsageProvider(this.client) {
    fetchInstalledApps();
    _startBackgroundTimer();
    
    // Defer cloud polling so it doesn't block the UI's first frame rendering
    Future.microtask(() => _initializeCloudSync());
  }

  /// Called once on app boot. Re-runs the strict pipeline so the Parent
  /// immediately has an up-to-date app list even after the app is relaunched.
  Future<void> _initializeCloudSync() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('app_role') ?? 'standalone';

    // ── Always restore the paired-children list regardless of role ────────────
    _pairedChildren = prefs.getStringList('paired_children') ?? [];
    if (_pairedChildren.isNotEmpty) {
      print('=== 👨‍👧 BOOT: Restored ${_pairedChildren.length} paired child(ren): $_pairedChildren ===');
      notifyListeners();
    }

    if (role == 'parent') {
      // Restore in-memory state for the parent role on reboot.
      final savedCode = prefs.getString('pairing_code') ?? '';
      _pairingCode = savedCode.isNotEmpty ? savedCode : null;
      _appRole = role;
      print('=== 🔄 BOOT SYNC (PARENT): Restored role and pairingCode=$savedCode ===');
      return; // No child pipeline needed for the parent role.
    }

    if (role == 'child') {
      final savedCode = prefs.getString('pairing_code') ?? '';
      if (savedCode.isEmpty) {
        print('=== 🚨 BOOT SYNC: No pairing code found. Skipping pipeline. ===');
        return;
      }
      // Restore in-memory state so the rest of the app sees the correct code.
      _pairingCode = savedCode;
      _appRole = role;

      print('=== 🔄 BOOT SYNC: Re-running pipeline for code=$savedCode ===');

      // ── STEP 1 (already persisted from previous session) ──────────────────
      print('=== [1/4] 🔑 CODE SAVED (restored): code=$savedCode ===');

      // ── STEP 2: Re-fetch apps ─────────────────────────────────────────────
      print('=== [2/4] 📦 APPS FETCHING: Spawning background Isolate on boot... ===');
      List<Map<String, dynamic>> allApps = [];
      try {
        final token = RootIsolateToken.instance!;
        allApps = await Isolate.run(() async {
          BackgroundIsolateBinaryMessenger.ensureInitialized(token);
          final apps = await InstalledApps.getInstalledApps(
            excludeSystemApps: false,
            withIcon: false,
          );
          return apps.map((app) => {
            'packageName': app.packageName,
            'appName': app.name,
          }).toList();
        });
        print('=== [2/4] 📦 APPS FETCHED: ${allApps.length} apps ready. ===');
      } catch (e) {
        print('=== [2/4] ⚠️ APPS FETCH ERROR on boot: $e ===');
      }

      // ── STEP 3: Push ──────────────────────────────────────────────────────
      print('=== [3/4] ☁️  APPS PUSHING: Sending ${allApps.length} apps to cloud on code=$savedCode ===');
      try {
        await CloudSyncService(client).pushAppListToCloud(allApps, savedCode);
        print('=== [3/4] ☁️  APPS PUSHED: Boot-time cloud upload complete. ===');
      } catch (e) {
        print('=== [3/4] ☁️  APPS PUSH ERROR on boot: $e ===');
      }

      // ── STEP 4: Start polling ─────────────────────────────────────────────
      print('=== [4/4] 📡 POLLING STARTED: Listening on code=$savedCode ===');
      _listenToCloudAsChild(savedCode);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> setRoastLevel(String level) async {
    _isLoading = true;
    notifyListeners();

    try {
      _roastLevel = level;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('roast_level', level);
      await prefs.remove('cached_roasts');
      
      print('=== 🎭 ROASTER: Generating new ammunition for level $level... ===');
      final newRoasts = await AIAgentService().generateRoastAmunition(10, level);
      List<String> roastsToSave = newRoasts.isNotEmpty ? newRoasts : ["Nice try. Get back to work."];
      await prefs.setStringList('cached_roasts', roastsToSave);
      
      final blockedList = _appUsages
          .where((app) => app.isBlocked && app.packageName != myPackageName)
          .map((app) => app.packageName)
          .toList();
      if (blockedList.isNotEmpty) {
        _channel.invokeMethod('startService', {
          'blockedApps': blockedList,
          'roasts': roastsToSave,
        });
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateNativeService(List<String> blockedApps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_apps', blockedApps);
    
    if (blockedApps.isNotEmpty) {
      List<String> cachedRoasts = prefs.getStringList('cached_roasts') ?? [];
      
      if (cachedRoasts.isEmpty) {
        print('=== 🎭 ROASTER: Generating new ammunition... ===');
        cachedRoasts = await AIAgentService().generateRoastAmunition(10, _roastLevel);
        if (cachedRoasts.isNotEmpty) {
          await prefs.setStringList('cached_roasts', cachedRoasts);
        } else {
          cachedRoasts = ["Nice try. Get back to work."];
        }
      }
      
      print('=== 🎭 ROASTER: Sending ${cachedRoasts.length} roasts to Kotlin ===');
      print('Roasts being sent: $cachedRoasts');
      
      // Start (or restart) the service with the full current blocklist
      _channel.invokeMethod('startService', {
        'blockedApps': blockedApps,
        'roasts': cachedRoasts,
      });
      
      // Also hot-update the running service's blocklist so it applies
      // immediately without waiting for a full service restart cycle.
      // The Kotlin side should handle 'updateBlockedApps' as a no-restart update.
      try {
        await _channel.invokeMethod('updateBlockedApps', {
          'blockedApps': blockedApps,
        });
        print('=== 📡 NATIVE SYNC: updateBlockedApps sent: $blockedApps ===');
      } catch (e) {
        // Gracefully ignore if the Kotlin side hasn't implemented this yet;
        // startService above already covers the restart path.
        print('=== ⚠️ NATIVE SYNC: updateBlockedApps not handled: $e ===');
      }
    } else {
      _channel.invokeMethod('stopService');
    }
  }

  void _startBackgroundTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      bool hasChanges = false;
      for (var app in _appUsages) {
        if (app.packageName == myPackageName) continue;
        final shouldBlock = _shouldBeBlockedNow(app);
        if (app.isBlocked != shouldBlock) {
          app.isBlocked = shouldBlock;
          hasChanges = true;
        }
      }
      
      if (hasChanges) {
        final blockedList = _appUsages
            .where((app) => app.isBlocked && app.packageName != myPackageName)
            .map((app) => app.packageName)
            .toList();
            
        await _updateNativeService(blockedList);
        notifyListeners();
      }
    });
  }

  bool _shouldBeBlockedNow(AppUsageModel app) {
    if (app.packageName == myPackageName) return false;
    
    if (app.isManuallyBlocked) return true;
    
    if (app.maxDailyMinutes != null && app.maxDailyMinutes! > 0) {
      if (app.dailyUsageMinutes >= app.maxDailyMinutes!) return true;
    }
    
    final now = DateTime.now();
    if (app.allowedDays.isEmpty) return true;
    if (!app.allowedDays.contains(now.weekday)) return true;

    if (app.startTime != null && app.endTime != null) {
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = app.startTime!.hour * 60 + app.startTime!.minute;
      final endMinutes = app.endTime!.hour * 60 + app.endTime!.minute;

      if (startMinutes <= endMinutes) {
        if (nowMinutes < startMinutes || nowMinutes > endMinutes) return true;
      } else {
        if (nowMinutes < startMinutes && nowMinutes > endMinutes) return true;
      }
    }
    
    return false;
  }

  List<AppUsageModel> get appUsages => _appUsages;
  bool get isLoading => _isLoading;
  bool get showSystemApps => _showSystemApps;
  String get currentRoast => _currentRoast;
  String get roastLevel => _roastLevel;

  Future<void> fetchRoastForApp(String appName, String category) async {
    print('\n=== 🎭 ROASTER AGENT CALLED ===');
    print('Target App: $appName | Category: $category');
    try {
      final roast = await AIAgentService().getSarcasticRoast(appName, category);
      _currentRoast = roast;
      print('Resulting Roast: $_currentRoast');
    } catch (e) {
      _currentRoast = "Nice try. Get back to work.";
      print('Roaster Error: $e');
    }
    notifyListeners(); 
    print('=== 🎭 ROASTER AGENT FINISHED ===\n');
  }

  void toggleSystemApps(bool value) {
    _showSystemApps = value;
    fetchInstalledApps();
  }
  int _weeklyUsage = 0;
  int _monthlyUsage = 0;
  int _yesterdayUsage = 0;
  int _lastWeekUsage = 0;
  int _lastMonthUsage = 0;

  int getWeeklyUsage() => _weeklyUsage;
  int getMonthlyUsage() => _monthlyUsage;
  int get yesterdayUsage => _yesterdayUsage;
  int get lastWeekUsage => _lastWeekUsage;
  int get lastMonthUsage => _lastMonthUsage;
  String get analyticsVerdict => _analyticsVerdict;

  Future<void> fetchAnalyticsVerdict() async {
    final topCategory = _appUsages.isNotEmpty 
        ? _appUsages.reduce((a, b) => a.dailyUsageMinutes > b.dailyUsageMinutes ? a : b).category 
        : 'Unknown';
    
    final int minutesToReport = _isMonthlyView ? _monthlyUsage : totalScreenTimeMinutes;
    final String timeframe = _isMonthlyView ? "this month" : "today";
    
    final aiService = AIAgentService();
    _analyticsVerdict = await aiService.getAnalyticsVerdict(minutesToReport, topCategory, timeframe);
    notifyListeners();
  }

  Map<String, double> getCategoryData() {
    Map<String, double> categoryMap = {};
    for (var app in _appUsages) {
      if (app.dailyUsageMinutes > 0) {
        categoryMap[app.category] = (categoryMap[app.category] ?? 0) + app.dailyUsageMinutes.toDouble();
      }
    }
    return categoryMap;
  }

  Future<List<double>> getWeeklyChartData() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    List<double> weekData = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final minutes = await db.getUsageForDateRange(dateStr, dateStr);
      weekData.add(minutes.toDouble());
    }
    return weekData;
  }

  Future<List<double>> getMonthlyChartData() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    List<double> monthData = [0, 0, 0, 0];
    
    for (int i = 0; i < 4; i++) {
      int sum = 0;
      for (int j = 0; j < 7; j++) {
        final daysAgo = i * 7 + j;
        final date = now.subtract(Duration(days: daysAgo));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        sum += await db.getUsageForDateRange(dateStr, dateStr);
      }
      monthData[3 - i] = sum.toDouble();
    }
    return monthData;
  }

  int get totalScreenTimeMinutes {
    return _appUsages.fold(0, (sum, app) => sum + app.dailyUsageMinutes);
  }

  Future<void> fetchInstalledApps() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = RootIsolateToken.instance!;
      final bool showSystem = _showSystemApps;
      
      final mappedApps = await Isolate.run(() async {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
        List<AppInfo> apps = await InstalledApps.getInstalledApps(excludeSystemApps: !showSystem, withIcon: true);
        return apps.map((app) => {
          'packageName': app.packageName,
          'appName': app.name,
          'iconData': app.icon,
        }).toList();
      });
      
      final prefs = await SharedPreferences.getInstance();
      _roastLevel = prefs.getString('roast_level') ?? 'Snarky';
      _appRole = prefs.getString('app_role') ?? 'standalone';
      _isRoleLocked = prefs.getBool('is_role_locked') ?? false;
      
      final savedBlockedApps = prefs.getStringList('blocked_apps') ?? [];
      final savedManuallyBlockedApps = prefs.getStringList('manually_blocked_apps') ?? [];
      
      Map<Object?, Object?> usageMap = {};
      try {
        final result = await _channel.invokeMethod('getDailyUsageStats');
        if (result != null) {
          usageMap = result as Map<Object?, Object?>;
        }
      } catch (e) {
        print("Error fetching daily usage stats: $e");
      }
      
      final random = Random();
      final schedules = await DatabaseHelper.instance.getSchedules();
      final categoriesMap = await DatabaseHelper.instance.getCategories();
      
      _appUsages = mappedApps.map((appMap) {
        final packageName = appMap['packageName'] as String;
        final appName = appMap['appName'] as String;
        final iconData = appMap['iconData'] as Uint8List?;
        
        final usageMinutes = usageMap[packageName] as int? ?? 0;
        final schedule = schedules[packageName];
        var savedCategory = categoriesMap[packageName] ?? 'Other';
        if (savedCategory == 'Other' || savedCategory == 'Others') {
          final cachedCatsStr = prefs.getString('cached_app_categories');
          if (cachedCatsStr != null && cachedCatsStr.isNotEmpty) {
            try {
              final Map<String, dynamic> decoded = jsonDecode(cachedCatsStr);
              final String? cachedCat = decoded[packageName]?.toString();
              if (cachedCat != null && cachedCat.isNotEmpty) {
                savedCategory = cachedCat;
                DatabaseHelper.instance.upsertCategory(packageName, cachedCat);
              }
            } catch (_) {}
          }
        }
        
        List<int> allowedDays = [1, 2, 3, 4, 5, 6, 7];
        TimeOfDay? startTime;
        TimeOfDay? endTime;
        
        if (schedule != null) {
          if (schedule['allowed_days'] != null) {
            allowedDays = List<int>.from(jsonDecode(schedule['allowed_days']));
          }
          if (schedule['start_time'] != null) {
            final parts = schedule['start_time'].split(':');
            startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (schedule['end_time'] != null) {
            final parts = schedule['end_time'].split(':');
            endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        }

        bool isManuallyBlocked = savedManuallyBlockedApps.contains(packageName);
        if (packageName == myPackageName) {
          isManuallyBlocked = false;
        }

        final maxDailyStr = prefs.getInt('max_limit_$packageName');

        return AppUsageModel(
          appName: appName,
          packageName: packageName,
          durationInMinutes: usageMinutes,
          category: savedCategory,
          iconData: iconData,
          isBlocked: false,
          dailyUsageMinutes: usageMinutes,
          allowedDays: allowedDays,
          startTime: startTime,
          endTime: endTime,
          maxDailyMinutes: maxDailyStr,
          isManuallyBlocked: isManuallyBlocked,
        );
      }).toList();
      
      for (var app in _appUsages) {
        if (app.packageName != myPackageName) {
          app.isBlocked = _shouldBeBlockedNow(app);
        }
      }
      
      // Sort by daily usage duration
      _appUsages.sort((a, b) => b.dailyUsageMinutes.compareTo(a.dailyUsageMinutes));
      
      // Database Operations
      final db = DatabaseHelper.instance;
      
      final now = DateTime.now();
      String formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final todayStr = formatDate(now);
      await db.upsertUsage(todayStr, totalScreenTimeMinutes);
      await saveTodayUsage(totalScreenTimeMinutes);
      
      final savedYesterday = await getYesterdayUsage();
      _yesterdayUsage = savedYesterday ?? 0;
      
      _weeklyUsage = await db.getUsageForDateRange(
        formatDate(now.subtract(const Duration(days: 6))), 
        todayStr
      );
      
      _lastWeekUsage = await db.getUsageForDateRange(
        formatDate(now.subtract(const Duration(days: 13))), 
        formatDate(now.subtract(const Duration(days: 7)))
      );
      
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      _monthlyUsage = await db.getUsageForDateRange(
        formatDate(firstDayOfMonth), 
        todayStr
      );
      
      int lastMonth = now.month - 1;
      int lastMonthYear = now.year;
      if (lastMonth == 0) {
        lastMonth = 12;
        lastMonthYear--;
      }
      final firstDayOfLastMonth = DateTime(lastMonthYear, lastMonth, 1);
      final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
      _lastMonthUsage = await db.getUsageForDateRange(
        formatDate(firstDayOfLastMonth), 
        formatDate(lastDayOfLastMonth)
      );
      
      // Auto start or stop native service
      if (savedBlockedApps.isNotEmpty) {
        await _updateNativeService(savedBlockedApps);
      } else {
        _channel.invokeMethod('stopService');
      }
      
      final uncategorizedApps = _appUsages.where((app) => app.category == 'Other').toList();
      _autoCategorizeUncategorizedApps(uncategorizedApps);
      
      // NOTE: The full app-list push is now handled by setRole() / _initializeCloudSync()
      // with strict ordering guarantees. Do NOT push here with a hardcoded code.
      
    } catch (e) {
      print("Error fetching apps: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleBlockState(String packageName) async {
    if (_appRole == 'child') return; // Enforced block for child mode
    
    final index = _appUsages.indexWhere((app) => app.packageName == packageName);
    if (index != -1) {
      final app = _appUsages[index];
      app.isManuallyBlocked = !app.isManuallyBlocked;
      
      final prefs = await SharedPreferences.getInstance();
      final savedManuallyBlockedApps = prefs.getStringList('manually_blocked_apps') ?? [];
      if (app.isManuallyBlocked) {
        if (!savedManuallyBlockedApps.contains(packageName)) savedManuallyBlockedApps.add(packageName);
      } else {
        savedManuallyBlockedApps.remove(packageName);
      }
      await prefs.setStringList('manually_blocked_apps', savedManuallyBlockedApps);
      
      app.isBlocked = _shouldBeBlockedNow(app);
      notifyListeners();
      
      if (_appRole == 'parent') {
        CloudSyncService(client).pushConfigToCloud({
          'targetApp': packageName,
          'isManuallyBlocked': app.isManuallyBlocked,
        }, '123456');
      }
      
      final blockedList = _appUsages
          .where((a) => a.isBlocked && a.packageName != myPackageName)
          .map((a) => a.packageName)
          .toList();
          
      await _updateNativeService(blockedList);
    }
  }

  Future<void> categorizeAllApps() async {
    _isLoading = true;
    notifyListeners();
    try {
      final aiService = AIAgentService();
      final appNames = _appUsages.map((a) => a.appName).toList();
      final aiCategories = await aiService.categorizeApps(appNames);
      
      final db = DatabaseHelper.instance;
      for (int i = 0; i < _appUsages.length; i++) {
        final newCategory = aiCategories[_appUsages[i].appName];
        if (newCategory != null) {
          _appUsages[i].category = newCategory;
          await db.upsertCategory(_appUsages[i].packageName, newCategory);
        }
      }
    } catch (e) {
      debugPrint("Error categorizing apps: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _autoCategorizeUncategorizedApps(List<AppUsageModel> uncategorizedApps) async {
    if (uncategorizedApps.isEmpty) return;

    try {
      final aiService = AIAgentService();
      final appNames = uncategorizedApps.map((a) => a.appName).toList();
      
      // Process in batches to handle API rate limits gracefully
      const int batchSize = 10;
      final db = DatabaseHelper.instance;

      for (int i = 0; i < appNames.length; i += batchSize) {
        final end = (i + batchSize < appNames.length) ? i + batchSize : appNames.length;
        final batch = appNames.sublist(i, end);
        
        try {
          final aiCategories = await aiService.categorizeApps(batch);
          
          bool hasUpdates = false;
          for (int j = 0; j < _appUsages.length; j++) {
            final currentApp = _appUsages[j];
            if (aiCategories.containsKey(currentApp.appName)) {
              final newCategory = aiCategories[currentApp.appName]!;
              _appUsages[j].category = newCategory;
              await db.upsertCategory(currentApp.packageName, newCategory);
              hasUpdates = true;
            }
          }
          
          if (hasUpdates) {
            notifyListeners();
          }
          
          if (end < appNames.length) {
            await Future.delayed(const Duration(seconds: 3));
          }
        } catch (e) {
          debugPrint("Error auto-categorizing batch: $e");
          break;
        }
      }
    } catch (e) {
      debugPrint("Error auto-categorizing apps: $e");
    }
  }

  Future<void> saveSchedule(String packageName, List<int> days, TimeOfDay? start, TimeOfDay? end, int? maxDailyMinutes) async {
    if (_appRole == 'child') return; // Enforced block for child mode
    
    final index = _appUsages.indexWhere((app) => app.packageName == packageName);
    if (index != -1) {
      _appUsages[index].allowedDays = days;
      _appUsages[index].startTime = start;
      _appUsages[index].endTime = end;
      _appUsages[index].maxDailyMinutes = maxDailyMinutes;
      
      _appUsages[index].isBlocked = _shouldBeBlockedNow(_appUsages[index]);
      
      notifyListeners();
      
      final db = DatabaseHelper.instance;
      String? startStr = start != null ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}' : null;
      String? endStr = end != null ? '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}' : null;
      
      await db.upsertSchedule(packageName, jsonEncode(days), startStr, endStr);
      
      final prefs = await SharedPreferences.getInstance();
      if (maxDailyMinutes != null && maxDailyMinutes > 0) {
        await prefs.setInt('max_limit_$packageName', maxDailyMinutes);
      } else {
        await prefs.remove('max_limit_$packageName');
      }
      
      if (_appRole == 'parent') {
        CloudSyncService(client).pushConfigToCloud({
          'targetApp': packageName,
          'allowedDays': days,
          'startTime': startStr,
          'endTime': endStr,
          'maxDailyMinutes': maxDailyMinutes,
        }, '123456');
      }
      
      final blockedList = _appUsages
          .where((app) => app.isBlocked && app.packageName != myPackageName)
          .map((app) => app.packageName)
          .toList();
          
      await _updateNativeService(blockedList);
    }
  }

  Future<String> executeNLPCommand(String userInput) async {
    _isLoading = true;
    notifyListeners();

    try {
      print("=== NLP Execution Started ===");
      print("Original User Input: $userInput");
      
      final activeCategories = _appUsages.map((app) => app.category).toSet().toList();
      print("Active Categories: $activeCategories");
      
      final aiService = AIAgentService();
      final configs = await aiService.parseScheduleCommand(userInput, activeCategories);
      print("Raw Parsed Commands: $configs");

      if (configs.isEmpty) {
        return "Butler is confused. Try: 'Block YouTube' or 'Block games on weekends'.";
      }

      int successCount = 0;
      final prefs = await SharedPreferences.getInstance();

      for (var config in configs) {
        final String target = config['target']?.toString() ?? '';
        final String targetType = config['target_type']?.toString() ?? '';
        final String actionType = config['action_type']?.toString() ?? 'schedule';
        final List<dynamic> daysDyn = config['allowed_days'] ?? [1, 2, 3, 4, 5, 6, 7];
        final List<int> days = daysDyn.map((e) => int.parse(e.toString())).toList();
        
        final String startStr = config['start_time']?.toString() ?? '';
        final String endStr = config['end_time']?.toString() ?? '';
        final int? maxDailyMinutes = config['max_daily_minutes'] != null ? int.tryParse(config['max_daily_minutes'].toString()) : null;
        
        print("Parsing Command -> Target: $target, Type: $targetType, Action: $actionType, Days: $days, Start: ${startStr.isEmpty ? 'Not set' : startStr}, End: ${endStr.isEmpty ? 'Not set' : endStr}, Max Limit: $maxDailyMinutes");
        
        TimeOfDay? parseTime(String? timeStr) {
          if (timeStr == null || timeStr.trim().isEmpty) return null;
          try {
            final parts = timeStr.split(':');
            if (parts.length == 2) {
              return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            }
          } catch (e) {
            print("Time parsing error for $timeStr: $e");
          }
          return null;
        }

        final startTime = parseTime(startStr);
        final endTime = parseTime(endStr);

        List<AppUsageModel> matchingApps = [];
        final lowerTarget = target.toLowerCase();
        
        if (targetType.toLowerCase() == 'category') {
          matchingApps = _appUsages.where((app) => app.category.toLowerCase() == lowerTarget).toList();
        } else if (targetType.toLowerCase() == 'app') {
          matchingApps = _appUsages.where((app) => app.appName.toLowerCase() == lowerTarget).toList();
        }

        if (matchingApps.isEmpty) {
          print("[FAILED ❌] No matching apps found for Target: $target (Type: $targetType)");
        } else {
          for (var app in matchingApps) {
            if (app.packageName == myPackageName) continue;
            
            print("[MATCH ✅] Updating ${app.appName} (Category: ${app.category})");
            
            if (actionType == 'manual_block') {
              app.isManuallyBlocked = true;
              final savedManuallyBlockedApps = prefs.getStringList('manually_blocked_apps') ?? [];
              if (!savedManuallyBlockedApps.contains(app.packageName)) {
                savedManuallyBlockedApps.add(app.packageName);
              }
              await prefs.setStringList('manually_blocked_apps', savedManuallyBlockedApps);
              app.isBlocked = _shouldBeBlockedNow(app);
              successCount++;
            } else if (actionType == 'unblock') {
              app.isManuallyBlocked = false;
              final savedManuallyBlockedApps = prefs.getStringList('manually_blocked_apps') ?? [];
              savedManuallyBlockedApps.remove(app.packageName);
              await prefs.setStringList('manually_blocked_apps', savedManuallyBlockedApps);
              app.isBlocked = _shouldBeBlockedNow(app);
              await saveSchedule(app.packageName, [1, 2, 3, 4, 5, 6, 7], null, null, null);
              successCount++;
            } else {
              await saveSchedule(app.packageName, days, startTime, endTime, maxDailyMinutes ?? app.maxDailyMinutes);
              successCount++;
            }
          }
        }
      }
      
      final blockedList = _appUsages.where((app) => app.isBlocked && app.packageName != myPackageName).map((app) => app.packageName).toList();
      await _updateNativeService(blockedList);

      if (successCount > 0) {
        return "Butler: Executed successfully on $successCount apps.";
      } else {
        return "Butler is confused. Try: 'Block YouTube' or 'Block games on weekends'.";
      }
    } catch (e) {
      print("=== 🚨 NLP ERROR ===");
      print("Exception: $e");
      return "Butler failed to process the request.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
