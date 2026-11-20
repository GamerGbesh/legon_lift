// Owner: WS4. Program tab (SPEC 4.5): program name, phase + week, next up, the day cards in
// rotation order (drag to reorder, pick the next workout), change split.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/profile_store.dart';
import '../../state/program_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'custom_program.dart';

/// Program screen.
class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final store = context.watch<ProgramStore>();
    final catalog = context.read<AssetCatalog>();
    final profile = context.watch<ProfileStore>().profile;
    final template = store.template;
    final active = store.active;
    final phase = store.phase;
    final days = store.days;

    if (template == null || active == null || phase == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Program')),
        body: EmptyState(
          icon: Icons.event_note,
          title: 'No program yet',
          body: 'Pick a split to get your plan.',
          action: FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.programSplit),
            child: const Text('Choose a split'),
          ),
        ),
      );
    }

    final totalWeeks = template.phases.expand((p) => p.weeks).fold<int>(0, (a, b) => b > a ? b : a);
    final next = store.nextDay;
    final sessionMinutes = profile?.sessionMinutes ?? 60;

    return Scaffold(
      appBar: AppBar(title: const Text('Program')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(active.name, style: AppText.title.copyWith(color: t.onSurface)),
                  const SizedBox(height: Space.xs),
                  Text(
                    template.splitKey == SplitKey.custom
                        ? 'Your own program'
                        : 'Week ${store.trainingWeek}${totalWeeks > 0 ? ' of $totalWeeks' : ''} · ${phase.name}',
                    style: AppText.body.copyWith(color: t.primary),
                  ),
                  if (phase.goal.isNotEmpty) ...[
                    const SizedBox(height: Space.s),
                    Text(phase.goal, style: AppText.label.copyWith(color: t.muted)),
                  ],
                  if (template.splitKey != SplitKey.custom && totalWeeks > 0) ...[
                    const SizedBox(height: Space.m),
                    LinearProgressIndicator(
                      value: (store.trainingWeek / totalWeeks).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                  if (next != null) ...[
                    const SizedBox(height: Space.m),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: t.secondary),
                        const SizedBox(width: Space.s),
                        Text('Next up: ${next.name}', style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SectionHeader(
            'Your days',
            trailing: Text('Hold and drag to reorder', style: AppText.caption.copyWith(color: t.muted)),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              final order = [for (final d in days) d.dayId];
              final id = order.removeAt(from);
              order.insert(to, id);
              unawaited(store.reorderDays(order));
            },
            children: [
              for (final (i, d) in days.indexed)
                _DayCard(
                  key: ValueKey(d.dayId),
                  index: i,
                  day: d,
                  isNext: next?.dayId == d.dayId,
                  minutes: store.estimateMinutes(d, sessionMinutes: sessionMinutes),
                  sessionMinutes: sessionMinutes,
                  focus: d.focus.isNotEmpty ? d.focus : CustomPrograms.focusOf(d, catalog),
                  onMakeNext: () => unawaited(store.setNextDay(i)),
                ),
            ],
          ),
          const SizedBox(height: Space.l),
          BigButton(
            label: 'Change split',
            icon: Icons.swap_horiz,
            kind: BigButtonKind.secondary,
            height: Sizes.heroButton,
            onPressed: () => Navigator.of(context).pushNamed(Routes.programSplit),
          ),
          const SizedBox(height: Space.s),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Workout days and reminders'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.index,
    required this.day,
    required this.isNext,
    required this.minutes,
    required this.sessionMinutes,
    required this.focus,
    required this.onMakeNext,
  });

  final int index;
  final ProgramDay day;
  final bool isNext;
  final int minutes, sessionMinutes;
  final List<String> focus;
  final VoidCallback onMakeNext;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final count = day.items.where((i) => i.role != ItemRole.warmup && i.role != ItemRole.cooldown && i.role != ItemRole.stretch).length;
    final over = minutes > sessionMinutes;
    return Card(
      margin: const EdgeInsets.only(bottom: Space.m),
      shape: isNext
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: t.secondary, width: 2))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => Navigator.of(context).pushNamed(Routes.programDay, arguments: day.dayId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.xs, Space.m),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isNext ? t.secondary : t.surface2,
                foregroundColor: isNext ? t.onPrimary : t.onSurface,
                child: Text('${index + 1}', style: AppText.bodyStrong),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(day.name, style: AppText.bodyStrong.copyWith(color: t.onSurface))),
                        if (isNext) ...[
                          const SizedBox(width: Space.s),
                          Text('NEXT', style: AppText.overline.copyWith(color: t.secondary)),
                        ],
                      ],
                    ),
                    if (focus.isNotEmpty)
                      Text(focus.join(' · '), style: AppText.label.copyWith(color: t.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '$count exercises · about $minutes min',
                      style: AppText.label.copyWith(color: over ? t.warning : t.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Day options',
                onSelected: (v) {
                  if (v == 'next') onMakeNext();
                  if (v == 'edit') Navigator.of(context).pushNamed(Routes.programDay, arguments: day.dayId);
                },
                itemBuilder: (_) => [
                  if (!isNext) const PopupMenuItem(value: 'next', child: Text('Make this my next workout')),
                  const PopupMenuItem(value: 'edit', child: Text('View and edit')),
                ],
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(Space.s),
                  child: Icon(Icons.drag_handle, color: t.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
