import 'package:fitness_app/data/day_key.dart';

/// 某一天的体重和腰围。两项可以只填一项。
class BodyMetric {
  BodyMetric({required this.date, this.weightKg, this.waistCm}) {
    validateDayKey(date);
    if (weightKg == null && waistCm == null) {
      throw ArgumentError('体重和腰围至少填一项');
    }
    if (weightKg != null) {
      _positive(weightKg!, '体重');
    }
    if (waistCm != null) {
      _positive(waistCm!, '腰围');
    }
  }

  /// `yyyy-MM-dd`
  final String date;

  /// 千克。没填时是 null。
  final double? weightKg;

  /// 厘米。没填时是 null。
  final double? waistCm;

  Map<String, Object?> toMap() {
    return {'date': date, 'weight_kg': weightKg, 'waist_cm': waistCm};
  }

  factory BodyMetric.fromMap(Map<String, Object?> map) {
    return BodyMetric(
      date: map['date'] as String,
      weightKg: _asDouble(map['weight_kg']),
      waistCm: _asDouble(map['waist_cm']),
    );
  }
}

double? _asDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  throw ArgumentError.value(value, 'value', '不是数字');
}

void _positive(double value, String label) {
  if (value <= 0) {
    throw ArgumentError.value(value, label, '必须大于 0');
  }
}
