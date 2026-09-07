import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_usage_provider.dart';
import '../../../pairing/presentation/screens/pairing_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppUsageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_remote),
            tooltip: 'Remote Control',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PairingScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Butler Configuration',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildSettingsCard(
              context: context,
              title: 'Roast Intensity',
              subtitle: 'Select how aggressively Butler should treat you.',
              icon: Icons.local_fire_department,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'Polite',
                          label: Text('Polite'),
                        ),
                        ButtonSegment<String>(
                          value: 'Snarky',
                          label: Text('Snarky'),
                        ),
                        ButtonSegment<String>(
                          value: 'Savage',
                          label: Text('Savage'),
                        ),
                      ],
                      selected: {
                        ['Polite', 'Snarky', 'Savage'].contains(provider.roastLevel)
                            ? provider.roastLevel
                            : 'Snarky'
                      },
                      onSelectionChanged: provider.isLoading 
                          ? null 
                          : (Set<String> newSelection) {
                              provider.setRoastLevel(newSelection.first);
                            },
                    ),
                  ),
                  if (provider.isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Generating fresh roasts...',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Future Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsCard(
              context: context,
              title: 'Advanced Analytics',
              subtitle: 'Coming soon in the next phase.',
              icon: Icons.analytics_outlined,
              child: const SizedBox.shrink(),
              isDisabled: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    bool isDisabled = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isDisabled ? Colors.grey : Colors.blueAccent),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (child is! SizedBox) ...[
              const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
