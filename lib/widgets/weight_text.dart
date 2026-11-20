// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models/models.dart';
import '../state/profile_store.dart';

/// A weight in the user's unit following SPEC 0.4: "2 × 12.5 kg" for a pair of dumbbells,
/// "Bodyweight" for bodyweight exercises.
class WeightText extends StatelessWidget {
  const WeightText({super.key, required this.kg, required this.exercise, this.style});

  final double kg;
  final Exercise exercise;
  final TextStyle? style;

  /// The label without a BuildContext (useful in strings and tests).
  static String label(double kg, Exercise exercise, {bool useLb = false}) {
    switch (exercise.loadType) {
      case LoadType.bodyweight:
        return 'Bodyweight';
      case LoadType.time:
        return '';
      case LoadType.dumbbell when (exercise.dumbbellCount ?? 1) > 1:
        return '${exercise.dumbbellCount} × ${Fmt.weight(kg, useLb: useLb)}';
      default:
        return Fmt.weight(kg, useLb: useLb);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool useLb;
    try {
      useLb = context.select<ProfileStore, bool>((s) => s.profile?.useLb ?? false);
    } on ProviderNotFoundException {
      useLb = false;
    }
    return Text(label(kg, exercise, useLb: useLb), style: style);
  }
}
