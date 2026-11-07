import 'package:fitness_app/models/exercise_plan.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('默认计划是俯卧撑、深蹲、平板支撑和快走', () {
    expect(ExercisePlan.defaultFor(ExerciseKind.pushup).summary, '3 组 × 15 个');
    expect(ExercisePlan.defaultFor(ExerciseKind.squat).summary, '3 组 × 20 个');
    expect(ExercisePlan.defaultFor(ExerciseKind.plank).summary, '3 组 × 40 秒');
    expect(ExercisePlan.defaultFor(ExerciseKind.walk).summary, '8000 步');
    expect(planError(ExerciseKind.pushup, 0, 15), isNotNull);
    expect(planError(ExerciseKind.walk, 1, 0), isNotNull);
    expect(planError(ExerciseKind.plank, 3, 40), isNull);
  });

  test('打勾按当前计划计算，取消最后一项后这一天清空', () {
    final checked = applyExerciseCheck(
      current: null,
      date: '2026-11-07',
      kind: ExerciseKind.pushup,
      plan: ExercisePlan.defaultFor(ExerciseKind.pushup),
    );

    expect(checked!.pushupCount, 45);
    expect(checked.pushupSets, 3);
    expect(checked.pushupPerSet, 15);
    expect(checked.describe(ExerciseKind.pushup), '3 组 × 15 个');

    final cleared = applyExerciseCheck(
      current: checked,
      date: '2026-11-07',
      kind: ExerciseKind.pushup,
      plan: ExercisePlan.defaultFor(ExerciseKind.pushup),
    );
    expect(cleared, isNull);
  });

  test('四项可以分别打勾，改计划不会改已经算好的数量', () {
    var day = applyExerciseCheck(
      current: null,
      date: '2026-11-07',
      kind: ExerciseKind.pushup,
      plan: ExercisePlan.pushup,
    );
    day = applyExerciseCheck(
      current: day,
      date: '2026-11-07',
      kind: ExerciseKind.squat,
      plan: ExercisePlan.squat,
    );
    day = applyExerciseCheck(
      current: day,
      date: '2026-11-07',
      kind: ExerciseKind.plank,
      plan: ExercisePlan.plank,
    );
    day = applyExerciseCheck(
      current: day,
      date: '2026-11-07',
      kind: ExerciseKind.walk,
      plan: ExercisePlan.walk,
    );

    expect(day!.finishedCount, 4);
    expect(day.squatCount, 60);
    expect(day.plankSets, 3);
    expect(day.plankSeconds, 120);
    expect(day.walkSteps, 8000);
    expect(day.historyLines, [
      '俯卧撑 3 组 × 15 个',
      '深蹲 3 组 × 20 个',
      '平板支撑 3 组 × 40 秒',
      '快走 8000 步',
    ]);

    final custom = const ExercisePlan(
      kind: ExerciseKind.walk,
      sets: 2,
      perSet: 3000,
    );
    expect(day.walkSteps, 8000);
    final redone = applyExerciseCheck(
      current: applyExerciseCheck(
        current: day,
        date: '2026-11-07',
        kind: ExerciseKind.walk,
        plan: custom,
      ),
      date: '2026-11-07',
      kind: ExerciseKind.walk,
      plan: custom,
    );
    expect(redone!.walkSteps, 6000);
    expect(redone.pushupCount, 45);
    expect(redone.describe(ExerciseKind.walk), '2 组 × 3000 步');
  });
}
