import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screen_time_app/core/routing/app_router.dart';
import '../../providers/app_usage_provider.dart';
import '../widgets/shared_app_list_tile.dart';
import '../widgets/shared_schedule_bottom_sheet.dart';
import '../widgets/carousel_summary_card.dart';
import '../widgets/shared_empty_state.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../screens/settings_screen.dart';
import '../screens/analytics_screen.dart';
import 'package:screen_time_app/features/pairing/presentation/screens/pairing_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _channel = MethodChannel('com.butler.app/blocker');
  final PageController _pageController = PageController();

  Future<void> _checkPermissions() async {
    try {
      final bool hasUsage = await _channel.invokeMethod('checkUsageStatsPermission');
      if (!hasUsage) {
        await _channel.invokeMethod('requestUsageStatsPermission');
      }

      final bool hasOverlay = await _channel.invokeMethod('checkOverlayPermission');
      if (!hasOverlay) {
        await _channel.invokeMethod('requestOverlayPermission');
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  void _showExitDialog(BuildContext context) {
    final TextEditingController pinController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Parental Unlock',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the 6-digit pairing PIN to exit child mode.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter 6-digit pairing code',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () async {
                final input = pinController.text.trim();
                final provider = context.read<AppUsageProvider>();
                
                final savedCode = provider.pairingCode ?? '';
                if (input == savedCode && savedCode.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('hasCompletedOnboarding');
                  await prefs.remove('app_role');
                  await prefs.remove('pairing_code');
                  
                  await provider.setRole('standalone', '');
                  
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRouter.onboardingRoute,
                      (route) => false,
                    );
                  }
                } else {
                  pinController.clear();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Incorrect PIN. Access Denied.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text('Unlock', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }


  void _showNLPBottomSheet(BuildContext context) {
    final TextEditingController nlpController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Consumer<AppUsageProvider>(
              builder: (context, provider, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Butler AI Scheduler',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ask Butler to manage your screen time schedules naturally.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nlpController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g., Block social media on weekdays',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: provider.isLoading ? null : () async {
                          final input = nlpController.text.trim();
                          if (input.isNotEmpty) {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            
                            final result = await provider.executeNLPCommand(input);
                            
                            if (context.mounted) Navigator.pop(context);
                            scaffoldMessenger.hideCurrentSnackBar();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text(result)),
                            );
                          }
                        },
                        child: provider.isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Ask Butler', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'social':
        return Icons.chat_bubble_outline;
      case 'entertainment':
        return Icons.play_circle_outline;
      case 'communication':
        return Icons.message_outlined;
      case 'productivity':
        return Icons.work_outline;
      case 'navigation':
        return Icons.map_outlined;
      default:
        return Icons.apps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUsageProvider = context.watch<AppUsageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            if (appUsageProvider.appRole == 'child') {
              _showExitDialog(context);
            }
          },
          child: const Text('Screen Time'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'The Butler\'s Audit',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'Check Permissions',
            onPressed: _checkPermissions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNLPBottomSheet(context),
        child: const Icon(Icons.auto_awesome),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Remote Management Card
              GestureDetector(
                onTap: () {
                  if (appUsageProvider.isRoleLocked) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: const Text('Access Denied', style: TextStyle(color: Colors.redAccent)),
                        content: const Text('This device is locked by the Parent.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PairingScreen()),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5E5CE6), Color(0xFF3A3A3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.family_restroom, color: Colors.white, size: 32),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Family Setup', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Manage remote devices or pair a child device', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),

              // Analytics Carousel
              SizedBox(
                height: 220,
                child: PageView(
                  controller: _pageController,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(initialTabIndex: 0),
                          ),
                        );
                      },
                      child: CarouselSummaryCard(
                        title: "Today's Screen Time",
                        currentMinutes: appUsageProvider.totalScreenTimeMinutes,
                        previousMinutes: appUsageProvider.yesterdayUsage,
                        gradientColors: const [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                        period: Period.today,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(initialTabIndex: 1),
                          ),
                        );
                      },
                      child: CarouselSummaryCard(
                        title: "This Week",
                        currentMinutes: appUsageProvider.getWeeklyUsage(),
                        previousMinutes: appUsageProvider.lastWeekUsage,
                        gradientColors: const [Color(0xFF3A3A3C), Color(0xFF2C2C2E)],
                        period: Period.week,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(initialTabIndex: 2),
                          ),
                        );
                      },
                      child: CarouselSummaryCard(
                        title: "This Month",
                        currentMinutes: appUsageProvider.getMonthlyUsage(),
                        previousMinutes: appUsageProvider.lastMonthUsage,
                        gradientColors: const [Color(0xFF48484A), Color(0xFF3A3A3C)],
                        period: Period.month,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: 3,
                  effect: const ExpandingDotsEffect(
                    activeDotColor: Colors.white,
                    dotColor: Colors.white24,
                    dotHeight: 8,
                    dotWidth: 8,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              


              
              // App Usage List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Most Used Apps',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  FilterChip(
                    label: const Text('Show System Apps', style: TextStyle(fontSize: 12)),
                    selected: appUsageProvider.showSystemApps,
                    onSelected: (bool value) {
                      appUsageProvider.toggleSystemApps(value);
                    },
                    backgroundColor: const Color(0xFF2C2C2E),
                    selectedColor: Colors.blueAccent.withOpacity(0.3),
                    checkmarkColor: Colors.blueAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (appUsageProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (appUsageProvider.appUsages.isEmpty)
                const SharedEmptyState(
                  icon: Icons.apps_outage,
                  title: "No Apps Found",
                  subtitle: "Waiting for app synchronization.",
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appUsageProvider.appUsages.length,
                  itemBuilder: (context, index) {
                    final usage = appUsageProvider.appUsages[index];
                    return SharedAppListTile(
                      key: ValueKey(usage.packageName),
                      appName: usage.appName,
                      packageName: usage.packageName,
                      category: usage.category,
                      usageTime: _formatDuration(usage.dailyUsageMinutes),
                      iconData: usage.iconData,
                      fallbackIcon: _getCategoryIcon(usage.category),
                      isBlocked: usage.isBlocked,
                      maxDailyMinutes: usage.maxDailyMinutes,
                      dailyUsageMinutes: usage.dailyUsageMinutes,
                      isChildMode: appUsageProvider.appRole == 'child',
                      onTap: appUsageProvider.appRole == 'child'
                          // ── Child: read-only info dialog ────────────────
                          ? () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1C1C1E),
                                  title: Text(usage.appName,
                                      style: const TextStyle(color: Colors.white)),
                                  content: Text(
                                    'Usage: ${_formatDuration(usage.dailyUsageMinutes)}\n'
                                    'Limit: ${usage.maxDailyMinutes != null ? '${usage.maxDailyMinutes}m' : 'None'}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          // ── Parent / Standalone: SharedScheduleBottomSheet
                          : () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) =>
                                    SharedScheduleBottomSheet(
                                  appName: usage.appName,
                                  packageName: usage.packageName,
                                  initialAllowedDays: usage.allowedDays,
                                  initialStartTime: usage.startTime,
                                  initialEndTime: usage.endTime,
                                  initialMaxDailyMinutes: usage.maxDailyMinutes,
                                  // ── LOCAL onSave: writes to SQLite ───────
                                  onSave: (days, start, end, limit) {
                                    appUsageProvider.saveSchedule(
                                      usage.packageName,
                                      days,
                                      start,
                                      end,
                                      limit,
                                    );
                                  },
                                ),
                              );
                            },
                      onToggleBlock: (_) {
                        appUsageProvider.toggleBlockState(usage.packageName);
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
