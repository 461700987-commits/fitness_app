import 'package:fitness_app/screens/home_shell.dart';
import 'package:fitness_app/state/body_records.dart';
import 'package:fitness_app/state/exercise_plans.dart';
import 'package:fitness_app/state/today_workout.dart';
import 'package:fitness_app/state/weekly_stats.dart';
import 'package:flutter/material.dart';

class FitnessApp extends StatelessWidget {
  const FitnessApp({
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '健身打卡',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B8A5A)),
      ),
      home: HomeShell(today: today, plans: plans, body: body, weekly: weekly),
    );
  }
}
