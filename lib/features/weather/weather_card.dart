import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/activity_type.dart';
import '../../core/ride_verdict.dart';
import '../../core/theme.dart';
import '../../core/time_format.dart';
import '../../core/units.dart';
import '../../core/weather.dart';
import '../../core/weather_code.dart';
import '../me/settings_controller.dart';
import 'weather_controller.dart';
import 'weather_widgets.dart';

/// Conditions, the ride call for [type], the best hour and the next 6 hours.
/// [compact] folds the hourly part behind a toggle (Record keeps START in reach).
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.type, this.compact = false});

  final ActivityType type;
  final bool compact;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  Timer? _tick;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final weather = context.read<WeatherController>()..load();
    // Keeps "updated X min ago" current and refreshes once the cache expires.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      weather.load();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wc = context.watch<WeatherController>();
    final w = wc.weather;
    return Card(
      child: AnimatedSize(
        duration: kMotion,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.s, Space.s),
          child: w == null ? _placeholder(wc) : _content(wc, w),
        ),
      ),
    );
  }

  Widget _placeholder(WeatherController wc) {
    final t = Theme.of(context).textTheme;
    final failed = wc.failed && !wc.loading;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (failed)
            Icon(Icons.cloud_off_outlined, color: AppColors.textMuted)
          else
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              failed ? 'Weather unavailable. Check your connection.' : 'Checking the weather…',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
          if (failed) TextButton(onPressed: () => wc.load(force: true), child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _content(WeatherController wc, Weather w) {
    final t = Theme.of(context).textTheme;
    final units = context.select<SettingsController, Units>((s) => s.units);
    final now = clock.now();
    final c = w.current;
    final call = rideVerdict(widget.type, w, now: now);
    final best = bestHourToRide(widget.type, w, now: now);
    final hours = w.upcoming(now, 6);
    final muted = t.bodySmall?.copyWith(color: AppColors.textMuted);
    final wind =
        '${(units == Units.km ? c.windKmh : kmToMi(c.windKmh)).round()} ${units.speedLabel}';
    final showHourly = !widget.compact || _expanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: Space.s),
          child: Row(
            children: [
              WeatherGlyph(code: c.code, isDay: c.isDay),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${c.tempC.round()}°',
                            style: t.headlineSmall?.copyWith(fontFeatures: kTabular, height: 1.1),
                          ),
                          TextSpan(
                            text: '  ${weatherLabel(c.code)}',
                            style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Semantics(
                      label:
                          'Feels like ${c.feelsLikeC.round()} degrees. '
                          'Wind $wind from ${compassPoint(c.windFromDeg)}',
                      excludeSemantics: true,
                      // One line that only cuts at its end, so "Feels like"
                      // always keeps its number.
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Feels like ${c.feelsLikeC.round()}° · '),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: WindArrow(fromDeg: c.windFromDeg),
                            ),
                            TextSpan(text: ' $wind'),
                          ],
                        ),
                        style: muted?.copyWith(fontFeatures: kTabular),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              VerdictPill(call.verdict),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(call.reason, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        if (best != null && showHourly) ...[
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(bestTimeHint(widget.type, w, best), style: muted)),
            ],
          ),
        ],
        if (showHourly && hours.isNotEmpty) ...[
          const SizedBox(height: Space.m),
          Padding(
            padding: const EdgeInsets.only(right: Space.s),
            child: HourlyStrip(weather: w, hours: hours),
          ),
        ],
        const SizedBox(height: Space.xs),
        _footer(wc, now),
      ],
    );
  }

  Widget _footer(WeatherController wc, DateTime now) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    final at = wc.updatedAt;
    final ago = at == null ? '' : 'Updated ${formatAgo(at, now)}';
    return Row(
      children: [
        Icon(
          wc.failed ? Icons.cloud_off_outlined : Icons.place_outlined,
          size: 16,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            wc.failed ? 'Offline · $ago' : '${wc.place.label} · $ago',
            style: muted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.compact)
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            iconAlignment: IconAlignment.end,
            icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_expanded ? 'Less' : 'Hourly'),
          )
        else if (wc.loading)
          const SizedBox.square(
            dimension: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh weather',
            onPressed: () => wc.load(force: true),
            icon: Icon(Icons.refresh_rounded, size: 20, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
