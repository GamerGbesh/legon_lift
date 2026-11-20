// Owner: WS4. Next-workout hero card (SPEC 4.3): day, phase and week, focus muscles, exercise
// thumbnails, time estimate, START WORKOUT, Preview and "Do a different day". Variants for a rest
// day, a finished day, a blocked program and a workout in progress.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../domain/api.dart';
import '../../../state/program_store.dart';
import '../../../state/today_store.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/exercise_thumb.dart';
import '../../progress/delete_workout.dart';
import '../sheets/day_picker_sheet.dart';
import '../sheets/preview_sheet.dart';
import '../today_actions.dart';

/// What the hero card is showing.
enum HeroMode { workoutDay, restDay, doneToday }

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.plan, required this.blocked});

  final SessionPlan plan;

  /// PAR-Q "yes" not yet cleared: START is disabled.
  final bool blocked;

  /// The week-1 notice (SPEC 4.3).
  static const String weekOneNotice =
      "This week's sessions take ~5 min longer while we find your weights; the cardio finisher is skipped.";

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = context.watch<TodayStore>();
    final program = context.watch<ProgramStore>();
    final catalog = context.read<AssetCatalog>();
    final template = program.template;
    final day = program.phase?.day(plan.dayId);
    final inProgress = today.inProgress;
    final mode = today.doneToday
        ? HeroMode.doneToday
        : (today.isWorkoutDay ? HeroMode.workoutDay : HeroMode.restDay);
    final dayName = Copy.dayShort(plan.dayName);
    final next = today.nextWorkoutDate;
    final nextLine = 'Next: $dayName${next == null ? '' : ' (${Fmt.weekdayShort(next.weekday)})'}.';

    final exercises = [
      for (final s in plan.exerciseSteps) ?catalog.tryExercise(s.item.exerciseId),
    ];
    final notices = [
      if (plan.trainingWeek == 1 && template != null && !template.isCustom && !plan.isDeload) weekOneNotice,
      for (final n in plan.notices)
        if (!n.contains('find your weights') && !n.contains('~5 min longer')) n,
    ];

    final kicker = switch (mode) {
      HeroMode.workoutDay => inProgress == null ? "TODAY'S WORKOUT" : 'IN PROGRESS',
      HeroMode.restDay => 'REST DAY',
      HeroMode.doneToday => 'DONE TODAY',
    };

    final Widget title = switch (mode) {
      HeroMode.workoutDay => Text(dayName, style: AppText.headline.copyWith(fontSize: 36, color: t.onSurface)),
      HeroMode.restDay => Text('Rest day', style: AppText.headline.copyWith(fontSize: 36, color: t.onSurface)),
      HeroMode.doneToday => Row(
          children: [
            Icon(Icons.check_circle, color: t.success, size: 36),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text('Nice work', style: AppText.headline.copyWith(fontSize: 36, color: t.onSurface)),
            ),
          ],
        ),
    };

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.card + 4),
        border: Border.all(color: Color.alphaBlend(t.primary.withValues(alpha: 0.35), t.surface2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(t.primary.withValues(alpha: mode == HeroMode.workoutDay ? 0.16 : 0.07), t.surface),
            t.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kicker,
                    style: AppText.overline.copyWith(color: mode == HeroMode.doneToday ? t.success : t.primary)),
              ),
              if (plan.isDeload) _Pill(text: 'Easy week', color: t.secondary),
            ],
          ),
          const SizedBox(height: Space.xs),
          title,
          if (template != null)
            Text(
              Copy.weekLine(template, program.trainingWeek, program.phase),
              style: AppText.tabular(AppText.body).copyWith(color: t.muted),
            ),
          if (mode != HeroMode.workoutDay) ...[
            const SizedBox(height: Space.s),
            Text(
              mode == HeroMode.restDay ? 'Recovery is when muscles grow. $nextLine' : 'Workout saved. $nextLine',
              style: AppText.body.copyWith(color: t.onSurface),
            ),
          ],
          const SizedBox(height: Space.m),
          if (mode == HeroMode.restDay || mode == HeroMode.doneToday)
            _UpNextRow(dayName: dayName, minutes: plan.estimatedMinutes, exercises: exercises.length)
          else ...[
            if (day != null && day.focus.isNotEmpty) _FocusChips(focus: day.focus),
            const SizedBox(height: Space.m),
            _ThumbStrip(exercises: exercises),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: t.muted),
                const SizedBox(width: Space.xs),
                Text('About ${plan.estimatedMinutes} min',
                    style: AppText.tabular(AppText.bodyStrong).copyWith(color: t.onSurface)),
                const SizedBox(width: Space.l),
                Icon(Icons.fitness_center, size: 20, color: t.muted),
                const SizedBox(width: Space.xs),
                Text('${exercises.length} exercises', style: AppText.tabular(AppText.body).copyWith(color: t.onSurface)),
              ],
            ),
          ],
          for (final n in notices)
            Container(
              margin: const EdgeInsets.only(top: Space.m),
              padding: const EdgeInsets.all(Space.m),
              decoration: BoxDecoration(
                color: t.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: t.secondary),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(n, style: AppText.label.copyWith(color: t.onSurface))),
                ],
              ),
            ),
          const SizedBox(height: Space.l),
          _actions(context, mode, inProgress),
          if (inProgress == null)
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => showPlanPreview(context, plan),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: mode == HeroMode.doneToday
                      ? _MoreMenu(onStartAnother: blocked ? null : () => _pickDay(context))
                      : TextButton.icon(
                          onPressed: blocked ? null : () => _pickDay(context),
                          icon: const Icon(Icons.swap_horiz),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Do a different day')),
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, HeroMode mode, Session? inProgress) {
    if (inProgress != null) {
      return BigButton(
        label: 'RESUME WORKOUT',
        icon: Icons.play_arrow_rounded,
        height: Sizes.heroButton,
        onPressed: () => openSession(context, inProgress.id),
      );
    }
    if (plan.exerciseSteps.isEmpty && mode != HeroMode.doneToday) {
      // An empty custom day: nothing to train yet, so send them to add exercises.
      return BigButton(
        label: 'Add exercises to this day',
        icon: Icons.edit_note,
        height: Sizes.heroButton,
        onPressed: () => Navigator.of(context).pushNamed(Routes.programDay, arguments: plan.dayId),
      );
    }
    final start = blocked ? null : () => startWorkout(context, dayName: plan.dayName);
    return switch (mode) {
      HeroMode.workoutDay => BigButton(
          label: 'START WORKOUT',
          icon: Icons.play_arrow_rounded,
          height: Sizes.heroButton,
          onPressed: start,
        ),
      HeroMode.restDay => BigButton(
          label: 'Start anyway',
          icon: Icons.play_arrow_rounded,
          kind: BigButtonKind.secondary,
          height: Sizes.heroButton,
          onPressed: start,
        ),
      HeroMode.doneToday => const SizedBox.shrink(),
    };
  }

  Future<void> _pickDay(BuildContext context) async {
    final program = context.read<ProgramStore>();
    final dayId = await showDayPicker(context, currentDayId: plan.dayId);
    if (dayId == null || !context.mounted) return;
    final day = program.phase?.day(dayId);
    await startWorkout(context, dayId: dayId, dayName: day?.name ?? dayId);
  }
}

/// "More" on a finished day: starting another session is possible but not pushed (SPEC 4.4).
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onStartAnother});

  final VoidCallback? onStartAnother;

  /// "Delete today's workout": the latest workout completed today, if any.
  Future<void> _deleteToday(BuildContext context) async {
    final now = DateTime.now();
    final done = await context.read<SessionRepository>().listCompleted(from: DateTime(now.year, now.month, now.day));
    if (done.isEmpty || !context.mounted) return;
    done.sort((a, b) => (b.endedAt ?? b.startedAt).compareTo(a.endedAt ?? a.startedAt));
    await confirmAndDeleteWorkout(context, done.first);
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (v) {
          if (v == 'another') onStartAnother?.call();
          if (v == 'delete') unawaited(_deleteToday(context));
        },
        itemBuilder: (_) => [
          if (onStartAnother != null)
            const PopupMenuItem<String>(
              value: 'another',
              height: Sizes.minTap,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.add),
                title: Text('Start another session'),
              ),
            ),
          const PopupMenuItem<String>(
            value: 'delete',
            height: Sizes.minTap,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline),
              title: Text("Delete today's workout"),
              subtitle: Text('Logged it by mistake?'),
            ),
          ),
        ],
        child: SizedBox(
          height: Sizes.minTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.more_horiz, color: context.tokens.primary),
              const SizedBox(width: Space.s),
              Text('More', style: AppText.label.copyWith(fontSize: 16, color: context.tokens.primary)),
            ],
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: color),
        ),
        child: Text(text, style: AppText.label.copyWith(color: context.tokens.onSurface)),
      );
}

class _FocusChips extends StatelessWidget {
  const _FocusChips({required this.focus});

  final List<String> focus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final f in focus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
            decoration: BoxDecoration(
              color: t.surface2,
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Text(Copy.focus(f), style: AppText.label.copyWith(color: t.onSurface)),
          ),
      ],
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, c) {
        const size = 52.0, gap = Space.s;
        final fit = ((c.maxWidth + gap) / (size + gap)).floor().clamp(1, 12);
        final shown = exercises.length > fit ? fit - 1 : exercises.length;
        final more = exercises.length - shown;
        return Row(
          children: [
            for (final ex in exercises.take(shown)) ...[
              ExerciseThumb(exercise: ex, size: size),
              const SizedBox(width: gap),
            ],
            if (more > 0)
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(Radii.chip)),
                child: Text('+$more', style: AppText.tabular(AppText.bodyStrong).copyWith(color: t.onSurface)),
              ),
          ],
        );
      },
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.dayName, required this.minutes, required this.exercises});

  final String dayName;
  final int minutes, exercises;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: t.bg.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(Radii.button)),
      child: Row(
        children: [
          Icon(Icons.upcoming_outlined, color: t.primary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text('Up next: $dayName', style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          ),
          Text('$exercises ex · ~$minutes min', style: AppText.tabular(AppText.label).copyWith(color: t.muted)),
        ],
      ),
    );
  }
}
