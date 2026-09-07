import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screen_time_app/core/theme/app_colors.dart';

/// A shared, pixel-perfect replica of the Normal Mode app list row.
///
/// Both [DashboardScreen] (local) and [RemoteScheduleScreen] (remote) use
/// this widget so the visual presentation is always identical.
///
/// Data differences are handled entirely via callbacks:
///   • [onTap]          – opens the scheduling bottom sheet (caller decides which one)
///   • [onToggleBlock]  – local: writes to DB; remote: updates draft map
class SharedAppListTile extends StatelessWidget {
  // ── Identity ─────────────────────────────────────────────────────────────
  final String appName;
  final String packageName;
  final String category;

  // ── Display values ────────────────────────────────────────────────────────
  /// Formatted usage string shown in the trailing area, e.g. "1h 23m" or "0m".
  /// Pass an empty string or "–" for remote mode where usage is unknown.
  final String usageTime;

  /// Raw icon bytes from the device (null in remote mode).
  final Uint8List? iconData;

  /// Fallback icon used when [iconData] is null.
  final IconData fallbackIcon;

  // ── State ─────────────────────────────────────────────────────────────────
  final bool isBlocked;

  /// When set, shows a mini progress bar beneath the app name.
  final int? maxDailyMinutes;
  final int dailyUsageMinutes;

  // ── Mode flags ────────────────────────────────────────────────────────────
  /// Hides the block switch in child (read-only) mode.
  final bool isChildMode;

  /// Whether to display the app/category icon.
  final bool showIcon;

  // ── Callbacks ─────────────────────────────────────────────────────────────
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleBlock;

  const SharedAppListTile({
    super.key,
    required this.appName,
    required this.packageName,
    required this.category,
    required this.usageTime,
    this.iconData,
    this.fallbackIcon = Icons.apps,
    this.isBlocked = false,
    this.maxDailyMinutes,
    this.dailyUsageMinutes = 0,
    this.isChildMode = false,
    this.onTap,
    this.onToggleBlock,
    this.showIcon = true,
  });

  // ── Category colour accent (subtle, consistent across both screens) ───────
  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Social':        return const Color(0xFFEC4899); // pink
      case 'Games':         return const Color(0xFFF97316); // orange
      case 'Messaging':     return const Color(0xFF14B8A6); // teal
      case 'Entertainment': return const Color(0xFFA855F7); // purple
      case 'Productivity':  return const Color(0xFF3B82F6); // blue
      case 'Education':     return const Color(0xFF06B6D4); // cyan
      case 'System':        return const Color(0xFF6B7280); // grey
      default:              return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(category);

    return Card(
      // Keep the same Card styling as the original AppUsageCard
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // ── App icon ─────────────────────────────────────────────────
              if (showIcon) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: iconData != null
                      ? Image.memory(iconData!, width: 24, height: 24)
                      : Icon(fallbackIcon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
              ],

              // ── Name + category badge + optional progress bar ─────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row: name + category badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _CategoryBadge(label: category, color: catColor),
                      ],
                    ),

                    // Optional: usage progress bar
                    if (maxDailyMinutes != null && maxDailyMinutes! > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (dailyUsageMinutes / maxDailyMinutes!)
                            .clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          dailyUsageMinutes >= maxDailyMinutes!
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${dailyUsageMinutes}m / ${maxDailyMinutes}m used',
                        style: TextStyle(
                          fontSize: 10,
                          color: dailyUsageMinutes >= maxDailyMinutes!
                              ? Colors.redAccent
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── Trailing: usage time + block switch ───────────────────────
              // The Switch is wrapped in a GestureDetector + HitTestBehavior
              // so its touch events do NOT bubble up to the parent InkWell.
              // This guarantees that tapping anywhere in the tile body (outside
              // the switch thumb) fires onTap → opens the bottom sheet.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (usageTime.isNotEmpty)
                    Text(
                      usageTime,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  if (!isChildMode) ...[
                    const SizedBox(width: 4),
                    // GestureDetector with opaque behaviour captures the switch
                    // touch events locally and prevents them reaching InkWell.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onToggleBlock?.call(!isBlocked),
                      child: Switch(
                        value: isBlocked,
                        // onChanged is intentionally null here: the
                        // GestureDetector above handles the tap so the
                        // Switch renders correctly without absorbing the
                        // InkWell's broader tap region.
                        onChanged: onToggleBlock,
                        activeColor: Colors.redAccent,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withValues(alpha: 0.35),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category badge ─────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CategoryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
