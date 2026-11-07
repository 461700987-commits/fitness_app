import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/week_summary.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:fitness_app/state/weekly_stats.dart';
import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.weekly, this.onDaySelected});

  final WeeklyStats weekly;
  final ValueChanged<String>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: weekly,
      builder: (context, _) {
        final summary = weekly.summary;
        if (summary == null) {
          if (weekly.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(child: Text(weekly.errorMessage ?? '读取本周统计失败'));
        }
        return _WeekView(
          summary: summary,
          history: weekly.history,
          onDaySelected: onDaySelected,
        );
      },
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.summary,
    required this.history,
    this.onDaySelected,
  });

  final WeekSummary summary;
  final List<Workout> history;
  final ValueChanged<String>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = dayKeyFrom(DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          '${formatChineseDay(summary.start)} 至 ${formatChineseDay(summary.end)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (summary.checkedInDays == 0) ...[
          Text('本周还没有运动记录', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '打卡之后，这里会显示本周打卡天数，以及俯卧撑、深蹲、平板支撑和快走的完成量。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          Text(
            '打卡 ${summary.checkedInDays}/7 天',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '俯卧撑 ${summary.pushupCount} 个',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '深蹲 ${summary.squatCount} 个',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '平板支撑 ${summary.plankSets} 组',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '平板支撑 ${summary.plankSeconds} 秒',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('快走 ${summary.walkSteps} 步', style: theme.textTheme.titleMedium),
        ],
        const SizedBox(height: 24),
        Text(
          '点下面的日期，可以查看或修改那一天。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var index = 0; index < summary.days.length; index++)
              Expanded(
                child: _DayMark(
                  label: weekdayLabels[index],
                  date: summary.days[index].date,
                  checkedIn: summary.days[index].checkedIn,
                  isToday: summary.days[index].date == today,
                  onTap: onDaySelected == null
                      ? null
                      : () => onDaySelected!(summary.days[index].date),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        Text('历史记录', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Text(
            '还没有运动记录。打勾之后，每一天会出现在这里。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final workout in history)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: Key('history-${workout.date}'),
                title: Text(formatChineseDay(workout.date)),
                subtitle: Text(workout.historyLines.join('\n')),
                trailing: const Icon(Icons.chevron_right),
                onTap: onDaySelected == null
                    ? null
                    : () => onDaySelected!(workout.date),
              ),
            ),
      ],
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.label,
    required this.date,
    required this.checkedIn,
    required this.isToday,
    this.onTap,
  });

  final String label;
  final String date;
  final bool checkedIn;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = checkedIn
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isToday ? theme.colorScheme.primary : null,
              fontWeight: isToday ? FontWeight.bold : null,
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            checkedIn ? Icons.check_circle : Icons.circle_outlined,
            key: Key('weekDay-$date'),
            color: color,
          ),
        ],
      ),
    );
  }
}
