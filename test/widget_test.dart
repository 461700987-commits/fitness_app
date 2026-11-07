import 'dart:io';

import 'package:fitness_app/app.dart';
import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/body_metric.dart';
import 'package:fitness_app/models/week_summary.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:fitness_app/state/body_records.dart';
import 'package:fitness_app/state/exercise_plans.dart';
import 'package:fitness_app/state/today_workout.dart';
import 'package:fitness_app/state/weekly_stats.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  late AppDatabase database;
  late TodayWorkout today;
  late ExercisePlans plans;
  late BodyRecords body;
  late WeeklyStats weekly;
  var databaseOpen = false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitness_app_widget_');
    dbPath = '${tempDir.path}/fitness.db';
    database = await AppDatabase.open(path: dbPath);
    databaseOpen = true;
    today = TodayWorkout(database);
    plans = ExercisePlans(database);
    body = BodyRecords(database);
    weekly = WeeklyStats(database);
    await today.load();
    await plans.load();
    await body.load();
    await weekly.load();
  });

  tearDown(() async {
    try {
      today.dispose();
    } on StateError {
      // 重新打开的测试里，旧的记录对象已经释放过。
    }
    try {
      plans.dispose();
    } on StateError {
      // 重新打开的测试里，旧的记录对象已经释放过。
    }
    try {
      body.dispose();
    } on StateError {
      // 重新打开的测试里，旧的记录对象已经释放过。
    }
    try {
      weekly.dispose();
    } on StateError {
      // 重新打开的测试里，旧的记录对象已经释放过。
    }
    if (databaseOpen) {
      await database.close();
      databaseOpen = false;
    }
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> reopen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final previousToday = today;
    final previousPlans = plans;
    final previousBody = body;
    final previousWeekly = weekly;
    previousToday.dispose();
    previousPlans.dispose();
    previousBody.dispose();
    previousWeekly.dispose();
    await tester.runAsync(() async {
      await database.close();
      databaseOpen = false;
      database = await AppDatabase.open(path: dbPath);
      databaseOpen = true;
      today = TodayWorkout(database);
      plans = ExercisePlans(database);
      body = BodyRecords(database);
      weekly = WeeklyStats(database);
      await today.load();
      await plans.load();
      await body.load();
      await weekly.load();
    });
    await _showApp(tester, today, plans, body, weekly);
  }

  testWidgets('底部导航可以在三个页面之间切换', (tester) async {
    await _showApp(tester, today, plans, body, weekly);

    expect(find.text('今日打卡'), findsOneWidget);
    expect(find.text('今天还没有打卡'), findsOneWidget);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('每周统计'), findsOneWidget);
    expect(find.text('本周还没有运动记录'), findsOneWidget);

    await tester.tap(find.text('身体'));
    await tester.pumpAndSettle();
    expect(find.text('身体记录'), findsOneWidget);
    expect(find.text('还没有体重和腰围记录'), findsOneWidget);
    expect(find.text('还没有记录'), findsNWidgets(2));
    expect(find.byKey(const Key('weightChart')), findsNothing);
    expect(find.byKey(const Key('waistChart')), findsNothing);

    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();
    expect(find.text('今天还没有打卡'), findsOneWidget);
  });

  testWidgets('取消全部分勾后，这一天不再算打卡', (tester) async {
    await _showApp(tester, today, plans, body, weekly);

    await _toggle(tester, 'pushup');
    expect(find.text('今天已完成 1/4'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 15 个'), findsOneWidget);

    await _toggle(tester, 'pushup');
    expect(find.text('今天还没有打卡'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 15 个'), findsNothing);
    expect(find.text('计划 · 3 组 × 15 个'), findsOneWidget);
  });

  testWidgets('勾选四项后，重新打开仍然在', (tester) async {
    await _showApp(tester, today, plans, body, weekly);
    await _toggle(tester, 'pushup');
    await _toggle(tester, 'squat');
    await _toggle(tester, 'plank');
    await _toggle(tester, 'walk');

    expect(find.text('今天全部完成'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 15 个'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 20 个'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 40 秒'), findsOneWidget);
    expect(find.text('已完成 · 8000 步'), findsOneWidget);

    await reopen(tester);

    expect(find.text('今天全部完成'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 15 个'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 20 个'), findsOneWidget);
    expect(find.text('已完成 · 3 组 × 40 秒'), findsOneWidget);
    expect(find.text('已完成 · 8000 步'), findsOneWidget);
  });

  testWidgets('可以只记录体重，历史按日期从新到旧排列', (tester) async {
    await tester.runAsync(() async {
      await database.saveBodyMetric(
        BodyMetric(date: '2020-01-02', waistCm: 90),
      );
      await body.load();
    });
    await _showApp(tester, today, plans, body, weekly);

    await tester.tap(find.text('身体'));
    await tester.pumpAndSettle();
    expect(find.text('今天还没有记录'), findsOneWidget);
    expect(find.text('2020年1月2日'), findsOneWidget);
    expect(find.text('腰围 90 厘米'), findsOneWidget);

    await _enter(tester, const Key('weightKg'), '70.5');
    await tester.ensureVisible(find.byKey(const Key('saveBody')));
    await tester.tap(find.byKey(const Key('saveBody')));
    await _flushDatabase(tester);

    expect(find.text('今天已记录'), findsOneWidget);
    expect(find.text('体重 70.5 千克'), findsWidgets);
    expect(find.text('更新今天的记录'), findsOneWidget);
    expect(find.byKey(const Key('weightChart')), findsOneWidget);
    expect(find.byKey(const Key('waistChart')), findsOneWidget);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(
      (tiles.first.title as Text).data,
      formatChineseDay(dayKeyFrom(DateTime.now())),
    );
    expect((tiles[1].title as Text).data, '2020年1月2日');

    await reopen(tester);
    await tester.tap(find.text('身体'));
    await tester.pumpAndSettle();

    expect(find.text('今天已记录'), findsOneWidget);
    expect(find.text('体重 70.5 千克'), findsWidgets);
    expect(find.text('腰围 90 厘米'), findsOneWidget);
    expect(find.byKey(const Key('weightChart')), findsOneWidget);
    expect(find.byKey(const Key('waistChart')), findsOneWidget);
  });

  testWidgets('打卡后本周统计只计算周一到周日', (tester) async {
    final outside = DateTime.now().subtract(const Duration(days: 8));
    await tester.runAsync(() async {
      await database.saveWorkout(
        Workout(
          date: dayKeyFrom(outside),
          pushupCount: 99,
          squatCount: 99,
          plankSets: 9,
          plankSeconds: 99,
        ),
      );
      await weekly.load();
    });
    await _showApp(tester, today, plans, body, weekly);
    await _toggle(tester, 'pushup');
    await _toggle(tester, 'squat');
    await _toggle(tester, 'plank');
    await _toggle(tester, 'walk');

    await tester.tap(find.text('统计'));
    await _flushDatabase(tester);

    final days = daysOfWeek(DateTime.now());
    expect(
      find.text(
        '${formatChineseDay(days.first)} 至 ${formatChineseDay(days.last)}',
      ),
      findsOneWidget,
    );
    expect(find.text('打卡 1/7 天'), findsOneWidget);
    expect(find.text('俯卧撑 45 个'), findsOneWidget);
    expect(find.text('深蹲 60 个'), findsOneWidget);
    expect(find.text('平板支撑 3 组'), findsOneWidget);
    expect(find.text('平板支撑 120 秒'), findsOneWidget);
    expect(find.text('快走 8000 步'), findsOneWidget);
    expect(find.text('本周还没有运动记录'), findsNothing);
    final outsideKey = dayKeyFrom(outside);
    await tester.ensureVisible(find.byKey(Key('history-$outsideKey')));
    expect(find.text(formatChineseDay(outsideKey)), findsOneWidget);
    expect(find.textContaining('俯卧撑 99 个'), findsOneWidget);
    final todayKey = dayKeyFrom(DateTime.now());
    expect(
      tester.widget<Icon>(find.byKey(Key('weekDay-$todayKey'))).icon,
      Icons.check_circle,
    );
  });

  testWidgets('可以从统计页修改以前某一天的打卡', (tester) async {
    final days = daysOfWeek(DateTime.now());
    final todayKey = dayKeyFrom(DateTime.now());
    final past = days.first == todayKey ? days[1] : days.first;
    await tester.runAsync(() async {
      await database.saveWorkout(
        Workout(
          date: past,
          pushupCount: 10,
          squatCount: 4,
          plankSets: 1,
          plankSeconds: 20,
        ),
      );
      await weekly.load();
    });
    await _showApp(tester, today, plans, body, weekly);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(Key('weekDay-$past')));
    await tester.tap(find.byKey(Key('weekDay-$past')));
    await _flushDatabase(tester);

    expect(find.text('今日打卡'), findsOneWidget);
    expect(find.text(formatChineseDay(past)), findsWidgets);
    expect(find.text('正在查看以前的记录'), findsOneWidget);
    expect(find.text('这一天已完成 3/4'), findsOneWidget);
    expect(find.text('已完成 · 10 个'), findsOneWidget);
    expect(find.text('计划 · 8000 步'), findsOneWidget);

    await _toggle(tester, 'walk');
    await _toggle(tester, 'pushup');

    await tester.tap(find.text('统计'));
    await _flushDatabase(tester);
    expect(find.text('俯卧撑 0 个'), findsOneWidget);
    expect(find.text('深蹲 4 个'), findsOneWidget);
    expect(find.text('平板支撑 1 组'), findsOneWidget);
    expect(find.text('平板支撑 20 秒'), findsOneWidget);
    expect(find.text('快走 8000 步'), findsOneWidget);
  });

  testWidgets('可以改组数和每组数量，已经打勾的记录先保持原计划', (tester) async {
    await _showApp(tester, today, plans, body, weekly);
    await _toggle(tester, 'pushup');
    expect(find.text('已完成 · 3 组 × 15 个'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-pushup')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('planSets')), '2');
    await tester.enterText(find.byKey(const Key('planPerSet')), '10');
    await tester.tap(find.byKey(const Key('savePlan')));
    await _flushDatabase(tester);
    await tester.pumpAndSettle();

    expect(find.text('已完成 · 3 组 × 15 个'), findsOneWidget);
    expect(find.text('计划 · 2 组 × 10 个'), findsNothing);

    await _toggle(tester, 'pushup');
    await _toggle(tester, 'pushup');
    expect(find.text('已完成 · 2 组 × 10 个'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit-walk')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restorePlan')));
    await tester.pump();
    expect(find.text('8000'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('planSets')), '2');
    await tester.enterText(find.byKey(const Key('planPerSet')), '4000');
    await tester.tap(find.byKey(const Key('savePlan')));
    await _flushDatabase(tester);
    await tester.pumpAndSettle();

    expect(find.text('计划 · 2 组 × 4000 步'), findsOneWidget);

    await reopen(tester);
    expect(find.text('已完成 · 2 组 × 10 个'), findsOneWidget);
    expect(find.text('计划 · 2 组 × 4000 步'), findsOneWidget);
  });

  testWidgets('可以修改以前某一天的腰围', (tester) async {
    await tester.runAsync(() async {
      await database.saveBodyMetric(
        BodyMetric(date: '2020-01-02', waistCm: 90),
      );
      await body.load();
    });
    await _showApp(tester, today, plans, body, weekly);
    await tester.tap(find.text('身体'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('bodyDay-2020-01-02')));
    await tester.tap(find.byKey(const Key('bodyDay-2020-01-02')));
    await tester.pump();

    expect(find.text('正在查看以前的记录'), findsOneWidget);
    expect(find.text('这一天已记录'), findsOneWidget);
    expect(find.text('90'), findsWidgets);

    await _enter(tester, const Key('waistCm'), '88');
    await tester.ensureVisible(find.byKey(const Key('saveBody')));
    await tester.tap(find.byKey(const Key('saveBody')));
    await _flushDatabase(tester);

    expect(find.text('腰围 88 厘米'), findsWidgets);
    await tester.tap(find.byKey(const Key('backToTodayBody')));
    await tester.pump();
    expect(find.text('今天还没有记录'), findsOneWidget);
  });

  testWidgets('修改过去的身体记录后，列表和折线立刻按日期排列', (tester) async {
    await tester.runAsync(() async {
      await database.saveBodyMetric(
        BodyMetric(date: '2020-01-02', weightKg: 80),
      );
      await database.saveBodyMetric(
        BodyMetric(date: '2020-01-05', weightKg: 70),
      );
      await body.load();
    });
    await _showApp(tester, today, plans, body, weekly);
    await tester.tap(find.text('身体'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('bodyDay-2020-01-02')));
    await tester.tap(find.byKey(const Key('bodyDay-2020-01-02')));
    await tester.pump();
    await _enter(tester, const Key('weightKg'), '90');
    await tester.ensureVisible(find.byKey(const Key('saveBody')));
    await tester.tap(find.byKey(const Key('saveBody')));
    await _flushDatabase(tester);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles[0].title as Text).data, '2020年1月5日');
    expect((tiles[1].title as Text).data, '2020年1月2日');

    final chart = tester.widget<LineChart>(
      find.descendant(
        of: find.byKey(const Key('weightChart')),
        matching: find.byType(LineChart),
      ),
    );
    expect(
      chart.data.lineBarsData.single.spots.map((spot) => spot.y).toList(),
      [90, 70],
    );
  });

  testWidgets('体重和腰围都空着不能保存', (tester) async {
    await _showApp(tester, today, plans, body, weekly);
    await tester.tap(find.text('身体'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveBody')));
    await tester.tap(find.byKey(const Key('saveBody')));
    await tester.pump();

    expect(find.text('请至少填写体重或腰围'), findsOneWidget);
    expect(find.text('今天已记录'), findsNothing);
  });
}

Future<void> _showApp(
  WidgetTester tester,
  TodayWorkout today,
  ExercisePlans plans,
  BodyRecords body,
  WeeklyStats weekly,
) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    FitnessApp(today: today, plans: plans, body: body, weekly: weekly),
  );
  await tester.pump();
}

Future<void> _toggle(WidgetTester tester, String kind) async {
  final key = Key('check-$kind');
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await _flushDatabase(tester);
}

/// 保存打卡时，数据库读写发生在测试时钟之外。
Future<void> _flushDatabase(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
}
