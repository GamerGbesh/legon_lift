import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/domain/food_calculator.dart';
import 'package:legon_lift/main.dart';
import 'package:legon_lift/state/food_calculator_store.dart';

import '../fakes/fakes.dart';

FoodDatabase loadFoods() => FoodDatabase.fromJson(
      (jsonDecode(File('assets/data/foods.json').readAsStringSync()) as Map).cast<String, dynamic>(),
    );

void main() {
  final db = loadFoods();

  group('foods.json', () {
    test('parses, every food has sane servings', () {
      expect(db.foods.length, greaterThan(100));
      for (final f in db.foods) {
        for (final s in f.servings) {
          expect(s.kcal, inInclusiveRange(0, 3000), reason: '${f.id} ${s.label}');
          expect(s.proteinG, inInclusiveRange(0, 150), reason: '${f.id} ${s.label}');
          // Protein can't supply more calories than the food has (4 kcal per gram).
          expect(s.proteinG * 4, lessThanOrEqualTo(s.kcal + 1), reason: '${f.id} ${s.label}');
        }
      }
    });

    test('has the pantry and campus foods', () {
      for (final id in [
        'sardines', 'tuna', 'corned_beef', 'sausage_tin', 'indomie', 'spaghetti', 'yam_boiled', 'rice_plain',
        'honey', 'gari', 'oats', 'stew_tomato', 'shito', 'milo', 'groundnuts', 'pizza', 'loaded_fries',
        'shawarma_chicken', 'waakye_plate', 'kelewele', 'bofrot', 'sobolo',
      ]) {
        expect(db.byId(id), isNotNull, reason: id);
      }
    });

    test('rejects duplicate ids and unknown categories', () {
      Map<String, dynamic> file(List<Map<String, dynamic>> foods) => {
            'categories': [
              {'id': 'a', 'label': 'A'},
            ],
            'foods': foods,
          };
      final egg = {
        'id': 'egg',
        'name': 'Egg',
        'cat': 'a',
        'servings': [
          {'label': '1', 'kcal': 75, 'p': 6},
        ],
      };
      expect(() => FoodDatabase.fromJson(file([egg, egg])), throwsFormatException);
      expect(() => FoodDatabase.fromJson(file([{...egg, 'cat': 'zzz'}])), throwsFormatException);
    });
  });

  group('search', () {
    test('finds by other names and is case-insensitive', () {
      expect(db.search('TALIA').map((f) => f.id), contains('spaghetti'));
      expect(db.search('puff puff').map((f) => f.id), contains('bofrot'));
      expect(db.search('pear').map((f) => f.id), contains('avocado'));
    });

    test('names starting with the query come first', () {
      expect(db.search('shawarma').take(2).map((f) => f.id), containsAll(['shawarma_chicken', 'shawarma_beef']));
      expect(db.search('waakye').first.id, startsWith('waakye'));
    });

    test('every word must match; category narrows', () {
      expect(db.search('chicken shawarma').single.id, 'shawarma_chicken');
      expect(db.search('', category: 'drinks').every((f) => f.category == 'drinks'), isTrue);
      expect(db.search('xyzzy'), isEmpty);
    });
  });

  group('totals and points', () {
    test('points round to the nearest half', () {
      expect(proteinPointsFor(31), 1.5);
      expect(proteinPointsFor(41), 2);
      expect(proteinPointsFor(4), 0);
    });

    test("the user's breakfast: 2 fried eggs, 1 sausage, 5 small slices, tea", () {
      CalcEntry e(String id, int serving, [double qty = 1]) {
        final f = db.byId(id)!;
        return CalcEntry.of(f, f.servings[serving], qty: qty);
      }

      final day = FoodCalcDay(date: '2026-11-22', entries: [
        e('egg_fried', 0, 2),
        e('sausage_tin', 0),
        e('bread_slice', 0, 5),
        e('tea_milk_honey', 0),
      ]);
      expect(day.kcal, 2 * 110 + 120 + 5 * 65 + 120);
      expect(day.proteinG, 12 + 5 + 10 + 4);
      expect(day.points, 1.5);
    });

    test('a day round-trips through JSON', () {
      const day = FoodCalcDay(
        date: '2026-11-22',
        loggedPoints: 1,
        entries: [CalcEntry(name: "Kofi's pie", serving: '1 serving', kcal: 410, proteinG: 9, qty: 2)],
      );
      final back = FoodCalcDay.fromJson(jsonDecode(jsonEncode(day.toJson())) as Map<String, dynamic>);
      expect(back.entries.single.foodId, isNull);
      expect(back.kcal, 820);
      expect(back.loggedPoints, 1);
    });

    test('recent keeps the newest first without duplicates', () {
      expect(pushRecent(['a', 'b', 'c'], 'b'), ['b', 'a', 'c']);
      expect(pushRecent(List.generate(8, (i) => '$i'), 'x').length, 8);
    });
  });

  group('FoodCalculatorStore', () {
    setUp(() => FoodCalculatorStore.debugDatabase = db);
    tearDown(() => FoodCalculatorStore.debugDatabase = null);

    Future<(FakeApp, AppStores, FoodCalculatorStore)> make() async {
      final app = FakeApp.seeded();
      final stores = await AppStores.create(app.deps);
      final calc = FoodCalculatorStore(settings: app.settings, nutrition: stores.nutrition, clock: app.clock);
      await calc.load();
      return (app, stores, calc);
    }

    test('logs only the points not yet logged, and takes them back after a removal', () async {
      final (_, stores, calc) = await make();
      final tuna = db.byId('tuna')!;
      final before = stores.nutrition.today.proteinPoints;

      await calc.add(CalcEntry.of(tuna, tuna.servings.first)); // 26 g -> 1.5 points
      expect(await calc.logPoints(), 1.5);
      expect(await calc.logPoints(), 0);
      expect(stores.nutrition.today.proteinPoints, before + 1.5);

      await calc.add(CalcEntry.of(tuna, tuna.servings.first)); // 52 g -> 2.5 points
      expect(await calc.logPoints(), 1);
      await calc.removeAt(0); // 26 g -> 1.5 points
      expect(calc.day.pointsToLog, -1);
      await calc.logPoints();
      expect(stores.nutrition.today.proteinPoints, before + 1.5);
    });

    test('the list survives a reload and resets the next day', () async {
      final (app, stores, calc) = await make();
      final egg = db.byId('egg_boiled')!;
      await calc.add(CalcEntry.of(egg, egg.servings.first, qty: 3));

      final again = FoodCalculatorStore(settings: app.settings, nutrition: stores.nutrition, clock: app.clock);
      await again.load();
      expect(again.day.entries.single.qty, 3);
      expect(again.recent, ['egg_boiled']);

      app.clock.advance(const Duration(days: 1));
      expect(again.day.entries, isEmpty);
    });
  });
}
