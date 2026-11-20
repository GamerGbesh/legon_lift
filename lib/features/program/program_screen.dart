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
import '../../state/today_store.dart';
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
    final plans = context.watch<TodayStore>().dayPlans;

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
                        Expanded(
                          child: Text('Next up: ${next.name}', style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                        ),
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
                  minutes: plans[d.dayId]?.estimatedMinutes ?? store.estimateMinutes(d, sessionMinutes: sessionMinutes),
                  exercises: plans[d.dayId]?.exerciseSteps.length ?? _countExercises(d),
                  sessionMinutes: sessionMinutes,
                  focus: [
                    for (final m in d.focus.isNotEmpty ? d.focus : CustomPrograms.focusOf(d, catalog))
                      _focusLabel(m),
                  ],
                  onMakeNext: () => unawaited(store.setNextDay(i)),
                  onRename: template.isCustom ? () => unawaited(_renameDay(context, store, catalog, d)) : null,
                  onRemove: template.isCustom && days.length > 1
                      ? () => unawaited(_removeDay(context, store, d))
                      : null,
                ),
            ],
          ),
          if (template.isCustom && days.length < maxCustomDays)
            Center(
              child: TextButton.icon(
                onPressed: () => unawaited(_addDay(context, store, catalog, days.length)),
                icon: const Icon(Icons.add),
                label: const Text('Add a day'),
              ),
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

/// Most days a custom program can have.
const int maxCustomDays = 7;

Future<String?> _askDayName(BuildContext context, {required String title, required String initial}) =>
    showDialog<String>(context: context, builder: (_) => _DayNameDialog(title: title, initial: initial));

/// Name field for a custom day. Owns its controller so it lives until the dialog is gone.
class _DayNameDialog extends StatefulWidget {
  const _DayNameDialog({required this.title, required this.initial});

  final String title, initial;

  @override
  State<_DayNameDialog> createState() => _DayNameDialogState();
}

class _DayNameDialogState extends State<_DayNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Arms and abs'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
        ],
      );
}

Future<void> _addDay(BuildContext context, ProgramStore store, AssetCatalog catalog, int count) async {
  final name = (await _askDayName(context, title: 'New day', initial: 'Day ${String.fromCharCode(65 + count)}'))
      ?.trim();
  final t = store.template;
  if (name == null || name.isEmpty || t == null) return;
  await store.saveCustom(CustomPrograms.addDay(t, catalog, name: name));
}

Future<void> _renameDay(BuildContext context, ProgramStore store, AssetCatalog catalog, ProgramDay day) async {
  final name = (await _askDayName(context, title: 'Rename day', initial: day.name))?.trim();
  final t = store.template;
  if (name == null || name.isEmpty || name == day.name || t == null) return;
  await store.saveCustom(CustomPrograms.replaceDay(t, day.copyWith(name: name), catalog));
}

Future<void> _removeDay(BuildContext context, ProgramStore store, ProgramDay day) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Remove ${day.name}?'),
      content: const Text('The day and its exercise list are removed from your program. '
          'Workouts you already did stay in your history.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
      ],
    ),
  );
  final t = store.template;
  if (ok != true || t == null) return;
  await store.saveCustom(CustomPrograms.removeDay(t, day.dayId));
}

/// "front_delts" -> "Front shoulders", "back" -> "Back".
String _focusLabel(String m) {
  final muscle = Muscle.values.where((v) => v.wire == m).firstOrNull;
  if (muscle != null) return muscle.label;
  final text = m.replaceAll('_', ' ');
  return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

/// Exercises in [day] before the session builder has run: main and superset items, without
/// switched-off extras.
int _countExercises(ProgramDay day) => day.blocks
    .where((b) => b.blockType == BlockType.main || b.blockType == BlockType.superset)
    .expand((b) => b.items)
    .where((i) => !i.optional)
    .length;

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.index,
    required this.day,
    required this.isNext,
    required this.minutes,
    required this.exercises,
    required this.sessionMinutes,
    required this.focus,
    required this.onMakeNext,
    this.onRename,
    this.onRemove,
  });

  final int index;
  final ProgramDay day;
  final bool isNext;
  final int minutes, exercises, sessionMinutes;
  final List<String> focus;
  final VoidCallback onMakeNext;
  final VoidCallback? onRename, onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
                      exercises == 0 ? 'No exercises yet: tap to add some' : '$exercises exercises · about $minutes min',
                      style: AppText.label.copyWith(color: exercises == 0 ? t.secondary : (over ? t.warning : t.muted)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Day options',
                onSelected: (v) {
                  if (v == 'next') onMakeNext();
                  if (v == 'edit') Navigator.of(context).pushNamed(Routes.programDay, arguments: day.dayId);
                  if (v == 'rename') onRename?.call();
                  if (v == 'remove') onRemove?.call();
                },
                itemBuilder: (_) => [
                  if (!isNext) const PopupMenuItem(value: 'next', child: Text('Make this my next workout')),
                  const PopupMenuItem(value: 'edit', child: Text('View and edit')),
                  if (onRename != null) const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  if (onRemove != null) const PopupMenuItem(value: 'remove', child: Text('Remove day')),
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
