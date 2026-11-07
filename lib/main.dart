import 'package:fitness_app/app.dart';
import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/screens/database_error_screen.dart';
import 'package:fitness_app/state/body_records.dart';
import 'package:fitness_app/state/exercise_plans.dart';
import 'package:fitness_app/state/today_workout.dart';
import 'package:fitness_app/state/weekly_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitnessBootstrap());
}

/// 先打开本地数据库，再进入打卡页面。
///
/// 打开失败时只显示说明和重试。不会删除、清空或重建数据库文件。
class FitnessBootstrap extends StatefulWidget {
  const FitnessBootstrap({super.key, this.openDatabase});

  /// 正式启动不传，测试可以换成会失败的打开方式。
  final Future<AppDatabase> Function()? openDatabase;

  @override
  State<FitnessBootstrap> createState() => _FitnessBootstrapState();
}

class _FitnessBootstrapState extends State<FitnessBootstrap> {
  AppDatabase? _database;
  FitnessApp? _app;
  Object? _error;
  var _opening = true;
  var _loadInProgress = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  void _retry() {
    if (_loadInProgress) {
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    _load();
  }

  void _load() {
    if (_loadInProgress) {
      return;
    }
    _loadInProgress = true;
    final Future<AppDatabase> opening;
    try {
      opening = (widget.openDatabase ?? AppDatabase.open)();
    } catch (error) {
      _fail(error);
      return;
    }
    opening.then(_useDatabase, onError: _fail);
  }

  Future<void> _useDatabase(AppDatabase database) async {
    TodayWorkout? today;
    ExercisePlans? plans;
    BodyRecords? body;
    WeeklyStats? weekly;
    try {
      if (!mounted) {
        await database.close();
        return;
      }
      today = TodayWorkout(database);
      plans = ExercisePlans(database);
      body = BodyRecords(database);
      weekly = WeeklyStats(database);
      await today.load();
      await plans.load();
      await body.load();
      await weekly.load();
      if (!mounted) {
        _release(today, plans, body, weekly, database);
        return;
      }
      setState(() {
        _database = database;
        _app = FitnessApp(
          today: today!,
          plans: plans!,
          body: body!,
          weekly: weekly!,
        );
        _error = null;
        _opening = false;
      });
    } catch (error) {
      _release(today, plans, body, weekly, database);
      _fail(error);
    } finally {
      _loadInProgress = false;
    }
  }

  void _fail(Object error) {
    void apply() {
      if (!mounted) {
        _loadInProgress = false;
        return;
      }
      setState(() {
        _error = error;
        _opening = false;
        _loadInProgress = false;
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      apply();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  }

  void _release(
    TodayWorkout? today,
    ExercisePlans? plans,
    BodyRecords? body,
    WeeklyStats? weekly,
    AppDatabase? database,
  ) {
    today?.dispose();
    plans?.dispose();
    body?.dispose();
    weekly?.dispose();
    if (!identical(database, _database)) {
      database?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (!_opening && app != null && _error == null) {
      return app;
    }
    return MaterialApp(
      title: '健身打卡',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B8A5A)),
      ),
      home: _opening
          ? const Scaffold(body: Center(child: Text('正在打开记录')))
          : DatabaseErrorScreen(onRetry: _retry),
    );
  }
}
