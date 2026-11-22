// Food > Calculator: add what you ate (or are about to eat) from a list of common Ghanaian,
// campus and fast foods, see calories and protein against today's targets, then log the protein
// points to the Today checklist.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../domain/food_calculator.dart';
import '../../../state/food_calculator_store.dart';
import '../../../state/nutrition_store.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/number_stepper.dart';
import '../../../widgets/section_header.dart';
import 'food_common.dart';

class FoodCalculatorTab extends StatelessWidget {
  const FoodCalculatorTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FoodCalculatorStore>();
    final db = store.db;
    if (!store.loaded || db == null) return const Center(child: CircularProgressIndicator());
    final day = store.day;
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
      children: [
        _Totals(day: day),
        const SizedBox(height: Space.m),
        BigButton(
          label: 'Add food',
          icon: Icons.add,
          height: Sizes.heroButton,
          onPressed: () => unawaited(_addFood(context, store)),
        ),
        if (day.entries.isNotEmpty || day.loggedPoints != 0) ...[
          const SizedBox(height: Space.m),
          _LogButton(store: store),
        ],
        SectionHeader(
          'On the list',
          trailing: day.entries.isEmpty
              ? null
              : TextButton(onPressed: () => unawaited(_confirmClear(context, store)), child: const Text('Clear')),
        ),
        if (day.entries.isEmpty)
          const EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Nothing added yet',
            body:
                'Add what you ate, or what you are thinking of eating, to see the calories and protein. '
                'The list resets at midnight.',
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, e) in day.entries.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.surface2),
                  _EntryTile(store: store, index: i, entry: e),
                ],
              ],
            ),
          ),
        if (db.note != null) ...[const SizedBox(height: Space.l), InfoNote(text: db.note!)],
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Totals

class _Totals extends StatelessWidget {
  const _Totals({required this.day});

  final FoodCalcDay day;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final targets = context.watch<NutritionStore>().targets;
    final kcal = day.kcal.round();
    final protein = day.proteinG.round();
    final lo = targets.calorieTargetKcal - 100, hi = targets.calorieTargetKcal + 100;
    final kcalLeft = targets.calorieTargetKcal - kcal;
    final proteinLeft = targets.proteinTargetG - protein;
    final over = kcal > hi;
    final String summary;
    if (day.entries.isEmpty) {
      summary = 'Your day: ${groupedInt(lo)}–${groupedInt(hi)} kcal and ${targets.proteinTargetG} g protein.';
    } else if (over) {
      summary =
          '${groupedInt(kcal - targets.calorieTargetKcal)} kcal over your target. '
          'One big day is fine; it is the week that counts.';
    } else {
      summary = [
        kcalLeft > 0 ? 'About ${groupedInt(kcalLeft)} kcal left' : 'Calories done for today',
        proteinLeft > 0 ? 'and $proteinLeft g protein to go.' : 'and protein done.',
      ].join(' ');
    }
    return FoodCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Meter(
                  icon: Icons.local_fire_department,
                  label: 'Calories',
                  value: groupedInt(kcal),
                  unit: 'kcal',
                  goal: 'of ${groupedInt(lo)}–${groupedInt(hi)}',
                  fraction: kcal / targets.calorieTargetKcal,
                  color: over ? t.warning : t.primary,
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: _Meter(
                  icon: Icons.egg_alt,
                  label: 'Protein',
                  value: '$protein',
                  unit: 'g',
                  goal: 'of ${targets.proteinTargetG} g · ${trimNumber(day.points)} pts',
                  fraction: protein / targets.proteinTargetG,
                  color: t.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(summary, style: AppText.label.copyWith(color: over ? t.warning : t.muted)),
        ],
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.goal,
    required this.fraction,
    required this.color,
  });

  final IconData icon;
  final String label, value, unit, goal;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      container: true,
      label: '$label: $value $unit $goal',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Space.xs),
              Text(label, style: AppText.label.copyWith(color: t.muted)),
            ],
          ),
          const SizedBox(height: Space.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: AppText.value.copyWith(fontSize: 32, color: t.onSurface),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: AppText.label.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: t.surface2,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            goal,
            style: AppText.tabular(AppText.label).copyWith(color: t.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.store});

  final FoodCalculatorStore store;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final day = store.day;
    final delta = day.pointsToLog;
    if (delta == 0) {
      if (day.loggedPoints == 0) return const SizedBox.shrink();
      return Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: t.success),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              '${trimNumber(day.loggedPoints)} protein ${_points(day.loggedPoints)} from this list are on Today.',
              style: AppText.label.copyWith(color: t.success),
            ),
          ),
        ],
      );
    }
    final label = delta > 0
        ? 'Log ${trimNumber(delta)} protein ${_points(delta)} to Today'
        : 'Take ${trimNumber(-delta)} ${_points(-delta)} back off Today';
    return BigButton(
      label: label,
      icon: delta > 0 ? Icons.playlist_add_check : Icons.undo,
      kind: BigButtonKind.secondary,
      height: Sizes.minTap,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final sent = await store.logPoints();
        final total = context.mounted ? context.read<NutritionStore>().today.proteinPoints : null;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${sent > 0 ? 'Added' : 'Took off'} ${trimNumber(sent.abs())} ${_points(sent.abs())}.'
              '${total == null ? '' : ' Today: ${trimNumber(total)} protein ${_points(total)}.'}',
            ),
          ),
        );
      },
    );
  }
}

String _points(double n) => n == 1 ? 'point' : 'points';

// ---------------------------------------------------------------------------------------------
// The list

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.store, required this.index, required this.entry});

  final FoodCalculatorStore store;
  final int index;
  final CalcEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final qty = entry.qty == 1 ? '' : '${trimNumber(entry.qty)} × ';
    return Dismissible(
      key: ObjectKey(entry),
      direction: DismissDirection.endToStart,
      background: Container(
        color: t.danger.withValues(alpha: 0.16),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        child: Icon(Icons.delete_outline, color: t.danger),
      ),
      onDismissed: (_) => unawaited(_remove(context, store, index, entry)),
      child: ListTile(
        minTileHeight: Sizes.minTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.xs),
        title: Text(entry.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
        subtitle: Text('$qty${entry.serving}', style: AppText.label.copyWith(color: t.muted)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${groupedInt(entry.totalKcal)} kcal',
              style: AppText.tabular(AppText.body).copyWith(color: t.onSurface),
            ),
            Text(
              '${trimNumber(entry.totalProteinG)} g protein',
              style: AppText.tabular(AppText.label).copyWith(color: t.muted),
            ),
          ],
        ),
        onTap: () => unawaited(_edit(context, store, index, entry)),
      ),
    );
  }
}

Future<void> _remove(BuildContext context, FoodCalculatorStore store, int index, CalcEntry entry) async {
  final messenger = ScaffoldMessenger.of(context);
  await store.removeAt(index);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Removed ${entry.name}.'),
      duration: Motion.snackUndo,
      action: SnackBarAction(label: 'Undo', onPressed: () => unawaited(store.insertAt(index, entry))),
    ),
  );
}

Future<void> _edit(BuildContext context, FoodCalculatorStore store, int index, CalcEntry entry) async {
  final food = entry.foodId == null ? null : store.db?.byId(entry.foodId!);
  final servings = food?.servings ?? [FoodServing(label: entry.serving, kcal: entry.kcal, proteinG: entry.proteinG)];
  final initial = food == null ? 0 : servings.indexWhere((s) => s.label == entry.serving);
  final result = await _showServingSheet(
    context,
    name: entry.name,
    note: food?.note,
    servings: servings,
    initialIndex: initial < 0 ? 0 : initial,
    initialQty: entry.qty,
    editing: true,
  );
  if (result == null || !context.mounted) return;
  if (result.remove) {
    await _remove(context, store, index, entry);
    return;
  }
  final s = servings[result.index];
  await store.replace(
    index,
    CalcEntry(
      foodId: entry.foodId,
      name: entry.name,
      serving: s.label,
      kcal: s.kcal,
      proteinG: s.proteinG,
      qty: result.qty,
    ),
  );
}

Future<void> _confirmClear(BuildContext context, FoodCalculatorStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear the list?'),
      content: const Text('Protein points you already logged stay on Today.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
      ],
    ),
  );
  if (ok ?? false) await store.clear();
}

// ---------------------------------------------------------------------------------------------
// Adding food

Future<void> _addFood(BuildContext context, FoodCalculatorStore store) async {
  final entry = await showModalBottomSheet<CalcEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: _FoodPicker(store: store)),
  );
  if (entry == null || !context.mounted) return;
  await store.add(entry);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Added ${entry.name}: ${groupedInt(entry.totalKcal)} kcal, ${trimNumber(entry.totalProteinG)} g protein.',
      ),
    ),
  );
}

class _FoodPicker extends StatefulWidget {
  const _FoodPicker({required this.store});

  final FoodCalculatorStore store;

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  static const _recentId = '_recent';
  final _query = TextEditingController();

  /// Null = all categories.
  String? _category;

  @override
  void initState() {
    super.initState();
    if (widget.store.recent.isNotEmpty) _category = _recentId;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Food> _results(FoodDatabase db) {
    final q = _query.text;
    if (_category == _recentId && q.trim().isEmpty) {
      return [for (final id in widget.store.recent) ?db.byId(id)];
    }
    return db.search(q, category: _category == _recentId ? null : _category);
  }

  Future<void> _pick(Food food) async {
    final result = await _showServingSheet(context, name: food.name, note: food.note, servings: food.servings);
    if (result == null || result.remove || !mounted) return;
    Navigator.of(context).pop(CalcEntry.of(food, food.servings[result.index], qty: result.qty));
  }

  Future<void> _custom() async {
    final entry = await _showCustomSheet(context, name: _query.text.trim());
    if (entry != null && mounted) Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final db = widget.store.db!;
    final results = _results(db);
    final chips = <(String?, String)>[
      if (widget.store.recent.isNotEmpty) (_recentId, 'Recent'),
      (null, 'All'),
      for (final c in db.categories) (c.id, c.label),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.s),
          child: Text('Add food', style: AppText.title.copyWith(color: t.onSurface)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search: waakye, shawarma, Milo…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: Space.s),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.page),
            children: [
              for (final (i, (id, label)) in chips.indexed) ...[
                if (i > 0) const SizedBox(width: Space.s),
                ChoiceChip(
                  label: Text(label),
                  selected: _category == id,
                  onSelected: (_) => setState(() => _category = id),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              for (final f in results) _FoodTile(food: f, onTap: () => unawaited(_pick(f))),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Text(
                    'No food matches "${_query.text.trim()}".',
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: t.muted),
                  ),
                ),
              ListTile(
                minTileHeight: Sizes.minTap,
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.page),
                leading: Icon(Icons.edit_note, color: t.primary),
                title: Text('Not on the list? Add your own', style: AppText.bodyStrong.copyWith(color: t.primary)),
                subtitle: Text(
                  'Type the calories and protein from the pack or a guess.',
                  style: AppText.label.copyWith(color: t.muted),
                ),
                onTap: () => unawaited(_custom()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = food.servings.first;
    final more = food.servings.length > 1 ? ' · +${food.servings.length - 1} more' : '';
    return ListTile(
      minTileHeight: Sizes.minTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.page),
      title: Text(food.name, style: AppText.body.copyWith(color: t.onSurface)),
      subtitle: Text(
        '${s.label} · ${groupedInt(s.kcal)} kcal · ${trimNumber(s.proteinG)} g protein$more',
        style: AppText.label.copyWith(color: t.muted),
      ),
      trailing: Icon(Icons.add_circle_outline, color: t.primary),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Serving + amount sheet

typedef _ServingResult = ({int index, double qty, bool remove});

Future<_ServingResult?> _showServingSheet(
  BuildContext context, {
  required String name,
  String? note,
  required List<FoodServing> servings,
  int initialIndex = 0,
  double initialQty = 1,
  bool editing = false,
}) => showModalBottomSheet<_ServingResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ServingSheet(
    name: name,
    note: note,
    servings: servings,
    initialIndex: initialIndex,
    initialQty: initialQty,
    editing: editing,
  ),
);

class _ServingSheet extends StatefulWidget {
  const _ServingSheet({
    required this.name,
    required this.note,
    required this.servings,
    required this.initialIndex,
    required this.initialQty,
    required this.editing,
  });

  final String name;
  final String? note;
  final List<FoodServing> servings;
  final int initialIndex;
  final double initialQty;
  final bool editing;

  @override
  State<_ServingSheet> createState() => _ServingSheetState();
}

class _ServingSheetState extends State<_ServingSheet> {
  late int _index = widget.initialIndex;
  late double _qty = widget.initialQty;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.servings[_index];
    final kcal = s.kcal * _qty, protein = s.proteinG * _qty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.name, style: AppText.title.copyWith(color: t.onSurface)),
          if (widget.note != null) ...[
            const SizedBox(height: Space.s),
            InfoNote(text: widget.note!, icon: Icons.lightbulb_outline, color: t.primary),
          ],
          if (widget.servings.length > 1) ...[
            const SizedBox(height: Space.l),
            Text('Serving', style: AppText.label.copyWith(color: t.muted)),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final (i, sv) in widget.servings.indexed)
                  ChoiceChip(
                    label: Text(sv.label),
                    selected: _index == i,
                    onSelected: (_) => setState(() => _index = i),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: Space.xs),
            Text(s.label, style: AppText.body.copyWith(color: t.muted)),
          ],
          const SizedBox(height: Space.l),
          Text('How many', style: AppText.label.copyWith(color: t.muted)),
          const SizedBox(height: Space.xs),
          NumberStepper(
            value: _qty,
            step: 0.5,
            min: 0.5,
            max: 20,
            unit: '×',
            onChanged: (v) => setState(() => _qty = v),
          ),
          const SizedBox(height: Space.l),
          Text(
            '≈ ${groupedInt(kcal)} kcal · ${trimNumber(protein)} g protein · ${trimNumber(proteinPointsFor(protein))} '
            '${_points(proteinPointsFor(protein))}',
            textAlign: TextAlign.center,
            style: AppText.tabular(AppText.bodyStrong).copyWith(color: t.onSurface),
          ),
          const SizedBox(height: Space.l),
          BigButton(
            label: widget.editing ? 'Save' : 'Add to list',
            icon: widget.editing ? Icons.check : Icons.add,
            height: Sizes.heroButton,
            onPressed: () => Navigator.of(context).pop((index: _index, qty: _qty, remove: false)),
          ),
          if (widget.editing) ...[
            const SizedBox(height: Space.s),
            BigButton(
              label: 'Remove from list',
              kind: BigButtonKind.destructive,
              height: Sizes.minTap,
              onPressed: () => Navigator.of(context).pop((index: _index, qty: _qty, remove: true)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Own food

Future<CalcEntry?> _showCustomSheet(BuildContext context, {String name = ''}) => showModalBottomSheet<CalcEntry>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _CustomSheet(initialName: name),
);

class _CustomSheet extends StatefulWidget {
  const _CustomSheet({required this.initialName});

  final String initialName;

  @override
  State<_CustomSheet> createState() => _CustomSheetState();
}

class _CustomSheetState extends State<_CustomSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  final _kcal = TextEditingController();
  final _protein = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kcal = _num(_kcal);
    final valid = _name.text.trim().isNotEmpty && kcal != null && kcal >= 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your own food', style: AppText.title.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.l),
          TextField(
            controller: _name,
            autofocus: widget.initialName.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What is it?'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kcal,
                  autofocus: widget.initialName.isNotEmpty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Calories', suffixText: 'kcal'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: TextField(
                  controller: _protein,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Protein (optional)', suffixText: 'g'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          BigButton(
            label: 'Add to list',
            icon: Icons.add,
            height: Sizes.heroButton,
            onPressed: valid
                ? () => Navigator.of(context).pop(
                    CalcEntry(
                      name: _name.text.trim(),
                      serving: '1 serving',
                      kcal: kcal,
                      proteinG: (_num(_protein) ?? 0).clamp(0, 500).toDouble(),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
