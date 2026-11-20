// Owner: WS4. Onboarding step 4 (SPEC 4.2): goal cards and training experience.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../widgets/option_card.dart';
import '../widgets/form_widgets.dart';

class GoalStep extends StatelessWidget {
  const GoalStep({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) => StepBody(
        title: 'Your goal',
        subtitle: 'You can change this later in You > Profile.',
        children: [GoalFields(profile: profile, onChanged: onChanged)],
      );
}

/// The fields of [GoalStep] (reused by the You hub editor).
class GoalFields extends StatelessWidget {
  const GoalFields({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  static const Map<Goal, IconData> _icons = {
    Goal.recomp: Icons.autorenew,
    Goal.fatLoss: Icons.trending_down,
    Goal.muscleGain: Icons.fitness_center,
    Goal.maintain: Icons.favorite_border,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.read<AssetCatalog>().personalization;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in Goal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: OptionCard(
              icon: _icons[g],
              title: Copy.goal(g, p),
              subtitle: Copy.goalHint(g),
              badge: g == Goal.recomp ? 'Recommended' : null,
              selected: profile.goal == g,
              onTap: () => onChanged(profile.copyWith(goal: g)),
            ),
          ),
        const FieldLabel('Training experience'),
        for (final e in Experience.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: OptionCard(
              title: Copy.experience(e),
              selected: profile.experience == e,
              onTap: () => onChanged(profile.copyWith(experience: e)),
            ),
          ),
      ],
    );
  }
}
