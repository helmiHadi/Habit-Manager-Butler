import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A fully self-contained, stateless schedule tile shared between the local
/// ScheduleScreen and RemoteScheduleScreen.
///
/// All mutations are propagated upward through callbacks; this widget holds
/// no state of its own, so either screen can own the state however it likes.
class AppScheduleTile extends StatelessWidget {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String appName;
  final String packageName;
  final String category;

  // ── Current values (driven by parent state) ───────────────────────────────
  final bool isBlocked;
  final int? limitMinutes;      // null = Unlimited
  final List<int> allowedDays;  // 1=Mon … 7=Sun
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  // ── Callbacks ─────────────────────────────────────────────────────────────
  final ValueChanged<bool> onBlockToggled;
  final ValueChanged<int?> onLimitChanged;
  final ValueChanged<List<int>> onDaysChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;

  // ── Optional context helpers ──────────────────────────────────────────────
  /// When provided, shows a progress bar (used in local mode where we know
  /// the child's actual usage minutes today).
  final int? dailyUsageMinutes;

  const AppScheduleTile({
    super.key,
    required this.appName,
    required this.packageName,
    required this.category,
    required this.isBlocked,
    required this.limitMinutes,
    required this.allowedDays,
    this.startTime,
    this.endTime,
    required this.onBlockToggled,
    required this.onLimitChanged,
    required this.onDaysChanged,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
    this.dailyUsageMinutes,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatLimit(int? m) {
    if (m == null) return 'Unlimited';
    if (m == 0) return 'Blocked';
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '${h}h ${rem}m' : '${h}h';
  }

  String _formatTime(TimeOfDay? t, BuildContext ctx) {
    if (t == null) return 'Not set';
    return t.format(ctx);
  }

  Color _limitColor(int? m) {
    if (m == null) return Colors.greenAccent;
    if (m <= 30) return Colors.redAccent;
    if (m <= 60) return Colors.amberAccent;
    return Colors.lightBlueAccent;
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Social':        return Colors.pinkAccent;
      case 'Games':         return Colors.orangeAccent;
      case 'Messaging':     return Colors.tealAccent;
      case 'Entertainment': return Colors.purpleAccent;
      case 'Productivity':  return Colors.blueAccent;
      case 'Education':     return Colors.cyanAccent;
      case 'System':        return Colors.white38;
      default:              return Colors.white30;
    }
  }

  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sliderVal = (limitMinutes ?? 0).toDouble().clamp(0.0, 480.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked
              ? Colors.redAccent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App icon placeholder
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _categoryColor(category).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _categoryColor(category).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        appName.isNotEmpty ? appName[0].toUpperCase() : '?',
                        style: GoogleFonts.dmSans(
                          color: _categoryColor(category),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // App name + package + category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _categoryColor(category)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                category,
                                style: GoogleFonts.dmSans(
                                  color: _categoryColor(category),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                packageName,
                                style: GoogleFonts.dmMono(
                                    color: Colors.white24, fontSize: 9),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Block toggle
                  Column(
                    children: [
                      Text(
                        'Block',
                        style: GoogleFonts.dmSans(
                            color: Colors.white38, fontSize: 9),
                      ),
                      Switch(
                        value: isBlocked,
                        onChanged: onBlockToggled,
                        activeColor: Colors.redAccent,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: const Color(0xFF3A3A3C),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Usage progress bar (local mode only) ──────────────────────
            if (dailyUsageMinutes != null &&
                limitMinutes != null &&
                limitMinutes! > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (dailyUsageMinutes! / limitMinutes!)
                          .clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        dailyUsageMinutes! >= limitMinutes!
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                      minHeight: 3,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${dailyUsageMinutes}m / ${limitMinutes}m used today',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: dailyUsageMinutes! >= limitMinutes!
                            ? Colors.redAccent
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(color: Colors.white10, height: 1),

            // ── Allowed days ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allowed Days',
                    style: GoogleFonts.dmSans(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final selected = allowedDays.contains(day);
                      return GestureDetector(
                        onTap: isBlocked
                            ? null
                            : () {
                                final updated =
                                    List<int>.from(allowedDays);
                                if (selected) {
                                  updated.remove(day);
                                } else {
                                  updated.add(day);
                                }
                                onDaysChanged(updated);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? Colors.deepPurpleAccent
                                : const Color(0xFF2C2C2E),
                            border: Border.all(
                              color: selected
                                  ? Colors.deepPurpleAccent
                                  : Colors.white12,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _dayLabels[i],
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Time window ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Allowed Time Window',
                    style: GoogleFonts.dmSans(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeButton(
                          label: 'From',
                          value: _formatTime(startTime, context),
                          isSet: startTime != null,
                          enabled: !isBlocked,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime ?? TimeOfDay.now(),
                              builder: (ctx, child) =>
                                  _darkTimePickerWrapper(ctx, child),
                            );
                            if (picked != null) onStartTimeChanged(picked);
                          },
                          onClear: startTime != null
                              ? () => onStartTimeChanged(null)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TimeButton(
                          label: 'Until',
                          value: _formatTime(endTime, context),
                          isSet: endTime != null,
                          enabled: !isBlocked,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime ?? TimeOfDay.now(),
                              builder: (ctx, child) =>
                                  _darkTimePickerWrapper(ctx, child),
                            );
                            if (picked != null) onEndTimeChanged(picked);
                          },
                          onClear: endTime != null
                              ? () => onEndTimeChanged(null)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Daily time limit ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'Daily Limit: ',
                        style: GoogleFonts.dmSans(
                            color: Colors.white38, fontSize: 11),
                      ),
                      Text(
                        _formatLimit(limitMinutes),
                        style: GoogleFonts.dmSans(
                          color: _limitColor(limitMinutes),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (limitMinutes != null)
                        GestureDetector(
                          onTap: () => onLimitChanged(null),
                          child: Text(
                            'Clear',
                            style: GoogleFonts.dmSans(
                              color: Colors.white24,
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Slider (0–480 min = 8 h, 10-min steps)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.deepPurpleAccent,
                      inactiveTrackColor: const Color(0xFF3A3A3C),
                      thumbColor: Colors.deepPurpleAccent,
                      overlayColor:
                          Colors.deepPurpleAccent.withValues(alpha: 0.15),
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: sliderVal,
                      min: 0,
                      max: 480,
                      divisions: 48, // 10-minute increments
                      onChanged: isBlocked
                          ? null
                          : (val) {
                              final rounded = (val / 10).round() * 10;
                              onLimitChanged(rounded == 0 ? null : rounded);
                            },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0m',
                          style: GoogleFonts.dmSans(
                              color: Colors.white24, fontSize: 9)),
                      Text('2h',
                          style: GoogleFonts.dmSans(
                              color: Colors.white24, fontSize: 9)),
                      Text('4h',
                          style: GoogleFonts.dmSans(
                              color: Colors.white24, fontSize: 9)),
                      Text('6h',
                          style: GoogleFonts.dmSans(
                              color: Colors.white24, fontSize: 9)),
                      Text('8h',
                          style: GoogleFonts.dmSans(
                              color: Colors.white24, fontSize: 9)),
                    ],
                  ),

                  // Manual minutes text-field (mirrors local ScheduleBottomSheet)
                  const SizedBox(height: 6),
                  _LimitTextField(
                    currentValue: limitMinutes,
                    onChanged: onLimitChanged,
                    enabled: !isBlocked,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _darkTimePickerWrapper(BuildContext ctx, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          onSurface: Colors.white,
          surface: Color(0xFF1C1C1E),
        ),
      ),
      child: child!,
    );
  }
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final bool isSet;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeButton({
    required this.label,
    required this.value,
    required this.isSet,
    required this.enabled,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSet
              ? Colors.deepPurpleAccent.withValues(alpha: 0.15)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSet
                ? Colors.deepPurpleAccent.withValues(alpha: 0.5)
                : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                      color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: isSet ? Colors.white : Colors.white38,
                    fontWeight:
                        isSet ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 12, color: Colors.white24),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline text-field for typing an exact minute value — mirrors the local
/// ScheduleBottomSheet's "Daily Limit (Minutes)" text input.
class _LimitTextField extends StatefulWidget {
  final int? currentValue;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  const _LimitTextField({
    required this.currentValue,
    required this.onChanged,
    required this.enabled,
  });

  @override
  State<_LimitTextField> createState() => _LimitTextFieldState();
}

class _LimitTextFieldState extends State<_LimitTextField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.currentValue != null
            ? widget.currentValue.toString()
            : '');
  }

  @override
  void didUpdateWidget(_LimitTextField old) {
    super.didUpdateWidget(old);
    // Sync external changes (slider or AI) without overwriting the user's
    // in-progress input. Compare by parsed int so "60" == 60 is stable.
    final currentParsed = int.tryParse(_ctrl.text.trim());
    if (currentParsed != widget.currentValue) {
      final newText =
          widget.currentValue != null ? widget.currentValue.toString() : '';
      _ctrl.value = _ctrl.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
      onChanged: (val) {
        final parsed = int.tryParse(val);
        widget.onChanged(parsed == 0 ? null : parsed);
      },
      decoration: InputDecoration(
        hintText: 'Type exact minutes (e.g. 60)',
        hintStyle: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        suffixText: 'min',
        suffixStyle: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}
