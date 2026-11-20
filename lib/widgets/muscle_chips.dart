// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';
import '../data/models/models.dart';

/// "Muscles worked": primary chips filled, secondary chips outlined.
class MuscleChips extends StatelessWidget {
  const MuscleChips({super.key, required this.primary, required this.secondary});

  final List<Muscle> primary;
  final List<Muscle> secondary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget chip(Muscle m, {required bool main}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
          decoration: BoxDecoration(
            color: main ? t.primary.withValues(alpha: 0.16) : null,
            border: Border.all(color: main ? t.primary : t.surface2),
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(m.label, style: AppText.label.copyWith(color: main ? t.onSurface : t.muted)),
        );
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final m in primary) chip(m, main: true),
        for (final m in secondary) chip(m, main: false),
      ],
    );
  }
}
