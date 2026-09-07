import 'package:flutter/material.dart';

enum Period { today, week, month }

class CarouselSummaryCard extends StatelessWidget {
  final String title;
  final int currentMinutes;
  final int previousMinutes;
  final List<Color> gradientColors;
  final Period period;

  const CarouselSummaryCard({
    super.key,
    required this.title,
    required this.currentMinutes,
    required this.previousMinutes,
    required this.gradientColors,
    required this.period,
  });

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Widget _buildComparison(BuildContext context) {
    if (previousMinutes == 0) {
      return const Text(
        "No previous data",
        style: TextStyle(
          color: Colors.grey,
          fontSize: 15,
        ),
      );
    }

    final diff = currentMinutes - previousMinutes;
    final percent = previousMinutes > 0 ? (diff.abs() / previousMinutes * 100).round() : 0;
    
    String suffix;
    switch (period) {
      case Period.today:
        suffix = "than yesterday";
        break;
      case Period.week:
        suffix = "than last week";
        break;
      case Period.month:
        suffix = "than last month";
        break;
    }

    if (diff < 0) {
      return Text(
        "↓ $percent% less $suffix",
        style: const TextStyle(
          color: Colors.greenAccent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    } else if (diff > 0) {
      return Text(
        "↑ $percent% more $suffix",
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
    } else {
      return Text(
        "Same as ${period == Period.today ? 'yesterday' : period == Period.week ? 'last week' : 'last month'}",
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 15,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(currentMinutes),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          _buildComparison(context),
        ],
      ),
    );
  }
}
