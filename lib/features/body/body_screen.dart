// Owner: WS5. Body tracking: weight and waist, one entry per date (SPEC 4.8).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/body_store.dart';
import '../../state/profile_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/number_stepper.dart';
import '../../widgets/section_header.dart';
import '../../widgets/undo_snackbar.dart';
import '../progress/history_format.dart';
import '../progress/progress_widgets.dart';

/// Body screen (route `/body`).
class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  late final BodyStore _store = context.read<BodyStore>();
  late String _date;

  /// Values in the user's display unit (kg or lb, cm or in).
  double _weight = 0, _waist = 0;
  bool _withWeight = true, _withWaist = false;
  bool _saving = false;

  bool get _useLb => context.read<ProfileStore>().profile?.useLb ?? false;
  bool get _useIn => context.read<ProfileStore>().profile?.useFtIn ?? false;

  @override
  void initState() {
    super.initState();
    _date = _store.todayKey;
    _prefill();
  }

  /// Loads the saved entry of [_date], or sensible starting values (last weigh-in / profile).
  void _prefill() {
    final profile = context.read<ProfileStore>().profile;
    final entry = _store.entryFor(_date);
    final weightKg = entry?.weightKg ?? _store.latestWeight?.weightKg ?? profile?.weightKg ?? 80;
    final waistCm = entry?.waistCm ?? _store.latestWaist?.waistCm ?? profile?.startWaistCm ?? 95;
    _weight = _round(Units.displayWeight(weightKg, useLb: _useLb), 1);
    _waist = _round(_useIn ? Units.cmToInches(waistCm) : waistCm, _useIn ? 2 : 1);
    _withWeight = entry == null || entry.weightKg != null;
    _withWaist = entry?.waistCm != null;
  }

  static double _round(double v, int decimals) => double.parse(v.toStringAsFixed(decimals));

  void _selectDate(String key) => setState(() {
        _date = key;
        _prefill();
      });

  Future<void> _pickDate() async {
    final today = Fmt.parseDateKey(_store.todayKey);
    final picked = await showDatePicker(
      context: context,
      initialDate: Fmt.parseDateKey(_date),
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      helpText: 'Date of the measurement',
    );
    if (picked != null && mounted) _selectDate(Fmt.dateKey(picked));
  }

  Future<void> _typeValue({required bool weight}) async {
    final unit = weight ? Units.weightUnit(useLb: _useLb) : (_useIn ? 'in' : 'cm');
    final v = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NumberEntrySheet(
        title: weight ? 'Weight ($unit)' : 'Waist ($unit)',
        initial: weight ? _weight : _waist,
        max: weight ? 700 : 300,
      ),
    );
    if (v == null || !mounted) return;
    setState(() => weight ? _weight = _round(v, 1) : _waist = _round(v, _useIn ? 2 : 1));
  }

  Future<void> _save() async {
    if (!_withWeight && !_withWaist) return;
    final existing = _store.entryFor(_date);
    final entry = BodyEntry(
      date: _date,
      weightKg: _withWeight ? _round(Units.weightToKg(_weight, useLb: _useLb), 2) : null,
      waistCm: _withWaist ? _round(_useIn ? Units.inchesToCm(_waist) : _waist, 1) : null,
      note: existing?.note,
    );
    setState(() => _saving = true);
    await _store.upsert(entry);
    if (!mounted) return;
    setState(() => _saving = false);
    final now = context.read<Clock>().now();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved for ${shortDate(Fmt.parseDateKey(_date), now: now)}')));
  }

  Future<void> _delete(BodyEntry e) async {
    await _store.delete(e.date);
    if (!mounted) return;
    if (e.date == _date) setState(_prefill);
    showUndoSnackBar(context, 'Entry deleted', () async {
      await _store.upsert(e);
      if (mounted && e.date == _date) setState(_prefill);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BodyStore>();
    final t = context.tokens;
    final useLb = _useLb;
    final useIn = _useIn;
    final now = context.read<Clock>().now();
    final todayKey = store.todayKey;
    final today = Fmt.parseDateKey(todayKey);
    final yesterdayKey = Fmt.dateKey(DateTime(today.year, today.month, today.day - 1));
    final existing = store.entryFor(_date);
    final tracking = _progressTracking(context.read<AssetCatalog>());
    final weighIn = (tracking['weigh_in'] as Map?)?.cast<String, dynamic>() ?? const {};
    final waistInfo = (tracking['waist'] as Map?)?.cast<String, dynamic>() ?? const {};
    final protocol = [for (final p in (weighIn['protocol'] as List?) ?? const <Object?>[]) '$p'];
    final weighInMessage = weighIn['message'] as String?;
    final waistProtocol = waistInfo['protocol'] as String?;
    final lastWaist = store.latestWaist;
    final daysSinceWaist =
        lastWaist == null ? null : today.difference(Fmt.parseDateKey(lastWaist.date)).inDays;
    final muted = AppText.body.copyWith(color: t.muted, fontSize: 14);
    final avg = store.avg7;

    return Scaffold(
      appBar: AppBar(title: const Text('Body')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
        children: [
          _AverageCard(
            text: avg == null ? 'Need 3 weigh-ins' : Fmt.weight(avg, useLb: useLb, maxDecimals: 1),
            sub: avg == null
                ? 'You have ${store.weighInsLast7} in the last 7 days. The average needs 3.'
                : '7-day average from ${store.weighInsLast7} weigh-ins',
          ),
          if (weighInMessage != null) ...[
            const SizedBox(height: Space.s),
            Text(weighInMessage, style: muted),
          ],
          const SectionHeader('Date'),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              _DateChip(label: 'Today', selected: _date == todayKey, onTap: () => _selectDate(todayKey)),
              _DateChip(
                label: 'Yesterday',
                selected: _date == yesterdayKey,
                onTap: () => _selectDate(yesterdayKey),
              ),
              _DateChip(
                label: _date == todayKey || _date == yesterdayKey
                    ? 'Other date'
                    : shortDate(Fmt.parseDateKey(_date), now: now),
                icon: Icons.calendar_today,
                selected: _date != todayKey && _date != yesterdayKey,
                onTap: () => unawaited(_pickDate()),
              ),
            ],
          ),
          if (existing != null) ...[
            const SizedBox(height: Space.s),
            Text('You already logged this date. Saving replaces it.', style: muted),
          ],
          _ToggleHeader(
            title: 'Weight',
            value: _withWeight,
            onChanged: (v) => setState(() => _withWeight = v),
          ),
          if (_withWeight)
            NumberStepper(
              value: _weight,
              step: useLb ? 0.2 : 0.1,
              unit: Units.weightUnit(useLb: useLb),
              min: useLb ? 66 : 30,
              max: useLb ? 660 : 300,
              decimals: 1,
              onChanged: (v) => setState(() => _weight = v),
              onTapValue: () => unawaited(_typeValue(weight: true)),
            ),
          _ToggleHeader(
            title: 'Waist at the navel',
            subtitle: daysSinceWaist == null
                ? 'Measure once a week'
                : daysSinceWaist >= 7
                    ? 'Due: last measured $daysSinceWaist days ago'
                    : 'Last measured ${daysSinceWaist == 0 ? 'today' : '$daysSinceWaist days ago'}',
            value: _withWaist,
            onChanged: (v) => setState(() => _withWaist = v),
          ),
          if (_withWaist) ...[
            NumberStepper(
              value: _waist,
              step: useIn ? 0.25 : 0.5,
              unit: useIn ? 'in' : 'cm',
              min: useIn ? 16 : 40,
              max: useIn ? 100 : 250,
              decimals: useIn ? 2 : 1,
              onChanged: (v) => setState(() => _waist = v),
              onTapValue: () => unawaited(_typeValue(weight: false)),
            ),
            if (waistProtocol != null) ...[
              const SizedBox(height: Space.s),
              Text('$waistProtocol.', style: muted),
            ],
          ],
          if (protocol.isNotEmpty) ...[
            const SectionHeader('How to weigh in'),
            for (final p in protocol)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: Space.s),
                      child: Icon(Icons.check_circle_outline, size: 20, color: t.success),
                    ),
                    Expanded(child: Text(p, style: AppText.body.copyWith(color: t.onSurface))),
                  ],
                ),
              ),
          ],
          if (store.entries.isNotEmpty) ...[
            SectionHeader('Recent entries', trailing: Text('Tap to edit', style: muted)),
            for (final e in store.entries.reversed.take(14))
              _EntryRow(
                entry: e,
                now: now,
                useLb: useLb,
                useIn: useIn,
                selected: e.date == _date,
                onTap: () => _selectDate(e.date),
                onDelete: () => unawaited(_delete(e)),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.page),
          child: BigButton(
            label: !_withWeight && !_withWaist
                ? 'Turn on weight or waist'
                : (existing != null ? 'Update entry' : 'Save'),
            icon: Icons.check,
            onPressed: _saving || (!_withWeight && !_withWaist) ? null : () => unawaited(_save()),
          ),
        ),
      ),
    );
  }

  static Map<String, dynamic> _progressTracking(AssetCatalog c) =>
      (c.personalization.raw['progress_tracking'] as Map?)?.cast<String, dynamic>() ?? const {};
}

class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.text, required this.sub});

  final String text, sub;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('7-day average', style: AppText.label.copyWith(color: t.muted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(text, style: AppText.value.copyWith(color: t.onSurface)),
            ),
            Text(sub, style: AppText.label.copyWith(color: t.muted)),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 18),
        selected: selected,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.m),
        onSelected: (_) => onTap(),
      );
}

/// Section title with an on/off switch; the whole row is the tap target.
class _ToggleHeader extends StatelessWidget {
  const _ToggleHeader({required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
      child: MergeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.button),
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.minTap),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
                      if (subtitle != null) Text(subtitle!, style: AppText.label.copyWith(color: t.muted)),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.now,
    required this.useLb,
    required this.useIn,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  final BodyEntry entry;
  final DateTime now;
  final bool useLb, useIn, selected;
  final VoidCallback onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parts = [
      if (entry.weightKg != null) Fmt.weight(entry.weightKg!, useLb: useLb, maxDecimals: 1),
      if (entry.waistCm != null)
        'waist ${useIn ? '${Fmt.number(Units.cmToInches(entry.waistCm!), maxDecimals: 1)} in' : '${Fmt.number(entry.waistCm!, maxDecimals: 1)} cm'}',
    ];
    final date = shortDate(Fmt.parseDateKey(entry.date), now: now);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            label: '$date, ${parts.join(', ')}. Tap to edit.',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.button),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.minTap),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 32,
                      margin: const EdgeInsets.only(right: Space.m),
                      decoration: BoxDecoration(
                        color: selected ? t.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 112, child: Text(date, style: AppText.label.copyWith(color: t.muted))),
                    Expanded(
                      child: Text(parts.join(' · '), style: AppText.tabular(AppText.body).copyWith(color: t.onSurface)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.s),
        IconButton(
          tooltip: 'Delete $date',
          constraints: const BoxConstraints.tightFor(width: Sizes.minTap, height: Sizes.minTap),
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline, color: t.muted),
        ),
      ],
    );
  }
}
