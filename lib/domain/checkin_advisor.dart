// Owner: WS6. Weekly calorie check-in (SPEC 10.2), driven by
// `personalization.progress_tracking.weekly_check_in`.
//
// Weeks are 7-day blocks counted from the day the profile was created (week 1 = the first 7
// days). Only complete weeks are judged. A week's weight is the mean of its weigh-ins and needs
// at least 3 of them. Week 1 is never used (water and glycogen loss), so the first weekly rate is
// week 2 -> week 3; once 3 weeks of averages exist the rate compares overlapping 2-week means.
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// Rule ids that are not in the data file.
abstract final class CheckinRuleIds {
  /// Fewer than 2 usable weekly averages (always the case in weeks 1-2).
  static const notEnoughData = 'not_enough_data';

  /// No rule matched this week.
  static const keepGoing = 'keep_going';

  /// The check-in only adjusts calories for fat loss and recomp goals.
  static const notForGoal = 'not_for_goal';
}

/// True on the day the Today card shows the check-in: the first workout weekday of the week
/// (Monday if no days are set), from week 3 on.
bool checkinDue(UserProfile u, DateTime now) {
  final first = u.workoutWeekdays.isEmpty ? DateTime.monday : u.workoutWeekdays.reduce(math.min);
  return now.weekday == first && _weekIndex(u.createdAt, now) >= 3;
}

/// The latest weekly change of the averaged weight, for display: `lossPct` > 0 means weight went
/// down. Null until two usable weeks exist.
({double lossPct, double kg, int week})? latestWeeklyChange(CheckinInput input) {
  final h = _History(input);
  final n = h.completeWeeks;
  final r = h.rate(n);
  if (r == null) return null;
  final now = h.avg[n]!;
  final before = h.avg[n - 1]!;
  return (lossPct: r, kg: before - now, week: n);
}

/// The weekly check-in (SPEC 10.2): evaluates `weekly_check_in.rules` in order with their
/// `consecutive` counts, then applies the guards (max 200 kcal per change, >= 2 weeks between
/// changes, never below the calorie floor).
CheckinAdvice weeklyCheckin(CheckinInput input) {
  final u = input.profile;
  if (u.goal != Goal.recomp && u.goal != Goal.fatLoss) {
    return const CheckinAdvice(
      ruleId: CheckinRuleIds.notForGoal,
      message: 'Your goal is not weight loss, so the weekly check-in does not change your calories. '
          'Keep eating close to your target and training hard.',
    );
  }
  final h = _History(input);
  final n = h.completeWeeks;
  if (h.rate(n) == null) {
    return CheckinAdvice(
      ruleId: CheckinRuleIds.notEnoughData,
      message: n < 3
          ? 'Weeks 1 and 2 are mostly water weight, so nothing changes yet. Keep weighing in: '
              'your first check-in comes after week 3.'
          : 'We need at least 3 weigh-ins in each of the last two weeks. Keep weighing in.',
    );
  }

  for (final rule in h.rules) {
    final id = rule['id'];
    if (id is! String) continue;
    final consecutive = (rule['consecutive'] as num?)?.toInt() ?? 1;
    var all = true;
    for (var k = 0; k < consecutive && all; k++) {
      all = h.condition(id, n - k) ?? false;
    }
    if (!all) continue;
    return _advice(h, id, rule, consecutive);
  }
  return const CheckinAdvice(
    ruleId: CheckinRuleIds.keepGoing,
    message: 'No change this week. Keep weighing in, hit your protein points and train.',
  );
}

CheckinAdvice _advice(_History h, String id, Map<String, dynamic> rule, int consecutive) {
  final message = rule['message'] is String ? rule['message'] as String : '';
  final action = rule['action'];
  var deltaKcal = 0;
  var deltaSteps = 0;
  final notes = <String>[];

  if (action is Map) {
    final a = action.cast<String, Object?>();
    final needsAdherence = a['first'] == 'adherence_check';
    final weak = needsAdherence ? h.weakAdherence() : null;
    if (weak != null) {
      notes.add(weak);
    } else {
      final options = <Map<String, Object?>>[
        if (a['then_one_of'] is List)
          for (final o in a['then_one_of'] as List)
            if (o is Map) o.cast<String, Object?>(),
        if (a['then'] is Map) (a['then'] as Map).cast<String, Object?>(),
        if (!needsAdherence) a,
      ];
      for (final o in options) {
        final (kcal, steps) = h.feasible(o, consecutive);
        if (kcal != 0 || steps != 0) {
          deltaKcal = kcal;
          deltaSteps = steps;
          break;
        }
      }
    }
  }

  final hasChange = deltaKcal != 0 || deltaSteps != 0;
  final lastChange = h.lastAdjustmentDay;
  final tooSoon = lastChange != null && h.today - lastChange < h.minWeeksBetween * 7;
  if (hasChange && tooSoon) {
    notes.add('Your targets changed less than ${h.minWeeksBetween} weeks ago, so we wait before changing them again.');
  }
  return CheckinAdvice(
    ruleId: id,
    message: [message, ...notes].where((s) => s.isNotEmpty).join(' '),
    deltaKcal: deltaKcal,
    deltaSteps: deltaSteps,
    canApply: hasChange && !tooSoon,
  );
}

/// Weekly history derived once from the inputs.
class _History {
  _History(this.input) {
    final cfg = input.p.raw['progress_tracking'];
    final wc = cfg is Map ? cfg['weekly_check_in'] : null;
    final weekly = wc is Map ? wc.cast<String, dynamic>() : const <String, dynamic>{};
    rules = [
      for (final r in (weekly['rules'] is List ? weekly['rules'] as List : const <Object?>[]))
        if (r is Map) r.cast<String, dynamic>(),
    ];
    final guards = weekly['guards'] is Map ? (weekly['guards'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    maxKcalChange = (guards['max_kcal_change_per_adjustment'] as num?)?.toInt() ?? 200;
    minWeeksBetween = (guards['min_weeks_between_adjustments'] as num?)?.toInt() ?? 2;
    neverBelowFloor = guards['never_below_floor'] != false;

    startDay = _dayNumber(input.profile.createdAt);
    today = _dayNumber(input.now);
    completeWeeks = (today - startDay) ~/ 7;

    final weights = <int, List<double>>{};
    final waists = <(int, double)>[];
    for (final e in input.body) {
      final day = _dayNumberOfKey(e.date);
      if (day >= today) continue;
      final week = _weekOf(day);
      if (e.weightKg != null && week >= 2) (weights[week] ??= []).add(e.weightKg!);
      if (e.waistCm != null) waists.add((day, e.waistCm!));
    }
    final startWaist = input.profile.startWaistCm;
    if (startWaist != null) waists.add((startDay, startWaist));
    waists.sort((a, b) => a.$1.compareTo(b.$1));
    _waists = waists;
    for (final MapEntry(key: week, value: w) in weights.entries) {
      if (w.length >= 3) avg[week] = w.reduce((a, b) => a + b) / w.length;
    }
  }

  final CheckinInput input;
  late final List<Map<String, dynamic>> rules;
  late final int maxKcalChange, minWeeksBetween;
  late final bool neverBelowFloor;
  late final int startDay, today, completeWeeks;
  final Map<int, double> avg = {};
  late final List<(int, double)> _waists;

  int _weekOf(int day) => (day - startDay) ~/ 7 + 1;

  /// Last day (inclusive) of week [n].
  int _weekEnd(int n) => startDay + 7 * n - 1;

  /// Weekly loss in % of body weight for week [n] (> 0 = loss); null when not computable.
  double? rate(int n) {
    if (n < 3) return null;
    final a0 = avg[n], a1 = avg[n - 1];
    if (a0 == null || a1 == null) return null;
    final a2 = n - 2 >= 2 ? avg[n - 2] : null;
    if (a2 == null) return (a1 - a0) / a1 * 100;
    final before = (a2 + a1) / 2;
    final after = (a1 + a0) / 2;
    return (before - after) / before * 100;
  }

  /// Latest waist reading at or before the end of week [n] (week 0 = the start).
  double? _waistAt(int n) {
    final end = n <= 0 ? startDay : _weekEnd(n);
    double? out;
    for (final (day, cm) in _waists) {
      if (day > end) break;
      out = cm;
    }
    return out;
  }

  /// Waist change over week [n] (cm, < 0 = smaller); null without readings on both sides.
  double? _waistChange(int n) {
    final now = _waistAt(n), before = _waistAt(n - 1);
    if (now == null || before == null) return null;
    return now - before;
  }

  /// Waist change across [weeks] weeks ending with week [n].
  double? waistChangeOver(int n, int weeks) {
    final now = _waistAt(n), before = _waistAt(n - weeks);
    if (now == null || before == null) return null;
    return now - before;
  }

  late final bool strengthIncreasing = () {
    final withData = input.anchorStates.values.where((s) => s.firstE1rm != null && s.bestE1rm != null).toList();
    if (withData.isEmpty) return false;
    final up = withData.where((s) => s.bestE1rm! > s.firstE1rm! * 1.01).length;
    return up * 2 > withData.length;
  }();

  late final bool strengthDropping = () {
    final states = input.anchorStates.values.toList();
    if (states.isEmpty) return false;
    final down = states.where((s) => s.lastTrend == Trend.down || s.lastTrend == Trend.deload).length;
    return down * 2 > states.length;
  }();

  /// Poor sleep in week [n]: at least 3 checklist days saved and "7+ hours sleep" ticked on fewer
  /// than half of them.
  bool _poorSleep(int n) {
    final from = startDay + 7 * (n - 1), to = _weekEnd(n);
    final days = input.nutrition.where((d) {
      final day = _dayNumberOfKey(d.date);
      return day >= from && day <= to;
    }).toList();
    if (days.length < 3) return false;
    return days.where((d) => d.sleepOk).length * 2 < days.length;
  }

  /// The rule condition for week [n] (rules are keyed by id; their `condition` text documents it).
  bool? condition(String id, int n) {
    final r = rate(n);
    if (r == null) return null;
    final waist = _waistChange(n);
    return switch (id) {
      'on_track' => r >= 0.5 && r <= 1.0,
      'too_fast' => r > 1.0 && n > 3,
      'slow_ok' => r >= 0.25 && r < 0.5,
      'plateau' => r < 0.25 && (waist == null || waist >= 0),
      'recomp' => r.abs() < 0.25 && waist != null && waist < 0 && strengthIncreasing,
      'gaining' => -r > 0.5,
      'fatigued' => _poorSleep(n) && strengthDropping,
      _ => null,
    };
  }

  /// The calorie target the user sees now (formula + applied deltas) and its floor.
  late final (int, int) _targetAndFloor = () {
    final w = targetsWeightFor(input.profile, input.body, input.now, input.p);
    final base = nutritionTargets(input.profile, input.p, currentWeightKg: w.kg);
    final floor = calorieFloorKcal(input.profile.sex, base.bmrKcal, input.p);
    final shown = adjustedTargets(base, input.adjustments, floorKcal: floor);
    return (shown.calorieTargetKcal, floor);
  }();

  late final int _stepsNow = () {
    final w = targetsWeightFor(input.profile, input.body, input.now, input.p);
    final base = nutritionTargets(input.profile, input.p, currentWeightKg: w.kg);
    final start = stepsTargetFor(base.stepsTarget, input.nutrition, input.profile.createdAt, input.now, input.p);
    return start + input.adjustments.fold<int>(0, (s, a) => s + (a.deltaSteps ?? 0));
  }();

  /// The (kcal, steps) change an action option allows, after the guards; (0, 0) when not possible.
  (int, int) feasible(Map<String, Object?> option, int consecutive) {
    final kcal = (option['kcal'] as num?)?.toInt();
    if (kcal != null) {
      var delta = kcal.clamp(-maxKcalChange, maxKcalChange);
      if (delta < 0 && neverBelowFloor) {
        final (target, floor) = _targetAndFloor;
        delta = math.max(delta, floor - target);
        if (delta > 0) delta = 0;
      }
      return (delta, 0);
    }
    final steps = (option['steps'] as num?)?.toInt();
    if (steps != null) return (0, _stepsRoom(steps));
    final ifFlat = (option['steps_if_waist_flat'] as num?)?.toInt();
    if (ifFlat != null) {
      final waist = waistChangeOver(completeWeeks, consecutive);
      return (0, waist == null || waist >= 0 ? _stepsRoom(ifFlat) : 0);
    }
    return (0, 0);
  }

  /// Adds steps up to the 10,000 progression maximum.
  int _stepsRoom(int steps) {
    const stepsMax = 10000;
    return math.max(0, math.min(steps, stepsMax - _stepsNow));
  }

  /// A sentence when the checklist shows protein or drinks are not solid yet (checked before
  /// trimming calories); null when they look fine or there is too little checklist data to tell.
  String? weakAdherence() {
    final from = today - 7;
    final days = input.nutrition.where((d) {
      final day = _dayNumberOfKey(d.date);
      return day >= from && day < today;
    }).toList();
    if (days.length < 4) return null;
    final w = targetsWeightFor(input.profile, input.body, input.now, input.p);
    final t = nutritionTargets(input.profile, input.p, currentWeightKg: w.kg);
    final protein = days.where((d) => d.proteinPoints >= t.proteinPointsGoodDay - 1e-9).length;
    final drinks = days.where((d) => d.noSugaryDrinks).length;
    final enough = (days.length * 5 / 7).ceil();
    if (protein >= enough && drinks >= enough) return null;
    return 'Your checklist shows protein on $protein and no sugary drinks on $drinks of the last ${days.length} days. '
        'Fix those first; we will look again next week.';
  }

  int? get lastAdjustmentDay {
    int? last;
    for (final a in input.adjustments) {
      final d = _dayNumberOfKey(a.date);
      if (last == null || d > last) last = d;
    }
    return last;
  }
}

int _weekIndex(DateTime start, DateTime now) => (_dayNumber(now) - _dayNumber(start)) ~/ 7 + 1;

int _dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

int _dayNumberOfKey(String key) => _dayNumber(DateTime.parse(key));
