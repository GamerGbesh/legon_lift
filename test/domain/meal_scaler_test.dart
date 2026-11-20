import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/meal_scaler.dart';

import '../fakes/fakes.dart';

void main() {
  group('scaleQuantities', () {
    test('grams and ml round to 5 or 10', () {
      expect(scaleQuantities('60 g oats', 0.75), '45 g oats');
      expect(scaleQuantities('250 ml milk', 1.25), '310 ml milk');
    });
    test('eggs, slices and sticks stay whole, even with a word in between', () {
      expect(scaleQuantities('2 boiled eggs', 1.25), '3 boiled eggs');
      expect(scaleQuantities('3-egg omelette', 1.5), '5-egg omelette');
      expect(scaleQuantities('3 sticks khebab', 0.75), '2 sticks khebab');
      expect(scaleQuantities('3-4 boiled eggs', 1.25), '4-5 boiled eggs');
    });
    test('balls, cups and tins use quarters; ranges and fractions scale', () {
      expect(scaleQuantities('1/2-1 ball Ga kenkey', 0.75), '½-¾ ball Ga kenkey');
      expect(scaleQuantities('1 tin sardines', 1.5), '1½ tin sardines');
      expect(scaleQuantities('1 pack noodles', 0.5), '½ pack noodles');
    });
    test('items without a number get a portion note; factor 1 changes nothing', () {
      expect(scaleQuantities('small banku', 0.75), 'small banku (¾ portion)');
      expect(scaleQuantities('rice or yam', 2), 'rice or yam (double portion)');
      expect(scaleQuantities('2 boiled eggs', 1), '2 boiled eggs');
    });
  });

  group('scaleMeal for 2,150 kcal and 160 g protein', () {
    final meals = {for (final m in loadTestCatalog().personalization.meals) m.id: m};
    ScaledMeal scale(String id) => scaleMeal(meals[id]!, calorieKcal: 2150, proteinG: 160);

    test('every meal has a role per component', () {
      for (final m in meals.values) {
        expect(m.componentRoles.length, m.components.length, reason: m.id);
      }
    });

    test('kenkey and fish: more fish, less kenkey, close to the dinner budget', () {
      final s = scale('kenkey_fish');
      expect(s.proteinFactor, greaterThan(1));
      expect(s.carbFactor, lessThan(1));
      expect(s.components.first, startsWith('½-¾ ball'));
      expect(s.kcal, closeTo(s.targetKcal, s.targetKcal * 0.15));
      expect(s.proteinG, closeTo(s.targetProteinG, 6));
    });

    test('every scaled meal lands near its share of the day', () {
      for (final m in meals.values) {
        final s = scale(m.id);
        expect(s.proteinFactor, inInclusiveRange(0.75, 2.0), reason: m.id);
        expect(s.carbFactor, inInclusiveRange(0.5, 1.5), reason: m.id);
        // Protein-only snacks (whey) can be well under the calorie share; nothing should overshoot.
        expect(s.kcal, lessThan(s.targetKcal * 1.3), reason: m.id);
      }
    });

    test('fats never get bigger', () {
      final s = scale('groundnut_soup_smart');
      expect(s.components.first, '¾ ladle groundnut soup');
    });

    test('a smaller person gets smaller protein portions', () {
      final small = scaleMeal(meals['kenkey_fish']!, calorieKcal: 1800, proteinG: 110);
      expect(small.proteinFactor, lessThan(scale('kenkey_fish').proteinFactor));
    });

    test('meals without roles are left as they are', () {
      final bare = meals['khebab']!.copyWith(componentRoles: const []);
      final s = scaleMeal(bare, calorieKcal: 2150, proteinG: 160);
      expect(s.isStandard, isTrue);
      expect(s.components, bare.components);
    });
  });

  test('meal shares add up to the day (3 meals + 1 snack)', () {
    expect(mealShare('breakfast') + mealShare('lunch') + mealShare('dinner') + mealShare('snack'), closeTo(1, 1e-9));
    expect(mealShare('lunch_or_dinner'), mealShare('lunch'));
    expect(const MealIdea(id: 'x', name: 'x', mealType: 'snack', proteinG: 1, kcalApprox: 1, costTier: 'low').mealType,
        'snack');
  });
}
