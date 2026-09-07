import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/dashboard/providers/app_usage_provider.dart';
import '../../../../features/dashboard/presentation/screens/parent_dashboard_screen.dart';

class PairingScreen extends StatefulWidget {
  /// Set to [true] when navigated from [ParentDashboardScreen] to add an
  /// additional child device.  Controls post-connect routing:
  ///   • false (default) → first-time setup → pushReplacement to Dashboard
  ///   • true            → adding extra    → pop() back to Dashboard
  final bool addingChild;

  const PairingScreen({super.key, this.addingChild = false});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();

  // The dynamically generated code for Child mode.
  // Persisted across rebuilds so it doesn't change when setState is called.
  String? _generatedChildCode;

  bool _isConnecting = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    // Only generate/load a child code when this screen is used in
    // child-setup mode.  When addingChild==true we are in Parent
    // code-entry mode — no child code needed.
    if (!widget.addingChild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initChildCode());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ─── Code Generation ────────────────────────────────────────────────────────

  /// Generates or retrieves the existing pairing code for this device.
  /// Once generated, the code is stable for the lifetime of the Child role.
  Future<void> _initChildCode() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('pairing_code');

    if (existing != null && existing.length == 6) {
      // Reuse the code already assigned to this device
      setState(() => _generatedChildCode = existing);
    } else {
      // Generate a fresh unique 6-digit code
      final code = _generateCode();
      await prefs.setString('pairing_code', code);

      // Persist via provider so the rest of the app is aware
      if (mounted) {
        await context.read<AppUsageProvider>().setPairingCode(code);
      }
      setState(() => _generatedChildCode = code);
    }
  }

  /// Returns a cryptographically-random 6-digit numeric string.
  String _generateCode() {
    final rng = Random.secure();
    final code = (rng.nextInt(900000) + 100000).toString(); // 100000–999999
    return code;
  }

  /// Regenerates a fresh code (e.g., user taps "Refresh" button).
  Future<void> _regenerateCode() async {
    final code = _generateCode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pairing_code', code);
    await context.read<AppUsageProvider>().setPairingCode(code);
    setState(() => _generatedChildCode = code);
  }

  // ─── Parent Connect ─────────────────────────────────────────────────────────

  Future<void> _connectAsParent() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _validationError = 'Please enter the 6-digit code from the child\'s device.');
      return;
    }
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _validationError = 'Code must be exactly 6 digits.');
      return;
    }

    setState(() {
      _validationError = null;
      _isConnecting    = true;
    });

    try {
      final provider = context.read<AppUsageProvider>();
      await provider.setRole('parent', code);

      if (mounted) {
        if (widget.addingChild) {
          // Came from the Dashboard FAB/AppBar "Add" button.
          // The provider already updated pairedChildren via setRole → addPairedChild.
          // Pop back so the Dashboard list rebuilds from the provider automatically.
          Navigator.pop(context);
        } else {
          // First-time Parent setup: replace the Pairing screen with the Dashboard.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _validationError = 'Connection failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Formats "839214" → "839 214" for readable display.
  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)} ${code.substring(3)}';
    }
    return code;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppUsageProvider>();
    final role     = provider.appRole;

    // ── FAST PATH: Adding a child from the Dashboard ───────────────────────
    // Skip the role-selector entirely and show the code-input panel directly.
    if (widget.addingChild) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          title: Text('Add Child Device',
              style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: _buildParentPanel(),
          ),
        ),
      );
    }

    // ── NORMAL PATH: First-time role selection ─────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Family Setup',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────────────
              Text(
                'Select Your Role',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This determines how Butler manages your device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // ── Role selector row ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _RoleCard(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Parent',
                    subtitle: 'Manage a child\'s device',
                    isSelected: role == 'parent',
                    activeColor: Colors.blueAccent,
                    onTap: () async {
                      // ── SMART ROUTING ──────────────────────────────────────
                      // If this device already has paired children, skip the
                      // code-entry panel and go straight to the Dashboard.
                      // Only show the input panel when this is the first pairing.
                      final provider = context.read<AppUsageProvider>();
                      if (provider.pairedChildren.isNotEmpty) {
                        // Already has children → go directly to Dashboard.
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ParentDashboardScreen()),
                          );
                        }
                      } else {
                        // No children yet → show the code-entry panel inline.
                        provider.setAppRole('parent');
                      }
                    },
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _RoleCard(
                    icon: Icons.child_care_rounded,
                    label: 'Child',
                    subtitle: 'Receive parental limits',
                    isSelected: role == 'child',
                    activeColor: Colors.cyanAccent,
                    onTap: () async {
                      await _initChildCode();
                      final code = _generatedChildCode;
                      if (code != null && mounted) {
                        await provider.setRole('child', code);
                      }
                    },
                  )),
                ],
              ),
              const SizedBox(height: 40),

              // ── Role-specific panel ────────────────────────────────────────
              if (role == 'child') _buildChildPanel()
              else if (role == 'parent') _buildParentPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Child Panel ─────────────────────────────────────────────────────────────

  Widget _buildChildPanel() {
    final code = _generatedChildCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          'Your Pairing Code',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),

        // Code display card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00C9FF).withOpacity(0.12), const Color(0xFF0A0A0A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: code == null
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2))
              : Column(
                  children: [
                    // Live code display with spacing
                    Text(
                      _formatCode(code),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 10,
                        color: Colors.cyanAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Copy button
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.cyanAccent),
                      label: Text('Copy Code', style: GoogleFonts.dmSans(color: Colors.cyanAccent, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),

        // Hint text
        Text(
          'Share this code with your parent.\nThey will enter it on their device to connect.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 20),

        // Regenerate button
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1E),
                title: const Text('Regenerate Code?', style: TextStyle(color: Colors.white)),
                content: const Text(
                  'Your current code will stop working. The Parent will need to reconnect with the new code.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Regenerate', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
            if (confirmed == true) await _regenerateCode();
          },
          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white38),
          label: Text('Generate New Code', style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13)),
        ),
      ],
    );
  }

  // ── Parent Panel ────────────────────────────────────────────────────────────

  Widget _buildParentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Connect to Child Device',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),

        // Code input
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 28, letterSpacing: 8, color: Colors.white, fontWeight: FontWeight.bold),
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) {
            if (_validationError != null) setState(() => _validationError = null);
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
            filled: true,
            fillColor: const Color(0xFF1C1C1E),
            contentPadding: const EdgeInsets.symmetric(vertical: 22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _validationError != null ? Colors.redAccent : Colors.blueAccent,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _validationError != null ? Colors.redAccent.withOpacity(0.6) : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Inline validation message
        if (_validationError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _validationError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: Colors.redAccent, fontSize: 12),
            ),
          ),

        const SizedBox(height: 16),

        // Connect button
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _isConnecting ? null : _connectAsParent,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              disabledBackgroundColor: Colors.blueAccent.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isConnecting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    'Connect',
                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Hint
        Text(
          'Enter the 6-digit code displayed on the child\'s device.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}

// ─── Role Card Widget ──────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : const Color(0xFF1C1C1E),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, size: 44, color: isSelected ? activeColor : Colors.white38),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: isSelected ? activeColor : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white30,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
