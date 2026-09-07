import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_usage_provider.dart';
import '../widgets/shared_empty_state.dart';

class AnalyticsScreen extends StatefulWidget {
  final int? initialTabIndex;
  const AnalyticsScreen({super.key, this.initialTabIndex});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppUsageProvider>();
      if (widget.initialTabIndex != null) {
        provider.toggleAnalyticsView(widget.initialTabIndex == 2);
      }
      provider.fetchAnalyticsVerdict();
    });
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppUsageProvider>();
    final categoryData = provider.getCategoryData();
    
    // Sort apps by dailyUsageMinutes for Detailed Usage
    final sortedApps = List.from(provider.appUsages)
      ..sort((a, b) => b.dailyUsageMinutes.compareTo(a.dailyUsageMinutes));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(
          "The Butler's Audit",
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: provider.appUsages.isEmpty
          ? const SharedEmptyState(
              icon: Icons.bar_chart_rounded,
              title: "No Data Yet",
              subtitle: "Butler is still gathering your screen time analytics.",
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Segmented Button for Timeframe
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Daily/Weekly'),
                    icon: Icon(Icons.view_week),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Monthly'),
                    icon: Icon(Icons.calendar_month),
                  ),
                ],
                selected: {provider.isMonthlyView},
                onSelectionChanged: (Set<bool> newSelection) {
                  provider.toggleAnalyticsView(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  selectedBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                  selectedForegroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Executive Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    'TOTAL SCREEN TIME',
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${(provider.isMonthlyView ? provider.getMonthlyUsage() : provider.totalScreenTimeMinutes) ~/ 60}',
                        style: GoogleFonts.dmSans(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'h ',
                        style: GoogleFonts.dmSans(
                          fontSize: 24,
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        '${(provider.isMonthlyView ? provider.getMonthlyUsage() : provider.totalScreenTimeMinutes) % 60}',
                        style: GoogleFonts.dmSans(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'm',
                        style: GoogleFonts.dmSans(
                          fontSize: 24,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!provider.isMonthlyView)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          provider.totalScreenTimeMinutes > provider.yesterdayUsage
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: provider.totalScreenTimeMinutes > provider.yesterdayUsage
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(provider.totalScreenTimeMinutes - provider.yesterdayUsage).abs()}m vs yesterday',
                          style: GoogleFonts.dmSans(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      provider.analyticsVerdict,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Text(
              'Time Allocation',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            // Pie Chart
            if (categoryData.isEmpty)
              const SizedBox(
                height: 200,
                child: Center(child: Text('No data for pie chart', style: TextStyle(color: Colors.white54))),
              )
            else
              Container(
                height: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: _buildPieChartSections(categoryData),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildPieChartLegend(categoryData),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),
            Text(
              provider.isMonthlyView ? 'Monthly Momentum' : 'Weekly Momentum',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            // Bar Chart
            Container(
              height: 250,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(24),
              ),
              child: FutureBuilder<List<double>>(
                future: provider.isMonthlyView ? provider.getMonthlyChartData() : provider.getWeeklyChartData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  final isMonthly = provider.isMonthlyView;
                  final itemCount = isMonthly ? 4 : 7;
                  
                  return WeeklyMomentum(
                    data: data,
                    isMonthly: isMonthly,
                    itemCount: itemCount,
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Detailed Usage',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedApps.length,
              itemBuilder: (context, index) {
                final app = sortedApps[index];
                final maxLimit = app.maxDailyMinutes ?? 0;
                final limitText = maxLimit > 0 
                    ? '${app.dailyUsageMinutes}m / ${maxLimit}m used'
                    : '${_formatDuration(app.dailyUsageMinutes)} total';
                final double progress = maxLimit > 0 
                    ? (app.dailyUsageMinutes / maxLimit).clamp(0.0, 1.0) 
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      if (app.iconData != null)
                        Image.memory(app.iconData!, width: 40, height: 40)
                      else
                        const Icon(Icons.apps, color: Colors.white54, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.appName,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (maxLimit > 0)
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0 ? Colors.redAccent : Colors.cyanAccent,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              limitText,
                              style: GoogleFonts.dmSans(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> data) {
    final colors = [
      Colors.cyanAccent,
      Colors.pinkAccent,
      Colors.limeAccent,
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.pinkAccent,
    ];
    
    int index = 0;
    return data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '',
        radius: 30,
      );
    }).toList();
  }

  List<Widget> _buildPieChartLegend(Map<String, double> data) {
    final colors = [
      Colors.cyanAccent,
      Colors.pinkAccent,
      Colors.limeAccent,
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.pinkAccent,
    ];
    
    final totalDuration = data.values.fold<double>(0.0, (sum, value) => sum + value);
    
    int index = 0;
    return data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      final percentage = totalDuration > 0 ? (entry.value / totalDuration * 100).round() : 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.key} $percentage%',
                style: GoogleFonts.dmSans(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class WeeklyMomentum extends StatelessWidget {
  final List<double> data;
  final bool isMonthly;
  final int itemCount;

  const WeeklyMomentum({
    super.key,
    required this.data,
    required this.isMonthly,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final dataMaxY = data.isNotEmpty
        ? (data.reduce((a, b) => a > b ? a : b) * 1.2).clamp(60.0, double.infinity)
        : 60.0;
    final double interval = (dataMaxY / 3).floorToDouble().clamp(15.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: dataMaxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                String title;
                if (isMonthly) {
                  final weeks = ['W1', 'W2', 'W3', 'W4'];
                  title = weeks[value.toInt() % 4];
                } else {
                  final now = DateTime.now();
                  final date = now.subtract(Duration(days: 6 - value.toInt()));
                  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  title = days[date.weekday - 1];
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: interval,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value > dataMaxY) return const SizedBox.shrink();
                final int minutes = value.round();
                String text;
                if (minutes == 0) {
                  text = '0m';
                } else if (minutes % 60 == 0) {
                  text = '${minutes ~/ 60}h';
                } else if (minutes > 60) {
                  text = '${minutes ~/ 60}h ${(minutes % 60)}m';
                } else {
                  text = '${minutes}m';
                }
                return Text(
                  text,
                  style: GoogleFonts.dmSans(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(itemCount, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.isNotEmpty ? data[index] : 0,
                color: index == (itemCount - 1) ? Colors.cyanAccent : Colors.white24,
                width: isMonthly ? 20 : 12,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: data.isNotEmpty ? (data.reduce((a, b) => a > b ? a : b) * 1.2).clamp(60.0, double.infinity) : 60.0,
                  color: Colors.black12,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
