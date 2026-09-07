import 'package:flutter/material.dart';

class ScheduleBottomSheet extends StatefulWidget {
  final String appName;
  final String packageName;
  final List<int> initialAllowedDays;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final int? initialMaxDailyMinutes;
  final Function(List<int>, TimeOfDay?, TimeOfDay?, int?) onSave;

  const ScheduleBottomSheet({
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
  State<ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<ScheduleBottomSheet> {
  late List<int> _selectedDays;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late TextEditingController _limitController;

  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDays = List.from(widget.initialAllowedDays);
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
    _limitController = TextEditingController(
      text: widget.initialMaxDailyMinutes != null && widget.initialMaxDailyMinutes! > 0
          ? widget.initialMaxDailyMinutes.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
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

  String _formatTime(TimeOfDay? time) {
    if (time == null) return "Not set";
    return time.format(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 24),
          Text(
            'Schedule for ${widget.appName}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 24),
          Text(
            'Allowed Days',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayNum = index + 1; // 1 to 7 (Mon-Sun)
              final isSelected = _selectedDays.contains(dayNum);
              return GestureDetector(
                onTap: () => _toggleDay(dayNum),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected ? Colors.greenAccent : Colors.white12,
                  child: Text(
                    _dayLabels[index],
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          Text(
            'Allowed Time Window',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectTime(true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Text("From", style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_startTime),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _selectTime(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Text("Until", style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_endTime),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Daily Limit (Minutes)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Max Daily Limit: ${widget.initialMaxDailyMinutes ?? 'No limit'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. 60 (leave blank for no limit)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                final text = _limitController.text.trim();
                final limit = text.isNotEmpty ? int.tryParse(text) : null;
                widget.onSave(_selectedDays, _startTime, _endTime, limit);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Save Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
