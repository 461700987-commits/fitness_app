import 'dart:io';

import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/models/body_metric.dart';
import 'package:fitness_app/models/exercise_plan.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitness_app_test_');
    db = await AppDatabase.open(path: '${tempDir.path}/fitness.db');
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Workout sampleWorkout({
    String date = '2026-11-07',
    int pushupCount = 20,
    int? pushupSeconds = 90,
    int squatCount = 30,
    int? squatSeconds = 100,
    int plankSets = 3,
    int plankSeconds = 90,
  }) {
    return Workout(
      date: date,
      pushupCount: pushupCount,
      pushupSeconds: pushupSeconds,
      squatCount: squatCount,
      squatSeconds: squatSeconds,
      plankSets: plankSets,
      plankSeconds: plankSeconds,
    );
  }

  test('保存后能按当天读出运动记录', () async {
    await db.saveWorkout(sampleWorkout());

    final loaded = await db.workoutOn('2026-11-07');

    expect(loaded, isNotNull);
    expect(loaded!.pushupCount, 20);
    expect(loaded.pushupSeconds, 90);
    expect(loaded.squatCount, 30);
    expect(loaded.squatSeconds, 100);
    expect(loaded.plankSets, 3);
    expect(loaded.plankSeconds, 90);
  });

  test('同一天再次保存会覆盖原来的记录', () async {
    await db.saveWorkout(sampleWorkout());
    await db.saveWorkout(
      sampleWorkout(
        pushupCount: 40,
        pushupSeconds: null,
        plankSets: 4,
        plankSeconds: 120,
      ),
    );

    final loaded = await db.workoutOn('2026-11-07');

    expect(loaded!.pushupCount, 40);
    expect(loaded.pushupSeconds, isNull);
    expect(loaded.plankSets, 4);
    expect(loaded.plankSeconds, 120);
    expect(await db.workoutsBetween('2026-11-01', '2026-11-30'), hasLength(1));
  });

  test('没有记录的日期读出来是空', () async {
    expect(await db.workoutOn('2026-11-07'), isNull);
    expect(await db.bodyMetricOn('2026-11-07'), isNull);
  });

  test('可以只保存体重，腰围留空', () async {
    await db.saveBodyMetric(BodyMetric(date: '2026-11-07', weightKg: 70.5));

    final loaded = await db.bodyMetricOn('2026-11-07');

    expect(loaded!.weightKg, 70.5);
    expect(loaded.waistCm, isNull);
  });

  test('同一天再次保存身体数据会覆盖', () async {
    await db.saveBodyMetric(
      BodyMetric(date: '2026-11-07', weightKg: 70.5, waistCm: 80),
    );
    await db.saveBodyMetric(BodyMetric(date: '2026-11-07', waistCm: 79));

    final loaded = await db.bodyMetricOn('2026-11-07');

    expect(loaded!.weightKg, isNull);
    expect(loaded.waistCm, 79);
  });

  test('按日期范围读出记录，并按日期排序', () async {
    await db.saveWorkout(sampleWorkout(date: '2026-11-08', pushupCount: 8));
    await db.saveWorkout(sampleWorkout(date: '2026-11-06', pushupCount: 6));
    await db.saveWorkout(sampleWorkout(date: '2026-11-01', pushupCount: 1));
    await db.saveBodyMetric(BodyMetric(date: '2026-11-08', weightKg: 70));
    await db.saveBodyMetric(BodyMetric(date: '2026-11-06', waistCm: 80));

    final workouts = await db.workoutsBetween('2026-11-06', '2026-11-08');
    final metrics = await db.bodyMetricsBetween('2026-11-06', '2026-11-08');

    expect(workouts.map((item) => item.date), ['2026-11-06', '2026-11-08']);
    expect(workouts.map((item) => item.pushupCount), [6, 8]);
    expect(
      await db.allWorkouts().then((items) => items.map((item) => item.date)),
      ['2026-11-08', '2026-11-06', '2026-11-01'],
    );
    expect(metrics.map((item) => item.date), ['2026-11-06', '2026-11-08']);
    expect(
      await db.allBodyMetrics().then((items) => items.map((item) => item.date)),
      ['2026-11-08', '2026-11-06'],
    );
  });

  test('次数不能为负数，体重和腰围不能都不填', () {
    expect(() => sampleWorkout(pushupCount: -1), throwsArgumentError);
    expect(
      () => Workout(
        date: '2026-11-07',
        pushupCount: 0,
        squatCount: 0,
        plankSets: 0,
        plankSeconds: 0,
        walkSteps: -1,
      ),
      throwsArgumentError,
    );
    expect(() => BodyMetric(date: '2026-11-07'), throwsArgumentError);
    expect(
      () => BodyMetric(date: '2026-11-07', weightKg: 0),
      throwsArgumentError,
    );
  });

  test('打勾时的组数和每组数量会一起保存', () async {
    await db.saveWorkout(
      Workout(
        date: '2026-11-07',
        pushupCount: 45,
        squatCount: 60,
        plankSets: 3,
        plankSeconds: 120,
        walkSteps: 8000,
        pushupSets: 3,
        pushupPerSet: 15,
        squatSets: 3,
        squatPerSet: 20,
        plankPerSet: 40,
        walkSets: 1,
        walkPerSet: 8000,
      ),
    );

    final loaded = await db.workoutOn('2026-11-07');

    expect(loaded!.describe(ExerciseKind.pushup), '3 组 × 15 个');
    expect(loaded.describe(ExerciseKind.squat), '3 组 × 20 个');
    expect(loaded.describe(ExerciseKind.plank), '3 组 × 40 秒');
    expect(loaded.describe(ExerciseKind.walk), '8000 步');
    expect(loaded.finishedCount, 4);
  });

  test('新数据库带有四项默认计划，修改后重新打开还在', () async {
    final initial = await db.loadPlans();
    expect(initial[ExerciseKind.pushup]!.summary, '3 组 × 15 个');
    expect(initial[ExerciseKind.squat]!.summary, '3 组 × 20 个');
    expect(initial[ExerciseKind.plank]!.summary, '3 组 × 40 秒');
    expect(initial[ExerciseKind.walk]!.summary, '8000 步');

    await db.savePlan(
      const ExercisePlan(kind: ExerciseKind.walk, sets: 2, perSet: 4000),
    );
    await db.close();
    db = await AppDatabase.open(path: '${tempDir.path}/fitness.db');

    final loaded = await db.loadPlans();
    expect(loaded[ExerciseKind.walk]!.summary, '2 组 × 4000 步');
    expect(loaded[ExerciseKind.pushup]!.perSet, 15);
    expect(
      () => db.savePlan(
        const ExercisePlan(kind: ExerciseKind.pushup, sets: 0, perSet: 15),
      ),
      throwsArgumentError,
    );
  });

  test('旧版本数据库升级后，原来的打卡和身体记录都还在', () async {
    final legacyPath = '${tempDir.path}/legacy.db';
    final legacy = await openDatabase(
      legacyPath,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE workouts (
            date TEXT PRIMARY KEY,
            pushup_count INTEGER NOT NULL,
            pushup_seconds INTEGER,
            squat_count INTEGER NOT NULL,
            squat_seconds INTEGER,
            plank_sets INTEGER NOT NULL,
            plank_seconds INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE body_metrics (
            date TEXT PRIMARY KEY,
            weight_kg REAL,
            waist_cm REAL
          )
        ''');
      },
    );
    await legacy.insert('workouts', {
      'date': '2026-11-07',
      'pushup_count': 20,
      'pushup_seconds': 90,
      'squat_count': 30,
      'squat_seconds': null,
      'plank_sets': 3,
      'plank_seconds': 90,
    });
    await legacy.insert('body_metrics', {
      'date': '2026-11-07',
      'weight_kg': 70.5,
      'waist_cm': 80,
    });
    await legacy.close();

    final upgraded = await AppDatabase.open(path: legacyPath);
    try {
      final loaded = await upgraded.workoutOn('2026-11-07');
      expect(loaded!.pushupCount, 20);
      expect(loaded.pushupSeconds, 90);
      expect(loaded.pushupSets, 1);
      expect(loaded.pushupPerSet, 20);
      expect(loaded.squatCount, 30);
      expect(loaded.squatPerSet, 30);
      expect(loaded.plankSets, 3);
      expect(loaded.plankSeconds, 90);
      expect(loaded.plankPerSet, 30);
      expect(loaded.walkSteps, 0);
      expect(loaded.isDone(ExerciseKind.walk), isFalse);
      expect(loaded.describe(ExerciseKind.pushup), '1 组 × 20 个，用时 90 秒');
      expect(loaded.describe(ExerciseKind.plank), '3 组 × 30 秒');

      final metric = await upgraded.bodyMetricOn('2026-11-07');
      expect(metric!.weightKg, 70.5);
      expect(metric.waistCm, 80);

      final plans = await upgraded.loadPlans();
      expect(plans[ExerciseKind.pushup]!.perSet, 15);
      expect(plans[ExerciseKind.walk]!.perSet, 8000);
    } finally {
      await upgraded.close();
    }
  });
}
