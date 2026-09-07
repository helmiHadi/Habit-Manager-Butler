import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../features/dashboard/providers/app_usage_provider.dart';
import '../../../../features/pairing/presentation/screens/pairing_screen.dart';
import 'remote_schedule_screen.dart';
import 'package:screen_time_app/features/dashboard/presentation/widgets/shared_empty_state.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  // ─── Child device tile ─────────────────────────────────────────────────────

  Widget _buildChildTile(BuildContext context, String code, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RemoteScheduleScreen(pairingCode: code),
            ),
          ),
          onLongPress: () => _confirmRemove(context, code),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1C2840),
                  const Color(0xFF1C1C2E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.dmSans(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Labels
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Child Device',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A2A10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.greenAccent.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Active',
                                style: GoogleFonts.dmSans(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Code: $code',
                              style: GoogleFonts.dmMono(
                                color: Colors.white38,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _navigateToPairing(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PairingScreen(addingChild: true)),
    );
  }

  Future<void> _confirmRemove(BuildContext context, String code) async {
    final provider = context.read<AppUsageProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Device?',
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove child device with code "$code"?\n\nYou can reconnect it at any time.',
          style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.removePairedChild(code);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the list rebuilds whenever pairedChildren changes.
    final pairedChildren = context.watch<AppUsageProvider>().pairedChildren;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          'Managed Profiles',
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (pairedChildren.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.blueAccent),
              tooltip: 'Add another child device',
              onPressed: () => _navigateToPairing(context),
            ),
        ],
      ),

      body: pairedChildren.isEmpty
          ? SharedEmptyState(
              icon: Icons.family_restroom,
              title: "No Devices Linked",
              subtitle: "Tap the + button to pair a child device.",
              action: ElevatedButton.icon(
                onPressed: () => _navigateToPairing(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text('Add Child Device', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header summary ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        '${pairedChildren.length} device${pairedChildren.length == 1 ? '' : 's'} connected',
                        style: GoogleFonts.dmSans(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Long-press to remove',
                        style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // ── Dynamic device list ─────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 100),
                    itemCount: pairedChildren.length,
                    itemBuilder: (context, index) =>
                        _buildChildTile(context, pairedChildren[index], index),
                  ),
                ),
              ],
            ),

      // ── Add Device FAB ──────────────────────────────────────────────────────
      floatingActionButton: pairedChildren.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToPairing(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Add Device', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
