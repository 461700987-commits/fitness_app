/// 每天要打卡的四项运动。
enum ExerciseKind {
  pushup('pushup', '俯卧撑', '个', 200),
  squat('squat', '深蹲', '个', 200),
  plank('plank', '平板支撑', '秒', 600),
  walk('walk', '快走', '步', 100000);

  const ExerciseKind(this.id, this.label, this.unit, this.maxPerSet);

  final String id;
  final String label;

  /// 个数、秒数或步数。
  final String unit;

  /// 每一组最多能填多少，避免误输入特别大的数字。
  final int maxPerSet;

  static const maxSets = 30;

  static ExerciseKind fromId(String id) {
    for (final kind in ExerciseKind.values) {
      if (kind.id == id) {
        return kind;
      }
    }
    throw ArgumentError.value(id, 'id', '未知的运动项目');
  }

  /// 一组时，快走直接显示步数，例如 `8000 步`。
  String summary(int sets, int perSet) {
    if (this == ExerciseKind.walk && sets <= 1) {
      return '$perSet $unit';
    }
    return '$sets 组 × $perSet $unit';
  }
}

/// 某一项运动的计划：做几组，以及每一组的数量。
///
/// 每一组用同一个数。例如俯卧撑 3 组、每组 15 个。
class ExercisePlan {
  const ExercisePlan({
    required this.kind,
    required this.sets,
    required this.perSet,
  });

  final ExerciseKind kind;
  final int sets;
  final int perSet;

  int get total => sets * perSet;

  String get summary => kind.summary(sets, perSet);

  static const pushup = ExercisePlan(
    kind: ExerciseKind.pushup,
    sets: 3,
    perSet: 15,
  );
  static const squat = ExercisePlan(
    kind: ExerciseKind.squat,
    sets: 3,
    perSet: 20,
  );
  static const plank = ExercisePlan(
    kind: ExerciseKind.plank,
    sets: 3,
    perSet: 40,
  );
  static const walk = ExercisePlan(
    kind: ExerciseKind.walk,
    sets: 1,
    perSet: 8000,
  );

  static ExercisePlan defaultFor(ExerciseKind kind) {
    return switch (kind) {
      ExerciseKind.pushup => pushup,
      ExerciseKind.squat => squat,
      ExerciseKind.plank => plank,
      ExerciseKind.walk => walk,
    };
  }

  static final defaults = {
    for (final kind in ExerciseKind.values) kind: defaultFor(kind),
  };

  Map<String, Object?> toMap() {
    return {'id': kind.id, 'sets': sets, 'per_set': perSet};
  }

  factory ExercisePlan.fromMap(Map<String, Object?> map) {
    final kind = ExerciseKind.fromId(map['id'] as String);
    final sets = map['sets'] as int;
    final perSet = map['per_set'] as int;
    if (planError(kind, sets, perSet) != null) {
      return defaultFor(kind);
    }
    return ExercisePlan(kind: kind, sets: sets, perSet: perSet);
  }
}

/// 组数或每组数量不合适时，返回给界面显示的说明。合适则返回 null。
String? planError(ExerciseKind kind, int sets, int perSet) {
  if (sets < 1 || sets > ExerciseKind.maxSets) {
    return '组数请填 1 到 ${ExerciseKind.maxSets}';
  }
  if (perSet < 1 || perSet > kind.maxPerSet) {
    return '每组请填 1 到 ${kind.maxPerSet} ${kind.unit}';
  }
  return null;
}
