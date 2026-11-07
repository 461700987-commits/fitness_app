import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/models/exercise_plan.dart';
import 'package:flutter/foundation.dart';

/// 四项运动的组数和每组数量。和某一天有没有打勾分开保存。
class ExercisePlans extends ChangeNotifier {
  ExercisePlans(this._database);

  final AppDatabase _database;

  Map<ExerciseKind, ExercisePlan> plans = Map.of(ExercisePlan.defaults);
  String? errorMessage;
  var _closed = false;

  ExercisePlan planFor(ExerciseKind kind) {
    return plans[kind] ?? ExercisePlan.defaultFor(kind);
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> load() async {
    try {
      plans = await _database.loadPlans();
      errorMessage = null;
    } catch (_) {
      errorMessage = '读取运动计划失败';
    } finally {
      if (!_closed) {
        notifyListeners();
      }
    }
  }

  Future<bool> update(ExerciseKind kind, int sets, int perSet) async {
    final error = planError(kind, sets, perSet);
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return false;
    }
    try {
      final plan = ExercisePlan(kind: kind, sets: sets, perSet: perSet);
      await _database.savePlan(plan);
      plans = {...plans, kind: plan};
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = '保存计划失败，请重试';
      notifyListeners();
      return false;
    }
  }
}
