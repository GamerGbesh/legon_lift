// Owner: WS4. "Preview" of the next workout (SPEC 4.3): every step of the built plan.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../domain/api.dart';
import '../../../widgets/exercise_thumb.dart';
import '../../../widgets/weight_text.dart';
import '../../library/exercise_detail_screen.dart';

Future<void> showPlanPreview(BuildContext context, SessionPlan plan) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, controller) => PlanPreview(plan: plan, controller: controller),
      ),
    );

class PlanPreview extends StatelessWidget {
  const PlanPreview({super.key, required this.plan, this.controller});

  final SessionPlan plan;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    String name(String id) => catalog.tryExercise(id)?.name ?? id;

    Widget group(IconData icon, String title, String body) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(Radii.chip)),
            child: Icon(icon, color: t.muted),
          ),
          title: Text(title, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          subtitle: Text(body, style: AppText.label.copyWith(color: t.muted)),
        );

    Widget exercise(ExerciseStep s) {
      final ex = catalog.tryExercise(s.item.exerciseId);
      if (ex == null) return const SizedBox.shrink();
      final rx = s.rx;
      final first = rx.working.isEmpty ? null : rx.working.first;
      final details = [
        Copy.setsLine(s.item),
        Copy.rest(rx.restSec),
        ?Copy.tank(rx.targetRir),
      ].join(' · ');
      final Widget load = rx.findWeight
          ? Text('Find your weight', style: AppText.label.copyWith(color: t.primary))
          : (first != null && ex.isLoaded
              ? WeightText(kg: first.weightKg, exercise: ex, style: AppText.tabular(AppText.label).copyWith(color: t.onSurface))
              : const SizedBox.shrink());
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ExerciseThumb(exercise: ex, size: 48),
        title: Text(ex.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(details, style: AppText.label.copyWith(color: t.muted)),
            load,
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(Routes.exercise, arguments: ExerciseDetailArgs(exerciseId: ex.id)),
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: Space.l, bottom: Space.xs),
          child: Text(text.toUpperCase(), style: AppText.overline.copyWith(color: t.primary)),
        );

    final children = <Widget>[];
    for (final step in plan.steps) {
      switch (step) {
        case WarmupCardioStep(:final item):
          children
            ..add(header('Warm-up'))
            ..add(group(Icons.directions_bike, name(item.exerciseId), Copy.target(item)));
        case MobilityStep(:final items):
          children.add(group(Icons.self_improvement, 'Warm-up drills', items.map((i) => name(i.exerciseId)).join(', ')));
        case ExerciseStep():
          if (children.isEmpty || step.index == plan.exerciseSteps.first.index) children.add(header('Workout'));
          children.add(exercise(step));
        case SupersetStep(:final members):
          children
            ..add(header('Pair: alternate these two'))
            ..addAll(members.map(exercise));
        case ExtrasStep(:final extras):
          children
            ..add(header('Extras if you have time'))
            ..addAll(extras.map(exercise));
        case FinisherStep(:final item, :final durationSec):
          children
            ..add(header('Finisher'))
            ..add(group(Icons.directions_walk, name(item.exerciseId), Fmt.minutes(durationSec)));
        case CooldownStep(:final items):
          children
            ..add(header('Cool-down'))
            ..add(group(Icons.spa_outlined, 'Walk and stretch', items.map((i) => name(i.exerciseId)).join(', ')));
      }
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
      children: [
        Text(Copy.dayShort(plan.dayName), style: AppText.headline.copyWith(color: t.onSurface)),
        Text('About ${plan.estimatedMinutes} min', style: AppText.body.copyWith(color: t.muted)),
        for (final n in plan.notices)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: t.secondary),
                const SizedBox(width: Space.s),
                Expanded(child: Text(n, style: AppText.label.copyWith(color: t.onSurface))),
              ],
            ),
          ),
        ...children,
      ],
    );
  }
}
