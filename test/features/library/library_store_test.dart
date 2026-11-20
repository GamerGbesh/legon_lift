import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/state/library_store.dart';
import 'package:legon_lift/state/settings_store.dart';
import 'package:legon_lift/state/types.dart';

import '../../fakes/fakes.dart';

void main() {
  late FakeApp app;
  late SettingsStore settings;
  late LibraryStore store;

  setUp(() async {
    app = FakeApp.seeded();
    settings = await SettingsStore.load(app.settings);
    store = LibraryStore(catalog: app.catalog, states: app.exerciseStates, settings: settings);
    await store.load();
  });

  tearDown(() => store.dispose());

  List<String> ids() => [for (final e in store.results) e.id];

  group('search', () {
    test('folds case, accents and punctuation', () {
      expect(foldForSearch('  CHÉST-Préss!  '), 'chest press');
      expect(searchTokens('Lat  pull-down'), ['lat', 'pull', 'down']);
    });

    test('matches names and aliases by word prefix, accent-insensitive', () {
      store.setQuery(const LibraryQuery(text: 'CHÉST préss', beginnerOnly: false));
      expect(ids(), contains('machine_chest_press'));
      expect(ids().first, 'machine_chest_press', reason: 'name starting with the query ranks first');

      store.setQuery(const LibraryQuery(text: 'db bench', beginnerOnly: false));
      expect(ids(), contains('dumbbell_bench_press'), reason: 'alias "DB Bench Press"');

      store.setQuery(const LibraryQuery(text: 'zzzz', beginnerOnly: false));
      expect(store.results, isEmpty);
    });
  });

  group('filters', () {
    test('"Beginner friendly" is on by default and keeps difficulty 1 only', () {
      expect(store.query.beginnerOnly, isTrue);
      expect(store.results, isNotEmpty);
      expect(store.results.every((e) => e.difficulty == 1), isTrue);
    });

    test('muscle groups match any primary muscle of the group', () {
      store.setQuery(const LibraryQuery(muscles: {Muscle.lats, Muscle.upperBack}, beginnerOnly: false));
      expect(store.results, isNotEmpty);
      expect(
        store.results.every((e) => e.primaryMuscles.any({Muscle.lats, Muscle.upperBack}.contains)),
        isTrue,
      );
    });

    test('Mobility chip lists stretches and drills, not warm-up cardio', () {
      store
        ..setQuery(const LibraryQuery(beginnerOnly: false))
        ..setMobility(true);
      expect(ids(), containsAll(['cat_cow', 'childs_pose']));
      expect(ids(), isNot(contains('general_warmup_cardio')));
      expect(ids(), isNot(contains('machine_chest_press')));
    });

    test('equipment chips keep exercises using any selected item', () {
      store.setQuery(const LibraryQuery(equipment: {Equipment.cable}, beginnerOnly: false));
      expect(store.results, isNotEmpty);
      expect(store.results.every((e) => e.equipment.contains(Equipment.cable)), isTrue);
    });

    test('only ticked equipment unless "Show all" is on', () {
      expect(settings.settings.equipment.available, isNot(contains(Equipment.ankleStrap)));
      store.setQuery(const LibraryQuery(beginnerOnly: false));
      expect(ids(), isNot(contains('cable_glute_kickback')));
      expect(ids(), isNot(contains('barbell_bench_press')), reason: 'needs uprights or a spotter');

      store.setQuery(const LibraryQuery(beginnerOnly: false, showAllEquipment: true));
      expect(ids(), containsAll(['cable_glute_kickback', 'barbell_bench_press']));
    });

    test('settings changes refresh the results', () async {
      store.setQuery(const LibraryQuery(beginnerOnly: false));
      expect(ids(), contains('machine_chest_press'));
      final eq = settings.settings.equipment;
      await settings.update(settings.settings
          .copyWith(equipment: eq.copyWith(available: {...eq.available}..remove(Equipment.chestPressMachine))));
      expect(ids(), isNot(contains('machine_chest_press')));
    });

    test('clearFilters goes back to the defaults', () {
      store
        ..setQuery(const LibraryQuery(text: 'press', favoritesOnly: true, beginnerOnly: false))
        ..setMobility(true)
        ..clearFilters();
      expect(store.query, LibraryQuery.initial);
      expect(store.mobility, isFalse);
    });
  });

  group('availability (SPEC 2.1)', () {
    test('bike + treadmill on a cardio entry means either one', () {
      final cardio = app.catalog.exercise('general_warmup_cardio');
      final eq = settings.settings.equipment;
      expect(exerciseAvailable(cardio, eq.copyWith(available: {...eq.available}..remove(Equipment.bike))), isTrue);
      expect(
        exerciseAvailable(cardio, eq.copyWith(available: {...eq.available}..removeAll([Equipment.bike, Equipment.treadmill]))),
        isFalse,
      );
    });

    test('bench press needs the uprights flag', () {
      final bench = app.catalog.exercise('barbell_bench_press');
      final eq = settings.settings.equipment;
      expect(exerciseAvailable(bench, eq), isFalse);
      expect(exerciseAvailable(bench, eq.copyWith(hasBenchUprights: true)), isTrue);
    });
  });

  group('favourites and notes', () {
    test('toggleFavorite persists and favoritesOnly filters', () async {
      await store.toggleFavorite('machine_chest_press');
      expect(store.isFavorite('machine_chest_press'), isTrue);
      expect(app.exerciseStates.prefRows['machine_chest_press']?.favorite, isTrue);

      store.setQuery(const LibraryQuery(favoritesOnly: true, beginnerOnly: false));
      expect(ids(), ['machine_chest_press']);

      await store.toggleFavorite('machine_chest_press');
      expect(store.results, isEmpty);
    });

    test('machine note is trimmed, and blank clears it', () async {
      await store.setMachineNote('leg_press', '  Seat on 4  ');
      expect(store.prefsFor('leg_press').machineNote, 'Seat on 4');
      expect(app.exerciseStates.prefRows['leg_press']?.machineNote, 'Seat on 4');
      await store.setMachineNote('leg_press', '   ');
      expect(store.prefsFor('leg_press').machineNote, isNull);
    });
  });
}
