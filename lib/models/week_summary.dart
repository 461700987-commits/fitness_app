import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/workout.dart';

const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

/// 包含 [date] 的那一周，从周一开始。
DateTime mondayOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// 这一周的七个日期，周一在前，周日在后。
List<String> daysOfWeek(DateTime date) {
  final monday = mondayOf(date);
  return [
    for (var offset = 0; offset < 7; offset++)
      dayKeyFrom(monday.add(Duration(days: offset))),
  ];
}

/// 把某一周的运动记录汇总起来。不在这七天里的记录不会计入。
WeekSummary summarizeWeek(DateTime anchor, Iterable<Workout> workouts) {
  final dates = daysOfWeek(anchor);
  final byDate = {for (final workout in workouts) workout.date: workout};
  return WeekSummary(
    days: [
      for (final date in dates) WeekDay(date: date, workout: byDate[date]),
    ],
  );
}

class WeekDay {
  const WeekDay({required this.date, required this.workout});

  final String date;
  final Workout? workout;

  bool get checkedIn => workout != null;
}

class WeekSummary {
  const WeekSummary({required this.days});

  final List<WeekDay> days;

  String get start => days.first.date;

  String get end => days.last.date;

  int get checkedInDays => days.where((day) => day.checkedIn).length;

  int get pushupCount => _sum((workout) => workout.pushupCount);

  int get squatCount => _sum((workout) => workout.squatCount);

  int get plankSets => _sum((workout) => workout.plankSets);

  int get plankSeconds => _sum((workout) => workout.plankSeconds);

  int get walkSteps => _sum((workout) => workout.walkSteps);

  int _sum(int Function(Workout workout) value) {
    var total = 0;
    for (final day in days) {
      final workout = day.workout;
      if (workout != null) {
        total += value(workout);
      }
    }
    return total;
  }
}
