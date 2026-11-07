import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/body_metric.dart';
import 'package:fitness_app/state/body_records.dart';
import 'package:fitness_app/widgets/body_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BodyScreen extends StatelessWidget {
  const BodyScreen({super.key, required this.records});

  final BodyRecords records;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: records,
      builder: (context, _) => _BodyForm(records: records),
    );
  }
}

class _BodyForm extends StatefulWidget {
  const _BodyForm({required this.records});

  final BodyRecords records;

  @override
  State<_BodyForm> createState() => _BodyFormState();
}

class _BodyFormState extends State<_BodyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _waist;
  var _saving = false;
  String? _formError;
  String? _shown;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController();
    _waist = TextEditingController();
    _syncFields();
  }

  @override
  void didUpdateWidget(covariant _BodyForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFields();
  }

  @override
  void dispose() {
    _weight.dispose();
    _waist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    final selected = records.loading ? null : records.selected;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            formatChineseDay(records.selectedDate),
            style: theme.textTheme.titleMedium,
          ),
          if (!records.isToday) ...[
            const SizedBox(height: 8),
            Text('正在查看以前的记录', style: theme.textTheme.bodyMedium),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('backToTodayBody'),
                onPressed: () => records.select(records.calendarToday),
                child: const Text('回到今天'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (selected != null)
            _TodayCard(
              title: records.isToday ? '今天已记录' : '这一天已记录',
              metric: selected,
            )
          else if (records.history.isEmpty) ...[
            Text('还没有体重和腰围记录', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '可以只填体重或腰围。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else
            Text(
              records.isToday ? '今天还没有记录' : '这一天还没有记录',
              style: theme.textTheme.titleLarge,
            ),
          const SizedBox(height: 16),
          _MeasureField(
            fieldKey: const Key('weightKg'),
            controller: _weight,
            label: '体重（千克，可不填）',
          ),
          _MeasureField(
            fieldKey: const Key('waistCm'),
            controller: _waist,
            label: '腰围（厘米，可不填）',
          ),
          if (_formError != null || records.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              _formError ?? records.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('saveBody'),
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving
                    ? '正在保存'
                    : selected == null
                    ? '保存'
                    : records.isToday
                    ? '更新今天的记录'
                    : '更新这一天',
              ),
            ),
          ),
          const SizedBox(height: 24),
          BodyTrendChart(
            title: '体重',
            points: bodyTrendPoints(records.history, (item) => item.weightKg),
            color: theme.colorScheme.primary,
            chartKey: const Key('weightChart'),
          ),
          const SizedBox(height: 24),
          BodyTrendChart(
            title: '腰围',
            points: bodyTrendPoints(records.history, (item) => item.waistCm),
            color: theme.colorScheme.tertiary,
            chartKey: const Key('waistChart'),
          ),
          if (records.history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('历史记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '点某一天可以修改。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in records.history)
              ListTile(
                key: Key('bodyDay-${item.date}'),
                contentPadding: EdgeInsets.zero,
                selected: item.date == records.selectedDate,
                onTap: () => records.select(item.date),
                title: Text(formatChineseDay(item.date)),
                subtitle: Text(_describeBody(item)),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() == false) {
      return;
    }
    final weight = _optional(_weight.text);
    final waist = _optional(_waist.text);
    if (weight == null && waist == null) {
      setState(() => _formError = '请至少填写体重或腰围');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    final saved = await widget.records.save(
      BodyMetric(
        date: widget.records.selectedDate,
        weightKg: weight,
        waistCm: waist,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (saved) {
      FocusScope.of(context).unfocus();
    }
  }

  void _syncFields() {
    final records = widget.records;
    if (records.loading) {
      return;
    }
    final metric = records.selected;
    final stamp = [
      records.selectedDate,
      metric?.weightKg,
      metric?.waistCm,
    ].join('|');
    if (_shown == stamp) {
      return;
    }
    _shown = stamp;
    _weight.text = _text(metric?.weightKg) ?? '';
    _waist.text = _text(metric?.waistCm) ?? '';
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.title, required this.metric});

  final String title;
  final BodyMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(_describeBody(metric)),
          ],
        ),
      ),
    );
  }
}

class _MeasureField extends StatelessWidget {
  const _MeasureField({
    required this.fieldKey,
    required this.controller,
    required this.label,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_oneDecimal],
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) {
            return null;
          }
          final number = double.tryParse(text);
          if (number == null || number <= 0) {
            return '请填写大于 0 的数字';
          }
          return null;
        },
      ),
    );
  }
}

/// 折线从左到右按日期变新，不依赖列表当前的排列。
List<TrendPoint> bodyTrendPoints(
  List<BodyMetric> history,
  double? Function(BodyMetric metric) read,
) {
  final points = [
    for (final item in history)
      if (read(item) != null) TrendPoint(date: item.date, value: read(item)!),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return points;
}

String? _text(double? value) {
  if (value == null) {
    return '';
  }
  return _formatNumber(value);
}

double? _optional(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.parse(trimmed);
}

final _oneDecimal = TextInputFormatter.withFunction((oldValue, newValue) {
  if (RegExp(r'^\d{0,3}(\.\d?)?$').hasMatch(newValue.text)) {
    return newValue;
  }
  return oldValue;
});

String _describeBody(BodyMetric metric) {
  final parts = <String>[];
  if (metric.weightKg != null) {
    parts.add('体重 ${_formatNumber(metric.weightKg!)} 千克');
  }
  if (metric.waistCm != null) {
    parts.add('腰围 ${_formatNumber(metric.waistCm!)} 厘米');
  }
  return parts.join('，');
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}
