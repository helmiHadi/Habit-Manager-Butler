import 'package:flutter/material.dart';
import 'package:screen_time_app/core/theme/app_colors.dart';
import 'dart:typed_data';

class AppUsageCard extends StatelessWidget {
  final String appName;
  final String usageTime;
  final String category;
  final Uint8List? iconData;
  final IconData fallbackIcon;
  final bool isBlocked;
  final int? maxDailyMinutes;
  final int dailyUsageMinutes;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleBlock;
  final bool isChildMode;

  const AppUsageCard({
    super.key,
    required this.appName,
    required this.usageTime,
    required this.category,
    this.iconData,
    this.fallbackIcon = Icons.apps,
    this.isBlocked = false,
    this.maxDailyMinutes,
    this.dailyUsageMinutes = 0,
    this.onTap,
    this.onToggleBlock,
    this.isChildMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: iconData != null
              ? Image.memory(iconData!, width: 24, height: 24)
              : Icon(fallbackIcon, color: AppColors.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ),
            if (maxDailyMinutes != null && maxDailyMinutes! > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (dailyUsageMinutes / maxDailyMinutes!).clamp(0.0, 1.0),
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  dailyUsageMinutes >= maxDailyMinutes! ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${dailyUsageMinutes}m / ${maxDailyMinutes}m used',
                style: TextStyle(
                  fontSize: 10,
                  color: dailyUsageMinutes >= maxDailyMinutes! ? Colors.redAccent : Colors.white70,
                ),
              ),
            ]
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              usageTime,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
            ),
            if (!isChildMode) ...[
              const SizedBox(width: 8),
              Switch(
                value: isBlocked,
                onChanged: onToggleBlock,
                activeColor: Colors.redAccent,
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
