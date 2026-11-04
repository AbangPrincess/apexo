import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/achievements.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/activity.dart';
import '../../data/models/user.dart';
import '../../data/repository.dart';
import '../auth/session_controller.dart';
import '../circle/circle_controller.dart';
import '../feed/activities_controller.dart';
import '../guard/garage_card.dart';
import 'achievements_section.dart';
import 'edit_profile_screen.dart';
import 'photo_picker.dart';
import 'profile_details.dart';
import 'profile_header.dart';
import 'settings_controller.dart';
import 'settings_screen.dart';
import 'stats_section.dart';

/// The rider's profile: cover and photo, details, achievements and stats.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _changePhoto(BuildContext context, AppUser user, PhotoSlot slot) async {
    final repo = context.read<AppRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final avatar = slot == PhotoSlot.avatar;
    final url = await pickProfilePhoto(
      context,
      slot: slot,
      hasPhoto: (avatar ? user.photoUrl : user.coverUrl).isNotEmpty,
    );
    if (url == null) return;
    await repo.updateProfile(
      user.uid,
      photoUrl: avatar ? url : null,
      coverUrl: avatar ? null : url,
    );
    messenger.showSnackBar(
      SnackBar(content: Text(url.isEmpty ? 'Photo removed' : 'Photo updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionController, AppUser?>((s) => s.user);
    final items = context.select<ActivitiesController, List<Activity>>((a) => a.items);
    final units = context.select<SettingsController, Units>((s) => s.units);
    final circles = context.select<CircleController, int>((c) => c.circles.length);
    if (user == null) return const SizedBox.shrink();

    final total = items.fold<double>(0, (s, a) => s + a.distanceM);
    final longest = items.isEmpty
        ? const <GeoPoint>[]
        : items.reduce((a, b) => a.distanceM >= b.distanceM ? a : b).points;
    final statsLine =
        '${items.length} ${items.length == 1 ? 'activity' : 'activities'} · '
        '${formatDistance(total, units)} ${units.distanceLabel} · '
        '$circles ${circles == 1 ? 'circle' : 'circles'}';
    final now = DateTime.now();
    void edit() => _push(context, EditProfileScreen(user: user));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 760;
          final side = math.max(0.0, (c.maxWidth - 980) / 2);
          final pad = wide ? Space.xl : Space.m;
          final intro = ProfileDetails(user: user, onEdit: edit);
          final achievements = AchievementsSection(
            achievements: computeAchievements(items),
            units: units,
          );
          final week = WeeklyChartCard(activities: items, units: units, now: now);
          final totals = TypeTotalsCard(activities: items, units: units);

          return ListView(
            padding: EdgeInsets.fromLTRB(side, 0, side, Space.xl),
            children: [
              ProfileHeader(
                user: user,
                statsLine: statsLine,
                wide: wide,
                coverRoute: longest,
                onChangeAvatar: () => _changePhoto(context, user, PhotoSlot.avatar),
                onChangeCover: () => _changePhoto(context, user, PhotoSlot.cover),
                actions: ProfileActions(
                  expand: !wide,
                  onEdit: edit,
                  onSettings: () => _push(context, const SettingsScreen()),
                ),
              ),
              const SizedBox(height: Space.l),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 340,
                            child: Column(
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(Space.m),
                                    child: intro,
                                  ),
                                ),
                                const SizedBox(height: Space.m),
                                const GarageCard(),
                                const SizedBox(height: Space.m),
                                week,
                                const SizedBox(height: Space.m),
                                totals,
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.l),
                          Expanded(child: achievements),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          intro,
                          const SizedBox(height: Space.l),
                          const GarageCard(),
                          const SizedBox(height: Space.l),
                          const Divider(),
                          const SizedBox(height: Space.l),
                          achievements,
                          const SizedBox(height: Space.l),
                          week,
                          const SizedBox(height: Space.m),
                          totals,
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
