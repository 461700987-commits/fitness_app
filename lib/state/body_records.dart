import 'package:fitness_app/data/app_database.dart';
import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/body_metric.dart';
import 'package:flutter/foundation.dart';

/// 体重和腰围。历史按日期从新到旧排列。
class BodyRecords extends ChangeNotifier {
  BodyRecords(this._database) {
    selectedDate = dayKeyFrom(DateTime.now());
  }

  final AppDatabase _database;

  late String selectedDate;
  List<BodyMetric> history = [];
  var loading = false;
  String? errorMessage;

  String get calendarToday => dayKeyFrom(DateTime.now());

  bool get isToday => selectedDate == calendarToday;

  BodyMetric? get selected {
    for (final item in history) {
      if (item.date == selectedDate) {
        return item;
      }
    }
    return null;
  }

  void select(String date) {
    validateDayKey(date);
    selectedDate = date;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      history = _newestFirst(await _database.allBodyMetrics());
      errorMessage = null;
    } catch (_) {
      errorMessage = '读取身体记录失败';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(BodyMetric metric) async {
    if (metric.date != selectedDate) {
      errorMessage = '只能保存正在查看的这一天';
      notifyListeners();
      return false;
    }
    try {
      await _database.saveBodyMetric(metric);
      history = _newestFirst([
        metric,
        ...history.where((item) => item.date != metric.date),
      ]);
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = '保存失败，请重试';
      notifyListeners();
      return false;
    }
  }
}

/// 日期文本是 `yyyy-MM-dd`，可以直接比较。新的日期在前。
List<BodyMetric> _newestFirst(Iterable<BodyMetric> items) {
  final sorted = items.toList()..sort((a, b) => b.date.compareTo(a.date));
  return sorted;
}
