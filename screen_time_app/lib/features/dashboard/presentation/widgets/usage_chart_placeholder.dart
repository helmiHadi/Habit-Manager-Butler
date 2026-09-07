import 'package:flutter/material.dart';
import 'package:screen_time_app/core/theme/app_colors.dart';

class UsageChartPlaceholder extends StatelessWidget {
  const UsageChartPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 64,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chart Data Pending',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
