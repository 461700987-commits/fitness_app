final _dayKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// 把 `2026-11-07` 显示成 `2026年11月7日`。
String formatChineseDay(String date) {
  validateDayKey(date);
  final parts = date.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  return '$year年$month月$day日';
}

/// 把某一天写成 `2026-11-07` 这种文本。
/// 数据库用它当主键，所以同一天只会有一条记录。
String dayKeyFrom(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

void validateDayKey(String date) {
  final match = _dayKeyPattern.firstMatch(date);
  if (match == null) {
    throw ArgumentError.value(date, 'date', '日期必须是 yyyy-MM-dd');
  }
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ArgumentError.value(date, 'date', '不是有效日期');
  }
}
