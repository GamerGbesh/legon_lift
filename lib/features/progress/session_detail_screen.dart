// Owner: WS5. A past workout: exercises, sets and notes, editable after the fact, plus
// "Repeat this workout" (SPEC 4.7). Constructor frozen (route args, SPEC 3.2).
import 'dart:async';

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/history_store.dart';
import '../../state/profile_store.dart';
import '../../state/program_store.dart';
import '../../state/today_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exercise_thumb.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/undo_snackbar.dart';
import '../library/exercise_detail_screen.dart';
import '../session_player/player_screen.dart';
import 'history_format.dart';
import 'progress_widgets.dart';

/// Session detail (route `/history/session`).
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  /// The session to show.
  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final HistoryStore _history = context.read<HistoryStore>();
  late Future<Session?> _future;

  /// Sets deleted on screen but kept in storage until their Undo window closes.
  final Map<String, Timer> _pendingDeletes = {};
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _future = _history.session(widget.sessionId);
  }

  void _reload() {
    final next = _history.session(widget.sessionId);
    setState(() {
      _future = next;
    });
  }

  @override
  void dispose() {
    // Leaving the screen ends the Undo window: delete what is still pending.
    for (final e in _pendingDeletes.entries) {
      e.value.cancel();
      unawaited(_history.deleteSet(e.key));
    }
    _pendingDeletes.clear();
    super.dispose();
  }

  Future<void> _edit(SetLog set, Exercise ex) async {
    final useLb = context.read<ProfileStore>().profile?.useLb ?? false;
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SetEditSheet(set: set, exercise: ex, useLb: useLb),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case _Save(:final set):
        await _history.updateSet(set);
        if (mounted) _reload();
      case _Delete():
        _deleteWithUndo(set);
    }
  }

  void _deleteWithUndo(SetLog set) {
    setState(() {
      _pendingDeletes[set.id] = Timer(Motion.snackUndo + const Duration(milliseconds: 300), () async {
        _pendingDeletes.remove(set.id);
        await _history.deleteSet(set.id);
        if (mounted) _reload();
      });
    });
    showUndoSnackBar(context, 'Set deleted', () {
      final timer = _pendingDeletes.remove(set.id);
      if (timer == null) return;
      timer.cancel();
      if (mounted) setState(() {});
    });
  }

  Future<void> _repeat(Session s) async {
    final today = context.read<TodayStore>();
    final navigator = Navigator.of(context);
    final running = today.inProgress;
    if (running != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Finish or end the workout in progress first.'),
          action: SnackBarAction(
            label: 'Resume',
            onPressed: () => navigator.pushNamed(Routes.session, arguments: PlayerArgs(sessionId: running.id)),
          ),
        ));
      return;
    }
    setState(() => _starting = true);
    try {
      final id = await today.startSession(dayId: s.dayId, hotDay: false, readiness: ReadinessCheck.none);
      await navigator.pushNamed(Routes.session, arguments: PlayerArgs(sessionId: id));
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't start this workout. Check your program on the Program tab.")),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Session?>(
        future: _future,
        builder: (context, snap) {
          final session = snap.data;
          if (snap.connectionState != ConnectionState.done && session == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
          }
          if (session == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.history,
                title: 'Workout not found',
                body: 'It may have been deleted or replaced by a backup import.',
              ),
            );
          }
          final dayOrder = context.select<ProgramStore, List<String>>((p) => p.active?.dayOrder ?? const []);
          final canRepeat = session.status == SessionStatus.completed && dayOrder.contains(session.dayId);
          return Scaffold(
            appBar: AppBar(title: Text(session.dayName)),
            body: _SessionBody(
              session: session,
              hiddenSetIds: _pendingDeletes.keys.toSet(),
              editable: session.status == SessionStatus.completed,
              onEdit: _edit,
            ),
            bottomNavigationBar: canRepeat
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.page),
                      child: BigButton(
                        label: _starting ? 'Starting…' : 'Repeat this workout',
                        icon: Icons.replay,
                        onPressed: _starting ? null : () => unawaited(_repeat(session)),
                      ),
                    ),
                  )
                : null,
          );
        },
      );
}

class _SessionBody extends StatelessWidget {
  const _SessionBody({
    required this.session,
    required this.hiddenSetIds,
    required this.editable,
    required this.onEdit,
  });

  final Session session;
  final Set<String> hiddenSetIds;
  final bool editable;
  final void Function(SetLog set, Exercise ex) onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    final useLb = useLbOf(context);
    final start = session.startedAt;
    final end = session.endedAt;
    final visible = [
      for (final e in [...session.exercises]..sort((a, b) => a.position.compareTo(b.position)))
        if (e.sets.any((s) => !hiddenSetIds.contains(s.id)) || e.status == SessionExerciseStatus.skipped) e,
    ];
    final workingSets =
        session.allSets.where((s) => s.kind == SetKind.working && !hiddenSetIds.contains(s.id)).length;
    final muted = AppText.body.copyWith(color: t.muted);
    final timeRange = end == null
        ? DateFormat('HH:mm').format(start)
        : '${DateFormat('HH:mm').format(start)}-${DateFormat('HH:mm').format(end)} '
            '(${end.difference(start).inMinutes} min)';

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
      children: [
        Text(DateFormat('EEEE d MMMM y').format(start), style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
        Text(timeRange, style: AppText.tabular(muted)),
        const SizedBox(height: Space.m),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            _Tag(text: 'Week ${session.trainingWeek}'),
            _Tag(text: '$workingSets working ${workingSets == 1 ? 'set' : 'sets'}'),
            _Tag(text: 'Volume ${Fmt.weight(session.totalVolumeKg, useLb: useLb, maxDecimals: 0)}'),
            if (session.isDeload) const _Tag(text: 'Easy week'),
            if (session.hotDay) const _Tag(text: 'Hot day'),
            if (session.feeling != null) _Tag(text: 'Felt ${session.feeling}/5'),
          ],
        ),
        if (session.status == SessionStatus.inProgress) ...[
          const SizedBox(height: Space.m),
          Text('This workout is still in progress.', style: muted),
        ],
        if (session.note case final note? when note.trim().isNotEmpty) ...[
          const SizedBox(height: Space.l),
          _NoteCard(text: note),
        ],
        if (editable && visible.isNotEmpty) ...[
          const SizedBox(height: Space.l),
          Text('Logged something wrong? Tap a set to fix it.', style: muted.copyWith(fontSize: 14)),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xl),
            child: Text('No sets were logged in this workout.', style: muted),
          ),
        for (final e in visible)
          if (catalog.tryExercise(e.exerciseId) case final ex?)
            _ExerciseBlock(
              entry: e,
              exercise: ex,
              original: e.originalExerciseId == null ? null : catalog.tryExercise(e.originalExerciseId!),
              hiddenSetIds: hiddenSetIds,
              useLb: useLb,
              onTapSet: editable ? (s) => onEdit(s, ex) : null,
            ),
      ],
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({
    required this.entry,
    required this.exercise,
    required this.original,
    required this.hiddenSetIds,
    required this.useLb,
    required this.onTapSet,
  });

  final SessionExercise entry;
  final Exercise exercise;
  final Exercise? original;
  final Set<String> hiddenSetIds;
  final bool useLb;
  final ValueChanged<SetLog>? onTapSet;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sets = [for (final s in entry.sets) if (!hiddenSetIds.contains(s.id)) s];
    var working = 0;
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () => Navigator.of(context)
                .pushNamed(Routes.exercise, arguments: ExerciseDetailArgs(exerciseId: exercise.id)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.minTap),
              child: Row(
                children: [
                  ExerciseThumb(exercise: exercise, size: 48),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
                        if (original != null)
                          Text('Swapped from ${original!.name}', style: AppText.label.copyWith(color: t.muted)),
                        if (entry.status == SessionExerciseStatus.skipped)
                          Text(_skipText(entry.skipReason), style: AppText.label.copyWith(color: t.warning)),
                      ],
                    ),
                  ),
                  Icon(Icons.info_outline, color: t.muted),
                ],
              ),
            ),
          ),
          for (final s in sets)
            _SetRow(
              set: s,
              exercise: exercise,
              label: setKindLabel(s, s.kind == SetKind.working ? ++working : 0),
              useLb: useLb,
              onTap: onTapSet == null ? null : () => onTapSet!(s),
            ),
          if (entry.note case final note? when note.trim().isNotEmpty) ...[
            const SizedBox(height: Space.s),
            _NoteCard(text: note),
          ],
        ],
      ),
    );
  }

  static String _skipText(SkipReason? r) => switch (r) {
        SkipReason.busy => 'Skipped: equipment was busy',
        SkipReason.pain => 'Skipped: pain',
        SkipReason.noTime => 'Skipped: no time',
        SkipReason.other || null => 'Skipped',
      };
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set, required this.exercise, required this.label, required this.useLb, this.onTap});

  final SetLog set;
  final Exercise exercise;
  final String label;
  final bool useLb;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final light = set.kind == SetKind.warmup || set.kind == SetKind.ramp;
    final color = light ? t.muted : t.onSurface;
    final summary = setSummary(set, exercise, useLb: useLb);
    final rir = set.rir == null ? null : Fmt.rirAnswer(set.rir!);
    return Semantics(
      button: onTap != null,
      label: [
        label,
        summary,
        ?rir,
        if (set.isPr) 'new record',
        if (set.painFlag) 'pain noted',
        if (onTap != null) 'tap to edit',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTap),
          child: Row(
            children: [
              SizedBox(width: 104, child: Text(label, style: AppText.label.copyWith(color: t.muted))),
              Expanded(child: Text(summary, style: AppText.tabular(AppText.body).copyWith(color: color))),
              if (rir != null) Text(rir, style: AppText.label.copyWith(color: t.muted)),
              if (set.isPr) ...[const SizedBox(width: Space.s), Icon(Icons.emoji_events, color: t.primary, size: 20)],
              if (set.painFlag) ...[const SizedBox(width: Space.s), Icon(Icons.healing, color: t.danger, size: 20)],
              if (onTap != null) ...[const SizedBox(width: Space.s), Icon(Icons.edit, color: t.muted, size: 18)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(Radii.chip)),
      child: Text(text, style: AppText.tabular(AppText.label).copyWith(color: t.onSurface)),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.surface2),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, color: t.muted, size: 20),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
        ],
      ),
    );
  }
}

// -- edit sheet ----------------------------------------------------------------------------------

sealed class _EditResult {
  const _EditResult();
}

class _Save extends _EditResult {
  const _Save(this.set);
  final SetLog set;
}

class _Delete extends _EditResult {
  const _Delete();
}

/// Fix a logged set: weight, reps (or time) and "how many more could you have done".
class _SetEditSheet extends StatefulWidget {
  const _SetEditSheet({required this.set, required this.exercise, required this.useLb});

  final SetLog set;
  final Exercise exercise;
  final bool useLb;

  @override
  State<_SetEditSheet> createState() => _SetEditSheetState();
}

class _SetEditSheetState extends State<_SetEditSheet> {
  late double _weight = Units.displayWeight(widget.set.weightKg, useLb: widget.useLb);
  late double _reps = widget.set.reps.toDouble();
  late double _duration = (widget.set.durationSec ?? 0).toDouble();
  late int? _rir = widget.set.rir;

  Exercise get _ex => widget.exercise;
  bool get _asksRir => widget.set.kind == SetKind.working || widget.set.kind == SetKind.test;

  double get _weightStep {
    if (widget.useLb) return 2.5;
    final inc = _ex.weightIncrementKg ?? 2.5;
    return inc > 0 ? inc : 2.5;
  }

  Future<void> _typeWeight() async {
    final unit = Units.weightUnit(useLb: widget.useLb);
    final typed = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => NumberEntrySheet(title: 'Weight ($unit)', initial: _weight),
    );
    if (typed != null && mounted) setState(() => _weight = typed);
  }

  SetLog _result() {
    final kg = double.parse(Units.weightToKg(_weight, useLb: widget.useLb).toStringAsFixed(2));
    return widget.set.copyWith(
      weightKg: _ex.isLoaded ? kg : widget.set.weightKg,
      reps: _ex.tracking == Tracking.time ? widget.set.reps : _reps.round(),
      durationSec: _ex.tracking == Tracking.time ? () => _duration.round() : null,
      rir: _asksRir ? () => _rir : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = Units.weightUnit(useLb: widget.useLb);
    final heading = AppText.label.copyWith(color: t.muted, fontSize: 16);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            Space.page, 0, Space.page, Space.page + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit set', style: AppText.title.copyWith(color: t.onSurface)),
            Text(_ex.name, style: AppText.body.copyWith(color: t.muted)),
            if (_ex.isLoaded) ...[
              const SizedBox(height: Space.l),
              Text(
                _ex.loadType == LoadType.dumbbell && (_ex.dumbbellCount ?? 1) > 1 ? 'Weight of one dumbbell' : 'Weight',
                style: heading,
              ),
              NumberStepper(
                value: _weight,
                step: _weightStep,
                unit: unit,
                max: 1000,
                decimals: 2,
                onChanged: (v) => setState(() => _weight = v),
                onTapValue: () => unawaited(_typeWeight()),
              ),
            ],
            if (_ex.tracking != Tracking.time) ...[
              const SizedBox(height: Space.l),
              Text(_ex.unilateral ? 'Reps (each side)' : 'Reps', style: heading),
              NumberStepper(
                value: _reps,
                step: 1,
                unit: 'reps',
                max: 200,
                decimals: 0,
                onChanged: (v) => setState(() => _reps = v),
              ),
            ] else ...[
              const SizedBox(height: Space.l),
              Text('Time', style: heading),
              NumberStepper(
                value: _duration,
                step: 5,
                unit: 's',
                max: 7200,
                decimals: 0,
                onChanged: (v) => setState(() => _duration = v),
              ),
            ],
            if (_asksRir) ...[
              const SizedBox(height: Space.l),
              Text('How many more could you have done?', style: heading),
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final v in const [0, 1, 2, 3, 4])
                    ChoiceChip(
                      label: Text(Fmt.rirAnswer(v)),
                      selected: _rir == v,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
                      onSelected: (_) => setState(() => _rir = v),
                    ),
                  ChoiceChip(
                    label: const Text('Not answered'),
                    selected: _rir == null,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
                    onSelected: (_) => setState(() => _rir = null),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.xl),
            BigButton(label: 'Save', icon: Icons.check, onPressed: () => Navigator.of(context).pop(_Save(_result()))),
            const SizedBox(height: Space.l),
            BigButton(
              label: 'Delete set',
              icon: Icons.delete_outline,
              kind: BigButtonKind.destructive,
              height: Sizes.minTap,
              onPressed: () => Navigator.of(context).pop(const _Delete()),
            ),
          ],
        ),
      ),
    );
  }
}
