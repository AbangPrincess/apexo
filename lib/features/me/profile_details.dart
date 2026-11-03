import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/user.dart';
import '../../widgets/visuals.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class ProfileActions extends StatelessWidget {
  const ProfileActions({super.key, required this.expand, required this.onEdit, required this.onSettings});

  final bool expand;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final edit = FilledButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Edit profile'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentSoft,
        foregroundColor: AppColors.accent,
        minimumSize: const Size(0, 44),
      ),
    );
    final settings = IconButton.outlined(
      tooltip: 'Settings',
      onPressed: onSettings,
      icon: const Icon(Icons.settings_outlined),
      style: IconButton.styleFrom(side: const BorderSide(color: AppColors.hairline)),
    );
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (expand) Expanded(child: edit) else edit,
        const SizedBox(width: Space.s),
        settings,
      ],
    );
  }
}

/// "Details" like a social profile intro: hometown, main activity, joined.
class ProfileDetails extends StatelessWidget {
  const ProfileDetails({super.key, required this.user, required this.onEdit});

  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final joined = user.createdAt;
    final rows = <(IconData, String)>[
      if (user.hometown.isNotEmpty) (Icons.location_on_outlined, 'From ${user.hometown}'),
      (user.defaultActivity.icon, 'Mostly ${user.defaultActivity.label.toLowerCase()}'),
      (Icons.calendar_month_outlined, 'Joined ${_months[joined.month - 1]} ${joined.year}'),
      if (user.emailVerified) (Icons.verified_outlined, 'Verified account'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Details', style: t.titleLarge),
        const SizedBox(height: Space.s),
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: t.bodyLarge)),
              ],
            ),
          ),
        if (user.bio.isEmpty || user.hometown.isEmpty)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.add_rounded),
            label: Text(user.bio.isEmpty ? 'Add a bio' : 'Add your hometown'),
          ),
      ],
    );
  }
}
