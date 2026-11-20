// Owner: WS5. Progress tab: Overview, Exercises, Body and Calendar (SPEC 4.7).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../state/history_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../library/muscle_groups.dart';
import 'calendar_view.dart';
import 'charts.dart';
import 'history_format.dart';
import 'progress_body_view.dart';
import 'progress_exercises_view.dart';
import 'progress_widgets.dart';

/// The four Progress views (SPEC 4.7).
enum ProgressView { overview, exercises, body, calendar }

/// Progress screen (tab).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressView _view = ProgressView.overview;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.s),
              child: SegmentedButton<ProgressView>(
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: false,
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
                  textStyle: WidgetStatePropertyAll(AppText.label),
                ),
                segments: [
                  for (final (v, label) in const [
                    (ProgressView.overview, 'Overview'),
                    (ProgressView.exercises, 'Exercises'),
                    (ProgressView.body, 'Body'),
                    (ProgressView.calendar, 'Calendar'),
                  ])
                    ButtonSegment(
                      value: v,
                      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
                    ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
            Expanded(
              child: switch (_view) {
                ProgressView.overview => const OverviewView(),
                ProgressView.exercises => const ProgressExercisesView(),
                ProgressView.body => const ProgressBodyView(),
                ProgressView.calendar => const CalendarView(),
              },
            ),
          ],
        ),
      );
}

/// Overview: workouts this month, weekly volume, hard sets per muscle, recent records.
class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryStore>();
    final t = context.tokens;
    final useLb = useLbOf(context);
    final now = context.read<Clock>().now();
    if (!h.loaded) return const Center(child: CircularProgressIndicator());
    if (h.recent.isEmpty) {
      return const EmptyState(
        icon: Icons.insights,
        title: 'No workouts yet',
        body: 'Finish your first workout and your progress shows up here.',
      );
    }
    final groups = trainingGroups;
    final caption = AppText.body.copyWith(color: t.muted, fontSize: 14);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: StatTile(label: 'Workouts this month', value: '${h.sessionsThisMonth}')),
            const SizedBox(width: Space.s),
            Expanded(child: StatTile(label: 'Working sets this week', value: '${h.thisWeek.workingSets}')),
          ],
        ),
        const SectionHeader('Weekly volume'),
        Text('Weight × reps of your working sets, per week (Monday to Sunday).', style: caption),
        const SizedBox(height: Space.m),
        ChartCard(child: WeeklyVolumeChart(weeks: h.weeklyVolume, useLb: useLb)),
        const SectionHeader('Hard sets per muscle this week'),
        Text(
          'Aim for 10-20 sets per muscle each week (the shaded band). A working set counts once for '
          'the main muscle and half for helper muscles.',
          style: caption,
        ),
        const SizedBox(height: Space.m),
        ChartCard(
          child: HardSetsChart(
            groups: groups,
            values: [for (final g in groups) groupHardSets(g, h.thisWeek.hardSets)],
          ),
        ),
        const SectionHeader('Recent records'),
        if (h.recentPrs.isEmpty)
          Text(
            'No records yet. Your first session of each exercise sets the starting point; '
            'beat it later and it shows up here.',
            style: caption,
          )
        else
          for (final pr in h.recentPrs)
            TapRow(
              leading: Icon(Icons.emoji_events, color: t.primary, size: 28),
              title: pr.exercise.name,
              subtitle: '${setSummary(pr.set, pr.exercise, useLb: useLb)} · '
                  '${shortDate(pr.set.completedAt, now: now)}',
              onTap: () => Navigator.of(context).pushNamed(Routes.historySession, arguments: pr.sessionId),
            ),
      ],
    );
  }
}
