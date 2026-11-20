// Owner: WS5. Progress > Calendar: 20-week heatmap and a month calendar (SPEC 4.7).
import 'dart:async';

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../state/history_store.dart';
import '../../widgets/section_header.dart';
import 'activity_heatmap.dart';
import 'history_format.dart';
import 'progress_widgets.dart';

/// Heatmap of the last 20 weeks, then a month calendar with that month's workouts listed.
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _month;
  Future<List<Session>>? _monthSessions;
  (DateTime, List<Session>)? _loadedFor;

  @override
  void initState() {
    super.initState();
    final now = context.read<Clock>().now();
    _month = DateTime(now.year, now.month);
  }

  /// Re-queries the month when the month or the store's history changes.
  Future<List<Session>> _sessionsFor(HistoryStore h) {
    final key = (_month, h.recent);
    if (_monthSessions == null || _loadedFor != key) {
      _loadedFor = key;
      _monthSessions = h.sessions(from: _month, to: DateTime(_month.year, _month.month + 1));
    }
    return _monthSessions!;
  }

  void _openDay(BuildContext context, DateTime day, List<Session> sessions) {
    final now = context.read<Clock>().now();
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('No workout on ${shortDate(day, now: now)}')));
    } else if (sessions.length == 1) {
      unawaited(Navigator.of(context).pushNamed(Routes.historySession, arguments: sessions.first.id));
    } else {
      unawaited(showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
            children: [
              for (final s in sessions)
                SessionRow(
                  session: s,
                  now: now,
                  onTap: () {
                    Navigator.of(sheet).pop();
                    unawaited(Navigator.of(context).pushNamed(Routes.historySession, arguments: s.id));
                  },
                ),
            ],
          ),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryStore>();
    final t = context.tokens;
    final now = context.read<Clock>().now();
    if (!h.loaded) return const Center(child: CircularProgressIndicator());
    final thisMonth = DateTime(now.year, now.month);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
      children: [
        const SectionHeader('Last ${HistoryStore.windowWeeks} weeks'),
        ActivityHeatmap(
          start: h.windowStart,
          weeks: HistoryStore.windowWeeks,
          setsByDay: h.workingSetsByDay,
          today: now,
          onTapDay: (day) => _openDay(context, day, h.sessionsOn(Fmt.dateKey(day))),
        ),
        const SizedBox(height: Space.s),
        const HeatmapLegend(),
        const SizedBox(height: Space.l),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              iconSize: 28,
              constraints: const BoxConstraints.tightFor(width: Sizes.minTap, height: Sizes.minTap),
              onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM y').format(_month),
                textAlign: TextAlign.center,
                style: AppText.title.copyWith(fontSize: 18, color: t.onSurface),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              iconSize: 28,
              constraints: const BoxConstraints.tightFor(width: Sizes.minTap, height: Sizes.minTap),
              onPressed: _month.isBefore(thisMonth)
                  ? () => setState(() => _month = DateTime(_month.year, _month.month + 1))
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        FutureBuilder<List<Session>>(
          future: _sessionsFor(h),
          builder: (context, snap) {
            final sessions = snap.data ?? const <Session>[];
            final byDay = <String, List<Session>>{};
            for (final s in sessions) {
              (byDay[Fmt.dateKey(s.startedAt)] ??= []).add(s);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonthGrid(
                  month: _month,
                  today: now,
                  trainedDays: byDay.keys.toSet(),
                  onTapDay: (day) => _openDay(context, day, byDay[Fmt.dateKey(day)] ?? const []),
                ),
                const SizedBox(height: Space.m),
                if (snap.connectionState == ConnectionState.done && sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.l),
                    child: Text(
                      'No workouts in ${DateFormat('MMMM').format(_month)}.',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: t.muted),
                    ),
                  ),
                for (final s in sessions.reversed)
                  SessionRow(
                    session: s,
                    now: now,
                    onTap: () => Navigator.of(context).pushNamed(Routes.historySession, arguments: s.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A completed workout as a tappable row: name, date, length and sets.
class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.session, required this.now, required this.onTap});

  final Session session;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sets = session.allSets.where((s) => s.kind == SetKind.working).length;
    final minutes = session.duration?.inMinutes;
    return TapRow(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: t.surface2,
        child: Icon(Icons.fitness_center, color: t.primary, size: 22),
      ),
      title: session.dayName,
      subtitle: [
        shortDate(session.startedAt, now: now),
        if (minutes != null) '$minutes min',
        '$sets ${sets == 1 ? 'set' : 'sets'}',
      ].join(' · '),
      onTap: onTap,
    );
  }
}

/// A Monday-first month grid; trained days are filled, today is outlined.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.today,
    required this.trainedDays,
    required this.onTapDay,
  });

  final DateTime month;
  final DateTime today;

  /// `yyyy-MM-dd` keys of days with a workout.
  final Set<String> trainedDays;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final todayKey = Fmt.dateKey(today);
    final labelStyle = AppText.label.copyWith(color: t.muted);
    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(child: Center(child: Text(d, style: labelStyle))),
          ],
        ),
        const SizedBox(height: Space.xs),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _dayCell(context, r * 7 + c - lead + 1, daysInMonth, todayKey),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, int day, int daysInMonth, String todayKey) {
    if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
    final t = context.tokens;
    final date = DateTime(month.year, month.month, day);
    final key = Fmt.dateKey(date);
    final trained = trainedDays.contains(key);
    final isToday = key == todayKey;
    final label = DateFormat('EEEE d MMMM').format(date);
    return Semantics(
      button: trained,
      label: trained ? '$label, workout done' : label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: trained ? () => onTapDay(date) : null,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: trained ? t.primary : null,
              border: isToday ? Border.all(color: t.onSurface, width: 2) : null,
            ),
            child: Text(
              '$day',
              style: AppText.tabular(AppText.body).copyWith(
                color: trained ? t.onPrimary : (date.isAfter(today) ? t.muted : t.onSurface),
                fontWeight: trained ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
