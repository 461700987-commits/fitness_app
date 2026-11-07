import 'package:fitness_app/screens/body_screen.dart';
import 'package:fitness_app/screens/stats_screen.dart';
import 'package:fitness_app/screens/today_screen.dart';
import 'package:fitness_app/state/body_records.dart';
import 'package:fitness_app/state/exercise_plans.dart';
import 'package:fitness_app/state/today_workout.dart';
import 'package:fitness_app/state/weekly_stats.dart';
import 'package:flutter/material.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.today,
    required this.plans,
    required this.body,
    required this.weekly,
  });

  final TodayWorkout today;
  final ExercisePlans plans;
  final BodyRecords body;
  final WeeklyStats weekly;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = <String>['今日打卡', '每周统计', '身体记录'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(today: widget.today, plans: widget.plans),
          StatsScreen(
            weekly: widget.weekly,
            onDaySelected: (date) {
              if (widget.today.saving) {
                return;
              }
              setState(() => _index = 0);
              widget.today.select(date);
            },
          ),
          BodyScreen(records: widget.body),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          if (index == 1) {
            widget.weekly.load();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: '身体',
          ),
        ],
      ),
    );
  }
}
