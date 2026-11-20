// Owner: WS3. The rest sheet (SPEC 4.4): RIR question, countdown ring, -15/+15, the next set,
// the in-session suggestion chip, the next exercise card and SKIP REST. Also the 2-minute wait.
import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/models/models.dart';
import '../../../services/api.dart';
import '../../../state/session_player_controller.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/exercise_thumb.dart';
import '../../../widgets/number_stepper.dart';
import 'info_sheets.dart';
import 'player_copy.dart';
import 'player_sheets.dart';

class RestPanel extends StatelessWidget {
  const RestPanel({super.key, required this.rest});

  final RestInfo rest;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final now = c.now;
    final left = rest.remainingSec(now);
    final over = rest.isOver(now);
    final timed = rest.endsAt != null;
    final wait = rest.kind == RestKind.wait;
    final hint = c.hint;
    final next = c.upNext;
    final question = rest.questions.where((q) => q.kind != SetKind.calibration).lastOrNull;
    final calibration = rest.calibration;

    return Material(
      color: t.bg,
      elevation: 12,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: Space.m),
              if (wait)
                Text('Waiting for the machine', style: AppText.title.copyWith(color: t.onSurface))
              else if (question != null) ...[
                Text(PlayerCopy.rirQuestion, style: AppText.title.copyWith(color: t.onSurface)),
                const SizedBox(height: Space.m),
                RirButtons(selected: question.rir, onSelected: (v) => unawaited(c.answerRir(question.id, v))),
              ],
              if (calibration != null) _CalibrationQuestion(set: calibration),
              if (wait)
                Padding(
                  padding: const EdgeInsets.only(top: Space.s),
                  child: Text(PlayerCopy.waitEtiquette, style: AppText.body.copyWith(color: t.muted)),
                ),
              if (timed) ...[
                const SizedBox(height: Space.l),
                Row(
                  children: [
                    _RoundButton(label: '−15', onPressed: () => unawaited(c.adjustRest(-PlayerTiming.adjustSec))),
                    Expanded(child: Center(child: _Ring(left: left, total: rest.totalSec, over: over))),
                    _RoundButton(label: '+15', onPressed: () => unawaited(c.adjustRest(PlayerTiming.adjustSec))),
                  ],
                ),
              ],
              if (hint != null) ...[
                const SizedBox(height: Space.m),
                ActionChip(
                  avatar: Icon(Icons.lightbulb_outline, color: t.secondary),
                  label: Text(hint.message, style: AppText.label.copyWith(color: t.onSurface)),
                  onPressed: hint.automatic ? null : () => c.acceptHint(hint),
                ),
              ],
              const SizedBox(height: Space.m),
              if (c.nextLabel != null)
                Text('Next: ${c.nextLabel}',
                    textAlign: TextAlign.center, style: PlayerText.strong(AppText.body).copyWith(color: t.onSurface)),
              const SizedBox(height: Space.xs),
              Text(
                c.session?.hotDay ?? false ? '${PlayerCopy.sipWater} · ${PlayerCopy.hotDay}' : PlayerCopy.sipWater,
                textAlign: TextAlign.center,
                style: AppText.label.copyWith(color: t.muted),
              ),
              if (next != null && c.activeRow == null && next.kind.hasSets) ...[
                const SizedBox(height: Space.m),
                _NextExerciseCard(stop: next),
              ],
              const SizedBox(height: Space.l),
              Row(
                children: [
                  if (c.canUndo && !wait) ...[
                    SizedBox(
                      width: Sizes.primaryButton,
                      height: Sizes.primaryButton,
                      child: IconButton.outlined(
                        tooltip: 'Undo last set',
                        onPressed: () => unawaited(c.undoLast()),
                        icon: const Icon(Icons.undo),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                  ],
                  Expanded(
                    child: BigButton(
                      label: over || !timed ? (wait ? "I'M ON IT" : 'GO') : (wait ? 'STOP WAITING' : 'SKIP REST'),
                      icon: over || !timed ? Icons.play_arrow : Icons.skip_next,
                      onPressed: () => unawaited(c.skipRest()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalibrationQuestion extends StatefulWidget {
  const _CalibrationQuestion({required this.set});

  final SetLog set;

  @override
  State<_CalibrationQuestion> createState() => _CalibrationQuestionState();
}

class _CalibrationQuestionState extends State<_CalibrationQuestion> {
  int _extra = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.read<SessionPlayerController>();
    return Padding(
      padding: const EdgeInsets.only(top: Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How many extra reps did you get after your guess?',
              style: PlayerText.strong(AppText.body).copyWith(color: t.onSurface)),
          const SizedBox(height: Space.s),
          NumberStepper(
            value: _extra.toDouble(),
            step: 1,
            decimals: 0,
            max: 30,
            unit: 'reps',
            onChanged: (v) => setState(() => _extra = v.round()),
          ),
          const SizedBox(height: Space.s),
          OutlinedButton(
            onPressed: () => unawaited(c.answerCalibration(widget.set.id, _extra)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.left, required this.total, required this.over});

  final int left, total;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fraction = total <= 0 ? 0.0 : (left / total).clamp(0.0, 1.0);
    final size = math.min(200.0, MediaQuery.sizeOf(context).width * 0.48);
    return Semantics(
      liveRegion: true,
      label: over ? 'Rest over' : 'Rest ${Fmt.clock(left)} left',
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: fraction,
              strokeWidth: 10,
              backgroundColor: t.surface2,
              color: over ? t.success : (left <= PlayerTiming.warnAtSec ? t.secondary : t.primary),
              strokeCap: StrokeCap.round,
            ),
            Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(Space.l),
                  child: Text(
                    over ? 'GO!' : Fmt.clock(left),
                    style: AppText.displayTimer.copyWith(color: over ? t.success : t.onSurface),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: Sizes.stepper,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            foregroundColor: context.tokens.onSurface,
          ),
          child: Text(label, style: AppText.bodyStrong),
        ),
      );
}

class _NextExerciseCard extends StatelessWidget {
  const _NextExerciseCard({required this.stop});

  final PlayerStop stop;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.read<SessionPlayerController>();
    final se = stop.exercise;
    if (se == null) return const SizedBox.shrink();
    final ex = c.exerciseOf(se);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.m),
        child: Row(
          children: [
            ExerciseThumb(exercise: ex),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UP NEXT', style: AppText.overline.copyWith(color: t.muted)),
                  Text(c.stopTitle(stop), style: PlayerText.strong(AppText.body).copyWith(color: t.onSurface)),
                  if (ex.cues.isNotEmpty)
                    Text('"${ex.cues.first}"', style: AppText.label.copyWith(color: t.muted, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => unawaited(showHowToSheet(context, ex, context.read<LauncherService>())),
              child: const Text('How'),
            ),
          ],
        ),
      ),
    );
  }
}
