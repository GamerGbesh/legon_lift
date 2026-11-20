// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../app/theme/typography.dart';
import '../data/models/models.dart';

/// Shown instead of photos for exercises without pictures: a category icon, the name and the
/// main muscles, on a calm card. Fills its parent (wrap it in an AspectRatio).
class PlaceholderFigure extends StatelessWidget {
  const PlaceholderFigure({super.key, required this.exercise});

  final Exercise exercise;

  /// Icon that suggests the kind of exercise.
  static IconData iconFor(Exercise ex) => switch (ex.category) {
        ExerciseCategory.cardio => ex.equipment.contains(Equipment.bike) ? Icons.directions_bike : Icons.directions_walk,
        ExerciseCategory.mobility || ExerciseCategory.warmup => Icons.self_improvement,
        ExerciseCategory.core => Icons.accessibility_new,
        _ => Icons.fitness_center,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: '${exercise.name}: no photo',
      child: Container(
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(Radii.imageCard),
          border: Border.all(color: t.muted.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(Space.l),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: t.primary.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(iconFor(exercise), size: 40, color: t.primary),
                ),
                const SizedBox(height: Space.m),
                Text(
                  exercise.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(color: t.onSurface),
                ),
                if (exercise.primaryMuscles.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    exercise.primaryMuscles.map((m) => m.label).join(' · '),
                    textAlign: TextAlign.center,
                    style: AppText.label.copyWith(color: t.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
