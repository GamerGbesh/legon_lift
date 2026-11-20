// Owner: WS4. Onboarding step 6 (SPEC 4.2): split cards; the program comes from
// `programSelection.table` for (split, days per week).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../widgets/option_card.dart';
import '../onboarding_draft.dart';
import '../widgets/form_widgets.dart';

class SplitStep extends StatelessWidget {
  const SplitStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final ValueChanged<OnboardingDraft> onChanged;

  static const List<SplitKey> choices = [
    SplitKey.pushPullLegs,
    SplitKey.upperLower,
    SplitKey.chestbackLegsArmsshoulders,
    SplitKey.custom,
  ];

  static const Map<SplitKey, IconData> _icons = {
    SplitKey.pushPullLegs: Icons.view_week_outlined,
    SplitKey.upperLower: Icons.swap_vert,
    SplitKey.chestbackLegsArmsshoulders: Icons.grid_view,
    SplitKey.custom: Icons.edit_note,
  };

  /// The `programSelection.table` note for the chosen (split, days), if any.
  static String? selectionNote(Personalization p, SplitKey split, int days) {
    final table = p.programSelection['table'];
    if (table is! List) return null;
    for (final row in table.whereType<Map<dynamic, dynamic>>()) {
      final d = row['days_per_week'];
      if (row['split'] == split.wire && d is List && d.contains(days) && row['note'] is String) {
        return row['note'] as String;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<AssetCatalog>();
    final p = draft.profile;
    final template = draft.template(catalog);
    final note = p.split == SplitKey.custom ? null : selectionNote(catalog.personalization, p.split, p.daysPerWeek);
    return StepBody(
      title: 'How to split your week',
      subtitle: 'All of them work. Push / Pull / Legs is the simplest to follow.',
      children: [
        for (final s in choices)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: OptionCard(
              icon: _icons[s],
              title: Copy.split(s),
              subtitle: Copy.splitHint(s),
              badge: s == SplitKey.pushPullLegs ? 'Recommended' : null,
              selected: p.split == s,
              onTap: () => onChanged(draft.withProfile(p.copyWith(split: s)).withDaysPerWeek(catalog, p.daysPerWeek)),
            ),
          ),
        NoticeBox(
          icon: Icons.event_note_outlined,
          color: context.tokens.secondary,
          text: p.split == SplitKey.custom
              ? 'You start with a copy of ${template.name} and can change every exercise, set and rest '
                  'in the Program tab.'
              : 'Your program: ${template.name}.${note == null ? '' : ' $note'}',
        ),
      ],
    );
  }
}
