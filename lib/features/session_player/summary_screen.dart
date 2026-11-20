// Owner: WS3. Workout summary (SPEC 4.4): confetti on a PR, first session or milestone; tiles,
// new bests, "Next time" weights with the reason, optional feeling / body weight / note, earned
// milestones, Done -> Today.
import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../state/body_store.dart';
import '../../state/milestone_store.dart';
import '../../state/profile_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';

/// Workout summary screen.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.sessionId});

  /// The completed session.
  final String sessionId;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _Best {
  const _Best(this.exercise, this.record);

  final Exercise exercise;
  final PersonalRecord record;
}

class _NextTime {
  const _NextTime(this.exercise, this.state);

  final Exercise exercise;
  final ExerciseState state;
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));
  final _note = TextEditingController();
  Session? _session;
  List<_Best> _bests = const [];
  List<_NextTime> _next = const [];
  List<Milestone> _milestones = const [];
  bool _firstEver = false;
  bool _loaded = false;
  int? _feeling;
  double? _bodyweight;
  bool _logWeight = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _confetti.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sessions = context.read<SessionRepository>();
    final states = context.read<ExerciseStateRepository>();
    final catalog = context.read<AssetCatalog>();
    final milestones = context.read<MilestoneStore>();
    final body = context.read<BodyStore>();
    final profileWeight = context.read<ProfileStore>().profile?.weightKg;
    final s = await sessions.byId(widget.sessionId);
    if (s == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final setIds = {for (final x in s.allSets) x.id};
    final bests = <_Best>[];
    final next = <_NextTime>[];
    for (final id in {for (final se in s.exercises) se.exerciseId}) {
      final ex = catalog.tryExercise(id);
      if (ex == null) continue;
      final prs = (await states.records(id)).where((r) => setIds.contains(r.setLogId)).toList();
      final pr = prs.where((r) => r.type == PrType.e1rm).firstOrNull ?? prs.firstOrNull;
      final markedNew = s.allSets.any((x) => x.exerciseId == id && x.isPr);
      if (pr != null && markedNew) bests.add(_Best(ex, pr));
      final st = await states.get(id);
      if (st != null && st.lastSessionId == s.id && ex.isLoaded && st.workingKg != null) next.add(_NextTime(ex, st));
    }
    final completed = await sessions.countCompleted(programId: s.programId, excludeDeload: false);
    final lastWeight = body.entries.where((e) => e.weightKg != null).lastOrNull?.weightKg;
    if (!mounted) return;
    setState(() {
      _session = s;
      _bests = bests;
      _next = next;
      _milestones = milestones.recent;
      _firstEver = completed <= 1;
      _bodyweight = s.bodyweightKg ?? lastWeight ?? profileWeight ?? 95;
      _loaded = true;
    });
    if (bests.isNotEmpty || _firstEver || _milestones.isNotEmpty) _confetti.play();
  }

  Future<void> _done() async {
    final s = _session;
    final navigator = Navigator.of(context);
    if (s != null) {
      final note = _note.text.trim();
      final weight = _logWeight ? _bodyweight : null;
      if (_feeling != null || note.isNotEmpty || weight != null) {
        await context.read<SessionRepository>().saveReflection(
              s.id,
              feeling: _feeling,
              note: note.isEmpty ? null : note,
              bodyweightKg: weight,
            );
      }
      if (weight != null && mounted) {
        final date = Fmt.dateKey(context.read<Clock>().now().toLocal());
        final body = context.read<BodyStore>();
        final existing = body.entries.where((e) => e.date == date).firstOrNull;
        await body.upsert(BodyEntry(date: date, weightKg: weight, waistCm: existing?.waistCm, note: existing?.note));
      }
    }
    navigator.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _session;
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: BigButton(label: 'Back to Today', onPressed: _done)),
      );
    }
    final minutes = (s.endedAt ?? s.startedAt).difference(s.startedAt).inSeconds;
    final workSets = s.allSets.where((x) => x.countsAsWork).length;
    final exercises = s.exercises.where((e) => e.sets.any((x) => x.countsAsWork)).length;
    final headline = _firstEver
        ? 'First workout done!'
        : _bests.isNotEmpty
            ? 'New bests today!'
            : 'Workout done';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_done());
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.xxl),
                children: [
                  Icon(Icons.emoji_events, size: 56, color: t.secondary),
                  const SizedBox(height: Space.s),
                  Text(headline, textAlign: TextAlign.center, style: AppText.headline.copyWith(color: t.onSurface)),
                  const SizedBox(height: Space.xs),
                  Text(s.dayName, textAlign: TextAlign.center, style: AppText.body.copyWith(color: t.muted)),
                  const SizedBox(height: Space.xl),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Space.m,
                    crossAxisSpacing: Space.m,
                    childAspectRatio: 1.7,
                    children: [
                      StatTile(label: 'Time', value: Fmt.minutes(minutes)),
                      StatTile(label: 'Sets', value: '$workSets'),
                      StatTile(label: 'Volume', value: Fmt.weight(s.totalVolumeKg, maxDecimals: 0)),
                      StatTile(label: 'Exercises', value: '$exercises'),
                    ],
                  ),
                  if (_bests.isNotEmpty) ...[
                    const SectionHeader('New bests'),
                    for (final b in _bests)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.emoji_events, color: t.secondary),
                        title: Text(b.exercise.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                        subtitle: Text(
                          switch (b.record.type) {
                            PrType.e1rm => 'Estimated best single: ${Fmt.weight(b.record.value)}',
                            PrType.maxWeight => 'Heaviest weight: ${Fmt.weight(b.record.value)}',
                            PrType.bestVolume => 'Most work in one set: ${Fmt.weight(b.record.value, maxDecimals: 0)}',
                          },
                          style: AppText.label.copyWith(color: t.muted),
                        ),
                      ),
                  ],
                  if (_next.isNotEmpty) ...[
                    const SectionHeader('Next time'),
                    for (final n in _next) _NextTimeRow(item: n),
                  ],
                  if (_milestones.isNotEmpty) ...[
                    const SectionHeader('Milestones earned'),
                    for (final m in _milestones)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.military_tech, color: t.primary, size: 32),
                        title: Text(m.title, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                        subtitle: Text(m.desc, style: AppText.label.copyWith(color: t.muted)),
                      ),
                  ],
                  const SectionHeader('How did it feel?'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final (v, icon, label) in const [
                        (1, Icons.sentiment_very_dissatisfied, 'Awful'),
                        (2, Icons.sentiment_dissatisfied, 'Hard'),
                        (3, Icons.sentiment_neutral, 'OK'),
                        (4, Icons.sentiment_satisfied, 'Good'),
                        (5, Icons.sentiment_very_satisfied, 'Great'),
                      ])
                        Column(
                          children: [
                            IconButton(
                              iconSize: 40,
                              tooltip: label,
                              onPressed: () => setState(() => _feeling = _feeling == v ? null : v),
                              icon: Icon(icon, color: _feeling == v ? t.primary : t.muted),
                            ),
                            Text(label, style: AppText.caption.copyWith(color: _feeling == v ? t.primary : t.muted)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.l),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Log my body weight', style: AppText.body.copyWith(color: t.onSurface)),
                    subtitle: Text('Best first thing in the morning, but any time is fine.',
                        style: AppText.label.copyWith(color: t.muted)),
                    value: _logWeight,
                    onChanged: (v) => setState(() => _logWeight = v),
                  ),
                  if (_logWeight)
                    NumberStepper(
                      value: _bodyweight ?? 95,
                      step: 0.1,
                      min: 30,
                      max: 250,
                      unit: 'kg',
                      onChanged: (v) => setState(() => _bodyweight = v),
                    ),
                  const SizedBox(height: Space.l),
                  TextField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'e.g. leg press was busy, felt strong today',
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  BigButton(label: 'Done', icon: Icons.check, onPressed: _done),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                blastDirection: math.pi / 2,
                numberOfParticles: 25,
                gravity: 0.25,
                colors: [t.primary, t.secondary, t.success, t.onSurface],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextTimeRow extends StatelessWidget {
  const _NextTimeRow({required this.item});

  final _NextTime item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = item.state;
    final (icon, color) = switch (st.lastTrend) {
      Trend.up => (Icons.arrow_upward, t.success),
      Trend.down || Trend.deload => (Icons.arrow_downward, t.warning),
      _ => (Icons.arrow_forward, t.muted),
    };
    final ex = item.exercise;
    final perHand = ex.loadType == LoadType.dumbbell && (ex.dumbbellCount ?? 1) >= 2;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(ex.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
      subtitle: st.lastReason.isEmpty ? null : Text(st.lastReason, style: AppText.label.copyWith(color: t.muted)),
      trailing: Text(
        '${perHand ? '2 × ' : ''}${Fmt.weight(st.workingKg!)}',
        style: AppText.tabular(AppText.bodyStrong).copyWith(color: color == t.muted ? t.onSurface : color),
      ),
    );
  }
}
