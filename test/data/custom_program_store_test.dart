import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/assets/asset_catalog.dart';
import 'package:legon_lift/features/program/custom_program.dart';
import 'package:legon_lift/state/program_store.dart';

import '../fakes/fakes.dart';

/// Editing a custom program from the Program tab: reordering, adding, renaming and removing days.
void main() {
  late AssetCatalog catalog;

  Future<ProgramStore> customStore() async {
    final app = FakeApp();
    catalog = app.catalog;
    final store = ProgramStore(catalog: app.catalog, programs: app.programs, sessions: app.sessions);
    await store.load();
    await store.createCustom(CustomPrograms.blank(app.catalog));
    return store;
  }

  test('an edit keeps the order the days were dragged into', () async {
    final store = await customStore();
    final ids = [for (final d in store.days) d.dayId];
    await store.reorderDays(ids.reversed.toList());

    final first = store.days.first;
    await store.saveCustom(CustomPrograms.replaceDay(store.template!, first.copyWith(name: 'Arms'), catalog));

    expect([for (final d in store.days) d.dayId], ids.reversed.toList());
    expect(store.days.first.name, 'Arms');
  });

  test('adding a day puts it last; removing one keeps the rest in order', () async {
    final store = await customStore();
    final before = [for (final d in store.days) d.dayId];
    await store.saveCustom(CustomPrograms.addDay(store.template!, catalog, name: 'Cardio and abs'));
    expect(store.days, hasLength(4));
    expect(store.days.last.name, 'Cardio and abs');

    await store.saveCustom(CustomPrograms.removeDay(store.template!, before[1]));
    expect([for (final d in store.days) d.dayId], [before[0], before[2], store.days.last.dayId]);
    expect(store.template!.daysPerWeek, 3);
  });

  test('removing the next day moves "next" to the first day', () async {
    final store = await customStore();
    await store.setNextDay(1);
    final next = store.nextDay!.dayId;
    await store.saveCustom(CustomPrograms.removeDay(store.template!, next));
    expect(store.nextDay!.dayId, store.days.first.dayId);
  });
}
