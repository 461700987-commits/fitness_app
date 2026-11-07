import 'dart:io';

import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/models/body_metric.dart';
import 'package:fitness_app/screens/body_screen.dart';
import 'package:fitness_app/state/body_records.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late BodyRecords records;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fitness_app_body_');
    database = await AppDatabase.open(path: '${tempDir.path}/fitness.db');
    records = BodyRecords(database);
    await records.load();
  });

  tearDown(() async {
    records.dispose();
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('修改过去日期的身体记录后，排序仍然正确', () async {
    await database.saveBodyMetric(BodyMetric(date: '2020-01-02', weightKg: 80));
    await database.saveBodyMetric(BodyMetric(date: '2020-01-05', weightKg: 70));
    await records.load();

    records.select('2020-01-02');
    final saved = await records.save(
      BodyMetric(date: '2020-01-02', weightKg: 90, waistCm: 81),
    );

    expect(saved, isTrue);
    expect(records.history.map((item) => item.date), [
      '2020-01-05',
      '2020-01-02',
    ]);
    expect(records.history.first.weightKg, 70);
    expect(records.selected!.weightKg, 90);
    expect(records.selected!.waistCm, 81);
  });

  test('修改身体记录后，折线图的数据顺序正确', () {
    final points = bodyTrendPoints([
      BodyMetric(date: '2020-01-05', weightKg: 70, waistCm: 80),
      BodyMetric(date: '2020-01-02', weightKg: 90),
      BodyMetric(date: '2020-01-09', waistCm: 79),
    ], (item) => item.weightKg);

    expect(points.map((point) => point.date), ['2020-01-02', '2020-01-05']);
    expect(points.map((point) => point.value), [90, 70]);
  });
}
