// Owner: WS4. Pre-start sheet (SPEC 4.3): hot day, power cut / cardio machines off, recent
// illness, optional readiness check-in, the gap message and a live time estimate.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/models/models.dart';
import '../../../state/today_store.dart';
import '../../../widgets/big_button.dart';

/// What the user chose on the pre-start sheet.
@immutable
class PreStartChoice {
  const PreStartChoice({
    required this.hotDay,
    required this.cardioOff,
    required this.recentIllness,
    required this.readiness,
  });

  final bool hotDay, cardioOff, recentIllness;
  final ReadinessCheck readiness;
}

/// Shows the pre-start sheet for [dayName] ([dayId] null = the next day in the rotation).
Future<PreStartChoice?> showPreStartSheet(BuildContext context, {String? dayId, required String dayName}) =>
    showModalBottomSheet<PreStartChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PreStartSheet(dayId: dayId, dayName: dayName),
    );

class PreStartSheet extends StatefulWidget {
  const PreStartSheet({super.key, this.dayId, required this.dayName});

  final String? dayId;
  final String dayName;

  @override
  State<PreStartSheet> createState() => _PreStartSheetState();
}

class _PreStartSheetState extends State<PreStartSheet> {
  late bool _hot = context.read<TodayStore>().hotDayDefault;
  bool _cardioOff = false;
  bool _illness = false;
  bool _showReadiness = false;
  int? _sleep, _soreness, _energy;
  int? _minutes;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_estimate());
  }

  Future<void> _estimate() async {
    final ticket = ++_request;
    final m = await context.read<TodayStore>().estimateMinutes(
          dayId: widget.dayId,
          hotDay: _hot,
          cardioOff: _cardioOff,
          recentIllness: _illness,
        );
    if (mounted && ticket == _request) setState(() => _minutes = m);
  }

  void _set(VoidCallback change) {
    setState(change);
    unawaited(_estimate());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gap = context.read<TodayStore>().daysSinceLastWorkout;
    Widget toggle({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(icon, color: value ? t.primary : t.muted),
          title: Text(title, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          subtitle: Text(subtitle, style: AppText.label.copyWith(color: t.muted)),
          value: value,
          onChanged: onChanged,
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text('Before you start', style: AppText.headline.copyWith(color: t.onSurface)),
                  Text(widget.dayName, style: AppText.body.copyWith(color: t.muted)),
                  const SizedBox(height: Space.m),
                  if (gap != null && gap >= 10)
                    _Note(
                      icon: Icons.waving_hand_outlined,
                      color: t.secondary,
                      text: 'Welcome back! It has been $gap days, so today starts a bit lighter. '
                          'That is normal: you will be back to your weights soon.',
                    ),
                  toggle(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Hot today?',
                    subtitle: 'Longer rests, a shorter finisher, more water reminders.',
                    value: _hot,
                    onChanged: (v) => _set(() => _hot = v),
                  ),
                  toggle(
                    icon: Icons.power_off_outlined,
                    title: 'Power cut / cardio machines off',
                    subtitle: 'Warm up with drills instead of the bike or treadmill.',
                    value: _cardioOff,
                    onChanged: (v) => _set(() => _cardioOff = v),
                  ),
                  toggle(
                    icon: Icons.thermostat_outlined,
                    title: 'Fever or malaria in the last 2 weeks?',
                    subtitle: 'Today becomes an easy session.',
                    value: _illness,
                    onChanged: (v) => _set(() => _illness = v),
                  ),
                  if (_illness)
                    _Note(
                      icon: Icons.healing_outlined,
                      color: t.warning,
                      text: 'Only train if you have been well for at least a week. Stop and rest if you feel '
                          'dizzy, very tired or short of breath.',
                    ),
                  const SizedBox(height: Space.s),
                  if (!_showReadiness)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showReadiness = true),
                        icon: const Icon(Icons.add),
                        label: const Text('How do you feel? (optional)'),
                      ),
                    )
                  else ...[
                    _ReadinessRow(
                      title: 'Sleep last night',
                      low: 'Bad',
                      high: 'Great',
                      value: _sleep,
                      onChanged: (v) => setState(() => _sleep = v),
                    ),
                    _ReadinessRow(
                      title: 'Soreness',
                      low: 'None',
                      high: 'Very sore',
                      inverted: true,
                      value: _soreness,
                      onChanged: (v) => setState(() => _soreness = v),
                    ),
                    _ReadinessRow(
                      title: 'Energy',
                      low: 'Low',
                      high: 'High',
                      value: _energy,
                      onChanged: (v) => setState(() => _energy = v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.m),
            Semantics(
              liveRegion: true,
              child: Text(
                _minutes == null ? ' ' : 'About $_minutes min',
                textAlign: TextAlign.center,
                style: AppText.tabular(AppText.bodyStrong).copyWith(color: t.onSurface),
              ),
            ),
            const SizedBox(height: Space.s),
            BigButton(
              label: 'START',
              icon: Icons.play_arrow_rounded,
              onPressed: () => Navigator.of(context).pop(PreStartChoice(
                hotDay: _hot,
                cardioOff: _cardioOff,
                recentIllness: _illness,
                readiness: ReadinessCheck(sleep: _sleep, soreness: _soreness, energy: _energy),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.12), t.surface),
        borderRadius: BorderRadius.circular(Radii.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
        ],
      ),
    );
  }
}

/// Five face buttons (1-5). [inverted]: 1 is the happy face (soreness: 1 = none).
class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.title,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
    this.inverted = false,
  });

  final String title, low, high;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool inverted;

  static const List<IconData> _faces = [
    Icons.sentiment_very_dissatisfied,
    Icons.sentiment_dissatisfied,
    Icons.sentiment_neutral,
    Icons.sentiment_satisfied,
    Icons.sentiment_very_satisfied,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var v = 1; v <= 5; v++)
                SizedBox.square(
                  dimension: Sizes.minTap,
                  child: IconButton(
                    tooltip: '$title: $v of 5${v == 1 ? ' ($low)' : v == 5 ? ' ($high)' : ''}',
                    isSelected: value == v,
                    onPressed: () => onChanged(value == v ? null : v),
                    style: IconButton.styleFrom(
                      backgroundColor: value == v ? t.primary.withValues(alpha: 0.2) : null,
                    ),
                    icon: Icon(
                      _faces[inverted ? 5 - v : v - 1],
                      size: 32,
                      color: value == v ? t.primary : t.muted,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(low, style: AppText.caption.copyWith(color: t.muted)),
              Text(high, style: AppText.caption.copyWith(color: t.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
