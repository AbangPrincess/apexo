import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/invite_code.dart';
import '../../core/theme.dart';
import '../../data/models/circle.dart';
import '../../data/repository.dart';
import '../../widgets/responsive.dart';
import '../auth/auth_widgets.dart';
import 'circle_controller.dart';
import 'consent_view.dart';
import 'member_panel.dart';
import 'sharing_controller.dart';

/// Enter a code, see who you are joining, consent, joined.
class JoinCircleScreen extends StatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  CirclePreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final circles = context.read<CircleController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = await circles.find(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (p == null) {
        _error = 'No circle uses that code. Check it with the person who invited you.';
      } else if (circles.circles.any((c) => c.id == p.id)) {
        _error = "You're already in ${p.name}.";
      } else {
        _preview = p;
      }
    });
  }

  Future<void> _join(bool share) async {
    final p = _preview;
    if (p == null) return;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final circles = context.read<CircleController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    // Without location access the join still happens, paused.
    final denied = share ? await context.read<SharingController>().ensureAccess() : null;
    try {
      await circles.join(p.id, sharing: share && denied == null);
      nav.pop();
      final paused = denied == null ? '' : ' $denied Sharing is paused.';
      messenger.showSnackBar(SnackBar(content: Text('You joined ${p.name}.$paused')));
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
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a circle'),
        leading: p == null
            ? null
            : BackButton(onPressed: () => setState(() => _preview = _error = null)),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: kMotion,
          child: p == null
              ? _codeStep(context)
              : ConsentView(
                  key: const ValueKey('consent'),
                  circleName: p.name,
                  details: '${memberCount(p.memberCount)} · Owner: ${p.ownerName}',
                  shareLabel: 'Join and share my location',
                  pausedLabel: 'Join with sharing paused',
                  onChoose: _join,
                  busy: _busy,
                  error: _error,
                ),
        ),
      ),
    );
  }

  Widget _codeStep(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final demo = context.read<AppRepository>().isDemo;
    return Form(
      key: _form,
      child: PageListView(
        maxWidth: 520,
        children: [
          Text('Enter your invite code', style: t.headlineSmall),
          const SizedBox(height: Space.s),
          Text(
            'Ask the person who invited you for their 6-character code.',
            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: Space.l),
          TextFormField(
            controller: _code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              LengthLimitingTextInputFormatter(9),
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            style: t.titleLarge?.copyWith(letterSpacing: 4, fontFeatures: kTabular),
            decoration: InputDecoration(
              labelText: 'Invite code',
              helperText: demo ? 'Demo: try TRAIL7' : null,
            ),
            validator: (v) => isInviteCodeShape(normalizeInviteCode(v ?? ''))
                ? null
                : 'Codes have 6 letters and numbers',
            onFieldSubmitted: (_) => _find(),
          ),
          if (_error != null) ...[const SizedBox(height: Space.m), ErrorBanner(_error!)],
          const SizedBox(height: Space.m),
          FilledButton(
            onPressed: _busy ? null : _find,
            child: _busy ? ButtonSpinner(color: AppColors.onInk) : const Text('Find circle'),
          ),
        ],
      ),
    );
  }
}
