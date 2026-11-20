// Owner: WS2. Training week, phase, effective reps in reserve and the return-after-a-break rule
// (SPEC 6.7, 6.8 gap rule).
import '../data/models/models.dart';
import 'api.dart';

/// Hardest effort ever prescribed: 4 = "4+ left (easy)".
const int maxRir = 4;

/// `rawWeek` of SPEC 6.7: the week counter before the cycle wrap (`startWeek` + full rotations
/// of non-deload sessions). Week 1 is the very first week; it keeps growing past `totalWeeks`.
int rawTrainingWeek(ProgramTemplate t, ActiveProgram a, int completedNonDeload) {
  final perWeek = t.daysPerWeek < 1 ? 1 : t.daysPerWeek;
  final start = a.startWeek < 1 ? 1 : a.startWeek;
  return start + (completedNonDeload < 0 ? 0 : completedNonDeload) ~/ perWeek;
}

/// Training week of the active program (SPEC 6.7). Custom programs are always week 1. After the
/// last week the cycle restarts at `cycleRestartWeek` (14 weeks, restart 5: 15 -> 5, 16 -> 6 ...).
int trainingWeek(ProgramTemplate t, ActiveProgram a, int completedNonDeload) =>
    wrapTrainingWeek(t, rawTrainingWeek(t, a, completedNonDeload));

/// `trainingWeek(rawWeek)` of SPEC 6.7.
int wrapTrainingWeek(ProgramTemplate t, int rawWeek) {
  final total = t.totalWeeks;
  if (total == null) return 1;
  if (rawWeek <= total) return rawWeek;
  final restart = t.cycleRestartWeek.clamp(1, total);
  final span = total - restart + 1;
  return restart + (rawWeek - total - 1) % span;
}

/// The phase whose weeks contain [week] (the last phase when none does, the first phase for
/// weeks before it).
Phase phaseFor(ProgramTemplate t, int week) {
  for (final p in t.phases) {
    if (p.weeks.contains(week)) return p;
  }
  final firstWeek = t.phases.first.weeks.isEmpty ? 1 : t.phases.first.weeks.reduce((a, b) => a < b ? a : b);
  return week < firstWeek ? t.phases.first : t.phases.last;
}

/// Target reps in reserve for [item] in [week] of [phase] (SPEC 6.7): the item's RIR plus the
/// phase's week offset, kept between the role's floor and 4. Null for items without a target.
int? effectiveRir(ProgramItem item, Phase phase, int week) {
  final base = item.rir;
  if (base == null) return null;
  final r = base + (phase.rirWeekOffsets[week] ?? 0);
  final floor = (phase.rirFloorByRole?[item.role] ?? 0).clamp(0, maxRir);
  return r.clamp(floor, maxRir);
}

/// Whole calendar days between [from] and [to] (local dates, DST-safe).
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Return-after-a-break adjustments (SPEC 6.8), from the last completed session of any program:
/// - under 10 days: none;
/// - 10 to 21 days: 10% lighter and one more rep in reserve for this session;
/// - over 21 days: 20% lighter, 4 reps in reserve, primaries find their weight again
///   (seeded at 80% of the old working weight);
/// - [recentIllness] ("fever or malaria in the last 2 weeks"): an easy (deload) session.
GapRule gapRule(DateTime? lastCompleted, DateTime now, {bool recentIllness = false}) {
  final days = lastCompleted == null ? 0 : calendarDaysBetween(lastCompleted, now);
  final GapRule base;
  if (days > 21) {
    base = const GapRule(0.8, maxRir, true, false,
        "Welcome back: lighter today, and we'll find your weight again on the main lifts");
  } else if (days >= 10) {
    base = const GapRule(0.9, 1, false, false, 'Welcome back: a bit lighter today');
  } else {
    base = GapRule.none;
  }
  if (!recentIllness) return base;
  return GapRule(
    base.loadMultiplier,
    base.rirBonus,
    base.forceFindWeightPrimary,
    true,
    [if (base.notice != null) base.notice!, 'You were ill recently: today is an easy session'].join('. '),
  );
}
