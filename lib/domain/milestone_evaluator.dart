// Owner: WS6. Milestone rules (SPEC 10.3) over `personalization.milestones`.
//
// Conventions: load = `totalLoadKg` (SPEC 0.4); body weight = latest 7-day average, else the
// profile weight; only working and test sets count; weeks are Monday to Sunday.
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// How far a locked milestone is, for the badge wall.
class MilestoneProgress {
  const MilestoneProgress({required this.fraction, required this.label});

  /// 0..1.
  final double fraction;

  /// Plain-language status, e.g. "3 of 10 sessions" or "Best: 40 of 48 kg".
  final String label;
}

/// Newly earned milestones (SPEC 10.3). Milestones in [alreadyAwarded] are skipped, except
/// repeatable ones (`"repeatable": true`, e.g. "New PR"), which are returned again whenever
/// their rule fires (from [MilestoneInput.newPrs]).
List<MilestoneAward> evaluateMilestones(MilestoneInput input, Personalization p, Set<String> alreadyAwarded) {
  final ctx = _Ctx(input, p);
  final repeatable = repeatableMilestoneIds(p);
  return [
    for (final m in p.milestones)
      if (!alreadyAwarded.contains(m.id) || repeatable.contains(m.id))
        if (ctx.evaluate(m) case final context?)
          MilestoneAward(milestoneId: m.id, awardedAt: input.now, context: context),
  ];
}

/// Progress of every milestone whose rule has a measurable distance (counts, loads, kg, cm ...).
/// Milestones that do not apply to this user (e.g. "Under 102" when the waist started below 102)
/// are left out.
Map<String, MilestoneProgress> milestoneProgress(MilestoneInput input, Personalization p) {
  final ctx = _Ctx(input, p);
  return {
    for (final m in p.milestones) m.id: ?ctx.progress(m),
  };
}

/// Ids of milestones marked `"repeatable": true` in the data.
Set<String> repeatableMilestoneIds(Personalization p) => _flagged(p, 'repeatable');

/// Ids of milestones marked `"low_emphasis": true` (shown softly, e.g. BMI).
Set<String> lowEmphasisMilestoneIds(Personalization p) => _flagged(p, 'low_emphasis');

/// True when every key of [rule] combination is understood by the evaluator.
bool isKnownMilestoneRule(Map<String, Object?> rule) => _kindOf(rule) != null;

Set<String> _flagged(Personalization p, String flag) {
  final list = p.raw['milestones'];
  if (list is! List) return const {};
  return {
    for (final m in list)
      if (m is Map && m[flag] == true && m['id'] is String) m['id'] as String,
  };
}

enum _Kind {
  sessionsCompleted,
  firstWeek,
  weekStreak,
  streakDuringTag,
  weeksInMonths,
  startedBefore,
  comeback,
  loadXBodyweight,
  loadKg,
  e1rmPr,
  anchorIncrease,
  avg7LossKg,
  avg7LossPct,
  recompWindow,
  waistLoss,
  waistBelow,
  waistToHeight,
  bmiBelow,
  habitWeek,
  badgeWeeks,
  weeklySteps,
  weeklySleep,
  cardioMinutes,
}

_Kind? _kindOf(Map<String, Object?> r) {
  bool has(String k) => r.containsKey(k);
  if (has('sessions_completed_gte')) return _Kind.sessionsCompleted;
  if (has('week_index') && has('sessions_eq_planned')) return _Kind.firstWeek;
  if (has('week_streak_gte')) return _Kind.weekStreak;
  if (has('streak_maintained_during_tag')) return _Kind.streakDuringTag;
  if (has('weeks_trained_in_months') && has('gte')) return _Kind.weeksInMonths;
  if (has('sessions_started_before') && has('gte')) return _Kind.startedBefore;
  if (has('session_within_days_after_missed_week')) return _Kind.comeback;
  if (has('exercise_any') && has('load_x_bodyweight_gte')) return _Kind.loadXBodyweight;
  if (has('exercise_any') && has('load_kg_gte')) return _Kind.loadKg;
  if (has('estimated_1rm_gt_previous_best')) return _Kind.e1rmPr;
  if (has('anchor_lifts_avg_increase_pct_gte')) return _Kind.anchorIncrease;
  if (has('avg7_loss_kg_gte')) return _Kind.avg7LossKg;
  if (has('avg7_loss_pct_gte')) return _Kind.avg7LossPct;
  if (has('weeks') && has('abs_weight_change_pct_lt') && has('waist_loss_cm_gte')) return _Kind.recompWindow;
  if (has('waist_loss_cm_gte')) return _Kind.waistLoss;
  if (has('waist_cm_lt')) return _Kind.waistBelow;
  if (has('waist_to_height_lt')) return _Kind.waistToHeight;
  if (has('bmi_lt')) return _Kind.bmiBelow;
  if (has('habit') && has('days_of_7_gte')) return _Kind.habitWeek;
  if (has('badge') && has('consecutive_weeks_gte')) return _Kind.badgeWeeks;
  if (has('weekly_avg_steps_gte')) return _Kind.weeklySteps;
  if (has('weekly_avg_sleep_h_gte')) return _Kind.weeklySleep;
  if (has('cardio_continuous_min_gte')) return _Kind.cardioMinutes;
  return null;
}

typedef _Ctxt = Map<String, Object?>;

/// Evaluation context: derived data computed once, lazily.
class _Ctx {
  _Ctx(this.i, this.p);

  final MilestoneInput i;
  final Personalization p;

  late final int today = _dayNumber(i.now);

  late final List<Session> sessions = [
    for (final s in i.sessions)
      if (s.status == SessionStatus.completed) s,
  ]..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  late final List<SetLog> workSets = [
    for (final s in i.workingSets)
      if (s.kind == SetKind.working || s.kind == SetKind.test) s,
  ];

  late final Map<int, int> perWeek = sessionsPerWeek(sessions);

  late final int streakTarget = streakTargetPerWeek(i.profile);

  late final Set<int> pausedWeeks = pausedWeekStarts(i.pauses, i.now);

  late final List<({String date, double kg})> avg = avg7Series(i.body);

  late final double bodyweight = avg.isNotEmpty ? avg.last.kg : i.profile.weightKg;

  /// Waist readings (day, cm), oldest first, with the onboarding waist at the profile's start.
  late final List<(int, double)> waists = () {
    final out = <(int, double)>[
      for (final e in i.body)
        if (e.waistCm != null) (_dayNumberOfKey(e.date), e.waistCm!),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final start = i.profile.startWaistCm;
    if (start != null) out.insert(0, (_dayNumber(i.profile.createdAt), start));
    return out;
  }();

  late final NutritionTargets targets = () {
    final w = targetsWeightFor(i.profile, i.body, i.now, p);
    return nutritionTargets(i.profile, p, currentWeightKg: w.kg);
  }();

  late final Set<int> trainingDays = {for (final s in sessions) _dayNumber(s.startedAt.toLocal())};

  double _n(Map<String, Object?> r, String k, [double fallback = 0]) {
    final v = r[k];
    return v is num ? v.toDouble() : fallback;
  }

  List<String> _ids(Map<String, Object?> r) => [
        for (final x in (r['exercise_any'] is List ? r['exercise_any'] as List : const <Object?>[]))
          if (x is String) x,
      ];

  // ---------------------------------------------------------------------------------------------
  // Evaluation

  _Ctxt? evaluate(Milestone m) {
    final r = m.rule;
    switch (_kindOf(r)) {
      case _Kind.sessionsCompleted:
        final n = _n(r, 'sessions_completed_gte');
        return sessions.length >= n ? {'sessions': sessions.length} : null;
      case _Kind.firstWeek:
        final done = _firstWeekSessions;
        return done >= i.profile.daysPerWeek ? {'sessions': done} : null;
      case _Kind.weekStreak:
        final weeks = weeklyStreak(sessions, i.pauses, i.profile, i.now).weeks;
        return weeks >= _n(r, 'week_streak_gte') ? {'weeks': weeks} : null;
      case _Kind.streakDuringTag:
        final tag = _streakTag('${r['streak_maintained_during_tag']}');
        return tag == null ? null : {'tag': tag.reason, 'from': tag.startDate, 'to': tag.endDate};
      case _Kind.weeksInMonths:
        final weeks = _weeksInMonths(r);
        return weeks >= _n(r, 'gte') ? {'weeks': weeks} : null;
      case _Kind.startedBefore:
        final count = _startedBefore('${r['sessions_started_before']}');
        return count >= _n(r, 'gte') ? {'sessions': count} : null;
      case _Kind.comeback:
        final day = _comebackDay(_n(r, 'session_within_days_after_missed_week').round());
        return day == null ? null : {'date': _keyOfDay(day)};
      case _Kind.loadXBodyweight:
        final need = _n(r, 'load_x_bodyweight_gte') * bodyweight;
        final best = _bestSet(r);
        return best != null && best.load >= need - 1e-9
            ? {'exerciseId': best.set.exerciseId, 'loadKg': best.load, 'reps': best.set.reps, 'bodyweightKg': bodyweight}
            : null;
      case _Kind.loadKg:
        final best = _bestSet(r);
        return best != null && best.load >= _n(r, 'load_kg_gte') - 1e-9
            ? {'exerciseId': best.set.exerciseId, 'loadKg': best.load, 'reps': best.set.reps}
            : null;
      case _Kind.e1rmPr:
        final pr = _realPrs.firstOrNull;
        return pr == null ? null : {'exerciseId': pr.exerciseId, 'value': pr.value, 'setLogId': pr.setLogId};
      case _Kind.anchorIncrease:
        final pct = _anchorIncreasePct;
        return pct != null && pct >= _n(r, 'anchor_lifts_avg_increase_pct_gte') ? {'pct': _round1(pct)} : null;
      case _Kind.avg7LossKg:
        final loss = _avgLossKg;
        return loss != null && loss >= _n(r, 'avg7_loss_kg_gte') - 1e-9 ? {'kg': _round1(loss)} : null;
      case _Kind.avg7LossPct:
        final loss = _avgLossPct;
        return loss != null && loss >= _n(r, 'avg7_loss_pct_gte') - 1e-9 ? {'pct': _round1(loss)} : null;
      case _Kind.recompWindow:
        return _recompWindow(r);
      case _Kind.waistLoss:
        final loss = _waistLoss;
        return loss != null && loss >= _n(r, 'waist_loss_cm_gte') - 1e-9 ? {'cm': _round1(loss)} : null;
      case _Kind.waistBelow:
        if (!_waistBelowApplies(r)) return null;
        final latest = waists.last.$2;
        return latest < _n(r, 'waist_cm_lt') ? {'cm': latest} : null;
      case _Kind.waistToHeight:
        if (waists.isEmpty) return null;
        final ratio = waists.last.$2 / i.profile.heightCm;
        return ratio < _n(r, 'waist_to_height_lt') ? {'ratio': (ratio * 100).round() / 100} : null;
      case _Kind.bmiBelow:
        if (avg.isEmpty || _bmi(_startWeight) < _n(r, 'only_if_start_gte')) return null;
        final bmi = _bmi(avg.last.kg);
        return bmi < _n(r, 'bmi_lt') ? {'bmi': _round1(bmi)} : null;
      case _Kind.habitWeek:
        final best = _bestHabitWeek('${r['habit']}');
        return best != null && best.days >= _n(r, 'days_of_7_gte') ? {'week': _keyOfDay(best.monday), 'days': best.days} : null;
      case _Kind.badgeWeeks:
        final run = _badgeRun('${r['badge']}');
        return run >= _n(r, 'consecutive_weeks_gte') ? {'weeks': run} : null;
      case _Kind.weeklySteps:
        final best = _bestStepsWeek;
        return best != null && best.avg >= _n(r, 'weekly_avg_steps_gte') ? {'week': _keyOfDay(best.monday), 'steps': best.avg.round()} : null;
      case _Kind.weeklySleep:
        final best = _bestSleepWeek;
        return best != null && best.days >= _sleepDaysNeeded ? {'week': _keyOfDay(best.monday), 'days': best.days} : null;
      case _Kind.cardioMinutes:
        final best = _longestCardioMin;
        return best >= _n(r, 'cardio_continuous_min_gte') - 1e-9 ? {'minutes': _round1(best)} : null;
      case null:
        return null;
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Progress

  MilestoneProgress? progress(Milestone m) {
    final r = m.rule;
    MilestoneProgress count(num current, num target, String unit) => MilestoneProgress(
          fraction: target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble(),
          label: '${_fmt(math.min(current, target).toDouble())} of ${_fmt(target.toDouble())} $unit',
        );
    switch (_kindOf(r)) {
      case _Kind.sessionsCompleted:
        return count(sessions.length, _n(r, 'sessions_completed_gte'), 'sessions');
      case _Kind.firstWeek:
        return count(_firstWeekSessions, i.profile.daysPerWeek, 'sessions in week 1');
      case _Kind.weekStreak:
        return count(weeklyStreak(sessions, i.pauses, i.profile, i.now).weeks, _n(r, 'week_streak_gte'), 'weeks');
      case _Kind.weeksInMonths:
        return count(_weeksInMonths(r), _n(r, 'gte'), 'weeks');
      case _Kind.startedBefore:
        return count(_startedBefore('${r['sessions_started_before']}'), _n(r, 'gte'), 'sessions');
      case _Kind.loadXBodyweight:
        final need = _n(r, 'load_x_bodyweight_gte') * bodyweight;
        final best = _bestSet(r)?.load ?? 0;
        return MilestoneProgress(
          fraction: need <= 0 ? 0 : (best / need).clamp(0, 1).toDouble(),
          label: 'Best: ${_fmt(best)} of ${_fmt(need)} kg',
        );
      case _Kind.loadKg:
        final need = _n(r, 'load_kg_gte');
        final best = _bestSet(r)?.load ?? 0;
        return MilestoneProgress(fraction: (best / need).clamp(0, 1).toDouble(), label: 'Best: ${_fmt(best)} of ${_fmt(need)} kg');
      case _Kind.anchorIncrease:
        final pct = _anchorIncreasePct;
        final need = _n(r, 'anchor_lifts_avg_increase_pct_gte');
        if (pct == null) return const MilestoneProgress(fraction: 0, label: 'Needs 3 main lifts trained in the last 2 weeks');
        return MilestoneProgress(fraction: (pct / need).clamp(0, 1).toDouble(), label: 'Now +${pct.round()}% of +${need.round()}%');
      case _Kind.avg7LossKg:
        final loss = math.max(0.0, _avgLossKg ?? 0);
        return count(_round1(loss), _n(r, 'avg7_loss_kg_gte'), 'kg');
      case _Kind.avg7LossPct:
        final loss = math.max(0.0, _avgLossPct ?? 0);
        return count(_round1(loss), _n(r, 'avg7_loss_pct_gte'), '%');
      case _Kind.waistLoss:
        final loss = math.max(0.0, _waistLoss ?? 0);
        return count(_round1(loss), _n(r, 'waist_loss_cm_gte'), 'cm');
      case _Kind.waistBelow:
        if (!_waistBelowApplies(r)) return null;
        final start = waists.first.$2, latest = waists.last.$2, goal = _n(r, 'waist_cm_lt');
        return MilestoneProgress(
          fraction: start <= goal ? 1 : ((start - latest) / (start - goal)).clamp(0, 1).toDouble(),
          label: 'Now ${_fmt(latest)} cm, goal under ${_fmt(goal)} cm',
        );
      case _Kind.waistToHeight:
        if (waists.isEmpty) return const MilestoneProgress(fraction: 0, label: 'Log your waist on the Body screen');
        final h = i.profile.heightCm, goal = _n(r, 'waist_to_height_lt');
        final start = waists.first.$2 / h, now = waists.last.$2 / h;
        return MilestoneProgress(
          fraction: start <= goal ? 1 : ((start - now) / (start - goal)).clamp(0, 1).toDouble(),
          label: 'Now ${now.toStringAsFixed(2)}, goal under ${goal.toStringAsFixed(2)}',
        );
      case _Kind.bmiBelow:
        if (_bmi(_startWeight) < _n(r, 'only_if_start_gte')) return null;
        if (avg.isEmpty) return const MilestoneProgress(fraction: 0, label: 'Needs 3 weigh-ins in a week');
        final start = _bmi(_startWeight), now = _bmi(avg.last.kg), goal = _n(r, 'bmi_lt');
        return MilestoneProgress(
          fraction: ((start - now) / (start - goal)).clamp(0, 1).toDouble(),
          label: 'Now ${now.toStringAsFixed(1)}, goal under ${_fmt(goal)}',
        );
      case _Kind.habitWeek:
        return count(_bestHabitWeek('${r['habit']}')?.days ?? 0, _n(r, 'days_of_7_gte'), 'days in a week');
      case _Kind.badgeWeeks:
        return count(_badgeRun('${r['badge']}'), _n(r, 'consecutive_weeks_gte'), 'weeks in a row');
      case _Kind.weeklySteps:
        final best = _bestStepsWeek?.avg ?? 0;
        return count(best.round(), _n(r, 'weekly_avg_steps_gte'), 'steps a day');
      case _Kind.weeklySleep:
        return count(_bestSleepWeek?.days ?? 0, _sleepDaysNeeded, 'good nights in a week');
      case _Kind.cardioMinutes:
        return count(_longestCardioMin.floor(), _n(r, 'cardio_continuous_min_gte'), 'min');
      case _Kind.streakDuringTag || _Kind.comeback || _Kind.e1rmPr || _Kind.recompWindow || null:
        return null;
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Consistency

  late final int _firstWeekSessions = () {
    final start = i.profile.createdAt;
    final end = start.add(const Duration(days: 7));
    return sessions.where((s) => !s.startedAt.isBefore(start) && s.startedAt.isBefore(end)).length;
  }();

  bool _weekCounted(int monday) => (perWeek[monday] ?? 0) >= streakTarget;

  /// A finished tag period of at least 7 days whose every week counted for the streak.
  Pause? _streakTag(String reason) {
    for (final t in i.pauses) {
      if (t.kind != Pause.kindTag || t.reason != reason || t.endDate == null) continue;
      final start = _dayNumberOfKey(t.startDate), end = _dayNumberOfKey(t.endDate!);
      if (end >= today || end - start + 1 < 7) continue;
      var all = true;
      for (var week = _monday(start); week <= end && all; week += 7) {
        all = _weekCounted(week);
      }
      if (all) return t;
    }
    return null;
  }

  int _weeksInMonths(Map<String, Object?> r) {
    final months = {
      for (final m in (r['weeks_trained_in_months'] is List ? r['weeks_trained_in_months'] as List : const <Object?>[]))
        if (m is num) m.toInt(),
    };
    final since = today - 365;
    return {
      for (final s in sessions)
        if (_dayNumber(s.startedAt.toLocal()) > since && months.contains(s.startedAt.toLocal().month))
          _monday(_dayNumber(s.startedAt.toLocal())),
    }.length;
  }

  int _startedBefore(String hhmm) {
    final parts = hhmm.split(':');
    final limit = (int.tryParse(parts.first) ?? 0) * 60 + (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
    return sessions.where((s) {
      final t = s.startedAt.toLocal();
      return t.hour * 60 + t.minute < limit;
    }).length;
  }

  /// The day of a session that came within [days] days after a missed (unpaused) week.
  int? _comebackDay(int days) {
    if (sessions.isEmpty) return null;
    final sessionDays = [for (final s in sessions) _dayNumber(s.startedAt.toLocal())];
    final first = _monday(sessionDays.first);
    for (var week = first + 7; week + 6 < today; week += 7) {
      if ((perWeek[week] ?? 0) > 0 || pausedWeeks.contains(week)) continue;
      final end = week + 6;
      for (final d in sessionDays) {
        if (d > end && d <= end + days) return d;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------------------------
  // Strength

  ({SetLog set, double load})? _bestSet(Map<String, Object?> r) {
    final ids = _ids(r).toSet();
    final minReps = _n(r, 'reps_gte', 1);
    final withSled = r['include_sled_weight'] == true;
    ({SetLog set, double load})? best;
    for (final s in workSets) {
      if (!ids.contains(s.exerciseId) || s.reps < minReps) continue;
      final load = _load(s, withSled: withSled);
      if (load == null) continue;
      if (best == null || load > best.load) best = (set: s, load: load);
    }
    return best;
  }

  /// Total load of [s]; the leg-press sled is only counted when the rule asks for it (and only if
  /// its weight is known, which [totalLoadKg] handles).
  double? _load(SetLog s, {bool withSled = true}) {
    final ex = i.catalog.tryExercise(s.exerciseId);
    if (ex == null) return null;
    if (ex.loadType == LoadType.plateLoaded && !withSled) return s.weightKg;
    return totalLoadKg(s, ex, i.eq);
  }

  double? _e1rm(SetLog s) {
    final load = _load(s);
    if (load == null || load <= 0 || s.reps <= 0) return null;
    return epley1rm(load, s.reps);
  }

  /// New estimated-best-single records that beat an earlier best (first-session baselines excluded).
  late final List<PersonalRecord> _realPrs = [
    for (final pr in i.newPrs)
      if (pr.type == PrType.e1rm && !_isBaseline(pr)) pr,
  ];

  bool _isBaseline(PersonalRecord pr) {
    final set = workSets.where((s) => s.id == pr.setLogId).firstOrNull;
    final state = i.states[pr.exerciseId];
    final first = state?.firstE1rm;
    if (first != null && pr.value > first + 1e-6) return false;
    if (set == null) return true;
    return !workSets.any((s) => s.exerciseId == pr.exerciseId && s.sessionId != set.sessionId && s.completedAt.isBefore(set.completedAt));
  }

  /// Mean % increase of the anchor lifts: best estimated single of the last 14 days vs the first
  /// one, over the anchors with data (null with fewer than 3).
  late final double? _anchorIncreasePct = () {
    final anchors = (p.raw['progress_tracking'] is Map ? (p.raw['progress_tracking'] as Map)['strength_anchor_lifts'] : null);
    if (anchors is! List) return null;
    final since = i.now.subtract(const Duration(days: 14));
    final pcts = <double>[];
    for (final a in anchors) {
      if (a is! Map) continue;
      final ids = [for (final x in (a['exercise_any'] is List ? a['exercise_any'] as List : const <Object?>[])) if (x is String) x];
      for (final id in ids) {
        final sets = workSets.where((s) => s.exerciseId == id).toList()..sort((x, y) => x.completedAt.compareTo(y.completedAt));
        if (sets.isEmpty) continue;
        double? recent;
        for (final s in sets) {
          if (s.completedAt.isBefore(since)) continue;
          final e = _e1rm(s);
          if (e != null && (recent == null || e > recent)) recent = e;
        }
        var first = i.states[id]?.firstE1rm;
        if (first == null) {
          final firstSession = sets.first.sessionId;
          for (final s in sets.where((s) => s.sessionId == firstSession)) {
            final e = _e1rm(s);
            if (e != null && (first == null || e > first)) first = e;
          }
        }
        if (recent == null || first == null || first <= 0) continue;
        pcts.add((recent / first - 1) * 100);
        break;
      }
    }
    if (pcts.length < 3) return null;
    return pcts.reduce((a, b) => a + b) / pcts.length;
  }();

  // ---------------------------------------------------------------------------------------------
  // Body

  late final double? _avgLossKg = avg.isEmpty ? null : avg.first.kg - avg.last.kg;

  late final double? _avgLossPct = avg.isEmpty ? null : (avg.first.kg - avg.last.kg) / avg.first.kg * 100;

  late final double? _waistLoss = waists.isEmpty ? null : waists.first.$2 - waists.last.$2;

  /// Starting weight for BMI rules: the first 7-day average, else the profile weight.
  late final double _startWeight = avg.isNotEmpty ? avg.first.kg : i.profile.weightKg;

  double _bmi(double kg) => kg / math.pow(i.profile.heightCm / 100, 2);

  bool _waistBelowApplies(Map<String, Object?> r) {
    final sex = r['sex'];
    if (sex is String && sex != i.profile.sex.wire) return false;
    if (waists.isEmpty) return false;
    return waists.first.$2 >= _n(r, 'only_if_start_gte');
  }

  _Ctxt? _recompWindow(Map<String, Object?> r) {
    if (avg.isEmpty) return null;
    final weeks = _n(r, 'weeks').round();
    final latestDay = _dayNumberOfKey(avg.last.date);
    final refDay = latestDay - weeks * 7;
    double? refKg;
    for (final a in avg) {
      final d = _dayNumberOfKey(a.date);
      if (d > refDay) break;
      if (d >= refDay - 7) refKg = a.kg;
    }
    if (refKg == null) return null;
    final changePct = (avg.last.kg - refKg).abs() / refKg * 100;
    double? refWaist;
    for (final (d, cm) in waists) {
      if (d > refDay) break;
      refWaist = cm;
    }
    if (refWaist == null || waists.isEmpty) return null;
    final waistDown = refWaist - waists.last.$2;
    if (changePct < _n(r, 'abs_weight_change_pct_lt') && waistDown >= _n(r, 'waist_loss_cm_gte') - 1e-9) {
      return {'weightChangePct': _round1(changePct), 'waistLossCm': _round1(waistDown)};
    }
    return null;
  }

  // ---------------------------------------------------------------------------------------------
  // Habits

  /// Nutrition days by Monday (day number).
  late final Map<int, List<NutritionDay>> _nutritionWeeks = () {
    final out = <int, List<NutritionDay>>{};
    for (final d in i.nutrition) {
      (out[_monday(_dayNumberOfKey(d.date))] ??= []).add(d);
    }
    return out;
  }();

  bool _habitMet(String habit, NutritionDay d) => switch (habit) {
        'protein' => d.proteinPoints >= targets.proteinPointsTarget - 1e-9,
        'water' => d.waterSachets >=
            sachetsFor(trainingDays.contains(_dayNumberOfKey(d.date)) ? targets.waterTrainingMl : targets.waterRestMl) -
                1e-9,
        _ => false,
      };

  /// Days per week the habit was met, by Monday.
  Map<int, int> _habitWeeks(String habit) => {
        for (final MapEntry(key: monday, value: days) in _nutritionWeeks.entries)
          monday: days.where((d) => _habitMet(habit, d)).length,
      };

  ({int monday, int days})? _bestHabitWeek(String habit) {
    ({int monday, int days})? best;
    for (final MapEntry(key: monday, value: days) in _habitWeeks(habit).entries) {
      if (best == null || days > best.days) best = (monday: monday, days: days);
    }
    return best;
  }

  /// Longest run of consecutive weeks in which the named habit badge's weekly condition held.
  int _badgeRun(String badgeId) {
    final badge = p.milestones.where((m) => m.id == badgeId).firstOrNull;
    if (badge == null || _kindOf(badge.rule) != _Kind.habitWeek) return 0;
    final need = _n(badge.rule, 'days_of_7_gte');
    final held = {
      for (final MapEntry(key: monday, value: days) in _habitWeeks('${badge.rule['habit']}').entries)
        if (days >= need) monday,
    };
    var best = 0;
    for (final monday in held) {
      if (held.contains(monday - 7)) continue;
      var run = 0;
      while (held.contains(monday + run * 7)) {
        run++;
      }
      best = math.max(best, run);
    }
    return best;
  }

  /// A week with at least 5 step entries; the best average.
  late final ({int monday, double avg})? _bestStepsWeek = () {
    ({int monday, double avg})? best;
    for (final MapEntry(key: monday, value: days) in _nutritionWeeks.entries) {
      final steps = [for (final d in days) if (d.steps != null) d.steps!];
      if (steps.length < 5) continue;
      final avg = steps.reduce((a, b) => a + b) / steps.length;
      if (best == null || avg > best.avg) best = (monday: monday, avg: avg);
    }
    return best;
  }();

  /// "7+ hours sleep" ticked on this many days of a week stands for a 7 h weekly average.
  static const int _sleepDaysNeeded = 6;

  late final ({int monday, int days})? _bestSleepWeek = () {
    ({int monday, int days})? best;
    for (final MapEntry(key: monday, value: days) in _nutritionWeeks.entries) {
      final n = days.where((d) => d.sleepOk).length;
      if (best == null || n > best.days) best = (monday: monday, days: n);
    }
    return best;
  }();

  /// Longest single cardio effort in minutes: a timed set of a cardio or finisher item, or a
  /// rest-day cardio log.
  late final double _longestCardioMin = () {
    var best = 0;
    for (final s in sessions) {
      for (final e in s.exercises) {
        final isCardio = e.blockType == BlockType.finisher || i.catalog.tryExercise(e.exerciseId)?.category == ExerciseCategory.cardio;
        if (!isCardio) continue;
        for (final set in e.sets) {
          best = math.max(best, set.durationSec ?? 0);
        }
      }
    }
    for (final c in i.cardio) {
      best = math.max(best, c.durationSec);
    }
    return best / 60;
  }();
}

double _round1(double x) => (x * 10).round() / 10;

/// 1 decimal at most, thousands grouped: 2.5, 40, 8,000.
String _fmt(double x) {
  final r = _round1(x);
  if (r != r.roundToDouble()) return r.toStringAsFixed(1);
  final digits = r.round().abs().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return r < 0 ? '-$grouped' : grouped;
}

int _dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

int _dayNumberOfKey(String key) => _dayNumber(DateTime.parse(key));

int _monday(int day) => day - ((day + 3) % 7);

String _keyOfDay(int day) {
  final d = DateTime.fromMillisecondsSinceEpoch(day * Duration.millisecondsPerDay, isUtc: true);
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
