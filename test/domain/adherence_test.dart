import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'milestone_fixtures.dart';

void main() {
  // Monday 7 Sep 2026; the default user plans 3 days, so a week counts with 2 sessions.
  final w0 = DateTime(2026, 9, 7);
  DateTime week(int n) => DateTime(w0.year, w0.month, w0.day + 7 * n);
  final u = profileAt(w0);

  /// [perWeek] sessions in each listed week (Mon, Wed, Fri ...).
  List<Session> weeks(List<int> perWeek) => [
        for (final (n, count) in perWeek.indexed) ...sessionsOn(week(n), [0, 2, 4].take(count).toList()),
      ];

  test('target per week is planned days - 1, at least 1', () {
    expect(streakTargetPerWeek(u), 2);
    expect(streakTargetPerWeek(u.copyWith(daysPerWeek: 1)), 1);
    expect(streakTargetPerWeek(u.copyWith(daysPerWeek: 2)), 1);
  });

  test('no sessions: empty streak', () {
    final s = weeklyStreak(const [], const [], u, week(0));
    expect(s.weeks, 0);
    expect(s.targetThisWeek, 2);
    expect(s.thisWeekCounted, isFalse);
  });

  test('counts consecutive weeks; the running week extends once it counts', () {
    final history = weeks([3, 2, 2]);
    // Thursday of week 2: 2 sessions already this week.
    final s = weeklyStreak(history, const [], u, week(2).add(const Duration(days: 3, hours: 20)));
    expect(s.weeks, 3);
    expect(s.thisWeekCounted, isTrue);
    expect(s.sessionsThisWeek, 2);
    // The running week does not break the streak before it is over.
    final monday = weeklyStreak(weeks([3, 2]), const [], u, week(2).add(const Duration(hours: 9)));
    expect(monday.weeks, 2);
    expect(monday.thisWeekCounted, isFalse);
    expect(monday.sessionsThisWeek, 0);
  });

  test('a missed week without tokens restarts the streak', () {
    final history = weeks([2, 2, 1, 2]);
    final s = weeklyStreak(history, const [], u, week(4));
    expect(s.weeks, 1);
  });

  test('a token is earned every 4 counted weeks and used on a missed week', () {
    final history = weeks([2, 2, 2, 2, 0, 2]);
    final s = weeklyStreak(history, const [], u, week(6));
    expect(s.weeks, 5);
    expect(s.graceTokens, 0);
    final noMiss = weeklyStreak(weeks([2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]), const [], u, week(12));
    expect(noMiss.weeks, 12);
    expect(noMiss.graceTokens, 2); // max 2 banked
  });

  test('a paused week is frozen: neither breaks nor extends', () {
    final history = weeks([2, 2, 0, 2]);
    final pause = Pause(
      id: 'x',
      kind: Pause.kindPause,
      reason: 'illness',
      startDate: dateKey(week(2)),
      endDate: dateKey(week(2).add(const Duration(days: 6))),
    );
    final s = weeklyStreak(history, [pause], u, week(4));
    expect(s.weeks, 3);
    // A tag (exams) does not freeze.
    final tag = Pause(id: 't', kind: Pause.kindTag, reason: 'exams', startDate: pause.startDate, endDate: pause.endDate);
    expect(weeklyStreak(history, [tag], u, week(4)).weeks, 1);
  });

  test('a pause freezes at most 3 weeks', () {
    final history = weeks([2, 2, 0, 0, 0, 0, 2]);
    final pause = Pause(id: 'x', kind: Pause.kindPause, reason: 'travel', startDate: dateKey(week(2)));
    expect(pausedWeekStarts([pause], week(7)), hasLength(3));
    expect(weeklyStreak(history, [pause], u, week(7)).weeks, 1);
    expect(activePause([pause], week(3)), pause);
    expect(activePause([pause], week(6)), isNull);
  });

  test('discarded sessions do not count', () {
    final history = [
      session(DateTime(2026, 9, 7, 17)),
      session(DateTime(2026, 9, 9, 17), status: SessionStatus.discarded),
    ];
    expect(weeklyStreak(history, const [], u, week(1)).weeks, 0);
  });

  test('missedPlannedDays: planned weekdays behind us without a session', () {
    // Friday evening of week 0, only Monday trained: Wednesday was missed.
    final friday = week(0).add(const Duration(days: 4, hours: 8));
    expect(missedPlannedDays(sessionsOn(week(0), [0]), const [], u, friday), 1);
    expect(missedPlannedDays(sessionsOn(week(0), [0, 2]), const [], u, friday), 0);
    // A session on Tuesday makes up for Wednesday.
    expect(missedPlannedDays(sessionsOn(week(0), [0, 1]), const [], u, friday), 0);
    final pause = Pause(id: 'x', kind: Pause.kindPause, reason: 'exams', startDate: dateKey(week(0)));
    expect(missedPlannedDays(const [], [pause], u, friday), 0);
  });
}
