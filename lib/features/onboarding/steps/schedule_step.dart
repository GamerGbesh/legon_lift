// Owner: WS4. Onboarding step 5 (SPEC 4.2): days per week, weekdays, session length, usual
// training time and reminders.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../onboarding_draft.dart';
import '../widgets/form_widgets.dart';

class ScheduleStep extends StatelessWidget {
  const ScheduleStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final ValueChanged<OnboardingDraft> onChanged;

  @override
  Widget build(BuildContext context) => StepBody(
        title: 'Your week',
        subtitle: 'Pick days you can really make. 3 days a week is plenty to change your body.',
        children: [ScheduleFields(draft: draft, onChanged: onChanged)],
      );
}

/// The fields of [ScheduleStep] (reused by the You hub editor).
class ScheduleFields extends StatelessWidget {
  const ScheduleFields({super.key, required this.draft, required this.onChanged, this.showReminders = true});

  final OnboardingDraft draft;
  final ValueChanged<OnboardingDraft> onChanged;
  final bool showReminders;

  static const List<int> sessionLengths = [30, 45, 60, 75];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    final p = draft.profile;
    final picked = p.workoutWeekdays.length;
    final options = Copy.options(catalog.personalization, 'training_time');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Days per week', top: 0),
        StepperField(
          title: 'Days per week',
          value: p.daysPerWeek.toDouble(),
          step: 1,
          unit: 'days',
          min: 2,
          max: 6,
          onChanged: (v) => onChanged(draft.withDaysPerWeek(catalog, v.round())),
        ),
        const FieldLabel('Which days?', hint: 'Leave a rest day between sessions when you can.'),
        WeekdayChips(selected: p.workoutWeekdays, onToggle: (d) => onChanged(draft.toggleWeekday(d))),
        if (picked < 2 || picked > 6)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Text(
              picked < 2 ? 'Pick at least 2 days.' : 'Pick at most 6 days: muscles grow on rest days.',
              style: AppText.label.copyWith(color: t.warning),
            ),
          ),
        const FieldLabel('Session length', hint: 'Including warm-up and cool-down.'),
        ChoiceSegments<int>(
          values: sessionLengths,
          labelOf: (m) => '$m min',
          selected: p.sessionMinutes,
          onChanged: (m) => onChanged(draft.withProfile(p.copyWith(sessionMinutes: m))),
        ),
        if (p.sessionMinutes < 45)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Text(
              '30 minutes is too short for most days: we will drop the extras, and you can end early. '
              '45-60 minutes works best.',
              style: AppText.label.copyWith(color: t.warning),
            ),
          ),
        if (options.isNotEmpty) ...[
          const FieldLabel('Usual training time'),
          ChoiceSegments<String>(
            values: options,
            labelOf: Copy.trainingTime,
            selected: options.contains(p.trainingTime) ? p.trainingTime : options.last,
            onChanged: (v) {
              final s = draft.settings;
              final followDefault = s.reminderTime == null || s.reminderTime == Copy.reminderTimeFor(p.trainingTime);
              onChanged(draft.copyWith(
                profile: p.copyWith(trainingTime: v),
                settings: followDefault && s.reminderTime != null
                    ? s.copyWith(reminderTime: () => Copy.reminderTimeFor(v))
                    : s,
              ));
            },
          ),
          if (p.trainingTime == 'afternoon')
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text('Midday is the hottest time: we will plan longer rests and more water.',
                  style: AppText.label.copyWith(color: t.muted)),
            ),
        ],
        if (showReminders) ...[
          const FieldLabel('Reminders'),
          ReminderRow(
            title: 'Workout-day reminder',
            time: draft.settings.reminderTime,
            fallback: Copy.reminderTimeFor(p.trainingTime),
            onChanged: (v) => onChanged(draft.copyWith(settings: draft.settings.copyWith(reminderTime: () => v))),
          ),
          ReminderRow(
            title: 'Morning weigh-in',
            time: draft.settings.weighInTime,
            fallback: '06:30',
            onChanged: (v) => onChanged(draft.copyWith(settings: draft.settings.copyWith(weighInTime: () => v))),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Pack-your-gym-bag reminder', style: AppText.body.copyWith(color: t.onSurface)),
            subtitle: Text('The evening before a workout', style: AppText.label.copyWith(color: t.muted)),
            value: draft.settings.gymBagReminder,
            onChanged: (v) => onChanged(draft.copyWith(settings: draft.settings.copyWith(gymBagReminder: v))),
          ),
        ],
      ],
    );
  }
}
