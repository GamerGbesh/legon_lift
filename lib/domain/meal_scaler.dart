// Scales a meal idea's portions to the user's daily targets.
//
// Each meal gets a share of the day (breakfast 25%, lunch 30%, dinner 30%, snack 15% of both
// calories and protein). Protein components are sized to the meal's protein share; carb
// components take the calories that are left; fats never grow; veg and fixed items stay as
// they are; "mixed" items (beans) go halfway. Quantities in the component text are rescaled
// and rounded to things you can actually serve (whole eggs and slices, quarter balls and cups,
// grams to 5 or 10).
import 'dart:math' as math;

import '../data/models/models.dart';

/// Share of the day's calories and protein for each meal type.
double mealShare(String mealType) => switch (mealType) {
      'breakfast' => 0.25,
      'snack' => 0.15,
      _ => 0.30, // lunch, dinner, lunch_or_dinner
    };

/// Roughly how many kcal come with each gram of protein from protein foods (eggs, fish,
/// chicken, tinned fish, milk), including their fat.
const double kcalPerProteinGram = 6;

/// A meal idea resized for the user.
class ScaledMeal {
  const ScaledMeal({
    required this.meal,
    required this.components,
    required this.proteinFactor,
    required this.carbFactor,
    required this.proteinG,
    required this.kcal,
    required this.targetProteinG,
    required this.targetKcal,
  });

  final MealIdea meal;

  /// The components with rescaled quantities (same order as [MealIdea.components]).
  final List<String> components;
  final double proteinFactor, carbFactor;

  /// Estimated protein and calories of the scaled portion.
  final int proteinG, kcal;

  /// This meal's share of the daily targets.
  final int targetProteinG, targetKcal;

  /// True when nothing changed (the standard portion already fits).
  bool get isStandard => proteinFactor == 1 && carbFactor == 1;
}

double _quarter(double v) => (v * 4).round() / 4;

/// Resizes [meal] for daily targets of [calorieKcal] and [proteinG].
ScaledMeal scaleMeal(MealIdea meal, {required int calorieKcal, required int proteinG}) {
  final share = mealShare(meal.mealType);
  final slotP = proteinG * share;
  final slotK = calorieKcal * share;
  final roles = meal.componentRoles;
  final hasCarb = roles.contains('carb') || roles.contains('mixed');

  if (roles.length != meal.components.length || meal.proteinG <= 0) {
    return ScaledMeal(
      meal: meal,
      components: meal.components,
      proteinFactor: 1,
      carbFactor: 1,
      proteinG: meal.proteinG,
      kcal: meal.kcalApprox,
      targetProteinG: slotP.round(),
      targetKcal: slotK.round(),
    );
  }

  final fp = _quarter((slotP / meal.proteinG).clamp(0.75, 2.0));
  final proteinKcal = math.min(meal.proteinG * kcalPerProteinGram, meal.kcalApprox * 0.85);
  final otherKcal = math.max(meal.kcalApprox - proteinKcal, meal.kcalApprox * 0.15);
  final fc = hasCarb ? _quarter(((slotK - proteinKcal * fp) / otherKcal).clamp(0.5, 1.5)) : 1.0;

  double factorFor(String role) => switch (role) {
        'protein' => fp,
        'carb' => fc,
        'mixed' => _quarter((fp + fc) / 2),
        'fat' => math.min(fc, 1.0),
        _ => 1.0,
      };

  return ScaledMeal(
    meal: meal,
    components: [
      for (final (i, c) in meal.components.indexed) scaleQuantities(c, factorFor(roles[i])),
    ],
    proteinFactor: fp,
    carbFactor: fc,
    proteinG: (meal.proteinG * fp).round(),
    kcal: (proteinKcal * fp + otherKcal * fc).round(),
    targetProteinG: slotP.round(),
    targetKcal: slotK.round(),
  );
}

// ---------------------------------------------------------------------------------------------
// Quantity text

final RegExp _number = RegExp(r'(\d+(?:\.\d+)?(?:/\d+)?)(?:\s*-\s*(\d+(?:\.\d+)?(?:/\d+)?))?(\s*-?\s*)([A-Za-z]*)');

/// Things served whole (you can't serve 2.5 eggs).
const Set<String> _wholeUnits = {
  'egg', 'eggs', 'slice', 'slices', 'stick', 'sticks', 'koose', 'thigh', 'piece', 'pieces', 'keta',
};

double _parse(String s) {
  if (s.contains('/')) {
    final parts = s.split('/');
    return double.parse(parts[0]) / double.parse(parts[1]);
  }
  return double.parse(s);
}

String _fraction(double v) {
  final whole = v.floor();
  final rest = v - whole;
  final frac = switch ((rest * 4).round()) {
    1 => '¼',
    2 => '½',
    3 => '¾',
    _ => '',
  };
  if ((rest * 4).round() == 4) return '${whole + 1}';
  if (whole == 0) return frac.isEmpty ? '0' : frac;
  return '$whole$frac';
}

String _formatScaled(double v, String unit, {required bool whole}) {
  final u = unit.toLowerCase();
  if (u == 'g' || u == 'ml') {
    final step = v < 50 ? 5 : 10;
    return '${math.max(step, (v / step).round() * step)}';
  }
  if (whole) return '${math.max(1, v.round())}';
  return _fraction(math.max(0.25, _quarter(v)));
}

/// True when the quantity counts whole things: the unit or one of the next two words is an egg,
/// slice, stick... ("2 boiled eggs", "3-egg omelette").
bool _isWhole(String unit, String after) {
  final words = [unit, ...after.trim().split(RegExp(r'[\s,/]+')).take(2)];
  return words.any((w) => _wholeUnits.contains(w.toLowerCase()));
}

/// Multiplies every quantity in [text] by [factor] ("60 g oats" x 0.75 -> "45 g oats",
/// "2 boiled eggs" x 1.25 -> "3 boiled eggs", "1/2-1 ball" x 1.5 -> "¾-1½ ball").
String scaleQuantities(String text, double factor) {
  if (factor == 1) return text;
  if (!text.contains(RegExp(r'\d'))) return '$text (${portionLabel(factor)})';
  return text.replaceAllMapped(_number, (m) {
    final unit = m[4] ?? '';
    final whole = _isWhole(unit, text.substring(m.end, math.min(text.length, m.end + 24)));
    final lo = _formatScaled(_parse(m[1]!) * factor, unit, whole: whole);
    final hi = m[2] == null ? null : _formatScaled(_parse(m[2]!) * factor, unit, whole: whole);
    final range = hi == null || hi == lo ? lo : '$lo-$hi';
    return '$range${m[3]}$unit';
  });
}

/// "¾ portion", "1½ portions", "double portion" for items without a number in their text.
String portionLabel(double factor) {
  if (factor == 2) return 'double portion';
  if (factor == 0.5) return 'half portion';
  final f = _fraction(factor);
  return factor > 1 ? '$f portions' : '$f portion';
}
