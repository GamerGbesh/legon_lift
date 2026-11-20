// Owner: WS5. Exercise detail: photos, muscles, how-to, video, my history, machine note,
// alternatives and credits (SPEC 4.6). ExerciseDetailArgs and the constructor are frozen (SPEC 3.2).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../core/units.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../services/api.dart';
import '../../state/history_store.dart';
import '../../state/library_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exercise_thumb.dart';
import '../../widgets/frame_animator.dart';
import '../../widgets/muscle_chips.dart';
import '../../widgets/placeholder_figure.dart';
import '../../widgets/section_header.dart';
import '../progress/charts.dart';
import '../progress/history_format.dart';
import '../progress/progress_widgets.dart';
import 'muscle_groups.dart';

/// Arguments of the `/exercise` route.
@immutable
class ExerciseDetailArgs {
  const ExerciseDetailArgs({required this.exerciseId, this.pickMode = false});

  final String exerciseId;

  /// Library opened from the custom-day editor: shows an "Add" button that pops the id.
  final bool pickMode;
}

/// Exercise detail (route `/exercise`). In pick mode, "Add" pops the exercise id (also when the
/// user first moved on to one of the alternatives).
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.args});

  final ExerciseDetailArgs args;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late Future<ExerciseHistory> _history;
  Object? _historyKey;

  void _refreshHistory(HistoryStore h) {
    if (identical(_historyKey, h.recent) && _historyKey != null) return;
    _historyKey = h.recent;
    _history = h.exerciseHistory(widget.args.exerciseId);
  }

  Future<void> _openAlternative(String id) async {
    final navigator = Navigator.of(context);
    final picked = await navigator.pushNamed<Object?>(
      Routes.exercise,
      arguments: ExerciseDetailArgs(exerciseId: id, pickMode: widget.args.pickMode),
    );
    if (widget.args.pickMode && picked is String && mounted) navigator.pop(picked);
  }

  Future<void> _watchVideo(Exercise ex) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<LauncherService>().openVideo(ex);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't open the video. It needs an internet connection.")));
    }
  }

  Future<void> _editNote(Exercise ex, String? current) async {
    final store = context.read<LibraryStore>();
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoteSheet(initial: current ?? ''),
    );
    if (note != null) await store.setMachineNote(ex.id, note);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<AssetCatalog>();
    final ex = catalog.tryExercise(widget.args.exerciseId);
    if (ex == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.help_outline, title: 'Exercise not found'),
      );
    }
    final library = context.watch<LibraryStore>();
    final history = context.watch<HistoryStore>();
    _refreshHistory(history);
    final t = context.tokens;
    final favorite = library.isFavorite(ex.id);
    final prefs = library.prefsFor(ex.id);
    final alternatives = [for (final id in ex.substitutions) ?catalog.tryExercise(id)];
    final body = AppText.body.copyWith(color: t.onSurface);

    return Scaffold(
      appBar: AppBar(
        title: Text(ex.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: favorite ? 'Remove from favourites' : 'Add to favourites',
            iconSize: 28,
            constraints: const BoxConstraints.tightFor(width: Sizes.minTap, height: Sizes.minTap),
            onPressed: () => unawaited(library.toggleFavorite(ex.id)),
            icon: Icon(favorite ? Icons.star : Icons.star_border, color: favorite ? t.primary : null),
          ),
        ],
      ),
      floatingActionButton: widget.args.pickMode
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pop(ex.id),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, 120),
        children: [
          if (ex.localImages.isEmpty)
            AspectRatio(aspectRatio: 1.6, child: PlaceholderFigure(exercise: ex))
          else
            FrameAnimator(assetPaths: ex.localImages, large: true),
          const SizedBox(height: Space.l),
          _QuickFacts(exercise: ex),
          const SizedBox(height: Space.l),
          BigButton(
            label: 'Watch video',
            icon: Icons.play_circle_outline,
            kind: BigButtonKind.secondary,
            height: Sizes.minTap,
            onPressed: () => unawaited(_watchVideo(ex)),
          ),
          const SizedBox(height: Space.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi, size: 16, color: t.muted),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  ex.video == null ? 'Needs internet · opens a YouTube search' : 'Needs internet · opens YouTube',
                  style: AppText.label.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
          const SectionHeader('Muscles worked'),
          MuscleChips(primary: ex.primaryMuscles, secondary: ex.secondaryMuscles),
          if (ex.setup.isNotEmpty) ...[
            const SectionHeader('Setup'),
            _NumberedList(items: ex.setup),
          ],
          if (ex.cues.isNotEmpty) ...[
            const SectionHeader('How to do it'),
            _BulletList(items: ex.cues, icon: Icons.check_circle_outline, color: t.success),
          ],
          if (ex.mistakes.isNotEmpty) ...[
            const SectionHeader('Common mistakes'),
            _BulletList(items: ex.mistakes, icon: Icons.cancel_outlined, color: t.danger),
          ],
          if (ex.breathing.trim().isNotEmpty) ...[
            const SectionHeader('Breathing'),
            Text(ex.breathing, style: body),
          ],
          if (ex.safety.trim().isNotEmpty) ...[
            const SectionHeader('Safety'),
            _SafetyCard(text: ex.safety),
          ],
          const SectionHeader('My history'),
          FutureBuilder<ExerciseHistory>(
            future: _history,
            builder: (context, snap) => snap.hasData
                ? _HistorySection(exercise: ex, history: snap.data!)
                : const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
          ),
          SectionHeader(
            'Machine note',
            trailing: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => unawaited(_editNote(ex, prefs.machineNote)),
              icon: Icon(prefs.machineNote == null ? Icons.add : Icons.edit, size: 18),
              label: Text(prefs.machineNote == null ? 'Add' : 'Edit'),
            ),
          ),
          Text(
            prefs.machineNote ?? 'Seat height, pin number or anything about the machine at your gym.',
            style: prefs.machineNote == null ? AppText.body.copyWith(color: t.muted, fontSize: 14) : body,
          ),
          if (alternatives.isNotEmpty) ...[
            const SectionHeader('Alternatives'),
            for (final alt in alternatives)
              TapRow(
                leading: ExerciseThumb(exercise: alt, size: 48),
                title: alt.name,
                subtitle: [
                  if (alt.primaryMuscles.isNotEmpty) alt.primaryMuscles.first.label,
                  mainEquipmentLabel(alt),
                  if (!library.isAvailable(alt)) 'not ticked in your equipment',
                ].join(' · '),
                onTap: () => unawaited(_openAlternative(alt.id)),
              ),
          ],
          const SizedBox(height: Space.xl),
          _Credits(exercise: ex),
        ],
      ),
    );
  }
}

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ex = exercise;
    final range = ex.repRange;
    final dose = ex.durationSeconds != null
        ? '${ex.defaultSets} × ${durationText(ex.durationSeconds!)}'
        : range == null
            ? null
            : '${ex.defaultSets} × ${range.$1}-${range.$2} reps${ex.unilateral ? ' each side' : ''}';
    final facts = [
      difficultyLabel(ex.difficulty),
      mainEquipmentLabel(ex),
      ?dose,
      if (ex.restSeconds > 0) 'Rest ${durationText(ex.restSeconds)}',
    ];
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final f in facts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
            decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(Radii.chip)),
            child: Text(f, style: AppText.label.copyWith(color: t.onSurface)),
          ),
      ],
    );
  }
}

class _NumberedList extends StatelessWidget {
  const _NumberedList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(right: Space.m),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
                  child: Text('${i + 1}', style: AppText.tabular(AppText.label).copyWith(color: t.onSurface)),
                ),
                Expanded(child: Text(s, style: AppText.body.copyWith(color: t.onSurface))),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.icon, required this.color});

  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: Space.m),
                  child: Icon(icon, size: 22, color: color),
                ),
                Expanded(child: Text(s, style: AppText.body.copyWith(color: t.onSurface))),
              ],
            ),
          ),
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.12),
        border: Border.all(color: t.warning.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_outlined, color: t.warning),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.exercise, required this.history});

  final Exercise exercise;
  final ExerciseHistory history;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final muted = AppText.body.copyWith(color: t.muted, fontSize: 14);
    if (history.isEmpty) return Text("You haven't done this one yet.", style: muted);
    final useLb = useLbOf(context);
    final now = context.read<Clock>().now();
    final best = history.bestSet;
    final points = [for (final (d, v) in history.bestSingle) (d, Units.displayWeight(v, useLb: useLb))];
    final unit = Units.weightUnit(useLb: useLb);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (best != null)
          Row(
            children: [
              Icon(Icons.emoji_events, color: t.primary),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'Best set: ', style: AppText.body.copyWith(color: t.muted)),
                    TextSpan(
                      text: setSummary(best, exercise, useLb: useLb),
                      style: AppText.tabular(AppText.body).copyWith(color: t.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        if (points.length >= 2) ...[
          const SizedBox(height: Space.m),
          Text('Estimated best single', style: AppText.label.copyWith(color: t.muted)),
          const SizedBox(height: Space.xs),
          TrendLineChart(
            points: points,
            unit: unit,
            compact: true,
            semanticLabel: 'Estimated best single over ${points.length} sessions, latest '
                '${points.last.$2.toStringAsFixed(1)} $unit.',
          ),
        ],
        const SizedBox(height: Space.m),
        Text('Last sessions', style: AppText.label.copyWith(color: t.muted)),
        for (final s in history.recent)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.button),
            onTap: () => Navigator.of(context).pushNamed(Routes.historySession, arguments: s.sessionId),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.minTap),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 104, child: Text(shortDate(s.date, now: now), style: muted)),
                    Expanded(
                      child: Text(
                        s.sets.map((x) => setSummary(x, exercise, useLb: useLb)).join('\n'),
                        style: AppText.tabular(AppText.body).copyWith(color: t.onSurface, fontSize: 15),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.muted),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final video = exercise.video;
    final lines = [
      if (exercise.freeExerciseDbId != null && exercise.localImages.isNotEmpty)
        'Photos: free-exercise-db (public domain, Unlicense).',
      if (video != null) 'Video: "${video.title}" by ${video.channel} on YouTube.',
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Text(lines.join('\n'), style: AppText.caption.copyWith(color: t.muted));
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.initial});

  final String initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Machine note', style: AppText.title.copyWith(color: context.tokens.onSurface)),
            const SizedBox(height: Space.m),
            TextField(
              controller: _c,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Seat on 4, start with the pin on 25',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Space.m),
            BigButton(label: 'Save note', onPressed: () => Navigator.of(context).pop(_c.text)),
          ],
        ),
      );
}
