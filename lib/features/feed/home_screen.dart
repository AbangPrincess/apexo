import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../shell/app_tab.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/responsive.dart';
import '../auth/session_controller.dart';
import '../me/settings_controller.dart';
import 'activities_controller.dart';
import 'activity_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    return Scaffold(
      appBar: AppBar(
        title: phone ? const BrandMark(size: 28) : const Text('Home'),
      ),
      body: const _Feed(),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed();

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<ActivitiesController>();
    final units = context.select<SettingsController, Units>((s) => s.units);
    final name = context.select<SessionController, String>((s) => s.user?.displayName ?? '');
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();

    if (!feed.loaded) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (feed.items.isEmpty) {
      return EmptyState(
        icon: Icons.route_rounded,
        title: 'No activities yet',
        message:
            'Record your first ride, commute or drive. It will show up here with its route and stats.',
        actionLabel: 'Start recording',
        onAction: () => context.read<ShellController>().go(AppTab.record),
      );
    }

    final hello = name.isEmpty || name == 'You' ? greeting(now) : '${greeting(now)}, $name';
    return PageListView(
      children: [
        Text(hello, style: t.headlineSmall),
        const SizedBox(height: Space.xs),
        Text(formatLongDate(now), style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: Space.l),
        Text('Recent activities', style: t.titleMedium),
        const SizedBox(height: 12),
        for (final a in feed.items) ...[
          ActivityCard(key: ValueKey(a.id), activity: a, units: units, now: now),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
