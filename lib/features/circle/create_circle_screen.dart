import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../data/repository.dart';
import '../../widgets/responsive.dart';
import '../auth/auth_widgets.dart';
import 'circle_controller.dart';
import 'consent_view.dart';
import 'invite_card.dart';
import 'sharing_controller.dart';

enum _Step { name, consent, invite }

/// Name, then consent, then the new invite code with Share.
class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  _Step _step = _Step.name;
  bool _busy = false;
  String? _error;
  Circle? _created;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_form.currentState?.validate() ?? false) setState(() => _step = _Step.consent);
  }

  Future<void> _create(bool share) async {
    final messenger = ScaffoldMessenger.of(context);
    final circles = context.read<CircleController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    // Without location access the circle is still created, paused.
    final denied = share ? await context.read<SharingController>().ensureAccess() : null;
    try {
      final c = await circles.create(_name.text, sharing: share && denied == null);
      if (!mounted) return;
      setState(() {
        _created = c;
        _busy = false;
        _step = _Step.invite;
      });
      if (denied != null) {
        messenger.showSnackBar(SnackBar(content: Text('$denied Sharing starts paused.')));
      }
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New circle'),
        leading: _step == _Step.consent
            ? BackButton(onPressed: () => setState(() => _step = _Step.name))
            : null,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: kMotion,
          child: switch (_step) {
            _Step.name => _nameStep(context),
            _Step.consent => ConsentView(
              key: const ValueKey('consent'),
              circleName: _name.text.trim(),
              shareLabel: 'Create and share my location',
              pausedLabel: 'Create with sharing paused',
              onChoose: _create,
              busy: _busy,
              error: _error,
            ),
            _Step.invite => created == null ? const SizedBox.shrink() : _inviteStep(created),
          },
        ),
      ),
    );
  }

  Widget _nameStep(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _form,
      child: PageListView(
        maxWidth: 520,
        children: [
          Text('Name your circle', style: t.headlineSmall),
          const SizedBox(height: Space.s),
          Text(
            'Family, riding buddies, the night crew. Members see each other live on the map.',
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: Space.l),
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Circle name'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name for your circle' : null,
            onFieldSubmitted: (_) => _next(),
          ),
          const SizedBox(height: Space.m),
          FilledButton(onPressed: _next, child: const Text('Next')),
        ],
      ),
    );
  }

  Widget _inviteStep(Circle c) {
    final t = Theme.of(context).textTheme;
    return PageListView(
      key: const ValueKey('invite'),
      maxWidth: 520,
      children: [
        const SizedBox(height: Space.m),
        Text('${c.name} is ready', style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: Space.s),
        Text(
          'Send this code to the people you want in it. Only people with the code can join.',
          style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.l),
        InviteCodeCard(circle: c),
        if (_error != null) ...[const SizedBox(height: Space.m), ErrorBanner(_error!)],
        const SizedBox(height: Space.m),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ],
    );
  }
}
