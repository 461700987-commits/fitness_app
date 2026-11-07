import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/models/week_summary.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:flutter/foundation.dart';

/// 本周运动统计。数字是从打卡记录算出来的，不另外保存。
class WeeklyStats extends ChangeNotifier {
  WeeklyStats(this._database);

  final AppDatabase _database;

  WeekSummary? summary;
  List<Workout> history = [];
  var loading = false;
  String? errorMessage;
  var _closed = false;

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> load([DateTime? today]) async {
    final anchor = today ?? DateTime.now();
    final showSpinner = summary == null;
    if (showSpinner) {
      loading = true;
      notifyListeners();
    }
    try {
      final days = daysOfWeek(anchor);
      final workouts = await _database.workoutsBetween(days.first, days.last);
      summary = summarizeWeek(anchor, workouts);
      history = await _database.allWorkouts();
      errorMessage = null;
    } catch (_) {
      errorMessage = '读取本周统计失败';
    } finally {
      if (!_closed) {
        loading = false;
        notifyListeners();
      }
    }
  }
}
