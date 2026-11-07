import 'dart:async';
import 'dart:io';

import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/models/exercise_plan.dart';
import 'package:fitness_app/state/today_workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late TodayWorkout today;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitness_app_today_');
    database = await AppDatabase.open(path: '${tempDir.path}/fitness.db');
    today = TodayWorkout(database);
    await today.load();
  });

  tearDown(() async {
    today.dispose();
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('保存运动记录期间切换日期，不会导致错误日期写入', () async {
    final gate = Completer<void>();
    today.debugPersistPause = () => gate.future;
    final original = today.selectedDate;
    const other = '2020-01-03';

    final pending = today.toggle(ExerciseKind.pushup);
    expect(today.saving, isTrue);

    try {
      await today.select(other);

      expect(today.selectedDate, original);
      expect(await database.workoutOn(original), isNull);
      expect(await database.workoutOn(other), isNull);
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
    expect(await pending, isTrue);
    expect(today.saving, isFalse);
    expect(today.errorMessage, isNull);
    expect(today.selectedDate, original);
    expect(today.workout!.date, original);
    expect(today.workout!.pushupCount, 45);

    expect((await database.workoutOn(original))!.pushupCount, 45);
    expect(await database.workoutOn(other), isNull);

    await today.select(other);
    expect(today.selectedDate, other);
    expect(today.workout, isNull);
  });

  test('保存失败后恢复可操作状态并提示', () async {
    today.debugPersistPause = () async {
      throw StateError('disk');
    };

    final saved = await today.toggle(ExerciseKind.pushup);

    expect(saved, isFalse);
    expect(today.saving, isFalse);
    expect(today.errorMessage, '保存失败，请重试');
    expect(today.workout, isNull);
    expect(await database.workoutOn(today.selectedDate), isNull);

    today.debugPersistPause = null;
    expect(await today.toggle(ExerciseKind.pushup), isTrue);
    expect(today.errorMessage, isNull);
    expect(today.workout!.pushupCount, 45);
  });
}
