import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:installed_apps/installed_apps.dart';

import 'package:screen_time_app/features/dashboard/providers/app_usage_provider.dart';
import 'package:screen_time_app/core/routing/app_router.dart';
import 'package:screen_time_app/core/ai/ai_categorization_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();

  int _currentPage = 0;
  String _selectedRole = 'standalone'; // 'standalone' (Manage Myself) vs 'parent' (Manage Family/Child)
  String _selectedLevel = 'Strict Manager'; // 'Gentle Nudge', 'Strict Manager', 'Ruthless Gatekeeper'
  
  static const _channel = MethodChannel('com.butler.app/blocker');
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;
  bool _categorizationStarted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool usage = await _channel.invokeMethod('checkUsageStatsPermission');
      final bool overlay = await _channel.invokeMethod('checkOverlayPermission');
      setState(() {
        _hasUsagePermission = usage;
        _hasOverlayPermission = overlay;
      });
      
      if (usage && overlay) {
        _startSilentCategorization();
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> _requestUsage() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
      Future.delayed(const Duration(seconds: 1), _checkPermissions);
    } catch (e) {
      debugPrint('Error requesting usage stats permission: $e');
    }
  }

  Future<void> _requestOverlay() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
      Future.delayed(const Duration(seconds: 1), _checkPermissions);
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }

  void _startSilentCategorization() {
    if (_categorizationStarted) return;
    _categorizationStarted = true;

    Future.microtask(() async {
      try {
        final apps = await InstalledApps.getInstalledApps(
          excludeSystemApps: false,
          withIcon: false,
        );
        final categorizer = AICategorizationService();
        await categorizer.categorizeApps(apps);
        debugPrint('=== ONBOARDING: Silent categorization complete ===');
      } catch (e) {
        debugPrint('=== ONBOARDING: Silent categorization error: $e ===');
      }
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);
    await prefs.setString('app_role', _selectedRole);
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('ai_critic_level', _selectedLevel);

    String roastLevel = 'Snarky';
    if (_selectedLevel == 'Gentle Nudge') roastLevel = 'Gentle';
    else if (_selectedLevel == 'Strict Manager') roastLevel = 'Snarky';
    else if (_selectedLevel == 'Ruthless Gatekeeper') roastLevel = 'Ruthless';
    await prefs.setString('roast_level', roastLevel);

    if (mounted) {
      final provider = context.read<AppUsageProvider>();
      await provider.setAppRole(_selectedRole);
      await provider.setRoastLevel(roastLevel);

      final route = _selectedRole == 'parent'
          ? AppRouter.parentDashboardRoute
          : AppRouter.dashboardRoute;

      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                  if (page == 4) {
                    _checkPermissions();
                  }
                },
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                  _buildPage5(),
                ],
              ),
            ),
            _buildNavigationRow(),
          ],
        ),
      ),
    );
  }

  // ── Page 1: The Hook ────────────────────────────────────────────────────────
  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'lib/assets/icon.png',
            width: 140,
            height: 140,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 64,
                  color: Colors.blueAccent,
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          Text(
            'Butler',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mengambil alih kendali waktu digital Anda',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: Colors.white60,
              fontSize: 18,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 2: Role Selection ─────────────────────────────────────────────────
  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mode Penggunaan',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih bagaimana Anda ingin menggunakan Butler.',
            style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 36),
          _buildRoleCard(
            role: 'standalone',
            title: 'Manage Myself',
            description: 'Monitor dan kelola batas screen time pada perangkat ini secara mandiri.',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            role: 'parent',
            title: 'Manage Family/Child',
            description: 'Kelola batas waktu dan aturan pemblokiran perangkat anak dari jarak jauh.',
            icon: Icons.family_restroom_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF181824) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? Colors.blueAccent : Colors.white60,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 3: Personalization ────────────────────────────────────────────────
  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil Anda',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bagaimana saya harus memanggil Anda?',
            style: GoogleFonts.dmSans(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Masukkan nama panggilan Anda',
              hintStyle: GoogleFonts.dmSans(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF141416),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 4: AI Critic Level ────────────────────────────────────────────────
  Widget _buildPage4() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level Kritik AI',
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seberapa keras kritik AI ketika Anda melewati batas waktu?',
            style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 36),
          _buildLevelCard(
            level: 'Gentle Nudge',
            description: 'Kritik sopan untuk mengingatkan Anda agar beristirahat.',
            tag: 'Level 1',
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            level: 'Strict Manager',
            description: 'Sindiran sarkastik dan pengingat tegas dari sang Butler.',
            tag: 'Level 2',
          ),
          const SizedBox(height: 12),
          _buildLevelCard(
            level: 'Ruthless Gatekeeper',
            description: 'Roasting tanpa ampun jika Anda membuang-buang waktu.',
            tag: 'Level 3',
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard({
    required String level,
    required String description,
    required String tag,
  }) {
    final isSelected = _selectedLevel == level;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLevel = level;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF181824) : const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        level,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.dmSans(
                            color: isSelected ? Colors.blueAccent : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.blueAccent : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  // ── Page 5: Permissions Gate ───────────────────────────────────────────────
  Widget _buildPage5() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Izin Akses',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Agar saya bisa menjaga gerbang digital Anda, saya butuh beberapa kunci.',
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 36),
            _buildPermissionTile(
              title: 'Usage Stats Permission',
              description: 'Digunakan untuk menghitung durasi pemakaian aplikasi secara real-time.',
              isGranted: _hasUsagePermission,
              onRequest: _requestUsage,
            ),
            const SizedBox(height: 16),
            _buildPermissionTile(
              title: 'Overlay Permission',
              description: 'Diperlukan untuk memunculkan layar pemblokiran ketika batas waktu tercapai.',
              isGranted: _hasOverlayPermission,
              onRequest: _requestOverlay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              isGranted
                  ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
                  : const Icon(Icons.error_outline_rounded, color: Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: GoogleFonts.dmSans(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isGranted ? Colors.white.withOpacity(0.05) : Colors.white10,
                foregroundColor: isGranted ? Colors.white30 : Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isGranted ? null : onRequest,
              child: Text(
                isGranted ? 'Akses Diberikan' : 'Izinkan Akses',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Row ──────────────────────────────────────────────────
  Widget _buildNavigationRow() {
    final isLastPage = _currentPage == 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Text(
                'Back',
                style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            )
          else
            const SizedBox(width: 60),
          SmoothPageIndicator(
            controller: _pageController,
            count: 5,
            effect: const WormEffect(
              activeDotColor: Colors.blueAccent,
              dotColor: Colors.white12,
              dotHeight: 8,
              dotWidth: 8,
              spacing: 8,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isLastPage ? Colors.blueAccent : Colors.white10,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: isLastPage ? _completeOnboarding : () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Text(
              isLastPage ? 'Get Started' : 'Next',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
