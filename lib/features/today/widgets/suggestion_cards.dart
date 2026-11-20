// Owner: WS4. Suggestion cards on Today (SPEC 4.3): easy week (deload), weekly calorie check-in,
// milestone just earned, "try a variation", yearly safety re-check and the daily tip.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../state/program_store.dart';
import '../../../state/today_store.dart';
import '../../../state/types.dart';
import '../../library/exercise_detail_screen.dart';

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({super.key, required this.card});

  final TodayCard card;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = context.read<TodayStore>();
    final navigator = Navigator.of(context);
    void dismiss() => today.dismiss(card);

    switch (card) {
      case DeloadCard(:final reasons):
        return _Frame(
          icon: Icons.spa_outlined,
          color: t.secondary,
          title: 'Time for an easy week?',
          body: 'Lighter weights and fewer sets for ${context.read<ProgramStore>().template?.daysPerWeek ?? 3} '
              'sessions let your body catch up. You come back stronger.',
          bullets: reasons,
          primary: ('Start easy week', () async {
            await context.read<ProgramStore>().acceptReactiveDeload();
            await today.dismiss(card);
          }),
          secondary: ('Not now', dismiss),
        );
      case CheckinCard(:final advice):
        return _Frame(
          icon: Icons.monitor_weight_outlined,
          color: t.secondary,
          title: 'Weekly check-in',
          body: advice.message,
          primary: advice.canApply ? ('Apply', () => today.applyCheckin(advice)) : ('Got it', dismiss),
          secondary: advice.canApply ? ('Not now', dismiss) : null,
        );
      case MilestoneCard(:final milestone):
        return _Frame(
          icon: Icons.emoji_events,
          color: t.primary,
          title: 'New badge: ${milestone.title}',
          body: milestone.desc,
          primary: ('See your badges', () => navigator.pushNamed(Routes.milestones)),
          onClose: dismiss,
        );
      case VariationCard(:final exerciseId):
        final name = context.read<AssetCatalog>().tryExercise(exerciseId)?.name ?? exerciseId;
        return _Frame(
          icon: Icons.swap_horiz,
          color: t.warning,
          title: 'Try a variation of $name?',
          body: 'This one has stalled twice. A similar exercise often gets progress moving again.',
          primary: (
            'See alternatives',
            () => navigator.pushNamed(Routes.exercise, arguments: ExerciseDetailArgs(exerciseId: exerciseId)),
          ),
          secondary: ('Not now', dismiss),
        );
      case ParqRecheckCard():
        return _Frame(
          icon: Icons.health_and_safety_outlined,
          color: t.warning,
          title: 'Yearly safety check',
          body: 'It has been a year since your health questions. It takes a minute.',
          primary: ('Check now', () => navigator.pushNamed(Routes.safety)),
          secondary: ('Later', dismiss),
        );
      case TipCard(:final text):
        return _Frame(icon: Icons.lightbulb_outline, color: t.primary, title: 'Tip of the day', body: text, onClose: dismiss);
    }
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.bullets = const [],
    this.primary,
    this.secondary,
    this.onClose,
  });

  final IconData icon;
  final Color color;
  final String title, body;
  final List<String> bullets;
  final (String, VoidCallback)? primary, secondary;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = primary, s = secondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.s, Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                        const SizedBox(height: Space.xs),
                        Text(body, style: AppText.body.copyWith(color: t.onSurface)),
                        for (final b in bullets)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Text('• $b', style: AppText.label.copyWith(color: t.muted)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(tooltip: 'Hide', onPressed: onClose, icon: Icon(Icons.close, color: t.muted))
                else
                  const SizedBox(width: Space.s),
              ],
            ),
            if (p != null || s != null) ...[
              const SizedBox(height: Space.m),
              Padding(
                padding: const EdgeInsets.only(right: Space.s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (s != null) TextButton(onPressed: s.$2, child: Text(s.$1)),
                    if (s != null && p != null) const SizedBox(width: Space.s),
                    if (p != null)
                      Flexible(
                        child: FilledButton(
                          onPressed: p.$2,
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(p.$1)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
