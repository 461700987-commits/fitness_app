import 'dart:io';

import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:fitness_app/screens/database_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitness_app_startup_');
    dbPath = '${tempDir.path}/fitness.db';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('数据库打开失败时显示错误提示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DatabaseErrorScreen(onRetry: () {})),
    );

    expect(find.text('打不开手机里的健康记录'), findsOneWidget);
    expect(find.text('记录还在这台手机上，没有被删除，也没有被清空。可以再试一次。'), findsOneWidget);
    expect(find.byKey(const Key('retryOpenDatabase')), findsOneWidget);
    expect(find.text('重新尝试'), findsOneWidget);
  });

  testWidgets('点击重试后可以重新尝试打开数据库', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      const MaterialApp(
        home: DatabaseErrorScreen(onRetry: _ignoreRetry),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DatabaseErrorScreen(
          onRetry: () {
            attempts += 1;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('retryOpenDatabase')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('retryOpenDatabase')));
    await tester.pump();

    expect(attempts, 2);
  });

  test('再次打开同一个数据库，原来的运动记录还在', () async {
    final today = dayKeyFrom(DateTime.now());
    final seeded = await AppDatabase.open(path: dbPath);
    await seeded.saveWorkout(
      Workout(
        date: today,
        pushupCount: 20,
        squatCount: 0,
        plankSets: 0,
        plankSeconds: 0,
      ),
    );
    await seeded.close();

    final reopened = await AppDatabase.open(path: dbPath);
    try {
      expect(File(dbPath).existsSync(), isTrue);
      expect((await reopened.workoutOn(today))!.pushupCount, 20);
    } finally {
      await reopened.close();
    }
  });
}

void _ignoreRetry() {}
