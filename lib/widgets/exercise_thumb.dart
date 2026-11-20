// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';
import '../data/models/models.dart';
import 'placeholder_figure.dart';

/// Square thumbnail of an exercise's first photo (a category icon when it has none).
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.exercise, this.size = 56});

  final Exercise exercise;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = Icon(PlaceholderFigure.iconFor(exercise), color: t.primary, size: size * 0.45);
    return Semantics(
      image: true,
      label: exercise.name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: exercise.localImages.isEmpty ? t.surface2 : t.imageCard,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        clipBehavior: Clip.antiAlias,
        child: exercise.localImages.isEmpty
            ? icon
            : Image.asset(
                exercise.localImages.first,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) => icon,
              ),
      ),
    );
  }
}
