// Owner: WS3. Bottom sheets and dialogs of the player (SPEC 4.4): edit set, swap ("Machine busy?"),
// step list, More, pain check, "I feel unwell", machine note and End workout.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../services/api.dart';
import '../../../state/session_player_controller.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/exercise_thumb.dart';
import '../../../widgets/number_stepper.dart';
import 'player_copy.dart';

Future<T?> _sheet<T>(BuildContext context, SessionPlayerController c, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider<SessionPlayerController>.value(value: c, child: Builder(builder: builder)),
    );

Widget _sheetTitle(BuildContext context, String title, {String? subtitle}) {
  final t = context.tokens;
  return Padding(
    padding: const EdgeInsets.only(bottom: Space.l),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.title.copyWith(color: t.onSurface)),
        if (subtitle != null) ...[
          const SizedBox(height: Space.xs),
          Text(subtitle, style: AppText.body.copyWith(color: t.muted)),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------------------------
// Edit a logged set

Future<void> showEditSetSheet(BuildContext context, SessionPlayerController c, SetLog log, Exercise ex) =>
    _sheet<void>(context, c, (_) => _EditSetSheet(log: log, exercise: ex));

class _EditSetSheet extends StatefulWidget {
  const _EditSetSheet({required this.log, required this.exercise});

  final SetLog log;
  final Exercise exercise;

  @override
  State<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<_EditSetSheet> {
  late double _kg = widget.log.weightKg;
  late int _reps = widget.log.reps;
  late int? _rir = widget.log.rir;
  late int _sec = widget.log.durationSec ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.read<SessionPlayerController>();
    final ex = widget.exercise;
    final timed = ex.tracking == Tracking.time;
    final messenger = ScaffoldMessenger.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle(context, 'Fix this set', subtitle: ex.name),
          if (ex.isLoaded) ...[
            NumberStepper(
              value: _kg,
              step: c.weightStep(ex),
              unit: 'kg',
              decimals: 2,
              onChanged: (v) => setState(() => _kg = v),
            ),
            const SizedBox(height: Space.m),
          ],
          if (timed)
            NumberStepper(
              value: _sec.toDouble(),
              step: 5,
              unit: 'sec',
              decimals: 0,
              onChanged: (v) => setState(() => _sec = v.round()),
            )
          else
            NumberStepper(
              value: _reps.toDouble(),
              step: 1,
              unit: 'reps',
              decimals: 0,
              max: 100,
              onChanged: (v) => setState(() => _reps = v.round()),
            ),
          if (!timed) ...[
            const SizedBox(height: Space.l),
            Text('How many more could you have done?', style: AppText.label.copyWith(color: context.tokens.muted)),
            const SizedBox(height: Space.s),
            RirButtons(selected: _rir, onSelected: (v) => setState(() => _rir = v)),
          ],
          const SizedBox(height: Space.xl),
          BigButton(
            label: 'Save',
            icon: Icons.check,
            onPressed: () async {
              Navigator.of(context).pop();
              await c.editSet(widget.log.id, weightKg: _kg, reps: _reps, rir: _rir, durationSec: timed ? _sec : null);
            },
          ),
          const SizedBox(height: Space.s),
          BigButton(
            label: 'Delete set',
            icon: Icons.delete_outline,
            kind: BigButtonKind.destructive,
            height: Sizes.heroButton,
            onPressed: () async {
              Navigator.of(context).pop();
              final deleted = await c.deleteSet(widget.log.id);
              if (deleted == null) return;
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(SnackBar(
                content: const Text('Set deleted'),
                duration: Motion.snackUndo,
                action: SnackBarAction(label: 'Undo', onPressed: () => unawaited(c.restoreSet(deleted))),
              ));
            },
          ),
        ],
      ),
    );
  }
}

/// 0 / 1 / 2 / 3 / 4+ buttons ("How many more could you have done?").
class RirButtons extends StatelessWidget {
  const RirButtons({super.key, required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (final (i, (value, label, caption)) in PlayerCopy.rirOptions.indexed) ...[
          if (i > 0) const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: Sizes.rirButton,
                  width: double.infinity,
                  child: selected == value
                      ? FilledButton(
                          onPressed: () => onSelected(null),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                          ),
                          child: Text(label, style: AppText.title),
                        )
                      : OutlinedButton(
                          onPressed: () => onSelected(value),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: t.onSurface,
                            side: BorderSide(color: t.muted),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                          ),
                          child: Text(label, style: AppText.title),
                        ),
                ),
                SizedBox(
                  height: 18,
                  child: caption == null
                      ? null
                      : Text(caption, style: AppText.caption.copyWith(color: t.muted), maxLines: 1),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Swap ("Machine busy?")

Future<void> showSwapSheet(BuildContext context, SessionPlayerController c, SessionExercise se) =>
    _sheet<void>(context, c, (_) => _SwapSheet(se: se));

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.se});

  final SessionExercise se;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  SwapScope _scope = SwapScope.today;

  Future<void> _swap(String exerciseId) async {
    final c = context.read<SessionPlayerController>();
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    navigator.pop();
    final askDefault = await c.swap(widget.se, exerciseId, _scope);
    if (!askDefault || !rootContext.mounted) return;
    final yes = await showDialog<bool>(
      context: rootContext,
      builder: (context) => AlertDialog(
        title: const Text('Make this your default?'),
        content: Text('You swapped to ${c.catalog.exercise(exerciseId).name} last time too. '
            'Use it in your program from now on?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes, make it default')),
        ],
      ),
    );
    if (yes ?? false) {
      final se = c.currentStop?.exercises.where((e) => e.exerciseId == exerciseId).firstOrNull;
      if (se != null) await c.makeDefault(se);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final ex = c.exerciseOf(widget.se);
    final options = c.swapOptions(widget.se);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
        children: [
          _sheetTitle(context, 'Machine busy?', subtitle: ex.name),
          _ActionTile(
            icon: Icons.hourglass_bottom,
            title: 'Wait 2 min / ask to work in',
            subtitle: PlayerCopy.waitEtiquette,
            onTap: () {
              Navigator.of(context).pop();
              unawaited(c.startWait());
            },
          ),
          if (c.canDoNextFirst())
            _ActionTile(
              icon: Icons.low_priority,
              title: 'Do the next exercise first',
              subtitle: 'Come back to this one after.',
              onTap: () {
                Navigator.of(context).pop();
                unawaited(c.doNextFirst());
              },
            ),
          if (c.isLastExercise)
            _ActionTile(
              icon: Icons.skip_next,
              title: 'Skip it today',
              subtitle: 'It stays in your program for next time.',
              onTap: () {
                Navigator.of(context).pop();
                unawaited(c.skipExercise(SkipReason.busy));
              },
            ),
          const SizedBox(height: Space.l),
          Text('Or swap for', style: PlayerText.strong(AppText.body).copyWith(color: t.onSurface)),
          const SizedBox(height: Space.s),
          SegmentedButton<SwapScope>(
            segments: const [
              ButtonSegment(value: SwapScope.today, label: Text('Just today')),
              ButtonSegment(value: SwapScope.program, label: Text('In my program')),
              ButtonSegment(value: SwapScope.notAtGym, label: Text('Not at my gym')),
            ],
            selected: {_scope},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
          if (_scope == SwapScope.notAtGym)
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                '${ex.name} will be hidden and replaced in your program. Undo in Settings > Equipment.',
                style: AppText.label.copyWith(color: t.muted),
              ),
            ),
          const SizedBox(height: Space.m),
          if (options.isEmpty)
            Text('No alternatives with your equipment. Wait for the machine or do the next exercise first.',
                style: AppText.body.copyWith(color: t.muted)),
          for (final o in options)
            Card(
              margin: const EdgeInsets.only(bottom: Space.s),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.card),
                onTap: () => _swap(o.exercise.id),
                child: Padding(
                  padding: const EdgeInsets.all(Space.m),
                  child: Row(
                    children: [
                      ExerciseThumb(exercise: o.exercise),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.exercise.name, style: PlayerText.strong(AppText.body).copyWith(color: t.onSurface)),
                            const SizedBox(height: Space.xs),
                            Text(o.why, style: AppText.label.copyWith(color: t.muted)),
                            if (!o.hasHistory)
                              Text('New: you will find your weight first',
                                  style: AppText.caption.copyWith(color: t.secondary)),
                          ],
                        ),
                      ),
                      Icon(Icons.swap_horiz, color: t.primary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, this.subtitle, required this.onTap, this.color});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      minTileHeight: Sizes.minTap + 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.s),
      leading: Icon(icon, color: color ?? t.primary, size: 28),
      title: Text(title, style: PlayerText.strong(AppText.body).copyWith(color: color ?? t.onSurface)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: AppText.label.copyWith(color: t.muted)),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Step list (tap the progress bar)

Future<void> showStepListSheet(BuildContext context, SessionPlayerController c) =>
    _sheet<void>(context, c, (_) => const _StepListSheet());

class _StepListSheet extends StatelessWidget {
  const _StepListSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final current = c.currentStop?.id;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
        children: [
          _sheetTitle(context, "Today's plan", subtitle: 'Tap anything not done yet to jump to it.'),
          for (final s in c.stops)
            ListTile(
              minTileHeight: Sizes.minTap,
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.s),
              leading: Icon(
                switch (s.state) {
                  StopState.done => Icons.check_circle,
                  StopState.skipped => Icons.remove_circle_outline,
                  StopState.pending => s.id == current ? Icons.play_circle : Icons.radio_button_unchecked,
                },
                color: switch (s.state) {
                  StopState.done => t.success,
                  StopState.skipped => t.muted,
                  StopState.pending => s.id == current ? t.primary : t.muted,
                },
              ),
              title: Text(
                c.stopTitle(s),
                style: AppText.body.copyWith(
                  color: s.isPending ? t.onSurface : t.muted,
                  fontWeight: s.id == current ? FontWeight.w700 : null,
                ),
              ),
              onTap: s.isPending && s.id != current
                  ? () {
                      Navigator.of(context).pop();
                      unawaited(c.jumpTo(s.id));
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// More menu

Future<void> showMoreSheet(BuildContext context, SessionPlayerController c) =>
    _sheet<void>(context, c, (_) => const _MoreSheet());

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final stop = c.currentStop;
    final hasSets = stop?.kind.hasSets ?? false;
    final row = c.activeRow;
    final rootContext = Navigator.of(context).context;
    void act(Future<void> Function() f) {
      Navigator.of(context).pop();
      unawaited(f());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasSets && row != null) ...[
            _ActionTile(icon: Icons.redo, title: 'Skip this set', onTap: () => act(c.skipSet)),
            _ActionTile(icon: Icons.add, title: 'Add a set', onTap: () => act(c.addSet)),
            _ActionTile(icon: Icons.remove, title: 'Remove a set', onTap: () => act(c.removeSet)),
          ],
          if (hasSets && c.canUndo) _ActionTile(icon: Icons.undo, title: 'Undo last set', onTap: () => act(c.undoLast)),
          if (hasSets)
            _ActionTile(
              icon: Icons.skip_next,
              title: 'Skip this exercise',
              subtitle: 'It stays in your program.',
              onTap: () => act(() => c.skipExercise(SkipReason.other)),
            ),
          if (hasSets && c.canDoNextFirst())
            _ActionTile(icon: Icons.low_priority, title: 'Do the next exercise first', onTap: () => act(c.doNextFirst)),
          if (stop?.kind == StopKind.extra)
            _ActionTile(icon: Icons.fast_forward, title: 'Skip the extras', onTap: () => act(c.skipExtras)),
          if (hasSets && row != null)
            _ActionTile(
              icon: Icons.sticky_note_2_outlined,
              title: 'Machine note',
              subtitle: c.prefsFor(row.exercise.id).machineNote ?? 'Seat height, pin, handle…',
              onTap: () {
                Navigator.of(context).pop();
                unawaited(showMachineNoteDialog(rootContext, c, row.exercise));
              },
            ),
          if (hasSets)
            _ActionTile(
              icon: Icons.healing,
              title: 'It hurts',
              color: t.warning,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(showPainSheet(rootContext, c));
              },
            ),
          _ActionTile(
            icon: Icons.sick_outlined,
            title: 'I feel unwell',
            color: t.danger,
            onTap: () {
              Navigator.of(context).pop();
              unawaited(showUnwellSheet(rootContext, c));
            },
          ),
          const Divider(),
          _ActionTile(
            icon: Icons.flag_outlined,
            title: 'End workout',
            onTap: () {
              Navigator.of(context).pop();
              unawaited(showEndWorkoutSheet(rootContext, c));
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showMachineNoteDialog(BuildContext context, SessionPlayerController c, Exercise ex) async {
  final controller = TextEditingController(text: c.prefsFor(ex.id).machineNote ?? '');
  final note = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Machine note: ${ex.name}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(hintText: 'e.g. seat 4, back pad 2'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
      ],
    ),
  );
  controller.dispose();
  if (note != null) await c.setMachineNote(ex.id, note);
}

// ---------------------------------------------------------------------------------------------
// Pain check

Future<void> showPainSheet(BuildContext context, SessionPlayerController c) async {
  await c.markPain();
  if (!context.mounted) return;
  final se = c.activeRow?.se ?? c.currentStop?.exercise;
  await _sheet<void>(
    context,
    c,
    (context) {
      final t = context.tokens;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetTitle(context, PlayerCopy.painTitle),
            for (final line in PlayerCopy.painRule)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: t.warning),
                    const SizedBox(width: Space.m),
                    Expanded(child: Text(line, style: AppText.body.copyWith(color: t.onSurface))),
                  ],
                ),
              ),
            const SizedBox(height: Space.l),
            if (se != null)
              BigButton(
                label: 'Swap for an easier exercise',
                icon: Icons.swap_horiz,
                onPressed: () {
                  final root = Navigator.of(context).context;
                  Navigator.of(context).pop();
                  unawaited(showSwapSheet(root, c, se));
                },
              ),
            const SizedBox(height: Space.s),
            BigButton(
              label: 'Skip this exercise',
              kind: BigButtonKind.secondary,
              height: Sizes.heroButton,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(c.skipExercise(SkipReason.pain));
              },
            ),
            const SizedBox(height: Space.s),
            BigButton(
              label: "It's mild, keep going",
              kind: BigButtonKind.destructive,
              height: Sizes.heroButton,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------------------------
// I feel unwell

Future<void> showUnwellSheet(BuildContext context, SessionPlayerController c) => _sheet<void>(
      context,
      c,
      (context) {
        final t = context.tokens;
        final safety = context.read<AssetCatalog>().personalization.safety;
        final heat = [
          for (final h in (safety['heat_illness'] as List?) ?? const <Object?>[])
            if (h is Map) h.cast<String, Object?>(),
        ];
        final flags = [for (final f in (safety['red_flags_stop_now'] as List?) ?? const <Object?>[]) '$f'];
        final launcher = context.read<LauncherService>();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
            children: [
              _sheetTitle(context, 'Stop and take care of yourself',
                  subtitle: 'Sit down somewhere cool, sip water, and tell someone near you.'),
              Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: 'Call 112',
                      icon: Icons.call,
                      height: Sizes.heroButton,
                      kind: BigButtonKind.secondary,
                      onPressed: () => unawaited(launcher.call('112')),
                    ),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: BigButton(
                      label: 'Ambulance 193',
                      icon: Icons.local_hospital,
                      height: Sizes.heroButton,
                      kind: BigButtonKind.secondary,
                      onPressed: () => unawaited(launcher.call('193')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.l),
              Text('Get help now if you have', style: PlayerText.strong(AppText.body).copyWith(color: t.danger)),
              const SizedBox(height: Space.s),
              for (final f in flags)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.xs),
                  child: Text('• $f', style: AppText.body.copyWith(color: t.onSurface)),
                ),
              for (final h in heat) ...[
                const SizedBox(height: Space.l),
                Text(
                  switch (h['severity']) {
                    'emergency' => 'Heat stroke (emergency)',
                    'moderate' => 'Heat exhaustion',
                    _ => 'Dehydration or cramps',
                  },
                  style: PlayerText.strong(AppText.body)
                      .copyWith(color: h['severity'] == 'emergency' ? t.danger : t.warning),
                ),
                const SizedBox(height: Space.xs),
                Text('Signs: ${((h['signs'] as List?) ?? const []).join(', ')}',
                    style: AppText.label.copyWith(color: t.muted)),
                const SizedBox(height: Space.xs),
                Text('${h['action']}', style: AppText.body.copyWith(color: t.onSurface)),
              ],
              const SizedBox(height: Space.xl),
              BigButton(
                label: 'End and save my workout',
                icon: Icons.flag,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(c.endWorkout(save: true));
                },
              ),
              const SizedBox(height: Space.s),
              BigButton(
                label: 'I feel better, keep going',
                kind: BigButtonKind.destructive,
                height: Sizes.heroButton,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );

// ---------------------------------------------------------------------------------------------
// End workout

Future<void> showEndWorkoutSheet(BuildContext context, SessionPlayerController c) => _sheet<void>(
      context,
      c,
      (context) {
        final (done, total) = c.progress;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetTitle(context, 'End workout?',
                  subtitle: '$done of $total steps done · ${Fmt.minutes(c.elapsed.inSeconds)}. ${PlayerCopy.endBody}'),
              BigButton(
                label: 'Finish and save',
                icon: Icons.check,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(c.endWorkout(save: true));
                },
              ),
              const SizedBox(height: Space.s),
              BigButton(
                label: 'Keep going',
                kind: BigButtonKind.secondary,
                height: Sizes.heroButton,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: Space.s),
              BigButton(
                label: 'Discard this workout',
                icon: Icons.delete_outline,
                kind: BigButtonKind.destructive,
                height: Sizes.heroButton,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Discard this workout?'),
                      content: const Text('Nothing from today will be saved. This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
                      ],
                    ),
                  );
                  if ((ok ?? false) && context.mounted) {
                    Navigator.of(context).pop();
                    unawaited(c.endWorkout(save: false));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
