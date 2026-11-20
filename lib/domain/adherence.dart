// Owner: WS6. Weekly streak, grace tokens, pause mode and the "never miss twice" nudge (SPEC 10.4),
// following `personalization.adherence`.
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// `adherence.streak.min_sessions_floor`.
const int streakMinSessionsFloor = 1;

/// `adherence.grace_tokens.earn_every_completed_weeks`.
const int graceTokenEveryWeeks = 4;

/// `adherence.grace_tokens.max_banked`.
const int graceTokensMaxBanked = 2;

/// `adherence.pause_mode.max_weeks`: a pause freezes at most this many weeks.
const int pauseMaxWeeks = 3;

/// `adherence.pause_mode.reasons`.
const List<String> pauseReasons = ['illness', 'exams', 'travel', 'injury'];

/// Sessions a Mon-Sun week needs to count: `max(min_sessions_floor, plannedDays - 1)`.
int streakTargetPerWeek(UserProfile u) => math.max(streakMinSessionsFloor, u.daysPerWeek - 1);

/// Weekly streak (SPEC 10.4). Weeks run Monday to Sunday. A week counts when it has at least
/// [streakTargetPerWeek] completed sessions. A missed week inside a pause is frozen (it neither
/// breaks nor extends the streak); otherwise a banked grace token is used up automatically, and
/// with no token the streak restarts. One token is earned per 4 counted weeks, at most 2 banked.
/// The current week extends the streak as soon as it counts, and never breaks it while running.
StreakInfo weeklyStreak(List<Session> completed, List<Pause> pauses, UserProfile u, DateTime now) {
  final target = streakTargetPerWeek(u);
  final counts = sessionsPerWeek(completed);
  final thisWeek = _mondayDay(_dayNumber(now));
  final sessionsThisWeek = counts[thisWeek] ?? 0;
  final thisWeekCounted = sessionsThisWeek >= target;
  if (counts.isEmpty) {
    return StreakInfo(weeks: 0, graceTokens: 0, thisWeekCounted: false, sessionsThisWeek: 0, targetThisWeek: target);
  }

  final frozen = pausedWeekStarts(pauses, now);
  var streak = 0;
  var tokens = 0;
  var sinceToken = 0;
  void countWeek() {
    streak++;
    sinceToken++;
    if (sinceToken >= graceTokenEveryWeeks) {
      tokens = math.min(graceTokensMaxBanked, tokens + 1);
      sinceToken = 0;
    }
  }

  final first = counts.keys.reduce(math.min);
  for (var week = first; week < thisWeek; week += 7) {
    if ((counts[week] ?? 0) >= target) {
      countWeek();
    } else if (frozen.contains(week)) {
      // Paused: frozen.
    } else if (tokens > 0) {
      tokens--;
    } else {
      streak = 0;
      sinceToken = 0;
    }
  }
  if (thisWeekCounted) countWeek();

  return StreakInfo(
    weeks: streak,
    graceTokens: tokens,
    thisWeekCounted: thisWeekCounted,
    sessionsThisWeek: sessionsThisWeek,
    targetThisWeek: target,
  );
}

/// Completed sessions per Mon-Sun week, keyed by the Monday's day number (UTC-date based).
Map<int, int> sessionsPerWeek(List<Session> sessions) {
  final out = <int, int>{};
  for (final s in sessions) {
    if (s.status != SessionStatus.completed) continue;
    final monday = _mondayDay(_dayNumber(s.startedAt.toLocal()));
    out[monday] = (out[monday] ?? 0) + 1;
  }
  return out;
}

/// Mondays (day numbers) of the weeks touched by a pause (`kind == pause`), each pause limited to
/// [pauseMaxWeeks] weeks from its start; a running pause lasts until today.
Set<int> pausedWeekStarts(List<Pause> pauses, DateTime now) {
  final today = _dayNumber(now);
  final out = <int>{};
  for (final p in pauses) {
    if (p.kind != Pause.kindPause) continue;
    final (start, end) = pauseDays(p, today);
    if (end < start) continue;
    for (var week = _mondayDay(start); week <= end; week += 7) {
      out.add(week);
    }
  }
  return out;
}

/// First and last day number a pause covers (end inclusive), capped at [pauseMaxWeeks] weeks.
(int, int) pauseDays(Pause p, int today) {
  final start = _dayNumberOfKey(p.startDate);
  final end = p.endDate == null ? today : _dayNumberOfKey(p.endDate!);
  return (start, math.min(end, start + pauseMaxWeeks * 7 - 1));
}

/// The pause running today (and not past its 3-week limit), if any.
Pause? activePause(List<Pause> pauses, DateTime now) {
  final today = _dayNumber(now);
  for (final p in pauses.reversed) {
    if (p.kind != Pause.kindPause) continue;
    final (start, end) = pauseDays(p, today);
    if (start <= today && today <= end) return p;
  }
  return null;
}

/// Planned workout days already behind us this week (before today) that have no session to
/// match them. Today shows the "never miss twice" nudge when this is 1 or more. Zero while a
/// pause is running.
int missedPlannedDays(List<Session> completed, List<Pause> pauses, UserProfile u, DateTime now) {
  if (activePause(pauses, now) != null) return 0;
  final today = _dayNumber(now);
  final monday = _mondayDay(today);
  final plannedSoFar = u.workoutWeekdays.where((wd) => monday + wd - 1 < today).length;
  final doneSoFar = completed.where((s) {
    if (s.status != SessionStatus.completed) return false;
    final d = _dayNumber(s.startedAt.toLocal());
    return d >= monday && d < today;
  }).length;
  return math.max(0, plannedSoFar - doneSoFar);
}

// ---------------------------------------------------------------------------------------------

/// Days since 1970-01-01 of the local calendar date (DST-proof).
int _dayNumber(DateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

int _dayNumberOfKey(String key) => _dayNumber(DateTime.parse(key));

/// Day 0 (1970-01-01) was a Thursday, so Monday = day - ((day + 3) % 7).
int _mondayDay(int day) => day - ((day + 3) % 7);
