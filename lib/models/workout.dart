import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/exercise_plan.dart';

/// 某一天的运动打卡。
///
/// 有这条记录，就表示这一天至少勾过一项。
/// 勾选时会记下当时的组数和每组数量，之后再改计划，不会改掉这一天。
class Workout {
  Workout({
    required this.date,
    required this.pushupCount,
    this.pushupSeconds,
    required this.squatCount,
    this.squatSeconds,
    required this.plankSets,
    required this.plankSeconds,
    this.walkSteps = 0,
    this.pushupSets = 0,
    this.pushupPerSet = 0,
    this.squatSets = 0,
    this.squatPerSet = 0,
    this.plankPerSet = 0,
    this.walkSets = 0,
    this.walkPerSet = 0,
  }) {
    validateDayKey(date);
    _nonNegative(pushupCount, '俯卧撑次数');
    _nonNegative(squatCount, '深蹲次数');
    _nonNegative(plankSets, '平板支撑组数');
    _nonNegative(plankSeconds, '平板支撑总秒数');
    _nonNegative(walkSteps, '快走步数');
    _nonNegative(pushupSets, '俯卧撑组数');
    _nonNegative(pushupPerSet, '俯卧撑每组个数');
    _nonNegative(squatSets, '深蹲组数');
    _nonNegative(squatPerSet, '深蹲每组个数');
    _nonNegative(plankPerSet, '平板支撑每组秒数');
    _nonNegative(walkSets, '快走组数');
    _nonNegative(walkPerSet, '快走每组步数');
    if (pushupSeconds != null) {
      _nonNegative(pushupSeconds!, '俯卧撑用时');
    }
    if (squatSeconds != null) {
      _nonNegative(squatSeconds!, '深蹲用时');
    }
  }

  factory Workout.empty(String date) {
    return Workout(
      date: date,
      pushupCount: 0,
      squatCount: 0,
      plankSets: 0,
      plankSeconds: 0,
    );
  }

  /// `yyyy-MM-dd`
  final String date;
  final int pushupCount;

  /// 早期记录可能填过用时。新的打勾不再填写用时。
  final int? pushupSeconds;
  final int squatCount;
  final int? squatSeconds;

  /// 今天平板支撑做了几组。
  final int plankSets;

  /// 今天平板支撑各组加在一起的秒数。
  final int plankSeconds;

  /// 快走各组加在一起的步数。
  final int walkSteps;

  /// 打勾时的计划。旧记录没有组数时，这些字段是 0。
  final int pushupSets;
  final int pushupPerSet;
  final int squatSets;
  final int squatPerSet;
  final int plankPerSet;
  final int walkSets;
  final int walkPerSet;

  bool isDone(ExerciseKind kind) {
    return switch (kind) {
      ExerciseKind.pushup => pushupCount > 0,
      ExerciseKind.squat => squatCount > 0,
      ExerciseKind.plank => plankSets > 0 || plankSeconds > 0,
      ExerciseKind.walk => walkSteps > 0,
    };
  }

  int get finishedCount {
    return ExerciseKind.values.where(isDone).length;
  }

  bool get hasAnyExercise => finishedCount > 0;

  /// 给历史列表和当天卡片看的简短说明。
  String describe(ExerciseKind kind) {
    switch (kind) {
      case ExerciseKind.pushup:
        return _countLine(
          kind: kind,
          sets: pushupSets,
          perSet: pushupPerSet,
          total: pushupCount,
          seconds: pushupSeconds,
        );
      case ExerciseKind.squat:
        return _countLine(
          kind: kind,
          sets: squatSets,
          perSet: squatPerSet,
          total: squatCount,
          seconds: squatSeconds,
        );
      case ExerciseKind.plank:
        if (plankSets > 0 &&
            plankPerSet > 0 &&
            plankSets * plankPerSet == plankSeconds) {
          return kind.summary(plankSets, plankPerSet);
        }
        if (plankSets > 0 || plankSeconds > 0) {
          return '$plankSets 组，共 $plankSeconds 秒';
        }
        return '';
      case ExerciseKind.walk:
        if (walkSets > 0 &&
            walkPerSet > 0 &&
            walkSets * walkPerSet == walkSteps) {
          return kind.summary(walkSets, walkPerSet);
        }
        if (walkSteps > 0) {
          return '$walkSteps 步';
        }
        return '';
    }
  }

  List<String> get historyLines {
    return [
      for (final kind in ExerciseKind.values)
        if (isDone(kind)) '${kind.label} ${describe(kind)}',
    ];
  }

  Workout withDone(
    ExerciseKind kind, {
    required bool done,
    required ExercisePlan plan,
  }) {
    if (plan.kind != kind) {
      throw ArgumentError('计划和运动项目不一致');
    }
    return switch (kind) {
      ExerciseKind.pushup => _copy(
        pushupCount: done ? plan.total : 0,
        pushupSeconds: null,
        pushupSets: done ? plan.sets : 0,
        pushupPerSet: done ? plan.perSet : 0,
      ),
      ExerciseKind.squat => _copy(
        squatCount: done ? plan.total : 0,
        squatSeconds: null,
        squatSets: done ? plan.sets : 0,
        squatPerSet: done ? plan.perSet : 0,
      ),
      ExerciseKind.plank => _copy(
        plankSets: done ? plan.sets : 0,
        plankSeconds: done ? plan.total : 0,
        plankPerSet: done ? plan.perSet : 0,
      ),
      ExerciseKind.walk => _copy(
        walkSteps: done ? plan.total : 0,
        walkSets: done ? plan.sets : 0,
        walkPerSet: done ? plan.perSet : 0,
      ),
    };
  }

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'pushup_count': pushupCount,
      'pushup_seconds': pushupSeconds,
      'squat_count': squatCount,
      'squat_seconds': squatSeconds,
      'plank_sets': plankSets,
      'plank_seconds': plankSeconds,
      'walk_steps': walkSteps,
      'pushup_sets': pushupSets,
      'pushup_per_set': pushupPerSet,
      'squat_sets': squatSets,
      'squat_per_set': squatPerSet,
      'plank_per_set': plankPerSet,
      'walk_sets': walkSets,
      'walk_per_set': walkPerSet,
    };
  }

  factory Workout.fromMap(Map<String, Object?> map) {
    return Workout(
      date: map['date'] as String,
      pushupCount: map['pushup_count'] as int,
      pushupSeconds: map['pushup_seconds'] as int?,
      squatCount: map['squat_count'] as int,
      squatSeconds: map['squat_seconds'] as int?,
      plankSets: map['plank_sets'] as int,
      plankSeconds: map['plank_seconds'] as int,
      walkSteps: _optionalInt(map['walk_steps']),
      pushupSets: _optionalInt(map['pushup_sets']),
      pushupPerSet: _optionalInt(map['pushup_per_set']),
      squatSets: _optionalInt(map['squat_sets']),
      squatPerSet: _optionalInt(map['squat_per_set']),
      plankPerSet: _optionalInt(map['plank_per_set']),
      walkSets: _optionalInt(map['walk_sets']),
      walkPerSet: _optionalInt(map['walk_per_set']),
    );
  }

  Workout _copy({
    int? pushupCount,
    Object? pushupSeconds = _keep,
    int? pushupSets,
    int? pushupPerSet,
    int? squatCount,
    Object? squatSeconds = _keep,
    int? squatSets,
    int? squatPerSet,
    int? plankSets,
    int? plankSeconds,
    int? plankPerSet,
    int? walkSteps,
    int? walkSets,
    int? walkPerSet,
  }) {
    return Workout(
      date: date,
      pushupCount: pushupCount ?? this.pushupCount,
      pushupSeconds: identical(pushupSeconds, _keep)
          ? this.pushupSeconds
          : pushupSeconds as int?,
      pushupSets: pushupSets ?? this.pushupSets,
      pushupPerSet: pushupPerSet ?? this.pushupPerSet,
      squatCount: squatCount ?? this.squatCount,
      squatSeconds: identical(squatSeconds, _keep)
          ? this.squatSeconds
          : squatSeconds as int?,
      squatSets: squatSets ?? this.squatSets,
      squatPerSet: squatPerSet ?? this.squatPerSet,
      plankSets: plankSets ?? this.plankSets,
      plankSeconds: plankSeconds ?? this.plankSeconds,
      plankPerSet: plankPerSet ?? this.plankPerSet,
      walkSteps: walkSteps ?? this.walkSteps,
      walkSets: walkSets ?? this.walkSets,
      walkPerSet: walkPerSet ?? this.walkPerSet,
    );
  }
}

/// 勾选或取消一项。四项都取消时返回 null，调用方要删掉这一天的记录。
Workout? applyExerciseCheck({
  required Workout? current,
  required String date,
  required ExerciseKind kind,
  required ExercisePlan plan,
}) {
  validateDayKey(date);
  if (current != null && current.date != date) {
    throw ArgumentError('记录日期和正在查看的日期不一致');
  }
  final base = current ?? Workout.empty(date);
  final next = base.withDone(kind, done: !base.isDone(kind), plan: plan);
  if (!next.hasAnyExercise) {
    return null;
  }
  return next;
}

String _countLine({
  required ExerciseKind kind,
  required int sets,
  required int perSet,
  required int total,
  required int? seconds,
}) {
  if (sets > 0 && perSet > 0) {
    final base = kind.summary(sets, perSet);
    if (seconds != null) {
      return '$base，用时 $seconds 秒';
    }
    return base;
  }
  if (total <= 0) {
    return '';
  }
  if (seconds != null) {
    return '$total 个，用时 $seconds 秒';
  }
  return '$total 个';
}

int _optionalInt(Object? value) {
  if (value == null) {
    return 0;
  }
  return value as int;
}

void _nonNegative(int value, String label) {
  if (value < 0) {
    throw ArgumentError.value(value, label, '不能小于 0');
  }
}

const _keep = Object();
