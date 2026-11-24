// Owner: WS4. The active program, its phase/week and per-slot overrides (SPEC 4.5, 6.7, 7.4).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import '../data/repositories/exercise_state_repository.dart';
import '../data/repositories/program_repository.dart';
import '../data/repositories/session_repository.dart';
import '../domain/api.dart';

/// One slot of a program day as the user sees it: the template item with the user's override
/// (replacement exercise, optional item switched on or off) applied.
@immutable
class DaySlot {
  const DaySlot({
    required this.blockIndex,
    required this.block,
    required this.item,
    required this.exerciseId,
    required this.enabled,
    required this.replaced,
  });

  final int blockIndex;
  final ProgramBlock block;

  /// The template item (its [ProgramItem.slotKey] identifies the slot).
  final ProgramItem item;

  /// The exercise done in this slot (the override's, or the template's).
  final String exerciseId;

  /// False for an optional item that is switched off.
  final bool enabled;

  /// True when "Replace in my program" changed the exercise.
  final bool replaced;

  String get slotKey => item.slotKey();
}

/// The active program, its phase/week and per-slot overrides.
///
/// Public API of SPEC 7.4 plus WS4 additions used by the Program tab: [days], [slotsFor],
/// [effectiveDay], [estimateMinutes], [swapOptions], [setOptionalEnabled], [createCustom],
/// [saveCustom], [completedSessions].
class ProgramStore extends ChangeNotifier {
  /// [states] gives swap suggestions the user's exercise history and "not at this gym" flags;
  /// without it suggestions ignore both.
  ProgramStore({
    required this._catalog,
    required this._programs,
    required this._sessions,
    this._states,
  }) {
    // A finished or deleted workout moves the rotation ("Next up") and the week: reload then.
    _sub = _sessions.changes.listen((_) {
      if (!_disposed) unawaited(load());
    });
  }

  StreamSubscription<void>? _sub;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  final AssetCatalog _catalog;
  final ProgramRepository _programs;
  final SessionRepository _sessions;
  final ExerciseStateRepository? _states;

  ActiveProgram? _active;
  List<ProgramOverride> _overrides = const [];
  int _completedNonDeload = 0;
  int _completedSessions = 0;

  ActiveProgram? get active => _active;

  ProgramTemplate? get template {
    final a = _active;
    if (a == null) return null;
    final custom = a.customTemplate;
    if (custom != null) return custom;
    final id = a.templateId;
    return id == null ? null : _catalog.template(id);
  }

  int get trainingWeek {
    final t = template;
    final a = _active;
    return t == null || a == null ? 1 : _trainingWeekFor(t, a, _completedNonDeload);
  }

  Phase? get phase {
    final t = template;
    return t == null || t.phases.isEmpty ? null : phaseFor(t, trainingWeek);
  }

  ProgramDay? get nextDay {
    final a = _active;
    if (a == null || a.dayOrder.isEmpty) return null;
    return phase?.day(a.nextDayId);
  }

  List<ProgramOverride> get overrides => _overrides;

  /// Number of completed non-deload sessions of the active program (drives the week).
  int get completedNonDeload => _completedNonDeload;

  /// Completed sessions of every program ("Start at Phase 2" needs 8).
  int get completedSessions => _completedSessions;

  /// The current phase's days in the user's rotation order.
  List<ProgramDay> get days {
    final a = _active;
    final p = phase;
    if (a == null || p == null) return const [];
    return [
      for (final id in a.dayOrder) ?p.day(id),
    ];
  }

  /// Reloads everything from the repositories.
  Future<void> load() async {
    _active = await _programs.active();
    final a = _active;
    _overrides = a == null ? const [] : await _programs.overrides(a.id);
    _completedNonDeload = a == null ? 0 : await _sessions.countCompleted(programId: a.id);
    _completedSessions = (await _sessions.listCompleted()).length;
    notifyListeners();
  }

  Future<void> switchTemplate(String id, {int startWeek = 1}) async {
    await _programs.activateTemplate(id, startWeek: startWeek);
    await load();
  }

  Future<void> setNextDay(int index) async {
    final a = _active;
    if (a == null || index < 0 || index >= a.dayOrder.length) return;
    await _programs.save(a.copyWith(nextDayIndex: index));
    await load();
  }

  /// New rotation order; the "next workout" pointer keeps pointing at the same day.
  Future<void> reorderDays(List<String> order) async {
    final a = _active;
    if (a == null || order.isEmpty) return;
    final next = a.nextDayId;
    final i = order.indexOf(next);
    await _programs.save(a.copyWith(dayOrder: order, nextDayIndex: i < 0 ? 0 : i));
    await load();
  }

  ProgramOverride? _overrideFor(String dayId, String slotKey) {
    for (final o in _overrides) {
      if (o.dayId == dayId && o.slotKey == slotKey) return o;
    }
    return null;
  }

  /// "Replace in my program": the slot uses [exId] in every phase. Keeps an optional item's on/off.
  Future<void> replaceInProgram(String dayId, String slotKey, String exId) async {
    final a = _active;
    if (a == null) return;
    final existing = _overrideFor(dayId, slotKey);
    await _programs.setOverride(ProgramOverride(
      programId: a.id,
      dayId: dayId,
      slotKey: slotKey,
      exerciseId: exId,
      optionalEnabled: existing?.optionalEnabled,
    ));
    await load();
  }

  /// Switches an optional item on or off for this program (keeps a replacement exercise).
  Future<void> setOptionalEnabled(String dayId, ProgramItem item, bool enabled) async {
    final a = _active;
    if (a == null) return;
    final slotKey = item.slotKey();
    final existing = _overrideFor(dayId, slotKey);
    await _programs.setOverride(ProgramOverride(
      programId: a.id,
      dayId: dayId,
      slotKey: slotKey,
      exerciseId: existing?.exerciseId ?? item.exerciseId,
      optionalEnabled: enabled,
    ));
    await load();
  }

  /// "Reset to template": removes the day's overrides.
  Future<void> resetDay(String dayId) async {
    final a = _active;
    if (a == null) return;
    await _programs.clearOverrides(a.id, dayId: dayId);
    await load();
  }

  Future<void> acceptReactiveDeload() async {
    final a = _active;
    final t = template;
    if (a == null || t == null) return;
    await _programs.save(a.copyWith(reactiveDeloadRemaining: t.daysPerWeek));
    await load();
  }

  /// Creates [custom] as a new active program (history is kept; weights carry over per exercise).
  Future<void> createCustom(ProgramTemplate custom) async {
    await _programs.createCustom(custom);
    await load();
  }

  /// Saves an edited custom program in place (same program id, so its sessions stay linked).
  Future<void> saveCustom(ProgramTemplate custom) async {
    final a = _active;
    if (a == null || !a.isCustom) return;
    final next = a.dayOrder.isEmpty ? null : a.nextDayId;
    // Keep the user's rotation order (reorderDays only changes the active program); new days go
    // at the end, removed days drop out.
    final ids = {for (final d in custom.phases.first.days) d.dayId};
    final order = [
      for (final id in a.dayOrder)
        if (ids.contains(id)) id,
      for (final id in custom.dayOrder)
        if (!a.dayOrder.contains(id) && ids.contains(id)) id,
    ];
    final i = next == null ? 0 : order.indexOf(next);
    final saved = custom.copyWith(dayOrder: order);
    await _programs.save(a.copyWith(
      customTemplate: () => saved,
      name: custom.name,
      dayOrder: order,
      nextDayIndex: i < 0 ? 0 : i,
    ));
    await load();
  }

  /// The day's slots for the current phase with overrides applied (empty for an unknown day).
  List<DaySlot> slotsFor(String dayId) {
    final day = phase?.day(dayId);
    if (day == null) return const [];
    return [
      for (final (bi, block) in day.blocks.indexed)
        for (final item in block.items) _slot(dayId, bi, block, item),
    ];
  }

  DaySlot _slot(String dayId, int blockIndex, ProgramBlock block, ProgramItem item) {
    final o = _overrideFor(dayId, item.slotKey());
    final exId = o?.exerciseId ?? item.exerciseId;
    final optional = item.optional || block.optional;
    return DaySlot(
      blockIndex: blockIndex,
      block: block,
      item: item,
      exerciseId: _catalog.tryExercise(exId) == null ? item.exerciseId : exId,
      enabled: !optional || (o?.optionalEnabled ?? autoIncluded(block, item)),
      replaced: exId != item.exerciseId,
    );
  }

  /// Optional items the session builder adds by itself unless switched off: the cardio finisher
  /// (from week 2, when it fits the time) and the cool-down stretches. Optional main-lift extras
  /// are off until switched on.
  static bool autoIncluded(ProgramBlock block, ProgramItem item) =>
      block.blockType == BlockType.finisher || block.blockType == BlockType.cooldown;

  /// [day] as it will be trained: replacements applied, optional items switched off removed and
  /// optional items switched on kept as regular items. Used for time estimates.
  ProgramDay effectiveDay(ProgramDay day) {
    final blocks = <ProgramBlock>[];
    for (final (bi, block) in day.blocks.indexed) {
      final items = <ProgramItem>[];
      for (final item in block.items) {
        final s = _slot(day.dayId, bi, block, item);
        if (!s.enabled) continue;
        final optional = item.optional || block.optional;
        final o = _overrideFor(day.dayId, item.slotKey());
        items.add(item.copyWith(
          exerciseId: s.exerciseId,
          optional: optional && o?.optionalEnabled == true ? false : item.optional,
        ));
      }
      if (items.isNotEmpty) blocks.add(block.copyWith(items: items));
    }
    return day.copyWith(blocks: blocks);
  }

  /// Minutes the day takes as built for a [sessionMinutes] budget: the core, plus the finisher
  /// after week 1 and the switched-on extras while they fit (SPEC 6.8, 6.10).
  int estimateMinutes(ProgramDay day, {required int sessionMinutes}) {
    final d = effectiveDay(day);
    final week = trainingWeek;
    final core = estimateSeconds(d);
    final budget = sessionMinutes * 60;
    var total = core;
    final isDeload = phase?.phaseId == PhaseId.deload;
    if (week > 1 && !isDeload) {
      final withFinisher = estimateSeconds(d, includeFinisher: true);
      if (withFinisher <= budget) total = withFinisher;
    }
    final withAll = estimateSeconds(d, includeOptional: true, includeFinisher: total > core);
    if (withAll <= budget && withAll > total) total = withAll;
    return (total / 60).round();
  }

  /// Up to 4 alternatives for a slot (SPEC 6.9), excluding the day's other exercises.
  Future<List<SwapOption>> swapOptions(String dayId, DaySlot slot, EquipmentProfile eq, {bool smithEarly = false}) async {
    final p = phase;
    final ex = _catalog.tryExercise(slot.exerciseId);
    if (p == null || ex == null) return const [];
    final dayIds = {for (final s in slotsFor(dayId)) s.exerciseId}..remove(slot.exerciseId);
    final states = _states;
    final prefs = states == null ? const <String, ExercisePrefs>{} : await states.allPrefs();
    final history = states == null
        ? const <String, ExerciseState>{}
        : await states.getAll(_catalog.exercises.map((e) => e.id));
    return suggestSwaps(ex, slot.item, _catalog, eq, p, dayIds, prefs, history, smithEarly: smithEarly);
  }
}

/// The domain [trainingWeek] (the getter of the same name shadows it inside the class).
int _trainingWeekFor(ProgramTemplate t, ActiveProgram a, int completedNonDeload) =>
    trainingWeek(t, a, completedNonDeload);
