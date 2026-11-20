// Owner: WS6. Food > Today: targets, daily checklist and the weekly check-in (SPEC 4.9, 10.2).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../domain/api.dart';
import '../../../state/nutrition_store.dart';
import '../../../state/profile_store.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/number_stepper.dart';
import '../../../widgets/section_header.dart';
import 'food_common.dart';

class FoodTodayTab extends StatelessWidget {
  const FoodTodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NutritionStore>();
    final p = context.read<AssetCatalog>().personalization;
    final disclaimer = p.raw['disclaimer'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
      children: [
        if (disclaimer is String) InfoNote(text: disclaimer),
        const SectionHeader('Your daily targets'),
        _TargetsGrid(store: store),
        const SizedBox(height: Space.m),
        _TargetsBasis(store: store),
        SectionHeader("Today's checklist", trailing: _GoodDayChip(good: store.isGoodDay)),
        _Checklist(store: store),
        const SectionHeader('Weekly check-in'),
        _CheckinCard(store: store),
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Targets

class _TargetsGrid extends StatelessWidget {
  const _TargetsGrid({required this.store});

  final NutritionStore store;

  @override
  Widget build(BuildContext context) {
    final t = store.targets;
    final training = store.isTrainingDay;
    final otherMl = training ? t.waterRestMl : t.waterTrainingMl;
    final tiles = [
      _TargetTile(
        icon: Icons.local_fire_department,
        label: 'Calories',
        value: '${groupedInt(t.calorieTargetKcal - 100)}–${groupedInt(t.calorieTargetKcal + 100)}',
        caption: 'kcal a day',
      ),
      _TargetTile(
        icon: Icons.egg_alt,
        label: 'Protein',
        value: '${t.proteinTargetG} g',
        caption: '${t.proteinPointsTarget} points of 20 g\nat least ${t.proteinMinG} g',
      ),
      _TargetTile(
        icon: Icons.water_drop,
        label: training ? 'Water (training day)' : 'Water (rest day)',
        value: litres(store.waterTargetMl),
        caption: '${trimNumber(store.waterTargetSachets)} sachets\n'
            '${training ? 'Rest' : 'Training'} days: ${trimNumber(sachetsFor(otherMl))}',
      ),
      _TargetTile(
        icon: Icons.directions_walk,
        label: 'Steps',
        value: groupedInt(t.stepsTarget),
        caption: 'steps a day',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - Space.m) / 2;
      return Wrap(
        spacing: Space.m,
        runSpacing: Space.m,
        children: [for (final tile in tiles) SizedBox(width: w, child: tile)],
      );
    });
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.icon, required this.label, required this.value, required this.caption});

  final IconData icon;
  final String label, value, caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      container: true,
      label: '$label: $value. ${caption.replaceAll('\n', '. ')}',
      excludeSemantics: true,
      child: FoodCard(
        padding: const EdgeInsets.all(Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: t.primary),
              const SizedBox(width: Space.xs),
              Expanded(child: Text(label, style: AppText.label.copyWith(color: t.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: Space.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppText.value.copyWith(fontSize: 32, color: t.onSurface)),
            ),
            Text(caption, style: AppText.label.copyWith(color: t.muted)),
          ],
        ),
      ),
    );
  }
}

class _TargetsBasis extends StatelessWidget {
  const _TargetsBasis({required this.store});

  final NutritionStore store;

  @override
  Widget build(BuildContext context) {
    final useLb = context.watch<ProfileStore>().profile?.useLb ?? false;
    final kg = Fmt.weight(store.targetsWeightKg, useLb: useLb, maxDecimals: 1);
    final date = store.targetsWeightDate;
    final adjust = store.calorieAdjustmentKcal;
    final lines = [
      if (date != null)
        'Based on $kg, your 7-day average on ${shortDate(date)}. Targets update after 4 kg or 8 weeks.'
      else
        'Based on your profile weight, $kg. Weigh in 3 or more times a week on the Body screen and we will use your average.',
      if (adjust != 0) 'Includes ${signedInt(adjust)} kcal from your weekly check-in.',
      'Calories are a range: anywhere in it is a good day.',
    ];
    return Text(lines.join(' '), style: AppText.label.copyWith(color: context.tokens.muted));
  }
}

// ---------------------------------------------------------------------------------------------
// Checklist

class _GoodDayChip extends StatelessWidget {
  const _GoodDayChip({required this.good});

  final bool good;

  @override
  Widget build(BuildContext context) {
    if (!good) return const SizedBox.shrink();
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs),
      decoration: BoxDecoration(color: t.success.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.chip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 18, color: t.success),
        const SizedBox(width: Space.xs),
        Text('Good day', style: AppText.label.copyWith(color: t.success)),
      ]),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.store});

  final NutritionStore store;

  /// Checklist labels from `personalization.daily_checklist`, by id.
  static Map<String, String> _labels(AssetCatalog catalog) {
    final list = catalog.personalization.raw['daily_checklist'];
    return {
      if (list is List)
        for (final item in list)
          if (item is Map && item['id'] is String && item['label'] is String) item['id'] as String: item['label'] as String,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final labels = _labels(context.read<AssetCatalog>());
    final day = store.today;
    final targets = store.targets;
    String label(String id, String fallback) => labels[id] ?? fallback;
    final toggles = [
      ('veg_fruit', label('veg_fruit', 'Veg or fruit with 2+ meals'), day.vegFruit),
      ('steps', label('steps', 'Step target reached'), day.stepsHit),
      ('sleep', label('sleep', '7+ hours sleep last night'), day.sleepOk),
      ('no_sugary_drinks', label('no_sugary_drinks', 'No sugary drinks (or 1 max)'), day.noSugaryDrinks),
    ];
    return FoodCard(
      padding: const EdgeInsets.symmetric(vertical: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CounterRow(
            title: label('protein', 'Protein points'),
            goal: 'Goal ${targets.proteinPointsTarget} · good day ${targets.proteinPointsGoodDay}+',
            stepper: NumberStepper(
              value: day.proteinPoints,
              step: 0.5,
              max: 30,
              unit: 'points',
              onChanged: (v) => unawaited(store.addProtein(v - day.proteinPoints)),
            ),
          ),
          Divider(color: t.surface2, height: Space.xl),
          _CounterRow(
            title: label('water', 'Water (sachets)'),
            goal: 'Goal ${trimNumber(store.waterTargetSachets)} · 1 sachet = 500 ml',
            stepper: NumberStepper(
              value: day.waterSachets,
              step: 0.5,
              max: 30,
              unit: 'sachets',
              onChanged: (v) => unawaited(store.addWater(v - day.waterSachets)),
            ),
          ),
          Divider(color: t.surface2, height: Space.xl),
          for (final (id, text, value) in toggles)
            CheckboxListTile(
              value: value,
              onChanged: (v) => unawaited(store.setCheck(id, v ?? false)),
              title: Text(text, style: AppText.body.copyWith(color: t.onSurface)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.s),
              activeColor: t.success,
            ),
          ListTile(
            minTileHeight: Sizes.minTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.l),
            leading: Icon(Icons.directions_walk, color: t.muted),
            title: Text('Steps today (optional)', style: AppText.body.copyWith(color: t.onSurface)),
            subtitle: Text(
              day.steps == null ? 'Tap to enter from your phone or watch' : '${groupedInt(day.steps!)} of ${groupedInt(targets.stepsTarget)}',
              style: AppText.label.copyWith(color: t.muted),
            ),
            trailing: Icon(Icons.edit, color: t.muted),
            onTap: () => unawaited(_editSteps(context, store)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, Space.s, Space.l, 0),
            child: Text(
              store.isGoodDay
                  ? 'Good day: protein done and ${store.otherItemsMet} of the other 5.'
                  : 'A good day is ${targets.proteinPointsGoodDay}+ protein points and 3 of the other 5 '
                      '(you have ${store.otherItemsMet}).',
              style: AppText.label.copyWith(color: store.isGoodDay ? t.success : t.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({required this.title, required this.goal, required this.stepper});

  final String title, goal;
  final Widget stepper;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.body.copyWith(color: t.onSurface, fontWeight: FontWeight.w600)),
          Text(goal, style: AppText.label.copyWith(color: t.muted)),
          const SizedBox(height: Space.s),
          stepper,
        ],
      ),
    );
  }
}

Future<void> _editSteps(BuildContext context, NutritionStore store) async {
  final controller = TextEditingController(text: store.today.steps?.toString() ?? '');
  final result = await showModalBottomSheet<({int? steps})>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final t = context.tokens;
      void save() => Navigator.of(context).pop((steps: int.tryParse(controller.text.trim())));
      return Padding(
        padding: EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.l + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Steps today', style: AppText.title.copyWith(color: t.onSurface)),
            const SizedBox(height: Space.s),
            Text('Copy the number from your phone or watch.', style: AppText.body.copyWith(color: t.muted)),
            const SizedBox(height: Space.l),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: AppText.value.copyWith(color: t.onSurface),
              decoration: const InputDecoration(hintText: '0', suffixText: 'steps'),
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: Space.xl),
            BigButton(label: 'Save', onPressed: save),
            const SizedBox(height: Space.s),
            BigButton(
              label: 'Clear',
              kind: BigButtonKind.secondary,
              height: Sizes.minTap,
              onPressed: () => Navigator.of(context).pop((steps: null)),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (result != null) await store.setSteps(result.steps);
}

// ---------------------------------------------------------------------------------------------
// Weekly check-in

class _CheckinCard extends StatelessWidget {
  const _CheckinCard({required this.store});

  final NutritionStore store;

  static String _title(String ruleId) => switch (ruleId) {
        'on_track' => 'On track',
        'too_fast' => 'Losing a bit fast',
        'slow_ok' => 'Slow but steady',
        'plateau' => 'Plateau',
        'recomp' => 'Losing fat, gaining muscle',
        'gaining' => 'Weight creeping up',
        'fatigued' => 'Tired and getting weaker?',
        CheckinRuleIds.keepGoing => 'Keep going',
        CheckinRuleIds.notEnoughData => 'Not enough weigh-ins yet',
        _ => 'This week',
      };

  static String _actionLabel(CheckinAdvice a) {
    final parts = [
      if (a.deltaKcal != 0) '${signedInt(a.deltaKcal)} kcal',
      if (a.deltaSteps != 0) '${signedInt(a.deltaSteps)} steps',
    ];
    return 'Apply: ${parts.join(' and ')} a day';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final advice = store.checkin;
    final change = store.lastWeekChange;
    final useLb = context.watch<ProfileStore>().profile?.useLb ?? false;
    return FoodCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title(advice.ruleId), style: AppText.title.copyWith(color: t.onSurface)),
          if (change != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              'Week ${change.week}: ${change.kg >= 0 ? 'down' : 'up'} ${Fmt.weight(change.kg.abs(), useLb: useLb, maxDecimals: 1)} '
              '(${change.lossPct.abs().toStringAsFixed(1)}% of body weight)',
              style: AppText.tabular(AppText.label).copyWith(color: t.muted),
            ),
          ],
          if (advice.message.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Text(advice.message, style: AppText.body.copyWith(color: t.onSurface)),
          ],
          if (advice.canApply) ...[
            const SizedBox(height: Space.l),
            BigButton(
              label: _actionLabel(advice),
              icon: Icons.check,
              height: Sizes.heroButton,
              onPressed: () => unawaited(_apply(context, advice)),
            ),
          ],
          if (store.adjustments.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            Text('Changes so far', style: AppText.label.copyWith(color: t.muted)),
            for (final a in store.adjustments.reversed.take(5))
              Bullet([
                shortDate(a.date),
                if (a.deltaKcal != 0) '${signedInt(a.deltaKcal)} kcal a day',
                if ((a.deltaSteps ?? 0) != 0) '${signedInt(a.deltaSteps!)} steps a day',
              ].join(' · ')),
          ],
          const SizedBox(height: Space.m),
          Text(
            'We look at your weekly average weight once a week. Changes are small (200 kcal at most) '
            'and at least 2 weeks apart.',
            style: AppText.label.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, CheckinAdvice advice) async {
    final messenger = ScaffoldMessenger.of(context);
    await store.applyCheckin(advice);
    final tg = store.targets;
    messenger.showSnackBar(SnackBar(
      content: Text('Done. Your targets: ${groupedInt(tg.calorieTargetKcal)} kcal and ${groupedInt(tg.stepsTarget)} steps a day.'),
    ));
  }
}
