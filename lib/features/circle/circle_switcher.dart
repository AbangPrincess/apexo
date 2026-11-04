import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import 'circle_controller.dart';
import 'create_circle_screen.dart';
import 'join_circle_screen.dart';

Future<void> openCreateCircle(BuildContext context) =>
    _openIfRoom(context, const CreateCircleScreen());

Future<void> openJoinCircle(BuildContext context) => _openIfRoom(context, const JoinCircleScreen());

Future<void> _openIfRoom(BuildContext context, Widget screen) async {
  // An old message must not cover the flow's buttons.
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  if (context.read<CircleController>().atLimit) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('You can be in up to $maxCirclesPerUser circles. Leave one to make room.'),
      ),
    );
    return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => screen));
}

/// App bar title that switches circles and leads to create and join.
class CircleSwitcher extends StatelessWidget {
  const CircleSwitcher({super.key});

  static const _create = '+create';
  static const _join = '+join';

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CircleController>();
    final current = ctrl.circle;
    return PopupMenuButton<String>(
      tooltip: 'Switch circle',
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == _create) {
          openCreateCircle(context);
        } else if (v == _join) {
          openJoinCircle(context);
        } else {
          ctrl.select(v);
        }
      },
      itemBuilder: (_) => [
        for (final c in ctrl.circles)
          CheckedPopupMenuItem(value: c.id, checked: c.id == current?.id, child: Text(c.name)),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _create,
          child: ListTile(leading: Icon(Icons.add_rounded), title: Text('Create a circle')),
        ),
        const PopupMenuItem(
          value: _join,
          child: ListTile(leading: Icon(Icons.login_rounded), title: Text('Join with a code')),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(current?.name ?? 'Circle', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
      ),
    );
  }
}
