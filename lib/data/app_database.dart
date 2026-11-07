import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/body_metric.dart';
import 'package:fitness_app/models/exercise_plan.dart';
import 'package:fitness_app/models/workout.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 手机本地的 SQLite 数据库。
///
/// `workouts` 每天一行运动打卡。
/// `exercise_plans` 保存四项运动的组数和每组数量，和某一天的打卡分开。
/// `body_metrics` 每天一行体重和腰围。
/// 日期是主键，同一天再保存会覆盖原来的那一行。
///
/// 第 2 版增加了快走，以及每项运动的组数、每组数量。
/// 升级时保留原来的打卡和身体记录。
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open({String? path}) async {
    final filePath = path ?? p.join(await getDatabasesPath(), 'fitness.db');
    final db = await openDatabase(
      filePath,
      version: 2,
      onCreate: (db, version) async {
        await _createLatest(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
      },
    );
    await _seedPlans(db);
    return AppDatabase._(db);
  }

  Future<void> close() => _db.close();

  Future<void> saveWorkout(Workout workout) async {
    await _db.insert(
      'workouts',
      workout.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWorkout(String date) async {
    validateDayKey(date);
    await _db.delete('workouts', where: 'date = ?', whereArgs: [date]);
  }

  Future<Workout?> workoutOn(String date) async {
    validateDayKey(date);
    final rows = await _db.query(
      'workouts',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) {
      return null;
    }
    return Workout.fromMap(rows.single);
  }

  Future<List<Workout>> workoutsBetween(String start, String end) async {
    validateDayKey(start);
    validateDayKey(end);
    final rows = await _db.query(
      'workouts',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );
    return rows.map(Workout.fromMap).toList();
  }

  Future<List<Workout>> allWorkouts() async {
    final rows = await _db.query('workouts', orderBy: 'date DESC');
    return rows.map(Workout.fromMap).toList();
  }

  Future<Map<ExerciseKind, ExercisePlan>> loadPlans() async {
    final rows = await _db.query('exercise_plans');
    final loaded = <ExerciseKind, ExercisePlan>{};
    for (final row in rows) {
      final plan = ExercisePlan.fromMap(row);
      loaded[plan.kind] = plan;
    }
    return {
      for (final kind in ExerciseKind.values)
        kind: loaded[kind] ?? ExercisePlan.defaultFor(kind),
    };
  }

  Future<ExercisePlan> planOf(ExerciseKind kind) async {
    final plans = await loadPlans();
    return plans[kind]!;
  }

  Future<void> savePlan(ExercisePlan plan) async {
    final error = planError(plan.kind, plan.sets, plan.perSet);
    if (error != null) {
      throw ArgumentError(error);
    }
    await _db.insert(
      'exercise_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveBodyMetric(BodyMetric metric) async {
    await _db.insert(
      'body_metrics',
      metric.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BodyMetric?> bodyMetricOn(String date) async {
    validateDayKey(date);
    final rows = await _db.query(
      'body_metrics',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) {
      return null;
    }
    return BodyMetric.fromMap(rows.single);
  }

  Future<List<BodyMetric>> allBodyMetrics() async {
    final rows = await _db.query('body_metrics', orderBy: 'date DESC');
    return rows.map(BodyMetric.fromMap).toList();
  }

  Future<List<BodyMetric>> bodyMetricsBetween(String start, String end) async {
    validateDayKey(start);
    validateDayKey(end);
    final rows = await _db.query(
      'body_metrics',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date ASC',
    );
    return rows.map(BodyMetric.fromMap).toList();
  }
}

Future<void> _createLatest(Database db) async {
  await db.execute('''
    CREATE TABLE workouts (
      date TEXT PRIMARY KEY,
      pushup_count INTEGER NOT NULL,
      pushup_seconds INTEGER,
      squat_count INTEGER NOT NULL,
      squat_seconds INTEGER,
      plank_sets INTEGER NOT NULL,
      plank_seconds INTEGER NOT NULL,
      walk_steps INTEGER NOT NULL DEFAULT 0,
      pushup_sets INTEGER NOT NULL DEFAULT 0,
      pushup_per_set INTEGER NOT NULL DEFAULT 0,
      squat_sets INTEGER NOT NULL DEFAULT 0,
      squat_per_set INTEGER NOT NULL DEFAULT 0,
      plank_per_set INTEGER NOT NULL DEFAULT 0,
      walk_sets INTEGER NOT NULL DEFAULT 0,
      walk_per_set INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE body_metrics (
      date TEXT PRIMARY KEY,
      weight_kg REAL,
      waist_cm REAL
    )
  ''');
  await _createPlans(db);
}

/// 给已经装过旧版本的手机加新字段，不删除原来的行。
Future<void> _upgradeToV2(Database db) async {
  const added = <String>[
    'walk_steps INTEGER NOT NULL DEFAULT 0',
    'pushup_sets INTEGER NOT NULL DEFAULT 0',
    'pushup_per_set INTEGER NOT NULL DEFAULT 0',
    'squat_sets INTEGER NOT NULL DEFAULT 0',
    'squat_per_set INTEGER NOT NULL DEFAULT 0',
    'plank_per_set INTEGER NOT NULL DEFAULT 0',
    'walk_sets INTEGER NOT NULL DEFAULT 0',
    'walk_per_set INTEGER NOT NULL DEFAULT 0',
  ];
  for (final column in added) {
    await db.execute('ALTER TABLE workouts ADD COLUMN $column');
  }
  await db.execute('''
    UPDATE workouts SET
      pushup_sets = CASE WHEN pushup_count > 0 THEN 1 ELSE 0 END,
      pushup_per_set = CASE WHEN pushup_count > 0 THEN pushup_count ELSE 0 END,
      squat_sets = CASE WHEN squat_count > 0 THEN 1 ELSE 0 END,
      squat_per_set = CASE WHEN squat_count > 0 THEN squat_count ELSE 0 END,
      plank_per_set = CASE
        WHEN plank_sets > 0 THEN plank_seconds / plank_sets
        ELSE 0
      END
  ''');
  await _createPlans(db);
}

Future<void> _createPlans(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS exercise_plans (
      id TEXT PRIMARY KEY,
      sets INTEGER NOT NULL,
      per_set INTEGER NOT NULL
    )
  ''');
}

Future<void> _seedPlans(DatabaseExecutor db) async {
  for (final plan in ExercisePlan.defaults.values) {
    await db.insert(
      'exercise_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
