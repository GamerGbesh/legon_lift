// Owner: WS1. Shared by Settings > Equipment and onboarding step 7 (SPEC 12.3) so the two
// equipment UIs cannot drift. Constructor frozen.
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/models/models.dart';
import '../../../widgets/number_stepper.dart';

/// Edits an [EquipmentProfile] (SPEC 4.2 step 7, 4.12): equipment ticks, bench uprights, plates,
/// barbell, Smith bar (+ "Don't know yet"), leg press sled (+ "Don't know yet"), dumbbells and
/// leg curl type. Weight sections only appear when their equipment is ticked. [compact] hides the
/// explanatory notes (onboarding).
///
/// The editor is a [Column]; put it inside a scrolling parent.
class EquipmentEditor extends StatelessWidget {
  const EquipmentEditor({
    super.key,
    required this.value,
    required this.defaults,
    required this.onChanged,
    this.compact = false,
  });

  final EquipmentProfile value;
  final GymProfileDefaults defaults;
  final ValueChanged<EquipmentProfile> onChanged;
  final bool compact;

  /// Plate sizes offered as ticks (kg), heaviest first. Sizes already saved are always shown.
  static const List<double> plateOptions = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5];

  /// Dumbbell spacings offered (kg).
  static const List<double> dumbbellSteps = [1, 2, 2.5];
  static const double dumbbellLimitKg = 60;

  /// Equipment rows in display order: the gym defaults, then optional extras (ankle strap).
  List<Equipment> get _rows => [
        ...defaults.equipment,
        for (final e in defaults.optionalEquipment)
          if (!defaults.equipment.contains(e)) e,
      ];

  void _toggle(Equipment e, bool on) {
    final next = {...value.available};
    on ? next.add(e) : next.remove(e);
    onChanged(value.copyWith(available: next));
  }

  @override
  Widget build(BuildContext context) {
    final showPlates = value.has(Equipment.plates) ||
        value.has(Equipment.barbell) ||
        value.has(Equipment.smithMachine) ||
        value.has(Equipment.legPress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading('What the gym has', note: compact ? null : 'Untick anything that is missing or broken.'),
        for (final e in _rows)
          _SwitchRow(
            title: defaults.labelFor(e),
            note: compact ? null : defaults.equipmentNotes[e.wire],
            value: value.has(e),
            onChanged: (on) => _toggle(e, on),
          ),
        _SwitchRow(
          title: 'Bench with uprights + spotter available',
          note: compact ? null : 'Only then is the barbell bench press offered as an alternative.',
          value: value.hasBenchUprights,
          onChanged: (on) => onChanged(value.copyWith(hasBenchUprights: on)),
        ),
        if (showPlates) ...[
          _Heading('Plates', note: compact ? null : 'Tick every plate size the gym has.'),
          _PlatePicker(value: value, onChanged: onChanged),
        ],
        if (value.has(Equipment.barbell)) ...[
          _Heading('Barbell', note: compact ? null : 'A standard long bar weighs 20 kg.'),
          NumberStepper(
            value: value.barKg,
            step: 2.5,
            min: 5,
            max: 25,
            unit: 'kg',
            onChanged: (kg) => onChanged(value.copyWith(barKg: kg)),
          ),
        ],
        if (value.has(Equipment.smithMachine))
          _KnownWeight(
            title: 'Smith machine bar',
            note: compact ? null : "Not sure? Keep \"Don't know yet\". The plate maths will remind you.",
            kg: value.smithBarKg,
            known: value.smithBarKnown,
            step: 2.5,
            max: 30,
            onChanged: (kg, known) => onChanged(value.copyWith(smithBarKg: kg, smithBarKnown: known)),
          ),
        if (value.has(Equipment.legPress))
          _KnownWeight(
            title: 'Leg press empty sled',
            note: compact
                ? null
                : 'You log only the plates you add. Once you know the sled weight, it is added to your totals.',
            kg: value.legPressSledKg,
            known: value.legPressSledKnown,
            step: 5,
            max: 200,
            onChanged: (kg, known) => onChanged(value.copyWith(legPressSledKg: kg, legPressSledKnown: known)),
          ),
        if (value.has(Equipment.dumbbell)) ...[
          _Heading('Dumbbells', note: compact ? null : 'Weight of ONE dumbbell. Untick any pair that is missing.'),
          _DumbbellPicker(value: value, defaults: defaults, onChanged: onChanged),
        ],
        if (value.has(Equipment.legCurlMachine)) ...[
          _Heading('Leg curl machine', note: compact ? null : "Not sure? Keep 'Seated'."),
          SizedBox(
            height: Sizes.minTap,
            child: SegmentedButton<LegCurlType>(
              segments: const [
                ButtonSegment(value: LegCurlType.seated, label: Text('Seated')),
                ButtonSegment(value: LegCurlType.lying, label: Text('Lying')),
              ],
              selected: {value.legCurlType},
              onSelectionChanged: (s) => onChanged(value.copyWith(legCurlType: s.first)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Section title with an optional muted note.
class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
          ),
          if (note != null) ...[
            const SizedBox(height: Space.xs),
            Text(note!, style: AppText.label.copyWith(color: t.muted)),
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, this.note, required this.value, required this.onChanged});

  final String title;
  final String? note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: Sizes.minTap,
      title: Text(title, style: AppText.body.copyWith(color: t.onSurface)),
      subtitle: note == null ? null : Text(note!, style: AppText.label.copyWith(color: t.muted)),
      value: value,
      onChanged: onChanged,
    );
  }
}

/// A 56 dp toggle tile used for plate and dumbbell ticks.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.chip),
      side: BorderSide(color: selected ? t.primary : t.surface2, width: selected ? 2 : 1),
    );
    return Semantics(
      toggled: selected,
      button: true,
      child: Material(
        color: selected ? t.primary.withValues(alpha: 0.16) : t.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTap, minWidth: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[Icon(Icons.check, size: 18, color: t.primary), const SizedBox(width: Space.xs)],
                  Text(label, style: AppText.tabular(AppText.body).copyWith(color: selected ? t.onSurface : t.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatePicker extends StatelessWidget {
  const _PlatePicker({required this.value, required this.onChanged});

  final EquipmentProfile value;
  final ValueChanged<EquipmentProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = {...EquipmentEditor.plateOptions, ...value.platesKg}.toList()..sort((a, b) => b.compareTo(a));
    bool has(double kg) => value.platesKg.any((p) => (p - kg).abs() < 1e-6);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final kg in options)
          _ToggleChip(
            label: Fmt.weight(kg),
            selected: has(kg),
            // At least one plate size must stay ticked or no load could be made.
            onTap: has(kg) && value.platesKg.length == 1
                ? null
                : () {
                    final next = has(kg)
                        ? value.platesKg.where((p) => (p - kg).abs() >= 1e-6).toList()
                        : [...value.platesKg, kg];
                    onChanged(value.copyWith(platesKg: next..sort((a, b) => b.compareTo(a))));
                  },
          ),
      ],
    );
  }
}

/// A weight that may be unknown: stepper + "Don't know yet". Changing the weight marks it known.
class _KnownWeight extends StatelessWidget {
  const _KnownWeight({
    required this.title,
    this.note,
    required this.kg,
    required this.known,
    required this.step,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String? note;
  final double kg;
  final bool known;
  final double step, max;
  final void Function(double kg, bool known) onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title, note: note),
        NumberStepper(
          value: kg.clamp(0, max),
          step: step,
          max: max,
          unit: 'kg',
          onChanged: (v) => onChanged(v, true),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: Sizes.minTap,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text("Don't know yet", style: AppText.body.copyWith(color: t.onSurface)),
          value: !known,
          onChanged: (dontKnow) => onChanged(kg, !(dontKnow ?? false)),
        ),
      ],
    );
  }
}

class _DumbbellPicker extends StatelessWidget {
  const _DumbbellPicker({required this.value, required this.defaults, required this.onChanged});

  final EquipmentProfile value;
  final GymProfileDefaults defaults;
  final ValueChanged<EquipmentProfile> onChanged;

  static bool _onGrid(double kg, double step) {
    final n = kg / step;
    return (n - n.roundToDouble()).abs() < 1e-6;
  }

  static List<double> _grid(double step, double maxKg) => [
        for (var i = 1; i * step <= maxKg + 1e-6; i++) double.parse((i * step).toStringAsFixed(2)),
      ];

  /// The coarsest offered spacing that fits every saved weight.
  double get _step {
    final list = value.dumbbellsKg;
    if (list.isEmpty) return defaults.dumbbellStepKg;
    for (final s in [...EquipmentEditor.dumbbellSteps]..sort((a, b) => b.compareTo(a))) {
      if (list.every((kg) => _onGrid(kg, s))) return s;
    }
    return EquipmentEditor.dumbbellSteps.first;
  }

  double get _max => value.dumbbellsKg.isEmpty ? defaults.dumbbellMaxKg : value.dumbbellsKg.reduce((a, b) => a > b ? a : b);

  void _emit(List<double> kgs) => onChanged(value.copyWith(dumbbellsKg: kgs.toSet().toList()..sort()));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final step = _step;
    final maxKg = _max;
    final grid = _grid(step, maxKg);
    bool has(double kg) => value.dumbbellsKg.any((d) => (d - kg).abs() < 1e-6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Spacing between dumbbells', style: AppText.label.copyWith(color: t.onSurface)),
        const SizedBox(height: Space.s),
        SizedBox(
          height: Sizes.minTap,
          child: SegmentedButton<double>(
            segments: [
              for (final s in EquipmentEditor.dumbbellSteps) ButtonSegment(value: s, label: Text(Fmt.weight(s))),
            ],
            selected: {step},
            onSelectionChanged: (s) {
              final next = s.first;
              final top = (maxKg / next).floorToDouble() * next;
              _emit(_grid(next, top < next ? next : top));
            },
          ),
        ),
        const SizedBox(height: Space.l),
        Text('Heaviest dumbbell', style: AppText.label.copyWith(color: t.onSurface)),
        NumberStepper(
          value: maxKg,
          step: step,
          min: step,
          max: EquipmentEditor.dumbbellLimitKg,
          unit: 'kg',
          onChanged: (newMax) {
            // Keep ticks up to the new top; assume every new heavier size exists.
            final kept = value.dumbbellsKg.where((kg) => kg <= newMax + 1e-6);
            final added = _grid(step, newMax).where((kg) => kg > maxKg + 1e-6);
            final next = [...kept, ...added];
            _emit(next.isEmpty ? [newMax] : next);
          },
        ),
        const SizedBox(height: Space.m),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final kg in grid)
              _ToggleChip(
                label: Fmt.number(kg),
                selected: has(kg),
                onTap: has(kg) && value.dumbbellsKg.length == 1
                    ? null
                    : () => _emit(has(kg)
                        ? value.dumbbellsKg.where((d) => (d - kg).abs() >= 1e-6).toList()
                        : [...value.dumbbellsKg, kg]),
              ),
          ],
        ),
      ],
    );
  }
}
