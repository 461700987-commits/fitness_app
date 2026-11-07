import 'package:fitness_app/data/day_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('日期写成 yyyy-MM-dd', () {
    expect(dayKeyFrom(DateTime(2026, 1, 2)), '2026-01-02');
    expect(dayKeyFrom(DateTime(2026, 11, 7)), '2026-11-07');
  });

  test('日期可以显示成中文', () {
    expect(formatChineseDay('2026-01-02'), '2026年1月2日');
  });

  test('非法日期会被拒绝', () {
    expect(() => validateDayKey('2026/11/07'), throwsArgumentError);
    expect(() => validateDayKey('2026-02-31'), throwsArgumentError);
    expect(() => validateDayKey('2026-11-07'), returnsNormally);
  });
}
