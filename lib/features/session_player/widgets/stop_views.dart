// Owner: WS3. The body of the player for each kind of stop (SPEC 4.4): set-based exercise stops
// (exercise, superset, extra) and timed/checklist stops (warm-up cardio, drills, finisher,
// cool-down).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/models/models.dart';
import '../../../services/api.dart';
import '../../../state/session_player_controller.dart';
import '../../../widgets/big_button.dart';
import 'exercise_media.dart';
import 'info_sheets.dart';
import 'player_copy.dart';
import 'player_sheets.dart';
import 'set_table.dart';

/// The user's weaker side (left arm fades first on presses; docs/research/USER_NOTES.md).
const String _weakSide = 'left';

/// Personal coaching line for the weaker left side, or null when it does not apply.
String? weakSideTip(Exercise ex) {
  final pressing = const {
    MovementPattern.horizontalPush,
    MovementPattern.inclinePush,
    MovementPattern.verticalPush,
    MovementPattern.chestFly,
    MovementPattern.elbowExtension,
  }.contains(ex.movementPattern);
  if (ex.unilateral) {
    return 'Start with your $_weakSide side. Then do the same reps on the right, not more.';
  }
  if (!pressing) return null;
  if (ex.loadType == LoadType.dumbbell) {
    return 'Your $_weakSide arm sets the pace: stop the set when it starts to slow, even if the right could do more.';
  }
  if (ex.loadType == LoadType.barbell || ex.loadType == LoadType.smith || ex.loadType == LoadType.stack) {
    return 'Keep both hands level. If the $_weakSide side lags or tilts, that set is done.';
  }
  return null;
}

/// Exercise / superset / extra stop.
class ExerciseStopView extends StatelessWidget {
  const ExerciseStopView({super.key, required this.stop});

  final PlayerStop stop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final rows = c.rowsOf(stop);
    final active = c.activeRow;
    final se = active?.se ?? stop.exercise;
    if (se == null) return const SizedBox.shrink();
    final ex = c.exerciseOf(se);
    final member = stop.members.isEmpty ? null : stop.members[(active?.member ?? 0).clamp(0, stop.members.length - 1)];
    final prefs = c.prefsFor(ex.id);
    final launcher = context.read<LauncherService>();
    final rampTarget = c.rampTargetReps(se);
    final tip = weakSideTip(ex);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
      children: [
        if (stop.kind == StopKind.extra)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Text('EXTRA ${stop.extraNumber} OF ${stop.extraCount} · ${PlayerCopy.extrasIntro}',
                style: AppText.overline.copyWith(color: t.secondary)),
          ),
        if (stop.kind == StopKind.superset)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: Text(c.stopTitle(stop).toUpperCase(), style: AppText.overline.copyWith(color: t.secondary)),
          ),
        ClipRRect(borderRadius: BorderRadius.circular(Radii.imageCard), child: ExerciseMedia(exercise: ex)),
        const SizedBox(height: Space.m),
        Text(ex.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: PlayerText.exerciseName.copyWith(color: t.onSurface)),
        if (member != null) ...[
          const SizedBox(height: Space.xs),
          Text(PlayerCopy.prescriptionLine(member.item, se.target, ex), style: AppText.body.copyWith(color: t.muted)),
        ],
        const SizedBox(height: Space.m),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ToolButton(icon: Icons.swap_horiz, label: 'Busy? Swap', onPressed: () => unawaited(showSwapSheet(context, c, se))),
              const SizedBox(width: Space.s),
              if (ex.needsBarMath) ...[
                ToolButton(
                  icon: Icons.view_week,
                  label: 'Plates',
                  onPressed: () async {
                    final kg = await showPlateSheet(context, exercise: ex, targetKg: c.draftWeight, equipment: c.equipment);
                    if (kg != null) c.setDraftWeight(kg);
                  },
                ),
                const SizedBox(width: Space.s),
              ],
              ToolButton(icon: Icons.help_outline, label: 'How', onPressed: () => unawaited(showHowToSheet(context, ex, launcher))),
              const SizedBox(width: Space.s),
              ToolButton(icon: Icons.play_circle_outline, label: 'Video', onPressed: () => unawaited(openVideo(context, launcher, ex))),
              const SizedBox(width: Space.s),
              ToolButton(icon: Icons.more_horiz, label: 'More', onPressed: () => unawaited(showMoreSheet(context, c))),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        if (rampTarget != null && c.findingWeight) ...[
          _Banner(
            icon: Icons.search,
            color: t.secondary,
            text: '${PlayerCopy.findWeightIntro} Aim for $rampTarget clean reps. '
                'Too easy? The app adds weight for the next try.',
          ),
          const SizedBox(height: Space.m),
        ],
        if (active?.kind == SetKind.calibration) ...[
          _Banner(icon: Icons.tune, color: t.secondary, text: PlayerCopy.calibrationIntro),
          const SizedBox(height: Space.m),
        ],
        if (c.session?.phaseId == PhaseId.retest && active?.kind == SetKind.working) ...[
          _Banner(icon: Icons.speed, color: t.secondary, text: PlayerCopy.retestIntro),
          const SizedBox(height: Space.m),
        ],
        CueCarousel(cues: ex.cues),
        if (tip != null) ...[
          const SizedBox(height: Space.s),
          _Banner(icon: Icons.balance, color: t.primary, text: tip),
        ],
        if (prefs.machineNote != null && prefs.machineNote!.isNotEmpty) ...[
          const SizedBox(height: Space.s),
          InkWell(
            onTap: () => unawaited(showMachineNoteDialog(context, c, ex)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s),
              child: Row(
                children: [
                  Icon(Icons.sticky_note_2_outlined, size: 20, color: t.muted),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text('Machine note: ${prefs.machineNote}', style: AppText.label.copyWith(color: t.muted)),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.m),
        SetTable(rows: rows),
        if (active == null) ...[
          const SizedBox(height: Space.m),
          BigButton(label: 'Next', icon: Icons.arrow_forward, onPressed: c.busy ? null : () => unawaited(c.nextStep())),
        ],
        const SizedBox(height: Space.s),
        if (active != null)
          Center(
            child: TextButton(
              onPressed: c.busy ? null : () => unawaited(c.skipSet()),
              child: const Text('Skip this set'),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: Space.m),
            Expanded(child: Text(text, style: AppText.body.copyWith(color: context.tokens.onSurface))),
          ],
        ),
      );
}

/// Warm-up cardio, warm-up drills, finisher and cool-down.
class TimedStopView extends StatelessWidget {
  const TimedStopView({super.key, required this.stop});

  final PlayerStop stop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final timer = c.stopTimer;
    if (timer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.page),
          child: BigButton(label: 'Next', icon: Icons.arrow_forward, onPressed: () => unawaited(c.nextStep())),
        ),
      );
    }
    final ex = timer.exercise;
    final launcher = context.read<LauncherService>();
    final heading = switch (stop.kind) {
      StopKind.warmupCardio => 'WARM-UP',
      StopKind.mobility => timer.rounds > 1
          ? 'WARM-UP DRILLS · ROUND ${timer.round} OF ${timer.rounds}'
          : 'WARM-UP DRILLS · ${timer.itemIndex + 1} OF ${timer.itemCount}',
      StopKind.finisher => 'FINISHER',
      StopKind.cooldown => 'COOL-DOWN · ${timer.itemIndex + 1} OF ${timer.itemCount}',
      _ => '',
    };
    final total = timer.totalSec;
    final left = timer.remainingSec(c.now);
    final reps = timer.item.repRange;
    final amount = total != null
        ? null
        : reps == null
            ? null
            : '${reps.$1 == reps.$2 ? reps.$1 : '${reps.$1}–${reps.$2}'} reps${timer.item.perSide ? ' each side' : ''}';
    final note = switch (stop.kind) {
      StopKind.warmupCardio => PlayerCopy.warmupCardio,
      StopKind.finisher => 'Steady pace you can keep talking at. This helps the fat-loss side.',
      _ => null,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
      children: [
        Text(heading, style: AppText.overline.copyWith(color: t.secondary)),
        const SizedBox(height: Space.s),
        ClipRRect(borderRadius: BorderRadius.circular(Radii.imageCard), child: ExerciseMedia(exercise: ex)),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(child: Text(ex.name, style: PlayerText.exerciseName.copyWith(color: t.onSurface))),
            IconButton(
              tooltip: 'How to do it',
              onPressed: () => unawaited(showHowToSheet(context, ex, launcher)),
              icon: Icon(Icons.help_outline, color: t.primary),
            ),
          ],
        ),
        if (note != null) Text(note, style: AppText.body.copyWith(color: t.muted)),
        if (timer.item.perSide && total != null)
          Text('Half the time on each side. The app beeps when it is time to switch.',
              style: AppText.label.copyWith(color: t.muted)),
        const SizedBox(height: Space.m),
        CueCarousel(cues: ex.cues),
        const SizedBox(height: Space.xl),
        if (total != null) ...[
          Center(
            child: Text(Fmt.clock(left),
                style: AppText.displayTimer.copyWith(color: timer.running ? t.onSurface : t.muted)),
          ),
          const SizedBox(height: Space.s),
          LinearProgressIndicator(
            value: total == 0 ? 0 : 1 - left / total,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              Expanded(
                child: BigButton(
                  label: timer.running ? 'Pause' : (timer.started ? 'Resume' : 'Start'),
                  icon: timer.running ? Icons.pause : Icons.play_arrow,
                  kind: timer.running ? BigButtonKind.secondary : BigButtonKind.primary,
                  onPressed: c.busy ? null : () => unawaited(timer.running ? c.pauseTimer() : c.startTimer()),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: BigButton(
                  label: 'Done',
                  icon: Icons.check,
                  kind: timer.running ? BigButtonKind.primary : BigButtonKind.secondary,
                  onPressed: c.busy ? null : () => unawaited(c.completeItem()),
                ),
              ),
            ],
          ),
        ] else ...[
          if (amount != null)
            Center(child: Text(amount, style: AppText.displayStat.copyWith(color: t.onSurface))),
          const SizedBox(height: Space.xl),
          BigButton(label: 'Done', icon: Icons.check, onPressed: c.busy ? null : () => unawaited(c.completeItem())),
        ],
        const SizedBox(height: Space.m),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.s,
          children: [
            if (stop.kind == StopKind.warmupCardio)
              TextButton.icon(
                onPressed: () => unawaited(c.cardioUnavailable()),
                icon: const Icon(Icons.block),
                label: const Text('No machine free'),
              ),
            if (stop.kind == StopKind.cooldown)
              TextButton(onPressed: () => unawaited(c.skipStretches()), child: const Text('Skip stretches')),
            TextButton(onPressed: () => unawaited(c.skipItem()), child: const Text('Skip')),
            TextButton(onPressed: () => unawaited(showMoreSheet(context, c)), child: const Text('More')),
          ],
        ),
      ],
    );
  }
}
