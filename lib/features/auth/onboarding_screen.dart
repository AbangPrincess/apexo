import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../me/settings_controller.dart';

class _Slide {
  const _Slide(this.icon, this.color, this.title, this.body);

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.route_rounded,
    AppColors.data,
    'Record every ride',
    'Rides, commutes and drives with their route, distance, speed and the weather at '
        'the start. Check the ride call before you head out.',
  ),
  _Slide(
    Icons.people_alt_rounded,
    AppColors.tracking,
    'Ride with your people',
    'See the people you choose live on the map. Sharing starts only when you agree, '
        'and you can pause it any time.',
  ),
  _Slide(
    Icons.shield_rounded,
    AppColors.accent,
    'Guard what you ride',
    'Leave your phone on your bike or car. If it moves, everyone in your circle gets '
        'an alert showing where it went.',
  ),
];

/// Three welcome slides, shown once before the first sign-in.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _done() => context.read<SettingsController>().finishOnboarding();

  void _next() {
    if (_page == _slides.length - 1) return _done();
    _pages.nextPage(duration: kMotion * 2, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.s),
                    child: TextButton(onPressed: _done, child: const Text('Skip')),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [for (final s in _slides) _SlideView(s)],
                  ),
                ),
                Semantics(
                  label: 'Page ${_page + 1} of ${_slides.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: kMotion,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? AppColors.ink : AppColors.hairline,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.l),
                  child: FilledButton(
                    key: const ValueKey('onboarding-next'),
                    onPressed: _next,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(last ? 'Get started' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView(this.slide);

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: Column(
        children: [
          const SizedBox(height: Space.l),
          Container(
            width: 144,
            height: 144,
            decoration: BoxDecoration(color: slide.color, shape: BoxShape.circle),
            child: Icon(slide.icon, size: 64, color: AppColors.on(slide.color)),
          ),
          const SizedBox(height: Space.xl),
          Text(slide.title, style: t.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.m),
          Text(
            slide.body,
            style: t.bodyLarge?.copyWith(color: AppColors.textMuted, height: 1.45),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
