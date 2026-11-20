// Owner: WS4. Onboarding step 3 (SPEC 4.2): units, sex, age, height, weight, optional waist and
// goal weight. Values are stored metric; imperial only changes what is shown (SPEC 0.3).
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format.dart';
import '../../../core/units.dart';
import '../../../data/models/models.dart';
import '../widgets/form_widgets.dart';

class BodyStep extends StatelessWidget {
  const BodyStep({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) => StepBody(
        title: 'About your body',
        subtitle: 'Used for your food targets and to pick safe starting weights. It stays on this phone.',
        children: [BodyFields(profile: profile, onChanged: onChanged)],
      );
}

/// The fields of [BodyStep] without the page title (reused by the You hub editor).
class BodyFields extends StatelessWidget {
  const BodyFields({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = profile;
    final lb = p.useLb;
    final wUnit = Units.weightUnit(useLb: lb);
    double shownW(double kg) => double.parse(Units.displayWeight(kg, useLb: lb).toStringAsFixed(1));
    double storeW(double v) => double.parse(Units.weightToKg(v, useLb: lb).toStringAsFixed(2));
    final wStep = lb ? 1.0 : 0.5;
    final wMin = shownW(40).floorToDouble(), wMax = shownW(250).ceilToDouble();
    final (ft, inch) = Units.cmToFtIn(p.heightCm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Units', top: 0),
        ChoiceSegments<bool>(
          values: const [false, true],
          labelOf: (imperial) => imperial ? 'lb, ft-in' : 'kg, cm',
          selected: p.useLb,
          onChanged: (imperial) => onChanged(p.copyWith(useLb: imperial, useFtIn: imperial)),
        ),
        const FieldLabel('Sex', hint: 'Used only for the calorie formula.'),
        ChoiceSegments<Sex>(
          values: Sex.values,
          labelOf: (s) => s == Sex.male ? 'Male' : 'Female',
          selected: p.sex,
          onChanged: (s) => onChanged(p.copyWith(sex: s)),
        ),
        const FieldLabel('Age'),
        StepperField(
          title: 'Age',
          value: p.ageY.toDouble(),
          step: 1,
          unit: 'years',
          min: 16,
          max: 80,
          onChanged: (v) => onChanged(p.copyWith(ageY: v.round())),
        ),
        if (p.ageY < 18)
          const NoticeBox(
            icon: Icons.supervisor_account_outlined,
            text: 'Under 18: please train with a coach or an experienced adult nearby, and keep every set '
                'with a few reps left in the tank.',
          ),
        const FieldLabel('Height'),
        if (!p.useFtIn)
          StepperField(
            title: 'Height',
            value: p.heightCm.roundToDouble(),
            step: 1,
            unit: 'cm',
            min: 140,
            max: 210,
            onChanged: (v) => onChanged(p.copyWith(heightCm: v)),
          )
        else ...[
          StepperField(
            title: 'Height: feet',
            value: ft.toDouble(),
            step: 1,
            unit: 'ft',
            min: 4,
            max: 6,
            onChanged: (v) => onChanged(p.copyWith(heightCm: Units.ftInToCm(v.round(), inch).clamp(140, 210))),
          ),
          const SizedBox(height: Space.s),
          StepperField(
            title: 'Height: inches',
            value: inch.toDouble(),
            step: 1,
            unit: 'in',
            min: 0,
            max: 11,
            onChanged: (v) => onChanged(p.copyWith(heightCm: Units.ftInToCm(ft, v.round()).clamp(140, 210))),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text('= ${Fmt.height(p.heightCm)}', style: TextStyle(color: t.muted)),
          ),
        ],
        const FieldLabel('Current weight'),
        StepperField(
          title: 'Current weight',
          value: shownW(p.weightKg),
          step: wStep,
          unit: wUnit,
          min: wMin,
          max: wMax,
          decimals: 1,
          onChanged: (v) => onChanged(p.copyWith(weightKg: storeW(v))),
        ),
        const SizedBox(height: Space.m),
        OptionalStepperField(
          label: 'Goal weight',
          hint: 'Optional. Helps set your protein target.',
          value: p.goalWeightKg == null ? null : shownW(p.goalWeightKg!),
          initial: shownW((p.weightKg - 10).clamp(40, 250)).roundToDouble(),
          step: wStep,
          unit: wUnit,
          min: wMin,
          max: wMax,
          decimals: 1,
          onChanged: (v) => onChanged(p.copyWith(goalWeightKg: () => v == null ? null : storeW(v))),
        ),
        OptionalStepperField(
          label: 'Waist at the navel',
          hint: 'Optional. The best sign of fat loss while you build muscle.',
          value: p.startWaistCm == null
              ? null
              : (p.useFtIn ? double.parse(Units.cmToInches(p.startWaistCm!).toStringAsFixed(1)) : p.startWaistCm),
          initial: p.useFtIn ? 40 : 100,
          step: p.useFtIn ? 0.5 : 1,
          unit: p.useFtIn ? 'in' : 'cm',
          min: p.useFtIn ? 20 : 50,
          max: p.useFtIn ? 79 : 200,
          decimals: 1,
          onChanged: (v) => onChanged(p.copyWith(
            startWaistCm: () => v == null ? null : (p.useFtIn ? double.parse(Units.inchesToCm(v).toStringAsFixed(1)) : v),
          )),
        ),
      ],
    );
  }
}
