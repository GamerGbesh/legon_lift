// Owner: WS4. Day editor (`/program/day`, SPEC 4.5). Template programs: swap a slot ("Replace in my
// program"), switch optional items on/off, reset to template. Custom programs: also sets, reps,
// add, remove and reorder. A live time estimate turns amber above the session length.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/profile_store.dart';
import '../../state/program_store.dart';
import '../../state/today_store.dart';
import '../../widgets/exercise_thumb.dart';
import '../../widgets/section_header.dart';
import '../library/exercise_detail_screen.dart';
import 'custom_program.dart';
import 'sheets/exercise_picker_sheet.dart';
import 'sheets/swap_sheet.dart';

/// Day editor screen.
class DayEditorScreen extends StatelessWidget {
  const DayEditorScreen({super.key, required this.dayId});

  final String dayId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final store = context.watch<ProgramStore>();
    final catalog = context.read<AssetCatalog>();
    final day = store.phase?.day(dayId);
    final template = store.template;
    if (day == null || template == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('This day is not in your program.')));
    }
    final custom = store.active?.isCustom ?? false;
    final sessionMinutes = context.watch<ProfileStore>().profile?.sessionMinutes ?? 60;
    final minutes = context.watch<TodayStore>().dayPlans[dayId]?.estimatedMinutes ??
        store.estimateMinutes(day, sessionMinutes: sessionMinutes);
    final slots = store.slotsFor(dayId);
    final anyReplaced = store.overrides.any((o) => o.dayId == dayId);

    return Scaffold(
      appBar: AppBar(
        title: Text(day.name),
        actions: [
          if (!custom && anyReplaced)
            TextButton(
              onPressed: () => unawaited(_confirmReset(context, store, day.name)),
              child: const Text('Reset'),
            ),
        ],
      ),
      floatingActionButton: custom
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(_addExercise(context, store, template, day)),
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, 96),
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: minutes > sessionMinutes ? t.warning : t.muted),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  minutes > sessionMinutes
                      ? 'About $minutes min: longer than your $sessionMinutes min. The app trims extras on the day.'
                      : 'About $minutes min (your sessions: $sessionMinutes min)',
                  style: AppText.label.copyWith(color: minutes > sessionMinutes ? t.warning : t.muted),
                ),
              ),
            ],
          ),
          if (day.notes.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(day.notes, style: AppText.body.copyWith(color: t.muted)),
          ],
          for (final (bi, block) in day.blocks.indexed) ...[
            SectionHeader(block.name.isEmpty ? _blockName(block.blockType) : block.name),
            if (block.items.isEmpty)
              Text('Nothing here yet. Tap "Add exercise".', style: AppText.body.copyWith(color: t.muted)),
            for (final slot in slots.where((s) => s.blockIndex == bi))
              _SlotTile(
                slot: slot,
                custom: custom,
                week: store.trainingWeek,
                onSwap: () => unawaited(_swap(context, store, template, day, slot, custom)),
                onToggle: (v) => unawaited(store.setOptionalEnabled(dayId, slot.item, v)),
                onEdit: custom ? () => unawaited(_editItem(context, store, template, day, slot)) : null,
                onRemove: custom ? () => unawaited(_save(store, catalog, template, _removeItem(day, slot))) : null,
                onMove: custom ? (delta) => unawaited(_save(store, catalog, template, _moveItem(day, slot, delta))) : null,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, ProgramStore store, String dayName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset $dayName?'),
        content: const Text('Replaced exercises and switched extras go back to the plan. '
            'Your history and weights are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) await store.resetDay(dayId);
  }

  static String _blockName(BlockType type) => switch (type) {
        BlockType.warmup => 'Warm-up',
        BlockType.cooldown => 'Cool-down',
        BlockType.finisher => 'Finisher',
        _ => 'Main',
      };

  Future<void> _save(ProgramStore store, AssetCatalog catalog, ProgramTemplate t, ProgramDay day) =>
      store.saveCustom(CustomPrograms.replaceDay(t, day, catalog));

  Future<void> _swap(
      BuildContext context, ProgramStore store, ProgramTemplate t, ProgramDay day, DaySlot slot, bool custom) async {
    final catalog = context.read<AssetCatalog>();
    final id = await showSwapSheet(context, dayId: dayId, slot: slot);
    if (id == null) return;
    if (!custom) {
      await store.replaceInProgram(dayId, slot.slotKey, id);
      return;
    }
    await _save(store, catalog, t, _mapItem(day, slot, (i) => i.copyWith(exerciseId: id)));
  }

  Future<void> _addExercise(BuildContext context, ProgramStore store, ProgramTemplate t, ProgramDay day) async {
    final catalog = context.read<AssetCatalog>();
    final id = await showExercisePicker(context, exclude: {for (final i in day.items) i.exerciseId});
    if (id == null) return;
    final item = CustomPrograms.itemFor(catalog.exercise(id));
    var mainIndex = day.blocks.lastIndexWhere((b) => b.blockType == BlockType.main);
    final blocks = [...day.blocks];
    if (mainIndex < 0) {
      blocks.add(const ProgramBlock(blockType: BlockType.main, name: 'Main', items: []));
      mainIndex = blocks.length - 1;
    }
    blocks[mainIndex] = blocks[mainIndex].copyWith(items: [...blocks[mainIndex].items, item]);
    await _save(store, catalog, t, day.copyWith(blocks: blocks));
  }

  Future<void> _editItem(
      BuildContext context, ProgramStore store, ProgramTemplate t, ProgramDay day, DaySlot slot) async {
    final catalog = context.read<AssetCatalog>();
    final edited = await showModalBottomSheet<ProgramItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemEditor(item: slot.item, exercise: catalog.exercise(slot.exerciseId)),
    );
    if (edited == null) return;
    await _save(store, catalog, t, _mapItem(day, slot, (_) => edited));
  }

  ProgramDay _mapItem(ProgramDay day, DaySlot slot, ProgramItem Function(ProgramItem) f) {
    final blocks = [
      for (final (bi, b) in day.blocks.indexed)
        bi == slot.blockIndex
            ? b.copyWith(items: [for (final i in b.items) identical(i, slot.item) || i == slot.item ? f(i) : i])
            : b,
    ];
    return day.copyWith(blocks: blocks);
  }

  ProgramDay _removeItem(ProgramDay day, DaySlot slot) => day.copyWith(blocks: [
        for (final (bi, b) in day.blocks.indexed)
          bi == slot.blockIndex ? b.copyWith(items: [for (final i in b.items) if (i != slot.item) i]) : b,
      ]);

  ProgramDay _moveItem(ProgramDay day, DaySlot slot, int delta) {
    final b = day.blocks[slot.blockIndex];
    final items = [...b.items];
    final from = items.indexOf(slot.item);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= items.length) return day;
    items.insert(to, items.removeAt(from));
    final blocks = [...day.blocks];
    blocks[slot.blockIndex] = b.copyWith(items: items);
    return day.copyWith(blocks: blocks);
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.custom,
    required this.week,
    required this.onSwap,
    required this.onToggle,
    this.onEdit,
    this.onRemove,
    this.onMove,
  });

  final DaySlot slot;
  final bool custom;
  final int week;
  final VoidCallback onSwap;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit, onRemove;
  final ValueChanged<int>? onMove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    final ex = catalog.exercise(slot.exerciseId);
    final item = slot.item;
    final optional = item.optional || slot.block.optional;
    final range = item.repRange;
    final amount = item.durationSeconds != null
        ? Fmt.clock(item.durationSeconds!)
        : range == null
            ? ''
            : (range.$1 == range.$2 ? '${range.$1}' : '${range.$1}–${range.$2}');
    final details = [
      if (amount.isNotEmpty) '${item.sets} × $amount${item.perSide ? ' each side' : ''}',
      if (item.restSeconds > 0) 'rest ${Fmt.clock(item.restSeconds)}',
      if (item.rir != null) Fmt.rirTarget(item.rir!),
    ].join(' · ');
    final swappable = item.role != ItemRole.warmup && item.role != ItemRole.cooldown && item.role != ItemRole.stretch;

    return Opacity(
      opacity: slot.enabled ? 1 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: Space.s),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => Navigator.of(context)
              .pushNamed(Routes.exercise, arguments: ExerciseDetailArgs(exerciseId: ex.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.xs, Space.m),
            child: Row(
              children: [
                ExerciseThumb(exercise: ex, size: 52),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                      if (details.isNotEmpty) Text(details, style: AppText.label.copyWith(color: t.muted)),
                      if (slot.replaced)
                        Text('Replaced: was ${catalog.tryExercise(item.exerciseId)?.name ?? item.exerciseId}',
                            style: AppText.caption.copyWith(color: t.secondary)),
                      if (optional && !custom)
                        Text(
                          slot.block.blockType != BlockType.finisher
                              ? 'Optional'
                              : !slot.enabled
                                  ? 'Off: never added'
                                  : week <= 1
                                      ? 'Starts in week 2, when it fits your time'
                                      : 'Added when it fits your time',
                          style: AppText.caption.copyWith(color: t.secondary),
                        ),
                    ],
                  ),
                ),
                if (optional && !custom) Switch(value: slot.enabled, onChanged: onToggle),
                if (swappable || custom)
                  PopupMenuButton<String>(
                    tooltip: 'Exercise options',
                    onSelected: (v) => switch (v) {
                      'swap' => onSwap(),
                      'edit' => onEdit?.call(),
                      'remove' => onRemove?.call(),
                      'up' => onMove?.call(-1),
                      'down' => onMove?.call(1),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'swap', child: Text(custom ? 'Change exercise' : 'Replace in my program')),
                      if (custom) ...[
                        const PopupMenuItem(value: 'edit', child: Text('Sets, reps and rest')),
                        const PopupMenuItem(value: 'up', child: Text('Move up')),
                        const PopupMenuItem(value: 'down', child: Text('Move down')),
                        const PopupMenuItem(value: 'remove', child: Text('Remove')),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.item, required this.exercise});

  final ProgramItem item;
  final Exercise exercise;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late int _sets = widget.item.sets;
  late int _low = widget.item.repRange?.$1 ?? 8;
  late int _high = widget.item.repRange?.$2 ?? 12;
  late int _rest = widget.item.restSeconds;
  late int? _rir = widget.item.rir;
  late int _seconds = widget.item.durationSeconds ?? 30;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final timed = widget.item.durationSeconds != null;
    Widget counter(String label, int value, int step, int min, int max, ValueChanged<int> set, {String Function(int)? fmt}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppText.body.copyWith(color: t.onSurface))),
              IconButton.filledTonal(
                onPressed: value - step >= min ? () => setState(() => set(value - step)) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 72,
                child: Text(fmt?.call(value) ?? '$value',
                    textAlign: TextAlign.center, style: AppText.tabular(AppText.title).copyWith(color: t.onSurface)),
              ),
              IconButton.filledTonal(
                onPressed: value + step <= max ? () => setState(() => set(value + step)) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.exercise.name, style: AppText.title.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.l),
          counter('Sets', _sets, 1, 1, 8, (v) => _sets = v),
          if (timed)
            counter('Seconds', _seconds, 5, 10, 600, (v) => _seconds = v)
          else ...[
            counter('Fewest reps', _low, 1, 1, 30, (v) {
              _low = v;
              if (_high < v) _high = v;
            }),
            counter('Most reps', _high, 1, 1, 30, (v) {
              _high = v;
              if (_low > v) _low = v;
            }),
            counter('Reps left in the tank', _rir ?? 2, 1, 0, 5, (v) => _rir = v),
          ],
          counter('Rest', _rest, 15, 15, 300, (v) => _rest = v, fmt: Fmt.clock),
          const SizedBox(height: Space.l),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(widget.item.copyWith(
              sets: _sets,
              repRange: () => timed ? null : (_low, _high),
              durationSeconds: () => timed ? _seconds : null,
              rir: () => timed ? null : _rir,
              restSeconds: _rest,
            )),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
