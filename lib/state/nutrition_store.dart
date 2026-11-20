// Owner: WS6. Nutrition helper state (SPEC 4.9, 10.1, 10.2).
import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../core/ids.dart';
import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import '../data/repositories/body_repository.dart';
import '../data/repositories/exercise_state_repository.dart';
import '../data/repositories/nutrition_repository.dart';
import '../domain/api.dart';
import 'profile_store.dart';

/// Nutrition targets, today's checklist and the weekly check-in (SPEC 4.9).
///
/// Public API of SPEC 7.4 ([targets], [today], [addProtein], [addWater], [setCheck]) plus WS6
/// additions for the Food screen: [load], [baseTargets], [targetsWeightKg], [isTrainingDay],
/// [waterTargetMl], [isGoodDay], [checkin], [lastWeekChange], [adjustments], [applyCheckin],
/// [setSteps].
class NutritionStore extends ChangeNotifier {
  /// [states] (optional) supplies the strength anchor lifts to the check-in's "recomp" and
  /// "fatigued" rules; without it those two rules never fire.
  NutritionStore({
    required this._nutrition,
    required this._body,
    required this._catalog,
    required this._profile,
    required this._clock,
    this._states,
  }) : _today = NutritionDay.empty(Fmt.dateKey(_clock.now())) {
    _profile.addListener(_recompute);
  }

  final NutritionRepository _nutrition;
  final BodyRepository _body;
  final AssetCatalog _catalog;
  final ProfileStore _profile;
  final Clock _clock;
  final ExerciseStateRepository? _states;

  NutritionDay _today;
  List<BodyEntry> _bodyEntries = const [];
  List<NutritionDay> _days = const [];
  List<CalorieAdjustment> _adjustments = const [];
  Map<String, ExerciseState> _anchorStates = const {};
  bool _disposed = false;

  NutritionTargets? _base;
  NutritionTargets? _targets;
  ({double kg, String? date, bool fromAverage})? _weight;
  CheckinAdvice? _checkin;
  ({double lossPct, double kg, int week})? _lastWeekChange;

  Personalization get _p => _catalog.personalization;

  UserProfile get _user => _profile.profile ?? UserProfile.defaults(_clock.now());

  /// Targets the user sees: the formula targets (from [targetsWeightKg]) plus applied check-in
  /// changes, with the step progression.
  NutritionTargets get targets => _targets ?? nutritionTargets(_user, _p);

  /// Formula-only targets, before check-in changes and step progression.
  NutritionTargets get baseTargets => _base ?? nutritionTargets(_user, _p);

  NutritionDay get today => _today;

  /// Weight the targets use (7-day average at the last recalculation, else the profile weight).
  double get targetsWeightKg => _weight?.kg ?? _user.weightKg;

  /// Date of the 7-day average the targets use; null while they use the profile weight.
  String? get targetsWeightDate => _weight?.date;

  /// Sum of applied check-in calorie changes.
  int get calorieAdjustmentKcal => targets.calorieTargetKcal - baseTargets.calorieTargetKcal;

  List<CalorieAdjustment> get adjustments => _adjustments;

  /// Today is one of the user's workout weekdays (training-day water target).
  bool get isTrainingDay => _user.workoutWeekdays.contains(_clock.now().weekday);

  int get waterTargetMl => isTrainingDay ? targets.waterTrainingMl : targets.waterRestMl;

  double get waterTargetSachets => sachetsFor(waterTargetMl);

  /// `good_day_rule` for today.
  bool get isGoodDay => isGoodNutritionDay(_today, targets, trainingDay: isTrainingDay);

  /// Non-protein checklist items met today (of 5).
  int get otherItemsMet => checklistItemsMet(_today, targets, trainingDay: isTrainingDay);

  /// The current weekly check-in (SPEC 10.2).
  CheckinAdvice get checkin => _checkin ?? const CheckinAdvice(ruleId: CheckinRuleIds.notEnoughData, message: '');

  /// Latest weekly change of the averaged weight (null until there are 2 usable weeks).
  ({double lossPct, double kg, int week})? get lastWeekChange => _lastWeekChange;

  /// Reads today's checklist, the body and checklist history and the adjustments, then
  /// recomputes targets and the check-in.
  Future<void> load() async {
    final now = _clock.now();
    final todayKey = Fmt.dateKey(now);
    _today = await _nutrition.day(todayKey);
    _bodyEntries = await _body.range('0000-01-01', todayKey);
    _days = await _nutrition.range('0000-01-01', todayKey);
    _adjustments = await _nutrition.adjustments();
    final states = _states;
    _anchorStates = states == null ? const {} : await states.getAll(_anchorIds());
    _recompute();
  }

  /// Exercise ids of `progress_tracking.strength_anchor_lifts`.
  Set<String> _anchorIds() {
    final pt = _p.raw['progress_tracking'];
    final anchors = pt is Map ? pt['strength_anchor_lifts'] : null;
    return {
      if (anchors is List)
        for (final a in anchors)
          if (a is Map && a['exercise_any'] is List)
            for (final id in a['exercise_any'] as List)
              if (id is String) id,
    };
  }

  void _recompute() {
    final u = _user;
    final now = _clock.now();
    final weight = targetsWeightFor(u, _bodyEntries, now, _p);
    final base = nutritionTargets(u, _p, currentWeightKg: weight.kg);
    final floor = calorieFloorKcal(u.sex, base.bmrKcal, _p);
    final steps = stepsTargetFor(base.stepsTarget, _days, u.createdAt, now, _p);
    _weight = weight;
    _base = base;
    _targets = adjustedTargets(base, _adjustments, floorKcal: floor, stepsTarget: steps);
    final input = CheckinInput(
      body: _bodyEntries,
      nutrition: _days,
      adjustments: _adjustments,
      anchorStates: _anchorStates,
      profile: u,
      p: _p,
      now: now,
    );
    _checkin = weeklyCheckin(input);
    _lastWeekChange = latestWeeklyChange(input);
    if (!_disposed) notifyListeners();
  }

  /// Moves [_today] to the current date when the app stayed open past midnight.
  Future<void> _rollover() async {
    final key = Fmt.dateKey(_clock.now());
    if (_today.date != key) {
      _today = await _nutrition.day(key);
    }
  }

  Future<void> _save(NutritionDay Function(NutritionDay) change) async {
    await _rollover();
    final d = change(_today);
    await _nutrition.save(d);
    _today = d;
    _days = [for (final x in _days) if (x.date != d.date) x, d]..sort((a, b) => a.date.compareTo(b.date));
    if (!_disposed) notifyListeners();
  }

  /// Adds (or with a negative value removes) protein points, in 0.5 steps, never below 0.
  Future<void> addProtein(double points) =>
      _save((t) => t.copyWith(proteinPoints: _half((t.proteinPoints + points).clamp(0, 99).toDouble())));

  /// Adds (or removes) 500 ml water sachets, never below 0.
  Future<void> addWater(double sachets) =>
      _save((t) => t.copyWith(waterSachets: _half((t.waterSachets + sachets).clamp(0, 99).toDouble())));

  /// Sets a yes/no checklist item: `veg_fruit`, `steps`, `sleep`, `no_sugary_drinks`.
  Future<void> setCheck(String id, bool v) => _save((t) => switch (id) {
        'veg_fruit' => t.copyWith(vegFruit: v),
        'steps' => t.copyWith(stepsHit: v),
        'sleep' => t.copyWith(sleepOk: v),
        'no_sugary_drinks' => t.copyWith(noSugaryDrinks: v),
        _ => throw ArgumentError.value(id, 'id', 'Unknown checklist item'),
      });

  /// Saves today's optional step count; reaching the step target ticks "Step target reached".
  Future<void> setSteps(int? steps) => _save((t) => t.copyWith(
        steps: () => steps,
        stepsHit: steps != null && steps >= targets.stepsTarget ? true : null,
      ));

  /// "Apply" on the weekly check-in: stores a `calorie_adjustments` row and recomputes targets.
  Future<void> applyCheckin(CheckinAdvice advice) async {
    if (!advice.canApply) return;
    await _nutrition.addCalorieAdjustment(CalorieAdjustment(
      id: newId(),
      date: Fmt.dateKey(_clock.now()),
      ruleId: advice.ruleId,
      deltaKcal: advice.deltaKcal,
      deltaSteps: advice.deltaSteps == 0 ? null : advice.deltaSteps,
    ));
    _adjustments = await _nutrition.adjustments();
    _recompute();
  }

  static double _half(double v) => (v * 2).round() / 2;

  @override
  void dispose() {
    _disposed = true;
    _profile.removeListener(_recompute);
    super.dispose();
  }
}
