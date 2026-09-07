import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A shared, pixel-perfect replica of the Normal Mode scheduling bottom sheet.
///
/// Used by both [DashboardScreen] (local) and [RemoteScheduleScreen] (remote).
///
/// The ONLY difference between modes is what happens in [onSave]:
///   • Local:  calls [AppUsageProvider.saveSchedule] → writes to SQLite
///   • Remote: writes values into the parent's draft map → synced to cloud
///
/// Design spec (matches the screenshot exactly):
///   ① Drag handle + "Schedule for <appName>"
///   ② Allowed Days — M T W T F S S circular chips (green when active)
///   ③ Allowed Time Window — "From" / "Until" OutlinedButtons
///   ④ Daily Limit (Minutes) — plain TextField, NO sliders
///   ⑤ "Save Schedule" green ElevatedButton
class SharedScheduleBottomSheet extends StatefulWidget {
  final String appName;
  final String packageName;

  // ── Pre-filled values ─────────────────────────────────────────────────────
  final List<int> initialAllowedDays;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final int? initialMaxDailyMinutes;

  /// Called when the user taps "Save Schedule".
  ///
  /// Parameters:
  ///   [days]      – Selected day numbers, 1=Mon … 7=Sun.
  ///   [startTime] – Optional window start (null = no restriction).
  ///   [endTime]   – Optional window end   (null = no restriction).
  ///   [limit]     – Max daily minutes, null = no limit.
  final void Function(
    List<int> days,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? limit,
  ) onSave;

  const SharedScheduleBottomSheet({
    super.key,
    required this.appName,
    required this.packageName,
    required this.initialAllowedDays,
    this.initialStartTime,
    this.initialEndTime,
    this.initialMaxDailyMinutes,
    required this.onSave,
  });

  @override
  State<SharedScheduleBottomSheet> createState() =>
      _SharedScheduleBottomSheetState();
}

class _SharedScheduleBottomSheetState
    extends State<SharedScheduleBottomSheet> {
  late List<int> _selectedDays;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late TextEditingController _limitCtrl;

  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDays = List<int>.from(widget.initialAllowedDays);
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _limitCtrl = TextEditingController(
      text: (widget.initialMaxDailyMinutes != null &&
              widget.initialMaxDailyMinutes! > 0)
          ? widget.initialMaxDailyMinutes.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.greenAccent,
            onSurface: Colors.white,
            surface: Color(0xFF1C1C1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _fmtTime(TimeOfDay? t) {
    if (t == null) return 'Not set';
    return t.format(context);
  }

  void _save() {
    final text = _limitCtrl.text.trim();
    final limit = text.isNotEmpty ? int.tryParse(text) : null;
    widget.onSave(_selectedDays, _startTime, _endTime, limit);
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Push the sheet up when the keyboard appears
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ① Drag handle ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────────
            Text(
              'Schedule for ${widget.appName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 24),

            // ── ② Allowed Days ────────────────────────────────────────────
            Text(
              'Allowed Days',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final isSelected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () => _toggleDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.greenAccent
                          : Colors.white12,
                    ),
                    child: Center(
                      child: Text(
                        _dayLabels[i],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // ── ③ Allowed Time Window ─────────────────────────────────────
            Text(
              'Allowed Time Window',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeWindowButton(
                    label: 'From',
                    value: _fmtTime(_startTime),
                    isSet: _startTime != null,
                    onTap: () => _pickTime(true),
                    onClear: _startTime != null
                        ? () => setState(() => _startTime = null)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeWindowButton(
                    label: 'Until',
                    value: _fmtTime(_endTime),
                    isSet: _endTime != null,
                    onTap: () => _pickTime(false),
                    onClear: _endTime != null
                        ? () => setState(() => _endTime = null)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── ④ Daily Limit (Minutes) ───────────────────────────────────
            Text(
              'Daily Limit (Minutes)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              'Current: ${widget.initialMaxDailyMinutes != null ? '${widget.initialMaxDailyMinutes}m' : 'No limit'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. 60  (leave blank = no limit)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                suffixText: 'min',
                suffixStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── ⑤ Save button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Schedule',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helper sub-widget ──────────────────────────────────────────────────────────

class _TimeWindowButton extends StatelessWidget {
  final String label;
  final String value;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeWindowButton({
    required this.label,
    required this.value,
    required this.isSet,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(
          color: isSet
              ? Colors.greenAccent.withValues(alpha: 0.6)
              : Colors.white24,
        ),
        backgroundColor: isSet
            ? Colors.greenAccent.withValues(alpha: 0.06)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isSet ? Colors.greenAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white38),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
