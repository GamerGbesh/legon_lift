// Owner: WS4. Form building blocks shared by the onboarding steps, the You hub editor and the
// Program tab (weekday chips).
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../widgets/number_entry_sheet.dart';
import '../../../widgets/number_stepper.dart';

/// Scrollable body of one onboarding step: big title, optional intro, then [children].
class StepBody extends StatelessWidget {
  const StepBody({super.key, required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xl),
      children: [
        Semantics(header: true, child: Text(title, style: AppText.headline.copyWith(color: t.onSurface))),
        if (subtitle != null) ...[
          const SizedBox(height: Space.s),
          Text(subtitle!, style: AppText.body.copyWith(color: t.muted)),
        ],
        const SizedBox(height: Space.l),
        ...children,
      ],
    );
  }
}

/// A field caption with an optional hint line.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.hint, this.top = Space.l});

  final String text;
  final String? hint;
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          if (hint != null) Text(hint!, style: AppText.label.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}

/// A row of equal segments (single choice), full width, 56 dp tall.
class ChoiceSegments<T> extends StatelessWidget {
  const ChoiceSegments({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final v in values)
              ButtonSegment<T>(
                value: v,
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(labelOf(v), maxLines: 1)),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      );
}

/// "No" / "Yes" segments for a yes/no question.
class YesNoToggle extends StatelessWidget {
  const YesNoToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceSegments<bool>(
        values: const [false, true],
        labelOf: (v) => v ? 'Yes' : 'No',
        selected: value,
        onChanged: onChanged,
      );
}

/// Mon-Sun chips (1 = Monday). Each chip is at least 48 dp wide and 56 dp tall.
class WeekdayChips extends StatelessWidget {
  const WeekdayChips({super.key, required this.selected, required this.onToggle});

  final List<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (var d = 1; d <= 7; d++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: d == 7 ? 0 : Space.xs),
              child: Semantics(
                label: '${Fmt.weekdayShort(d)}, ${selected.contains(d) ? 'workout day' : 'rest day'}',
                button: true,
                selected: selected.contains(d),
                excludeSemantics: true,
                child: Material(
                  color: selected.contains(d) ? t.primary : t.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.chip),
                    side: BorderSide(color: selected.contains(d) ? t.primary : t.surface2),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.chip),
                    onTap: () => onToggle(d),
                    child: SizedBox(
                      height: Sizes.minTap,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Fmt.weekdayShort(d).substring(0, 2),
                            style: AppText.bodyStrong.copyWith(
                              color: selected.contains(d) ? t.onPrimary : t.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A number stepper whose value can also be typed on the keypad sheet.
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.title,
    required this.value,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.decimals = 0,
  });

  final String title;
  final double value;
  final double step;
  final String unit;
  final ValueChanged<double> onChanged;
  final double min;
  final double? max;
  final int decimals;

  @override
  Widget build(BuildContext context) => NumberStepper(
        value: value,
        step: step,
        unit: unit,
        min: min,
        max: max,
        decimals: decimals,
        onChanged: onChanged,
        onTapValue: () async {
          final v = await showNumberEntrySheet(
            context,
            title: title,
            initial: value,
            unit: unit,
            decimals: decimals,
            min: min,
            max: max,
          );
          if (v != null) onChanged(v);
        },
      );
}

/// An optional number: a switch row ("Add a goal weight") that reveals a stepper.
class OptionalStepperField extends StatelessWidget {
  const OptionalStepperField({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.initial,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.decimals = 0,
  });

  final String label;
  final String? hint;

  /// Null = not given.
  final double? value;

  /// Value used when the switch is turned on.
  final double initial;
  final double step;
  final String unit;
  final ValueChanged<double?> onChanged;
  final double min;
  final double? max;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          subtitle: hint == null ? null : Text(hint!, style: AppText.label.copyWith(color: t.muted)),
          value: v != null,
          onChanged: (on) => onChanged(on ? initial : null),
        ),
        if (v != null)
          StepperField(
            title: label,
            value: v,
            step: step,
            unit: unit,
            min: min,
            max: max,
            decimals: decimals,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

/// A tinted message box (warning, advice, info).
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.icon, required this.text, this.color, this.child});

  final IconData icon;
  final String text;

  /// Accent colour (defaults to the warning colour).
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.warning;
    return Container(
      margin: const EdgeInsets.only(top: Space.s),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.12), t.surface),
        borderRadius: BorderRadius.circular(Radii.button),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c),
              const SizedBox(width: Space.m),
              Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
            ],
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Opens the time picker for an `HH:mm` value and returns the new value (null when cancelled).
Future<String?> pickHhmm(BuildContext context, String hhmm) async {
  final parts = hhmm.split(':');
  final initial = TimeOfDay(hour: int.tryParse(parts.first) ?? 7, minute: int.tryParse(parts.last) ?? 0);
  final picked = await showTimePicker(context: context, initialTime: initial);
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
}

/// A switch row with a tappable time ("Workout-day reminder · 15:00").
class ReminderRow extends StatelessWidget {
  const ReminderRow({super.key, required this.title, required this.time, required this.fallback, required this.onChanged});

  final String title;

  /// `HH:mm`, or null when the reminder is off.
  final String? time;

  /// Time used when the reminder is switched on.
  final String fallback;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = time != null;
    return Row(
      children: [
        Expanded(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title, style: AppText.body.copyWith(color: t.onSurface)),
            value: on,
            onChanged: (v) => onChanged(v ? fallback : null),
          ),
        ),
        if (on)
          TextButton.icon(
            onPressed: () async {
              final v = await pickHhmm(context, time!);
              if (v != null) onChanged(v);
            },
            icon: const Icon(Icons.schedule),
            label: Text(time!, style: AppText.tabular(AppText.bodyStrong)),
          ),
      ],
    );
  }
}
