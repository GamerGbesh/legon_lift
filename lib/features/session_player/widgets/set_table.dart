// Owner: WS3. The set table of an exercise stop (SPEC 4.4): logged rows, the active row with big
// steppers, pending rows, and the LOG SET button.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/models/models.dart';
import '../../../state/session_player_controller.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/number_entry_sheet.dart';
import '../../../widgets/number_stepper.dart';
import 'player_copy.dart';
import 'player_sheets.dart';

/// All rows of the current stop plus the controls of the active row.
class SetTable extends StatelessWidget {
  const SetTable({super.key, required this.rows});

  final List<SetRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final active = c.activeRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
          child: Row(
            children: [
              SizedBox(width: 44, child: Text('SET', style: PlayerText.tableHeader.copyWith(color: t.muted))),
              Expanded(flex: 4, child: Text('LAST TIME', style: PlayerText.tableHeader.copyWith(color: t.muted))),
              Expanded(flex: 5, child: Text('TARGET', style: PlayerText.tableHeader.copyWith(color: t.muted))),
              const SizedBox(width: 36),
            ],
          ),
        ),
        for (final row in rows)
          if (row.state == RowState.active)
            _ActiveRow(row: row)
          else
            _RowLine(row: row),
        const SizedBox(height: Space.m),
        if (active != null) _LogButton(row: active),
      ],
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({required this.row});

  final SetRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ex = row.exercise;
    final log = row.log;
    final muted = row.isWarmup || row.state == RowState.pending;
    final prev = row.previous;
    final color = switch (row.state) {
      RowState.logged => t.onSurface,
      RowState.skipped => t.muted,
      _ => muted ? t.muted : t.onSurface,
    };
    final target = log != null
        ? PlayerCopy.setText(log.weightKg, log.reps, ex, durationSec: log.durationSec)
        : row.state == RowState.skipped
            ? 'skipped'
            : PlayerCopy.setText(row.weightKg, row.reps, ex, durationSec: row.durationSec);
    final trailing = switch (row.state) {
      RowState.logged => Icon(Icons.check_circle, color: log?.painFlag ?? false ? t.warning : t.success),
      RowState.skipped => Icon(Icons.remove_circle_outline, color: t.muted),
      _ => Icon(Icons.radio_button_unchecked, color: t.surface2),
    };
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(row.label,
                style: PlayerText.strong(AppText.body).copyWith(color: row.isWarmup ? t.muted : t.primary)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              prev == null ? '—' : PlayerCopy.setText(prev.weightKg, prev.reps, ex, durationSec: prev.durationSec),
              style: PlayerText.tableCell.copyWith(color: t.muted),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Flexible(child: Text(target, style: PlayerText.tableCell.copyWith(color: color))),
                if (log?.isPr ?? false) ...[
                  const SizedBox(width: Space.xs),
                  Icon(Icons.emoji_events, size: 18, color: t.secondary),
                ],
              ],
            ),
          ),
          SizedBox(width: 36, child: trailing),
        ],
      ),
    );
    if (log == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.chip),
      onTap: () => showEditSetSheet(context, context.read<SessionPlayerController>(), log, ex),
      child: content,
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({required this.row});

  final SetRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final ex = row.exercise;
    final prev = row.previous;
    final kind = switch (row.kind) {
      SetKind.warmup => 'WARM-UP ${row.label.substring(1)}',
      SetKind.ramp => 'FIND YOUR WEIGHT ${row.label.substring(1)}',
      _ => c.currentStop?.kind == StopKind.superset ? '${ex.name.toUpperCase()} ${row.label}' : 'SET ${row.label}',
    };
    final unit = ex.loadType == LoadType.dumbbell && (ex.dumbbellCount ?? 1) >= 2 ? 'kg each' : 'kg';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Space.s),
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(kind, style: PlayerText.strong(AppText.label).copyWith(color: t.primary, letterSpacing: 0.6)),
              const Spacer(),
              if (prev != null)
                Text('last ${PlayerCopy.setText(prev.weightKg, prev.reps, ex, durationSec: prev.durationSec)}',
                    style: AppText.label.copyWith(color: t.muted)),
            ],
          ),
          const SizedBox(height: Space.s),
          if (ex.isLoaded) ...[
            NumberStepper(
              value: c.draftWeight,
              step: c.weightStepFor(row),
              unit: unit,
              decimals: 2,
              onChanged: c.setDraftWeight,
              onTapValue: () async {
                final v = await showNumberEntrySheet(context,
                    title: 'Weight', initial: c.draftWeight, unit: unit, decimals: 2, max: 500);
                if (v != null) c.setDraftWeight(v);
              },
            ),
            const SizedBox(height: Space.s),
          ],
          if (row.isTimed)
            _HoldControls(row: row)
          else
            NumberStepper(
              value: c.draftReps.toDouble(),
              step: 1,
              min: 0,
              max: 100,
              decimals: 0,
              unit: ex.unilateral ? 'reps / side' : 'reps',
              onChanged: (v) => c.setDraftReps(v.round()),
              onTapValue: () async {
                final v = await showNumberEntrySheet(context,
                    title: 'Reps', initial: c.draftReps.toDouble(), unit: 'reps', decimals: 0, max: 100);
                if (v != null) c.setDraftReps(v.round());
              },
            ),
        ],
      ),
    );
  }
}

/// Start/pause of a timed set (planks) with the seconds stepper while not running.
class _HoldControls extends StatelessWidget {
  const _HoldControls({required this.row});

  final SetRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final h = c.hold;
    final mine = h != null && h.setIndex == row.setIndex;
    if (!mine) {
      return NumberStepper(
        value: c.draftReps.toDouble(),
        step: 5,
        min: 5,
        max: 600,
        decimals: 0,
        unit: 'sec',
        onChanged: (v) => c.setDraftReps(v.round()),
      );
    }
    final left = h.remainingSec(c.now);
    return Column(
      children: [
        Text(Fmt.clock(left), style: AppText.displayTimer.copyWith(color: t.onSurface, fontSize: 64)),
        const SizedBox(height: Space.s),
        LinearProgressIndicator(
          value: h.totalSec == 0 ? 0 : 1 - left / h.totalSec,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.row});

  final SetRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SessionPlayerController>();
    if (row.isTimed) {
      final h = c.hold;
      final mine = h != null && h.setIndex == row.setIndex;
      if (mine && h.running) {
        return Row(
          children: [
            Expanded(
              child: BigButton(label: 'Pause', icon: Icons.pause, kind: BigButtonKind.secondary, onPressed: c.pauseHold),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: BigButton(
                label: 'Done',
                icon: Icons.check,
                onPressed: c.busy ? null : () => c.logSet(durationSec: h.totalSec - h.remainingSec(c.now)),
              ),
            ),
          ],
        );
      }
      return BigButton(
        label: mine ? 'Resume' : 'Start ${Fmt.clock(c.draftReps)} hold',
        icon: Icons.play_arrow,
        onPressed: c.startHold,
      );
    }
    final label = switch (row.kind) {
      SetKind.warmup => 'LOG WARM-UP',
      SetKind.ramp => 'LOG THIS TRY',
      _ => 'LOG SET ${row.label}',
    };
    return BigButton(label: label, icon: Icons.check, onPressed: c.busy ? null : () => c.logSet());
  }
}
