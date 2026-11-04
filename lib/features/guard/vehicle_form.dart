import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/user.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/visuals.dart';
import 'vehicles_controller.dart';

/// Add (no [vehicle]) or edit a vehicle: type and name, plus delete.
Future<void> showVehicleForm(BuildContext context, {Vehicle? vehicle}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _VehicleForm(vehicle: vehicle),
    );

class _VehicleForm extends StatefulWidget {
  const _VehicleForm({this.vehicle});

  final Vehicle? vehicle;

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  late VehicleType _type = widget.vehicle?.type ?? VehicleType.bike;
  late final _name = TextEditingController(text: widget.vehicle?.name ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name, like "Blue MTB"');
      return;
    }
    final nav = Navigator.of(context);
    final vehicles = context.read<VehiclesController>();
    final v = widget.vehicle;
    await vehicles.save(
      v == null ? Vehicle(id: '', type: _type, name: name) : v.copyWith(type: _type, name: name),
    );
    nav.pop();
  }

  Future<void> _delete(Vehicle v) async {
    final nav = Navigator.of(context);
    final vehicles = context.read<VehiclesController>();
    final ok = await confirmAction(
      context,
      title: 'Delete ${v.name}?',
      message: 'Past activities keep their stats.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await vehicles.delete(v.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final t = Theme.of(context).textTheme;
    final guarded = v != null && v.status != VehicleStatus.ok;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.m,
        0,
        Space.m,
        Space.l + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(v == null ? 'Add a vehicle' : 'Edit vehicle', style: t.titleLarge),
          const SizedBox(height: Space.m),
          SegmentedButton<VehicleType>(
            showSelectedIcon: false,
            segments: [
              for (final type in VehicleType.values)
                ButtonSegment(value: type, icon: Icon(type.icon), label: Text(type.label)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _name,
            autofocus: v == null,
            maxLength: 30,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Space.s),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (v != null) ...[
            const SizedBox(height: Space.s),
            TextButton(
              onPressed: guarded ? null : () => _delete(v),
              style: TextButton.styleFrom(foregroundColor: AppColors.alert),
              child: Text(guarded ? 'Disarm guard mode to delete' : 'Delete vehicle'),
            ),
          ],
        ],
      ),
    );
  }
}
