import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screen_time_app/core/ai/ai_categorization_service.dart';
import 'package:screen_time_app/core/cloud/cloud_sync_service.dart';
import 'package:screen_time_app/main.dart';
import '../widgets/shared_app_list_tile.dart';
import '../widgets/shared_schedule_bottom_sheet.dart';
import '../widgets/shared_empty_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RemoteScheduleScreen  (Phase 55 – fully mirrors Normal Mode UX)
// ─────────────────────────────────────────────────────────────────────────────
//
// Layout:
//   • Compact SharedAppListTile rows  ← identical to DashboardScreen
//   • Tap a row  → SharedScheduleBottomSheet  ← identical sheet UI
//     onSave writes into the local _draft map instead of SQLite
//   • Purple ✨ FAB  → AI auto-categorises child apps and updates drafts
//   • Green ☁ AppBar button → pushes all non-default drafts to the cloud
//
// Per-package draft structure:
//   {
//     'isManuallyBlocked': bool,
//     'maxDailyMinutes':   int?,
//     'allowedDays':       List<int>,   // 1=Mon … 7=Sun
//     'startTime':         String?,     // "HH:MM" or null
//     'endTime':           String?,     // "HH:MM" or null
//     'category':          String,
//   }
// ─────────────────────────────────────────────────────────────────────────────

class RemoteScheduleScreen extends StatefulWidget {
  final String pairingCode;
  const RemoteScheduleScreen({super.key, required this.pairingCode});

  @override
  State<RemoteScheduleScreen> createState() => _RemoteScheduleScreenState();
}

class _RemoteScheduleScreenState extends State<RemoteScheduleScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  List<dynamic> _childApps = [];
  Map<String, Map<String, dynamic>> _draft = {};

  bool _isLoading  = false;
  bool _isAiRunning = false;
  bool _isSyncing  = false;

  // Search + filter
  String _searchQuery   = '';
  String _filterCategory = 'All';

  // ── Best-practice limits per category (minutes). null = Unlimited ─────────
  static const Map<String, int?> _bestPracticeLimits = {
    'Social':            30,
    'Games':             20,
    'Messaging':         45,
    'Entertainment':     60,
    'News':              30,
    'Shopping':          20,
    'Food & Drink':      15,
    'Productivity':      null,
    'Education':         null,
    'Health & Fitness':  null,
    'Browser':           null,
    'Maps & Navigation': null,
    'Finance':           null,
    'Music & Audio':     90,
    'Photography':       30,
    'Utilities':         null,
    'System':            null,
    'Others':            null,
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchChildApps();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _encodeTime(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _defaultDraft() => {
        'isManuallyBlocked': false,
        'maxDailyMinutes':   null,
        'allowedDays':       [1, 2, 3, 4, 5, 6, 7],
        'startTime':         null,
        'endTime':           null,
        'category':          'Others',
      };

  String _fmtLimit(int? m) {
    if (m == null) return 'No limit';
    if (m == 0)   return 'Blocked';
    if (m < 60)   return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Social':        return Icons.chat_bubble_outline;
      case 'Games':         return Icons.sports_esports_outlined;
      case 'Messaging':     return Icons.message_outlined;
      case 'Entertainment': return Icons.play_circle_outline;
      case 'Productivity':  return Icons.work_outline;
      case 'Education':     return Icons.school_outlined;
      case 'System':        return Icons.settings_outlined;
      case 'Browser':       return Icons.language_outlined;
      case 'Music & Audio': return Icons.music_note_outlined;
      case 'Health & Fitness': return Icons.fitness_center_outlined;
      default:              return Icons.apps;
    }
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchChildApps() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        CloudSyncService(client).getChildAppList(widget.pairingCode),
        CloudSyncService(client).getCloudConfig(widget.pairingCode),
      ]);

      final appListRaw    = results[0];
      final savedConfigRaw = results[1];

      // 1. Parse app list
      if (appListRaw != null) {
        final decoded = jsonDecode(appListRaw) as List<dynamic>;
        setState(() {
          _childApps = decoded;
          for (final app in decoded) {
            final pkg = app['packageName'] as String? ?? '';
            if (pkg.isNotEmpty) _draft[pkg] ??= _defaultDraft();
          }
        });
      }

      // 2. Merge saved config (Parent-Amnesia fix)
      if (savedConfigRaw != null) {
        try {
          final saved      = jsonDecode(savedConfigRaw) as Map<String, dynamic>;
          final targetApp  = saved['targetApp'] as String?;
          if (targetApp != null && _draft.containsKey(targetApp)) {
            setState(() {
              final d = _draft[targetApp]!;
              if (saved.containsKey('isManuallyBlocked'))
                d['isManuallyBlocked'] = saved['isManuallyBlocked'] as bool? ?? false;
              if (saved.containsKey('maxDailyMinutes'))
                d['maxDailyMinutes'] = saved['maxDailyMinutes'] as int?;
              if (saved.containsKey('allowedDays')) {
                final raw = saved['allowedDays'];
                if (raw is List)
                  d['allowedDays'] = raw.map((e) => int.tryParse(e.toString()) ?? 1).toList();
              }
              if (saved.containsKey('startTime')) d['startTime'] = saved['startTime'];
              if (saved.containsKey('endTime'))   d['endTime']   = saved['endTime'];
            });
            debugPrint('=== 📲 PARENT AMNESIA FIX: Restored config for $targetApp ===');
          }
        } catch (e) {
          debugPrint('Warning: Could not parse saved config: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching child data: $e');
    }
    setState(() => _isLoading = false);
  }

  // ── AI Auto-Categorize FAB (matches local DashboardScreen FAB exactly) ────

  Future<void> _runAiCategorization() async {
    if (_childApps.isEmpty || _isAiRunning) return;
    setState(() => _isAiRunning = true);

    try {
      final appMaps = _childApps.map((a) => {
            'packageName': (a['packageName'] as String?) ?? '',
            'appName':     (a['appName']     as String?) ?? '',
          }).toList();

      final categorizer  = AICategorizationService();
      final categoryMap  = await categorizer.categorizeFromMap(appMaps);

      int applied = 0;
      setState(() {
        for (final app in _childApps) {
          final pkg = app['packageName'] as String? ?? '';
          if (pkg.isEmpty) continue;

          final category = categoryMap[pkg] ?? 'Others';
          final limit    = _bestPracticeLimits[category];

          _draft[pkg] ??= _defaultDraft();
          _draft[pkg]!['category']        = category;
          _draft[pkg]!['maxDailyMinutes'] = limit;
          if (limit != null && limit == 0) {
            _draft[pkg]!['isManuallyBlocked'] = true;
          }
          applied++;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✨ AI applied best-practice limits to $applied apps. Review & sync!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple[700],
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      debugPrint('AI categorization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('AI categorization failed. Check your API key.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    }

    setState(() => _isAiRunning = false);
  }

  // ── Sync draft → cloud ────────────────────────────────────────────────────
  //
  // CRITICAL FIX: the old approach called pushConfigToCloud once per app in a
  // loop.  Because the server stores ONE config slot per pairing code, every
  // call overwrote the previous one — only the LAST app in the loop survived.
  //
  // Fix: collect ALL modified app configs into a single List payload and push
  // it in ONE call wrapped under the key "bulkConfig".  The child listener
  // detects this key and iterates the list, applying every entry.
  Future<void> _syncToChild() async {
    // Collect every entry that has at least one non-default value.
    final List<Map<String, dynamic>> payload = [];

    for (final entry in _draft.entries) {
      final pkg       = entry.key;
      final d         = entry.value;
      final isBlocked = d['isManuallyBlocked'] as bool? ?? false;
      final maxMins   = d['maxDailyMinutes']   as int?;
      final days      = (d['allowedDays'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];
      final startTime = d['startTime'] as String?;
      final endTime   = d['endTime']   as String?;

      // Include this app if ANY field differs from the default state.
      final hasChanges = isBlocked ||
          maxMins != null ||
          days.length != 7 ||
          startTime != null ||
          endTime   != null;
      if (!hasChanges) continue;

      payload.add(<String, dynamic>{
        'targetApp':         pkg,
        'isManuallyBlocked': isBlocked,
        'allowedDays':       days,
        if (maxMins != null)   'maxDailyMinutes': maxMins,
        if (startTime != null) 'startTime': startTime,
        if (endTime   != null) 'endTime':   endTime,
      });
    }

    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No changes detected to sync.'),
      ));
      return;
    }

    setState(() => _isSyncing = true);

    // Push the entire batch in a SINGLE call.
    // The server stores this as one JSON blob; the child listener detects
    // the "bulkConfig" key and applies each entry in the list.
    await CloudSyncService(client).pushConfigToCloud(
      <String, dynamic>{'bulkConfig': payload},
      widget.pairingCode,
    );

    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '☁️ Synced ${payload.length} rule(s) to child device.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[800],
      ));
    }
  }

  // ── REMOTE onSave: updates draft map (called from SharedScheduleBottomSheet)
  void _onSaveSchedule(
    String pkg,
    List<int>    days,
    TimeOfDay?   start,
    TimeOfDay?   end,
    int?         limit,
    bool         isBlocked,
  ) {
    setState(() {
      _draft[pkg] ??= _defaultDraft();
      _draft[pkg]!['allowedDays']       = days;
      _draft[pkg]!['startTime']         = _encodeTime(start);
      _draft[pkg]!['endTime']           = _encodeTime(end);
      _draft[pkg]!['maxDailyMinutes']   = limit;
      _draft[pkg]!['isManuallyBlocked'] = isBlocked;
    });
  }

  // ── Open scheduling bottom sheet for one app ──────────────────────────────

  void _openScheduleSheet(BuildContext context, String pkg, String appName) {
    final d = _draft[pkg] ?? _defaultDraft();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharedScheduleBottomSheet(
        appName:                appName,
        packageName:            pkg,
        initialAllowedDays:     (d['allowedDays'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7],
        initialStartTime:       _parseTime(d['startTime'] as String?),
        initialEndTime:         _parseTime(d['endTime']   as String?),
        initialMaxDailyMinutes: d['maxDailyMinutes'] as int?,
        // ── REMOTE onSave: writes to _draft, NOT SQLite ──────────────────
        // CRITICAL: read isManuallyBlocked from _draft at save-time, not
        // from the 'd' snapshot captured when the sheet was opened.  The
        // user may have toggled the block switch WHILE the sheet is open
        // (or before opening it); stale capture would silently revert it.
        onSave: (days, start, end, limit) {
          _onSaveSchedule(
            pkg, days, start, end, limit,
            (_draft[pkg] ?? _defaultDraft())['isManuallyBlocked'] as bool? ?? false,
          );
        },
      ),
    );
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  List<dynamic> get _filteredApps {
    return _childApps.where((app) {
      final name     = (app['appName']     as String? ?? '').toLowerCase();
      final pkg      = (app['packageName'] as String? ?? '').toLowerCase();
      final category = (_draft[app['packageName']]?['category'] as String?) ?? 'Others';

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) || pkg.contains(_searchQuery);
      final matchesFilter =
          _filterCategory == 'All' || category == _filterCategory;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  List<String> get _availableCategories {
    final cats = <String>{'All'};
    for (final d in _draft.values) {
      cats.add(d['category'] as String? ?? 'Others');
    }
    final sorted = cats.toList()..sort();
    // Always put "All" first
    sorted.remove('All');
    return ['All', ...sorted];
  }

  int get _modifiedCount => _draft.values.where((d) {
        return (d['isManuallyBlocked'] as bool? ?? false) ||
            d['maxDailyMinutes'] != null ||
            (d['allowedDays'] as List?)?.length != 7 ||
            d['startTime'] != null ||
            d['endTime']   != null;
      }).length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered  = _filteredApps;
    final modCount  = _modifiedCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remote Schedule',
              style: GoogleFonts.dmSans(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Device [${widget.pairingCode}]',
              style: GoogleFonts.dmMono(
                  color: Colors.white38, fontSize: 11, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          // Sync button with pending-changes badge
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.greenAccent, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_rounded,
                        color: Colors.greenAccent),
                tooltip: 'Sync & Apply to Child',
                onPressed: (_isSyncing || _isLoading) ? null : _syncToChild,
              ),
              if (modCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.orangeAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        modCount > 9 ? '9+' : '$modCount',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── AI FAB — purple rounded square with stars (matches local mode) ──
      floatingActionButton: FloatingActionButton(
        heroTag: 'ai_remote_fab',
        onPressed: _isAiRunning ? null : _runAiCategorization,
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
        tooltip: 'AI: Apply Best-Practice Limits',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: _isAiRunning
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.auto_awesome, size: 26),
      ),

      // ── Body ────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Info banner
          _InfoBanner(
            pairingCode:   widget.pairingCode,
            modifiedCount: modCount,
          ),

          // Search + filter
          if (_childApps.isNotEmpty) ...[
            _CategoryFilterBar(
              categories: _availableCategories,
              selected:   _filterCategory,
              onSelected: (cat) => setState(() => _filterCategory = cat),
            ),
          ],

          // App list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.deepPurpleAccent))
                : _childApps.isEmpty
                    ? SharedEmptyState(
                        icon: Icons.apps_outage_rounded,
                        title: "No Apps Found",
                        subtitle: "Waiting for app synchronization.",
                        action: TextButton.icon(
                          onPressed: _fetchChildApps,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text('Retry',
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No apps match "$_searchQuery".',
                              style: GoogleFonts.dmSans(color: Colors.white38),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 8, 12, 100),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final app     = filtered[i];
                              final pkg     = app['packageName'] as String? ?? '';
                              final appName = app['appName']     as String? ?? pkg;
                              final d       = _draft[pkg] ?? _defaultDraft();

                              final isBlocked  = d['isManuallyBlocked'] as bool? ?? false;
                              final maxMins    = d['maxDailyMinutes']   as int?;
                              final category   = d['category']          as String? ?? 'Others';

                              // ── Usage time label for remote mode ────────
                              // We don't have real usage data; show the
                              // configured limit so the Parent can see it
                              // at-a-glance without opening the sheet.
                              final trailingLabel = isBlocked
                                  ? 'Blocked'
                                  : _fmtLimit(maxMins);

                              return SharedAppListTile(
                                key: ValueKey(pkg),
                                appName:     appName,
                                packageName: pkg,
                                category:    category,
                                // Show limit / "Blocked" instead of usage time
                                usageTime:   trailingLabel,
                                // No icon bytes from cloud; use category icon
                                iconData:    null,
                                fallbackIcon: _categoryIcon(category),
                                isBlocked:   isBlocked,
                                // No live usage data in remote mode
                                maxDailyMinutes:   null,
                                dailyUsageMinutes: 0,
                                isChildMode: false,
                                showIcon:    false,
                                // ── Tap → SharedScheduleBottomSheet ────────
                                onTap: () => _openScheduleSheet(
                                    context, pkg, appName),
                                // ── Block switch → update draft ────────────
                                onToggleBlock: (val) => setState(() {
                                  _draft[pkg] ??= _defaultDraft();
                                  _draft[pkg]!['isManuallyBlocked'] = val;
                                }),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String pairingCode;
  final int modifiedCount;

  const _InfoBanner({required this.pairingCode, required this.modifiedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.blue[900]!.withValues(alpha: 0.9),
          Colors.blue[900]!.withValues(alpha: 0.5),
        ]),
        border: const Border(
            bottom: BorderSide(color: Color(0xFF1A3A5C), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_sync_rounded,
              color: Colors.blueAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap an app to set its schedule. Changes sync on ☁ button.',
              style: GoogleFonts.dmSans(color: Colors.white60, fontSize: 12),
            ),
          ),
          if (modifiedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                '$modifiedCount pending',
                style: GoogleFonts.dmSans(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final cat        = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.deepPurpleAccent.withValues(alpha: 0.25)
                    : const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.deepPurpleAccent
                      : Colors.white12,
                  width: 1,
                ),
              ),
              child: Text(
                cat,
                style: GoogleFonts.dmSans(
                  color: isSelected ? Colors.deepPurpleAccent : Colors.white38,
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


