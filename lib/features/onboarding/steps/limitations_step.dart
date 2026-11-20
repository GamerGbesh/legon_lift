// Owner: WS4. Onboarding step 8 (SPEC 4.2): limitations, daily activity, food budget and diet.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../widgets/option_card.dart';
import '../widgets/form_widgets.dart';

class LimitationsStep extends StatelessWidget {
  const LimitationsStep({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) => StepBody(
        title: 'Body niggles and food',
        subtitle: 'So we can swap exercises that load a sore spot, and suggest meals you can buy.',
        children: [LimitationsFields(profile: profile, onChanged: onChanged)],
      );
}

/// The fields of [LimitationsStep] (reused by the You hub editor).
class LimitationsFields extends StatelessWidget {
  const LimitationsFields({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  static List<String> _toggle(List<String> list, String id) =>
      list.contains(id) ? [for (final x in list) if (x != id) x] : [...list, id];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = context.read<AssetCatalog>().personalization;
    final lims = Copy.options(p, 'limitations');
    final diets = Copy.options(p, 'diet_notes');
    final budgets = Copy.options(p, 'budget');
    final activityHint = Copy.field(p, 'activity_level')?['hint'];
    final u = profile;
    Widget chips(List<String> ids, List<String> selected, String Function(String) label, ValueChanged<String> toggle) =>
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final id in ids)
              FilterChip(
                label: Text(label(id)),
                selected: selected.contains(id),
                onSelected: (_) => toggle(id),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Any pain or old injuries?', hint: 'Leave empty if none.', top: 0),
        chips(lims, u.limitations, Copy.limitation, (id) => onChanged(u.copyWith(limitations: _toggle(u.limitations, id)))),
        if (u.limitations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Text(
              u.limitations.contains('other')
                  ? 'We swap exercises that load the areas you picked. For anything else: stop any exercise '
                      'that hurts more than 3 out of 10.'
                  : 'We swap exercises that load these areas. Stop any exercise that hurts more than 3 out of 10.',
              style: AppText.label.copyWith(color: t.muted),
            ),
          ),
        FieldLabel('Daily activity outside the gym', hint: activityHint is String ? activityHint : null),
        for (final a in ActivityLevel.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: OptionCard(
              title: Copy.activity(a),
              subtitle: Copy.activityHint(a),
              selected: u.activityLevel == a,
              onTap: () => onChanged(u.copyWith(activityLevel: a)),
            ),
          ),
        OptionalStepperField(
          label: 'I know my daily steps',
          hint: 'Optional, from your phone\'s step counter.',
          value: u.baselineSteps?.toDouble(),
          initial: 5000,
          step: 500,
          unit: 'steps',
          min: 0,
          max: 40000,
          onChanged: (v) => onChanged(u.copyWith(baselineSteps: () => v?.round())),
        ),
        if (budgets.isNotEmpty) ...[
          const FieldLabel('Food budget'),
          ChoiceSegments<String>(
            values: budgets,
            labelOf: Copy.budget,
            selected: budgets.contains(u.budget) ? u.budget : budgets.first,
            onChanged: (b) => onChanged(u.copyWith(budget: b)),
          ),
        ],
        const FieldLabel('Diet notes', hint: 'We leave these out of meal ideas.'),
        chips(diets, u.dietNotes, Copy.diet, (id) => onChanged(u.copyWith(dietNotes: _toggle(u.dietNotes, id)))),
      ],
    );
  }
}
