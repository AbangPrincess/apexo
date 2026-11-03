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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final session = context.read<SessionController>();
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: session.isDemo ? 'Demo changes stay until you reload the app.' : null,
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!ok) return;
    navigator.popUntil((r) => r.isFirst);
    await session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final user = context.select<SessionController, AppUser?>((s) => s.user);
    final isDemo = context.read<SessionController>().isDemo;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageListView(
        children: [
          const SectionLabel('Preferences'),
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
                  Text(
                    'Preselected when you open Record',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      for (final type in ActivityType.values)
                        ChoiceChip(
                          avatar: Icon(
                            type.icon,
                            size: 18,
                            color: settings.defaultActivity == type ? Colors.white : AppColors.text,
                          ),
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
          const SectionLabel('Account'),
          Card(
            child: Column(
              children: [
                if (user != null)
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(user.emailVerified ? 'Verified email' : 'Not verified yet'),
                    trailing: user.emailVerified
                        ? const Icon(Icons.verified_rounded, color: AppColors.ink)
                        : null,
                  ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Privacy'),
                  subtitle: Text(
                    'Your location is shared only inside circles you join, and you can pause it any time. '
                    'Location data is removed from photos you upload.',
                  ),
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: Space.xs, bottom: Space.s),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
    ),
  );
}
