// Owner: WS4. Onboarding step 7 (SPEC 4.2): the gym's equipment, via the shared WS1
// EquipmentEditor so onboarding and Settings cannot drift.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../settings/widgets/equipment_editor.dart';
import '../onboarding_draft.dart';
import '../widgets/form_widgets.dart';

class EquipmentStep extends StatelessWidget {
  const EquipmentStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final ValueChanged<OnboardingDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final gym = context.read<AssetCatalog>().personalization.gym;
    final eq = draft.settings.equipment;
    final db = eq.dumbbellsKg;
    final plates = [...eq.platesKg]..sort((a, b) => b.compareTo(a));
    return StepBody(
      title: 'What the gym has',
      subtitle: 'Already set for the UG gym. Untick anything that is missing or broken: we pick a swap.',
      children: [
        EquipmentEditor(
          value: eq,
          defaults: gym,
          compact: true,
          onChanged: (v) => onChanged(draft.copyWith(settings: draft.settings.copyWith(equipment: v))),
        ),
        const SizedBox(height: Space.l),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weights we assume', style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                const SizedBox(height: Space.xs),
                Text(
                  db.isEmpty
                      ? 'Dumbbells: none'
                      : 'Dumbbells: ${Fmt.number(db.first)} to ${Fmt.number(db.last)} kg (${db.length} pairs)',
                  style: AppText.body.copyWith(color: t.onSurface),
                ),
                Text('Plates: ${plates.map(Fmt.number).join(', ')} kg',
                    style: AppText.body.copyWith(color: t.onSurface)),
                const SizedBox(height: Space.xs),
                Text('Check on your first visit and fix them any time in You > Settings > Equipment.',
                    style: AppText.label.copyWith(color: t.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
