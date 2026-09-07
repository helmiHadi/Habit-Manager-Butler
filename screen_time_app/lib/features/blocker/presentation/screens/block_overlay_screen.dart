import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../dashboard/providers/app_usage_provider.dart';

class BlockOverlayScreen extends StatefulWidget {
  final String appName;
  final String category;

  const BlockOverlayScreen({
    super.key,
    this.appName = 'this app',
    this.category = 'Unknown',
  });

  @override
  State<BlockOverlayScreen> createState() => _BlockOverlayScreenState();
}

class _BlockOverlayScreenState extends State<BlockOverlayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppUsageProvider>().fetchRoastForApp(
        widget.appName,
        widget.category,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final roast = context.watch<AppUsageProvider>().currentRoast;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_clock, color: Colors.white, size: 80),
                const SizedBox(height: 24),
                Text(
                  roast,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    // For testing purposes, we close the app or pop
                    SystemNavigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
