// Owner: WS4. Resume banner (SPEC 4.3): amber, 72 dp, "Push · 3 of 5 done · 24 min". Sessions
// left open for more than 12 h offer "Finish and save" / "Discard" instead.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/clock.dart';
import '../../../data/models/models.dart';
import '../../../state/today_store.dart';
import '../../../widgets/undo_snackbar.dart';
import '../today_actions.dart';

class ResumeBanner extends StatefulWidget {
  const ResumeBanner({super.key, required this.session});

  final Session session;

  /// Sessions open longer than this are treated as forgotten.
  static const Duration staleAfter = Duration(hours: 12);

  static bool _counts(SessionExercise e) =>
      e.role != ItemRole.warmup && e.role != ItemRole.cardio && e.role != ItemRole.cooldown && e.role != ItemRole.stretch;

  /// "Push · 3 of 5 done · 24 min".
  static String summary(Session s, DateTime now) {
    final work = s.exercises.where(_counts).toList();
    final done = work.where((e) => e.status == SessionExerciseStatus.done).length;
    final minutes = now.difference(s.startedAt).inMinutes;
    final time = minutes >= 120 ? '${minutes ~/ 60} h' : '$minutes min';
    return '${Copy.dayShort(s.dayName)} · $done of ${work.length} done · $time';
  }

  @override
  State<ResumeBanner> createState() => _ResumeBannerState();
}

class _ResumeBannerState extends State<ResumeBanner> {
  /// Hidden while a discard waits out its undo window.
  bool _discarding = false;

  Session get session => widget.session;

  @override
  Widget build(BuildContext context) {
    if (_discarding) return const SizedBox.shrink();
    final t = context.tokens;
    final now = context.read<Clock>().now();
    final stale = now.difference(session.startedAt) > ResumeBanner.staleAfter;
    final fg = t.onPrimary;
    final banner = Material(
      color: t.warning,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: stale ? null : () => openSession(context, session.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.resumeBanner),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
            child: Row(
              children: [
                Icon(stale ? Icons.history : Icons.play_circle_fill, color: fg, size: 36),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(stale ? 'Unfinished workout' : 'Resume workout',
                          style: AppText.bodyStrong.copyWith(color: fg, fontSize: 18)),
                      Text(ResumeBanner.summary(session, now), style: AppText.tabular(AppText.label).copyWith(color: fg)),
                    ],
                  ),
                ),
                if (!stale) Icon(Icons.chevron_right, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
    if (!stale) return Semantics(button: true, child: banner);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banner,
        const SizedBox(height: Space.s),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.read<TodayStore>().finishInProgress(),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Finish and save'),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: t.danger),
                onPressed: () => _discard(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Discard'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Discard with a 5 s undo (sheets and undo instead of confirmations, SPEC 4.1).
  void _discard(BuildContext context) {
    final today = context.read<TodayStore>();
    var undone = false;
    setState(() => _discarding = true);
    showUndoSnackBar(context, 'Workout discarded', () {
      undone = true;
      if (mounted) setState(() => _discarding = false);
    });
    Future<void>.delayed(Motion.snackUndo + const Duration(milliseconds: 500), () async {
      if (!undone) await today.discardInProgress();
    });
  }
}
