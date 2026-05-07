import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/pocketbase/report_service.dart';

class StatusDonutChart extends StatelessWidget {
  final double size;
  final String ownerId;

  const StatusDonutChart({super.key, required this.ownerId, this.size = 250});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: size,
          child: StreamBuilder<Map<String, int>>(
            stream: ReportService(ownerId).getOrderStatusStats(),
            builder: (context, snapshot) {
              final stats =
                  snapshot.data ?? {'pending': 0, 'ready': 0, 'completed': 0};

              List<PieChartSectionData> sections = [
                PieChartSectionData(
                  color: Colors.red,
                  value: (stats['pending'] ?? 0).toDouble() + 1,
                  title: '${stats['pending'] ?? 0}',
                  radius: 80,
                  titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  borderSide: const BorderSide(color: Colors.white, width: 4),
                ),
                PieChartSectionData(
                  color: Colors.orange,
                  value: (stats['ready'] ?? 0).toDouble() + 1,
                  title: '${stats['ready'] ?? 0}',
                  radius: 80,
                  titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  borderSide: const BorderSide(color: Colors.white, width: 4),
                ),
                PieChartSectionData(
                  color: Colors.green,
                  value: (stats['completed'] ?? 0).toDouble() + 1,
                  title: '${stats['completed'] ?? 0}',
                  radius: 80,
                  titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  borderSide: const BorderSide(color: Colors.white, width: 4),
                ),
              ];

              return PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 55,
                  sectionsSpace: 4,
                  borderData: FlBorderData(show: false),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            LegendItem(title: 'Pending', color: Colors.red),
            LegendItem(title: 'Ready', color: Colors.orange),
            LegendItem(title: 'Completed', color: Colors.green),
          ],
        ),
      ],
    );
  }
}

class LegendItem extends StatelessWidget {
  final String title;
  final Color color;

  const LegendItem({super.key, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
