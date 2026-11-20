// Owner: WS4. Building and editing custom programs (SPEC 4.5): "Custom from blank",
// "Custom from PPL" and the edits of the custom day editor. Pure functions over the models.
import '../../core/ids.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';

abstract final class CustomPrograms {
  /// The template custom programs start from ("pre-filled from ppl_3day Phase 1").
  static const String baseTemplateId = 'ppl_3day';

  /// Wraps [days] as a custom program: no fixed length, one `custom` phase with every unlock.
  static ProgramTemplate wrap({required String name, required List<ProgramDay> days, String? programId}) =>
      ProgramTemplate(
        programId: programId ?? 'custom_${newId()}',
        name: name,
        splitType: 'custom',
        splitKey: SplitKey.custom,
        daysPerWeek: days.length,
        dayOrder: [for (final d in days) d.dayId],
        description: 'Your own program.',
        recommendedWeekdays: _spread(days.length),
        phases: [
          Phase(phaseId: PhaseId.custom, name: 'Custom', weeks: const [1], unlocks: Phase.allUnlocks, days: days),
        ],
      );

  /// A copy of [template]'s first phase that the user can edit.
  static ProgramTemplate fromTemplate(ProgramTemplate template, {String? name}) => wrap(
        name: name ?? 'My ${_short(template.name)}',
        days: template.phases.first.days,
      );

  /// [count] empty days (A, B, C ...) with the standard warm-up and cool-down of the base
  /// template's Push day, ready for exercises from the Library.
  static ProgramTemplate blank(AssetCatalog catalog, {int count = 3}) {
    final n = count.clamp(1, 6);
    final days = <ProgramDay>[];
    for (var i = 0; i < n; i++) {
      days.add(newDay(catalog, name: 'Day ${String.fromCharCode(65 + i)}', taken: {for (final d in days) d.dayId}));
    }
    return wrap(name: 'My program', days: days);
  }

  /// A new day with warm-up and cool-down blocks and an empty main block.
  static ProgramDay newDay(AssetCatalog catalog, {required String name, required Set<String> taken}) {
    final base = catalog.template(baseTemplateId).phases.first.days.first;
    final warmup = base.blocks.where((b) => b.blockType == BlockType.warmup).toList();
    final cooldown = base.blocks.where((b) => b.blockType == BlockType.cooldown).toList();
    var i = 1;
    while (taken.contains('day_$i')) {
      i++;
    }
    return ProgramDay(
      dayId: 'day_$i',
      name: name,
      focus: const [],
      notes: '',
      estimatedMinutes: const EstimatedMinutes(core: 0, withOptionalExercises: 0, withFinisher: 0),
      blocks: [
        ...warmup,
        const ProgramBlock(blockType: BlockType.main, name: 'Main', items: []),
        ...cooldown,
      ],
    );
  }

  /// A program item for [ex] with the exercise's own defaults.
  static ProgramItem itemFor(Exercise ex) {
    final timed = ex.tracking == Tracking.time;
    final compound = ex.mechanic == Mechanic.compound;
    return ProgramItem(
      exerciseId: ex.id,
      sets: ex.defaultSets < 1 ? 3 : ex.defaultSets,
      repRange: timed ? null : (ex.repRange ?? (8, 12)),
      durationSeconds: timed ? (ex.durationSeconds ?? 30) : null,
      rir: timed ? null : 2,
      restSeconds: ex.restSeconds > 0 ? ex.restSeconds : (compound ? 120 : 75),
      role: ex.category == ExerciseCategory.core
          ? ItemRole.core
          : (compound ? ItemRole.secondary : ItemRole.accessory),
      warmupSets: compound && ex.isLoaded ? 1 : 0,
      perSide: ex.unilateral,
      substitutions: ex.substitutions,
    );
  }

  /// Replaces the day [dayId] in [t] (a custom program) with [day]. Focus muscles are derived
  /// from the main exercises.
  static ProgramTemplate replaceDay(ProgramTemplate t, ProgramDay day, AssetCatalog catalog) {
    final withFocus = day.copyWith(focus: focusOf(day, catalog));
    final phase = t.phases.first;
    final days = [for (final d in phase.days) d.dayId == day.dayId ? withFocus : d];
    return t.copyWith(phases: [phase.copyWith(days: days)]);
  }

  /// Adds a new day at the end of the rotation.
  static ProgramTemplate addDay(ProgramTemplate t, AssetCatalog catalog, {required String name}) {
    final phase = t.phases.first;
    final day = newDay(catalog, name: name, taken: {for (final d in phase.days) d.dayId});
    final days = [...phase.days, day];
    return t.copyWith(
      phases: [phase.copyWith(days: days)],
      dayOrder: [...t.dayOrder, day.dayId],
      daysPerWeek: days.length,
    );
  }

  /// Removes a day (a program keeps at least one).
  static ProgramTemplate removeDay(ProgramTemplate t, String dayId) {
    final phase = t.phases.first;
    if (phase.days.length <= 1) return t;
    final days = [for (final d in phase.days) if (d.dayId != dayId) d];
    return t.copyWith(
      phases: [phase.copyWith(days: days)],
      dayOrder: [for (final id in t.dayOrder) if (id != dayId) id],
      daysPerWeek: days.length,
    );
  }

  /// Up to 4 distinct primary muscles of the day's main and superset items.
  static List<String> focusOf(ProgramDay day, AssetCatalog catalog) {
    final out = <String>[];
    for (final b in day.blocks) {
      if (b.blockType != BlockType.main && b.blockType != BlockType.superset) continue;
      for (final item in b.items) {
        for (final m in catalog.tryExercise(item.exerciseId)?.primaryMuscles ?? const <Muscle>[]) {
          if (!out.contains(m.wire)) out.add(m.wire);
        }
      }
    }
    return out.take(4).toList();
  }

  /// "Push / Pull / Legs - 3 days" -> "Push / Pull / Legs".
  static String _short(String name) {
    final i = name.indexOf(' - ');
    return i > 0 ? name.substring(0, i) : name;
  }

  static List<int> _spread(int days) => switch (days) {
        1 => const [3],
        2 => const [2, 5],
        3 => const [1, 3, 5],
        4 => const [1, 2, 4, 5],
        5 => const [1, 2, 3, 4, 5],
        _ => const [1, 2, 3, 4, 5, 6],
      };

  /// Default workout weekdays for [days] per week.
  static List<int> defaultWeekdays(int days) => _spread(days);
}
