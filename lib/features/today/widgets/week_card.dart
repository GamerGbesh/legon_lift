// Owner: WS4. Week strip Mon-Sun (done / planned / today) and the weekly streak (SPEC 4.3).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../state/today_store.dart';

class WeekCard extends StatelessWidget {
  const WeekCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = context.watch<TodayStore>();
    final streak = today.streak;
    final week = today.week;
    final done = week.where((d) => d.done).length;
    final target = streak.targetThisWeek;
    final streakText = streak.weeks == 0
        ? 'Start your streak this week'
        : '${streak.weeks}-week streak';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('This week', style: AppText.bodyStrong.copyWith(color: t.onSurface))),
                Text('$done of $target workouts', style: AppText.tabular(AppText.label).copyWith(color: t.muted)),
              ],
            ),
            const SizedBox(height: Space.m),
            Row(
              children: [
                for (final d in week) Expanded(child: _DayDot(day: d)),
              ],
            ),
            const SizedBox(height: Space.m),
            Divider(color: t.surface2),
            const SizedBox(height: Space.s),
            Row(
              children: [
                Icon(Icons.local_fire_department, color: streak.weeks > 0 ? t.primary : t.muted, size: 28),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(streakText, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                      Text(
                        streak.thisWeekCounted
                            ? 'This week already counts. Great job.'
                            : _remainingText((target - streak.sessionsThisWeek).clamp(1, 7), streak.weeks > 0),
                        style: AppText.label.copyWith(color: t.muted),
                      ),
                    ],
                  ),
                ),
                if (streak.graceTokens > 0)
                  Tooltip(
                    message: 'Saves: a missed week will not break your streak',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < streak.graceTokens; i++) Icon(Icons.shield, color: t.secondary, size: 22),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});

  final WeekDayStatus day;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = day.done ? 'done' : (day.planned ? 'planned' : 'rest');
    final Widget mark;
    if (day.done) {
      mark = Container(
        decoration: BoxDecoration(color: t.success, shape: BoxShape.circle),
        child: Icon(Icons.check, color: t.bg, size: 22),
      );
    } else if (day.planned) {
      mark = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: day.isToday ? t.primary.withValues(alpha: 0.2) : null,
          border: Border.all(color: t.primary, width: 2),
        ),
        child: Icon(Icons.fitness_center, size: 16, color: t.primary),
      );
    } else {
      mark = Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: t.muted.withValues(alpha: 0.6), shape: BoxShape.circle),
        ),
      );
    }
    return Semantics(
      label: '${Fmt.weekdayShort(day.date.weekday)}${day.isToday ? ', today' : ''}: $status',
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            Fmt.weekdayShort(day.date.weekday).substring(0, 1),
            style: AppText.label.copyWith(
              color: day.isToday ? t.primary : t.muted,
              fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: Space.xs),
          Container(
            width: 40,
            height: 40,
            padding: day.isToday && !day.done ? EdgeInsets.zero : null,
            decoration: day.isToday
                ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.onSurface.withValues(alpha: 0.6)))
                : null,
            child: Padding(padding: EdgeInsets.all(day.isToday ? 3 : 0), child: mark),
          ),
        ],
      ),
    );
  }
}

/// "1 more workout this week starts your streak."
String _remainingText(int left, bool hasStreak) =>
    '$left more ${left == 1 ? 'workout' : 'workouts'} this week ${hasStreak ? 'keeps it going' : 'starts your streak'}.';
