import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  /// `yyyy-MM-dd`，图表从左到右按日期变新。
  final String date;
  final double value;
}

/// 一条身体数据折线。没有点时显示「还没有记录」，只有一个点也会画出圆点。
class BodyTrendChart extends StatelessWidget {
  const BodyTrendChart({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    required this.chartKey,
  });

  final String title;
  final List<TrendPoint> points;
  final Color color;
  final Key chartKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (points.isEmpty)
          Text(
            '还没有记录',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          SizedBox(
            key: chartKey,
            height: 180,
            child: LineChart(_chartData(theme), duration: Duration.zero),
          ),
      ],
    );
  }

  LineChartData _chartData(ThemeData theme) {
    final values = points.map((point) => point.value).toList();
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final padding = highest - lowest < 0.5 ? 1.0 : (highest - lowest) * 0.25;
    return LineChartData(
      minX: 0,
      maxX: points.length == 1 ? 1 : (points.length - 1).toDouble(),
      minY: lowest - padding,
      maxY: highest + padding,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) {
              return Text(
                _formatAxis(value),
                style: theme.textTheme.labelSmall,
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if ((value - index).abs() > 0.01 ||
                  index < 0 ||
                  index >= points.length) {
                return const SizedBox.shrink();
              }
              if (points.length > 6 &&
                  index != 0 &&
                  index != points.length - 1 &&
                  index != points.length ~/ 2) {
                return const SizedBox.shrink();
              }
              return Text(
                _shortDay(points[index].date),
                style: theme.textTheme.labelSmall,
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var index = 0; index < points.length; index++)
              FlSpot(index.toDouble(), points[index].value),
          ],
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

String _formatAxis(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _shortDay(String date) {
  final parts = date.split('-');
  return '${int.parse(parts[1])}/${int.parse(parts[2])}';
}
