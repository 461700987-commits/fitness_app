import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/exercise_plan.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:flutter/foundation.dart';

/// 正在查看的某一天的运动打卡。默认是今天，也可以改成以前的日期。
class TodayWorkout extends ChangeNotifier {
  TodayWorkout(this._database) {
    selectedDate = dayKeyFrom(DateTime.now());
  }

  final AppDatabase _database;

  late String selectedDate;
  Workout? workout;
  var loading = false;
  var saving = false;
  String? errorMessage;
  var _closed = false;

  /// 测试用来把一次保存停在写库之前。正式运行不会赋值。
  @visibleForTesting
  Future<void> Function()? debugPersistPause;

  String get calendarToday => dayKeyFrom(DateTime.now());

  bool get isToday => selectedDate == calendarToday;

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> load() => _read();

  Future<void> select(String date) async {
    validateDayKey(date);
    if (saving || _closed) {
      return;
    }
    selectedDate = date;
    workout = null;
    errorMessage = null;
    await _read();
  }

  /// 勾选或取消一项，并立刻写进手机数据库。
  /// 四项都取消时，这一天的运动记录会被删掉。
  ///
  /// 日期在开始时固定。保存完成前不能切到另一天，写入也只用这一天。
  Future<bool> toggle(ExerciseKind kind) async {
    if (saving || _closed) {
      return false;
    }
    final date = selectedDate;
    final current = workout;
    saving = true;
    notifyListeners();
    try {
      final pause = debugPersistPause;
      if (pause != null) {
        await pause();
      }
      if (_closed) {
        return false;
      }
      final plan = await _database.planOf(kind);
      if (_closed) {
        return false;
      }
      final next = applyExerciseCheck(
        current: current,
        date: date,
        kind: kind,
        plan: plan,
      );
      if (next == null) {
        await _database.deleteWorkout(date);
      } else {
        await _database.saveWorkout(next);
      }
      if (!_closed && selectedDate == date) {
        workout = next;
        errorMessage = null;
      }
      return true;
    } catch (_) {
      if (!_closed && selectedDate == date) {
        errorMessage = '保存失败，请重试';
      }
      return false;
    } finally {
      saving = false;
      if (!_closed) {
        notifyListeners();
      }
    }
  }

  Future<void> _read() async {
    loading = true;
    notifyListeners();
    try {
      workout = await _database.workoutOn(selectedDate);
      errorMessage = null;
    } catch (_) {
      errorMessage = '读取打卡失败';
    } finally {
      if (!_closed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(Workout next) async {
    if (saving || _closed) {
      return false;
    }
    final date = selectedDate;
    if (next.date != date) {
      errorMessage = '只能保存正在查看的这一天';
      notifyListeners();
      return false;
    }
    saving = true;
    notifyListeners();
    try {
      await _database.saveWorkout(next);
      if (!_closed && selectedDate == date) {
        workout = next;
        errorMessage = null;
      }
      return true;
    } catch (_) {
      if (!_closed && selectedDate == date) {
        errorMessage = '保存失败，请重试';
      }
      return false;
    } finally {
      saving = false;
      if (!_closed) {
        notifyListeners();
      }
    }
  }
}
