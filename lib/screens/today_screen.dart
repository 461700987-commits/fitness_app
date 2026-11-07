import 'package:fitness_app/data/day_key.dart';
import 'package:fitness_app/models/exercise_plan.dart';
import 'package:fitness_app/state/exercise_plans.dart';
import 'package:fitness_app/state/today_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.today, required this.plans});

  final TodayWorkout today;
  final ExercisePlans plans;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: today,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: plans,
          builder: (context, _) {
            if (today.loading && today.workout == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _TodayBody(today: today, plans: plans);
          },
        );
      },
    );
  }
}

class _TodayBody extends StatefulWidget {
  const _TodayBody({required this.today, required this.plans});

  final TodayWorkout today;
  final ExercisePlans plans;

  @override
  State<_TodayBody> createState() => _TodayBodyState();
}

class _TodayBodyState extends State<_TodayBody> {
  var _pending = false;

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    final workout = today.workout;
    final theme = Theme.of(context);
    final finished = workout?.finishedCount ?? 0;
    final busy = _pending || today.saving;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          formatChineseDay(today.selectedDate),
          style: theme.textTheme.titleMedium,
        ),
        if (!today.isToday) ...[
          const SizedBox(height: 8),
          Text('正在查看以前的记录', style: theme.textTheme.bodyMedium),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('backToToday'),
              onPressed: busy ? null : () => today.select(today.calendarToday),
              child: const Text('回到今天'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(_headline(today), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '已完成 $finished/4',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: finished / ExerciseKind.values.length,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '点右边的圆圈打勾，不用填写数字。打勾后会立刻记在手机里。要改做几组、每组多少，点「调整」。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final kind in ExerciseKind.values)
          _ExerciseCard(
            kind: kind,
            done: workout?.isDone(kind) ?? false,
            detail: workout != null && workout.isDone(kind)
                ? workout.describe(kind)
                : widget.plans.planFor(kind).summary,
            pending: busy,
            onToggle: () => _toggle(kind),
            onEdit: () => _edit(kind),
          ),
        if (today.errorMessage != null)
          Text(
            today.errorMessage!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (widget.plans.errorMessage != null)
          Text(
            widget.plans.errorMessage!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
      ],
    );
  }

  Future<void> _toggle(ExerciseKind kind) async {
    if (_pending) {
      return;
    }
    setState(() => _pending = true);
    await widget.today.toggle(kind);
    if (!mounted) {
      return;
    }
    setState(() => _pending = false);
  }

  Future<void> _edit(ExerciseKind kind) async {
    final current = widget.plans.planFor(kind);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _PlanSheet(
          kind: kind,
          initial: current,
          onSave: (sets, perSet) => widget.plans.update(kind, sets, perSet),
        );
      },
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.kind,
    required this.done,
    required this.detail,
    required this.pending,
    required this.onToggle,
    required this.onEdit,
  });

  final ExerciseKind kind;
  final bool done;
  final String detail;
  final bool pending;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = done
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surface;
    final foreground = done
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return Card(
      color: background,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: done ? Colors.transparent : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(_iconFor(kind), color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: pending ? null : onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        done ? '已完成 · $detail' : '计划 · $detail',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: done
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              key: Key('edit-${kind.id}'),
              onPressed: pending ? null : onEdit,
              child: const Text('调整'),
            ),
            IconButton(
              key: Key('check-${kind.id}'),
              tooltip: done ? '取消${kind.label}' : '完成${kind.label}',
              onPressed: pending ? null : onToggle,
              icon: Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSheet extends StatefulWidget {
  const _PlanSheet({
    required this.kind,
    required this.initial,
    required this.onSave,
  });

  final ExerciseKind kind;
  final ExercisePlan initial;
  final Future<bool> Function(int sets, int perSet) onSave;

  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  late final TextEditingController _sets;
  late final TextEditingController _perSet;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sets = TextEditingController(text: widget.initial.sets.toString());
    _perSet = TextEditingController(text: widget.initial.perSet.toString());
    _sets.addListener(_refresh);
    _perSet.addListener(_refresh);
  }

  @override
  void dispose() {
    _sets.removeListener(_refresh);
    _perSet.removeListener(_refresh);
    _sets.dispose();
    _perSet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sets = int.tryParse(_sets.text.trim());
    final perSet = int.tryParse(_perSet.text.trim());
    final preview = sets == null || perSet == null
        ? '请填写整数'
        : '一共 ${sets * perSet} ${widget.kind.unit}';
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('调整${widget.kind.label}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '打勾时按这里的组数和每组数量记录，不用再填数字。已经打勾的日期不会自动改，取消勾选再勾一次就会用新计划。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _NumberRow(
              label: '做几组',
              controller: _sets,
              fieldKey: const Key('planSets'),
              minusKey: const Key('planSetsMinus'),
              plusKey: const Key('planSetsPlus'),
              step: 1,
              min: 1,
              max: ExerciseKind.maxSets,
            ),
            const SizedBox(height: 12),
            _NumberRow(
              label: '每组多少${widget.kind.unit}',
              controller: _perSet,
              fieldKey: const Key('planPerSet'),
              minusKey: const Key('planPerSetMinus'),
              plusKey: const Key('planPerSetPlus'),
              step: widget.kind == ExerciseKind.walk ? 500 : 1,
              min: 1,
              max: widget.kind.maxPerSet,
            ),
            const SizedBox(height: 12),
            Text(preview, style: theme.textTheme.titleMedium),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  key: const Key('restorePlan'),
                  onPressed: _saving ? null : _restore,
                  child: const Text('恢复默认'),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('savePlan'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '正在保存' : '保存计划'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _restore() {
    final plan = ExercisePlan.defaultFor(widget.kind);
    _sets.text = plan.sets.toString();
    _perSet.text = plan.perSet.toString();
    setState(() => _error = null);
  }

  Future<void> _save() async {
    final sets = int.tryParse(_sets.text.trim());
    final perSet = int.tryParse(_perSet.text.trim());
    if (sets == null || perSet == null) {
      setState(() => _error = '请填写整数');
      return;
    }
    final error = planError(widget.kind, sets, perSet);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSave(sets, perSet);
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = '保存计划失败，请重试';
    });
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.controller,
    required this.fieldKey,
    required this.minusKey,
    required this.plusKey,
    required this.step,
    required this.min,
    required this.max,
  });

  final String label;
  final TextEditingController controller;
  final Key fieldKey;
  final Key minusKey;
  final Key plusKey;
  final int step;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(label)),
        IconButton(
          key: minusKey,
          tooltip: '减少',
          onPressed: () => _bump(-step),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: fieldKey,
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        IconButton(
          key: plusKey,
          tooltip: '增加',
          onPressed: () => _bump(step),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  void _bump(int delta) {
    final current = int.tryParse(controller.text.trim()) ?? min;
    final next = (current + delta).clamp(min, max);
    controller.text = next.toString();
  }
}

String _headline(TodayWorkout today) {
  final finished = today.workout?.finishedCount ?? 0;
  if (finished == 0) {
    return today.isToday ? '今天还没有打卡' : '这一天还没有打卡';
  }
  if (finished == ExerciseKind.values.length) {
    return today.isToday ? '今天全部完成' : '这一天全部完成';
  }
  return today.isToday ? '今天已完成 $finished/4' : '这一天已完成 $finished/4';
}

IconData _iconFor(ExerciseKind kind) {
  return switch (kind) {
    ExerciseKind.pushup => Icons.fitness_center,
    ExerciseKind.squat => Icons.accessibility_new,
    ExerciseKind.plank => Icons.self_improvement,
    ExerciseKind.walk => Icons.directions_walk,
  };
}
