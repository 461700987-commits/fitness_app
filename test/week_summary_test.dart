import 'package:fitness_app/models/week_summary.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Workout workout(
    String date, {
    int pushups = 1,
    int squats = 1,
    int sets = 1,
    int seconds = 1,
    int walkSteps = 0,
  }) {
    return Workout(
      date: date,
      pushupCount: pushups,
      squatCount: squats,
      plankSets: sets,
      plankSeconds: seconds,
      walkSteps: walkSteps,
    );
  }

  test('一周从周一排到周日', () {
    final sunday = DateTime(2026, 3, 1);
    expect(sunday.weekday, DateTime.sunday);
    expect(daysOfWeek(sunday), [
      '2026-02-23',
      '2026-02-24',
      '2026-02-25',
      '2026-02-26',
      '2026-02-27',
      '2026-02-28',
      '2026-03-01',
    ]);

    final saturday = DateTime(2026, 11, 7);
    expect(saturday.weekday, DateTime.saturday);
    expect(daysOfWeek(saturday).first, '2026-11-02');
    expect(daysOfWeek(saturday).last, '2026-11-08');
  });

  test('只汇总这一周的打卡', () {
    final summary = summarizeWeek(DateTime(2026, 11, 7), [
      workout('2026-11-01', pushups: 100, squats: 100, sets: 9, seconds: 900),
      workout('2026-11-02', pushups: 10, squats: 20, sets: 1, seconds: 30),
      workout(
        '2026-11-07',
        pushups: 5,
        squats: 8,
        sets: 2,
        seconds: 40,
        walkSteps: 8000,
      ),
      workout('2026-11-09', pushups: 7, squats: 7, sets: 7, seconds: 70),
    ]);

    expect(summary.checkedInDays, 2);
    expect(summary.pushupCount, 15);
    expect(summary.squatCount, 28);
    expect(summary.plankSets, 3);
    expect(summary.plankSeconds, 70);
    expect(summary.walkSteps, 8000);
    expect(summary.days.first.checkedIn, isTrue);
    expect(summary.days[1].checkedIn, isFalse);
    expect(summary.days[5].checkedIn, isTrue);
    expect(summary.days.last.checkedIn, isFalse);
  });
}
