import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../data/models/user.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/responsive.dart';
import '../../widgets/visuals.dart';
import '../auth/session_controller.dart';
import 'settings_controller.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<SessionController>();
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: session.isDemo ? 'Demo changes stay until you reload the app.' : null,
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (ok) await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionController, AppUser?>((s) => s.user);
    final isDemo = context.read<SessionController>().isDemo;
    final settings = context.watch<SettingsController>();
    final t = Theme.of(context).textTheme;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: PageListView(
        children: [
          _ProfileHeader(user: user, isDemo: isDemo),
          const SizedBox(height: Space.l),
          const _SectionLabel('Preferences'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Units', style: t.titleSmall),
                  const SizedBox(height: Space.s),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<Units>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: Units.km, label: Text('Kilometers')),
                        ButtonSegment(value: Units.mi, label: Text('Miles')),
                      ],
                      selected: {settings.units},
                      onSelectionChanged: (s) => settings.setUnits(s.first),
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  const Divider(),
                  const SizedBox(height: Space.m),
                  Text('Default activity', style: t.titleSmall),
                  const SizedBox(height: 2),
                  Text('Preselected when you open Record',
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      for (final type in ActivityType.values)
                        ChoiceChip(
                          avatar: Icon(type.icon, size: 18),
                          label: Text(type.label),
                          selected: settings.defaultActivity == type,
                          onSelected: (_) => settings.setDefaultActivity(type),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.l),
          const _SectionLabel('Account'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Privacy'),
                  subtitle: Text(
                      'Your location is shared only inside circles you join, and you can pause it any time.'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.alert),
                  title: const Text('Sign out', style: TextStyle(color: AppColors.alert)),
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
          if (isDemo) ...[
            const SizedBox(height: Space.l),
            Text(
              'Demo mode · data is kept in memory and resets when you reload.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.isDemo});

  final AppUser user;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.accent,
          child: Text(user.initial,
              style: const TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.displayName, style: t.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(user.email,
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (isDemo) ...[
                const SizedBox(height: Space.s),
                const IconTileLabel(icon: Icons.science_outlined, label: 'Demo account'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Space.xs, bottom: Space.s),
        child: Text(text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted)),
      );
}

/// Small pill with an icon, e.g. "Demo account".
class IconTileLabel extends StatelessWidget {
  const IconTileLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.accent)),
        ]),
      );
}
