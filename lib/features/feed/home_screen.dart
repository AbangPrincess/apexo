import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../data/models/activity.dart';
import '../../data/models/user.dart';
import '../../shell/app_tab.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/profile_image.dart';
import '../../widgets/responsive.dart';
import '../auth/session_controller.dart';
import '../me/settings_controller.dart';
import '../weather/weather_card.dart';
import '../weather/weather_controller.dart';
import 'activities_controller.dart';
import 'activity_card.dart';
import 'activity_detail_screen.dart';
import 'circle_feed_controller.dart';
import 'weekly_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    final user = context.select<SessionController, AppUser?>((s) => s.user);
    return Scaffold(
      appBar: AppBar(
        title: phone ? const BrandMark(size: 28) : const Text('Home'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Your profile',
              onPressed: () => context.read<ShellController>().go(AppTab.me),
              icon: UserAvatar(photoUrl: user.photoUrl, initial: user.initial, radius: 16),
            ),
          const SizedBox(width: Space.s),
        ],
      ),
      body: const _Feed(),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed();

  void _open(BuildContext context, Activity a, String? owner) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ActivityDetailScreen(activity: a, ownerName: owner),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<ActivitiesController>();
    final shared = context.watch<CircleFeedController>().items;
    final units = context.select<SettingsController, Units>((s) => s.units);
    final type = context.select<SettingsController, ActivityType>((s) => s.defaultActivity);
    final name = context.select<SessionController, String>((s) => s.user?.displayName ?? '');
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final weather = WeatherCard(key: const ValueKey('home-weather'), type: type);

    if (!feed.loaded) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (feed.failed && feed.items.isEmpty && shared.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your activities",
        message: 'Check your connection, then try again. Recording still works offline.',
        actionLabel: 'Try again',
        onAction: feed.refresh,
      );
    }
    if (feed.items.isEmpty && shared.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => ListView(
          padding: pageInsets(c.maxWidth),
          children: [
            weather,
            const SizedBox(height: Space.s),
            EmptyState(
              icon: Icons.route_rounded,
              title: 'No activities yet',
              message:
                  'Record your first ride, commute or drive. It will show up here with its route and stats.',
              actionLabel: 'Start recording',
              onAction: () => context.read<ShellController>().go(AppTab.record),
            ),
          ],
        ),
      );
    }

    final hello = name.isEmpty || name == 'You' ? greeting(now) : '${greeting(now)}, $name';
    // Mine and my circles' activities, newest first; owner is null for mine.
    final entries = <({Activity activity, String key, String? owner})>[
      for (final a in feed.items) (activity: a, key: a.id, owner: null),
      for (final s in shared)
        (activity: s.activity, key: '${s.ownerUid}/${s.id}', owner: s.ownerName),
    ]..sort((a, b) => b.activity.startedAt.compareTo(a.activity.startedAt));
    return RefreshIndicator.adaptive(
      onRefresh: () =>
          Future.wait([feed.refresh(), context.read<WeatherController>().load(force: true)]),
      child: LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pageInsets(c.maxWidth),
          children: [
            Text(hello, style: t.headlineSmall),
            const SizedBox(height: Space.xs),
            Text(formatLongDate(now), style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: Space.m),
            weather,
            const SizedBox(height: Space.m),
            WeeklyHeader(activities: feed.items, units: units, now: now),
            const SizedBox(height: Space.l),
            Text('Recent activities', style: t.titleMedium),
            const SizedBox(height: 12),
            for (final e in entries) ...[
              ActivityCard(
                key: ValueKey(e.key),
                activity: e.activity,
                units: units,
                now: now,
                ownerName: e.owner,
                onTap: () => _open(context, e.activity, e.owner),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
