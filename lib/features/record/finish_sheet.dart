import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/activity.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/route_thumbnail.dart';
import '../../widgets/stat_value.dart';
import '../me/settings_controller.dart';
import 'record_controller.dart';

/// Review a finished recording: edit the title, choose who sees it, then
/// save or discard. Returns true when saved.
Future<bool> showFinishSheet(BuildContext context, RecordController rec, Activity draft) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _FinishSheet(rec: rec, draft: draft),
  );
  return saved ?? false;
}

class _FinishSheet extends StatefulWidget {
  const _FinishSheet({required this.rec, required this.draft});

  final RecordController rec;
  final Activity draft;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  late final _title = TextEditingController(text: widget.draft.title);
  ActivityVisibility _visibility = ActivityVisibility.private;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.rec.save(widget.draft, title: _title.text, visibility: _visibility);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _discard() async {
    final ok = await confirmAction(
      context,
      title: 'Discard this activity?',
      message: 'The route and stats will be deleted.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!ok || !mounted) return;
    widget.rec.discard();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final units = context.select<SettingsController, Units>((s) => s.units);
    final t = Theme.of(context).textTheme;
    final d = widget.draft;
    final canSave = d.points.length >= 2;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Save activity', style: t.titleLarge),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Expanded(
                  child: StatValue(
                    label: 'Distance',
                    value: formatDistance(d.distanceM, units),
                    unit: units.distanceLabel,
                  ),
                ),
                Expanded(
                  child: StatValue(label: 'Moving time', value: formatDuration(d.movingSec)),
                ),
                Expanded(
                  child: StatValue(
                    label: 'Avg speed',
                    value: formatSpeed(d.avgKmh, units),
                    unit: units.speedLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            RouteThumbnail(points: d.points, height: 120),
            const SizedBox(height: Space.m),
            TextField(
              controller: _title,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title', counterText: ''),
            ),
            const SizedBox(height: Space.m),
            Text('Who can see it', style: t.titleSmall),
            const SizedBox(height: Space.s),
            SegmentedButton<ActivityVisibility>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ActivityVisibility.private,
                  icon: Icon(Icons.lock_outline_rounded),
                  label: Text('Only me'),
                ),
                ButtonSegment(
                  value: ActivityVisibility.circles,
                  icon: Icon(Icons.people_outline_rounded),
                  label: Text('My circles'),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (s) => setState(() => _visibility = s.first),
            ),
            if (!canSave) ...[
              const SizedBox(height: Space.m),
              Text(
                'Not enough GPS points were recorded to save this one.',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: Space.l),
            FilledButton(
              onPressed: _saving || !canSave ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(_saving ? 'Saving…' : 'Save activity'),
            ),
            const SizedBox(height: Space.s),
            TextButton(
              onPressed: _saving ? null : _discard,
              style: TextButton.styleFrom(foregroundColor: AppColors.alert),
              child: const Text('Discard'),
            ),
          ],
        ),
      ),
    );
  }
}
