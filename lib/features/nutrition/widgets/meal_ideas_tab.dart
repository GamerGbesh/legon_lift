// Owner: WS6. Food > Meals: Ghanaian meal ideas with filters, and what a protein point looks like
// (SPEC 4.9, `meal_ideas`, `protein_points`).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../domain/api.dart';
import '../../../domain/meal_scaler.dart';
import '../../../state/nutrition_store.dart';
import '../../../state/profile_store.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/section_header.dart';
import 'food_common.dart';

class MealIdeasTab extends StatefulWidget {
  const MealIdeasTab({super.key});

  @override
  State<MealIdeasTab> createState() => _MealIdeasTabState();
}

class _MealIdeasTabState extends State<MealIdeasTab> {
  static const _types = <(String?, String)>[
    (null, 'All'),
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('snack', 'Snack'),
  ];
  static const _costs = <(String?, String)>[(null, 'Any cost'), ('low', 'Low'), ('medium', 'Medium'), ('high', 'High')];
  static const _dietNotes = <(String, String)>[
    ('no_pork', 'No pork'),
    ('vegetarian', 'Vegetarian'),
    ('lactose_intolerant', 'No milk'),
    ('groundnut_allergy', 'No groundnuts'),
    ('fish_allergy', 'No fish'),
  ];

  String? _type;
  String? _cost;
  bool _costFromBudget = true;

  /// "Size portions for me": scale each meal to this meal's share of the daily targets.
  bool _sized = true;

  @override
  Widget build(BuildContext context) {
    final p = context.read<AssetCatalog>().personalization;
    final profileStore = context.watch<ProfileStore>();
    final profile = profileStore.profile;
    final dietNotes = profile?.dietNotes ?? const <String>[];
    // A tight food budget starts on low-cost meals; the chips can change it.
    final cost = _costFromBudget && profile?.budget == 'tight' ? 'low' : _cost;
    final meals = [
      for (final m in p.meals)
        if (mealMatchesType(m, _type) && (cost == null || m.costTier == cost) && mealFitsDiet(m, dietNotes)) m,
    ];
    final t = context.tokens;
    final valuesNote = p.raw['values_note'];
    final targets = context.watch<NutritionStore>().targets;
    ScaledMeal? sizedFor(MealIdea m) => _sized
        ? scaleMeal(m, calorieKcal: targets.calorieTargetKcal, proteinG: targets.proteinTargetG)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
      children: [
        _ChipRow(
          children: [
            for (final (value, label) in _types)
              ChoiceChip(
                label: Text(label),
                selected: _type == value,
                onSelected: (_) => setState(() => _type = value),
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        _ChipRow(
          children: [
            for (final (value, label) in _costs)
              ChoiceChip(
                label: Text(label),
                selected: cost == value,
                onSelected: (_) => setState(() {
                  _cost = value;
                  _costFromBudget = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        _ChipRow(
          children: [
            for (final (id, label) in _dietNotes)
              FilterChip(
                label: Text(label),
                selected: dietNotes.contains(id),
                onSelected: profile == null
                    ? null
                    : (on) => unawaited(profileStore.save(profile.copyWith(
                          dietNotes: on ? [...dietNotes, id] : [for (final n in dietNotes) if (n != id) n],
                        ))),
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        Card(
          child: SwitchListTile(
            value: _sized,
            onChanged: (v) => setState(() => _sized = v),
            title: Text('Size portions for me', style: AppText.bodyStrong.copyWith(color: t.onSurface)),
            subtitle: Text(
              'For ${groupedInt(targets.calorieTargetKcal)} kcal and ${targets.proteinTargetG} g protein a day: '
              'breakfast 25%, lunch 30%, dinner 30%, snack 15%. More protein, less starch.',
              style: AppText.label.copyWith(color: t.muted),
            ),
          ),
        ),
        const SizedBox(height: Space.m),
        Text(
          '${meals.length} ${meals.length == 1 ? 'idea' : 'ideas'}. Protein and kcal are rough values (~)'
          '${_sized ? ' for your portion.' : ' for a typical portion.'}',
          style: AppText.label.copyWith(color: t.muted),
        ),
        const SizedBox(height: Space.m),
        if (meals.isEmpty)
          const EmptyState(
            icon: Icons.restaurant,
            title: 'No meals match',
            body: 'Try "All" or "Any cost". Diet notes are saved to your profile.',
          )
        else
          for (final m in meals) Padding(padding: const EdgeInsets.only(bottom: Space.m), child: _MealCard(meal: m, scaled: sizedFor(m))),
        const SectionHeader('What is 1 protein point?'),
        _ProteinPoints(p: p),
        const SectionHeader('Pair these with protein'),
        _PlainList(items: _strings(p.raw['low_protein_foods_pair_with_protein'])),
        const SectionHeader('Cheap protein to keep at home'),
        _PlainList(items: _strings(p.raw['pantry_protein_boosters'])),
        if (valuesNote is String) ...[
          const SizedBox(height: Space.l),
          InfoNote(text: valuesNote),
        ],
      ],
    );
  }

  static List<String> _strings(Object? v) => [if (v is List) for (final x in v) if (x is String) x];
}

/// Horizontally scrolling chips with 8 dp gaps.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: Space.s), c],
        ]),
      );
}

class _MealCard extends StatefulWidget {
  const _MealCard({required this.meal, this.scaled});

  final MealIdea meal;

  /// The portion sized to the user's targets (null: show the standard portion).
  final ScaledMeal? scaled;

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _open = false;

  static String _cost(String tier) => switch (tier) {
        'low' => 'Low cost',
        'medium' => 'Medium cost',
        'high' => 'Higher cost',
        _ => tier,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = widget.meal;
    final scaled = widget.scaled;
    final sized = scaled != null && !scaled.isStandard;
    final proteinG = sized ? scaled.proteinG : m.proteinG;
    final kcal = sized ? scaled.kcal : m.kcalApprox;
    final components = sized ? scaled.components : m.components;
    final points = proteinG / proteinGramsPerPoint;
    final roundedPoints = (points * 2).round() / 2;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTap),
          child: Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(m.name, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface))),
                    Icon(_open ? Icons.expand_less : Icons.expand_more, color: t.muted),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  '${sized ? 'For you: ' : ''}~$proteinG g protein (${trimNumber(roundedPoints)} '
                  '${roundedPoints == 1 ? 'point' : 'points'}) · ~${groupedInt(kcal)} kcal · ${_cost(m.costTier)}',
                  style: AppText.tabular(AppText.label).copyWith(color: sized ? t.primary : t.muted),
                ),
                if (_open) ...[
                  const SizedBox(height: Space.m),
                  for (final c in components) Bullet(c),
                  if (sized) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      'Standard portion: ~${m.proteinG} g protein · ~${groupedInt(m.kcalApprox)} kcal '
                      '(${m.components.join(', ')})',
                      style: AppText.caption.copyWith(color: t.muted),
                    ),
                  ],
                  if (m.tips.isNotEmpty) ...[
                    const SizedBox(height: Space.s),
                    InfoNote(text: m.tips, icon: Icons.lightbulb_outline, color: t.primary),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProteinPoints extends StatelessWidget {
  const _ProteinPoints({required this.p});

  final Personalization p;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pp = p.raw['protein_points'];
    final items = [
      if (pp is Map && pp['items'] is List)
        for (final i in pp['items'] as List)
          if (i is Map && i['label'] is String && i['points'] is num) (i['label'] as String, (i['points'] as num).toDouble()),
    ];
    return FoodCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('1 point = about 20 g of protein. Count half points for small portions.',
              style: AppText.body.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.m),
          for (final (label, points) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Row(children: [
                Expanded(child: Text(label, style: AppText.body.copyWith(color: t.onSurface))),
                const SizedBox(width: Space.m),
                Text(
                  '${trimNumber(points)} ${points == 1 ? 'point' : 'points'}',
                  style: AppText.tabular(AppText.label).copyWith(color: t.primary),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _PlainList extends StatelessWidget {
  const _PlainList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) => FoodCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final i in items) Bullet(_capitalise(i))],
        ),
      );

  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
