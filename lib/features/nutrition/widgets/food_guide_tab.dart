// Owner: WS6. Food > Guide: hand portions, the swallow rule and what to expect week by week
// (SPEC 4.9, `portion_guide`, `expectations_timeline`).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../state/profile_store.dart';
import '../../../widgets/section_header.dart';
import 'food_common.dart';

class FoodGuideTab extends StatelessWidget {
  const FoodGuideTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.read<AssetCatalog>().personalization;
    final sex = context.watch<ProfileStore>().profile?.sex ?? Sex.male;
    final guide = _map(p.raw['portion_guide']);
    final perMeal = _map(guide[sex == Sex.female ? 'per_meal_female_deficit' : 'per_meal_male_deficit']);
    final equivalents = _map(guide['equivalents']);
    final swallow = guide['swallow_rule'];
    final timeline = [
      for (final row in (p.raw['expectations_timeline'] is List ? p.raw['expectations_timeline'] as List : const <Object?>[]))
        if (row is Map) row.cast<String, Object?>(),
    ];
    final disclaimer = p.raw['disclaimer'];
    final t = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
      children: [
        if (disclaimer is String) InfoNote(text: disclaimer),
        const SectionHeader('Each meal, use your hand'),
        FoodCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PortionRow(icon: Icons.set_meal, what: 'Protein', amount: _count(perMeal['protein_palms'], 'palm'), note: equivalents['palm_protein']),
              _PortionRow(icon: Icons.rice_bowl, what: 'Carbs', amount: _count(perMeal['carb_cupped_hands'], 'cupped hand'), note: equivalents['cupped_hand_carb']),
              _PortionRow(icon: Icons.eco, what: 'Vegetables', amount: _count(perMeal['veg_fists'], 'fist'), note: null),
              _PortionRow(icon: Icons.opacity, what: 'Fat (oil, shito, paste)', amount: _count(perMeal['fat_thumbs'], 'thumb'), note: equivalents['thumb_fat']),
            ],
          ),
        ),
        if (swallow is String) ...[
          const SizedBox(height: Space.m),
          InfoNote(text: swallow, icon: Icons.lightbulb_outline, color: t.primary),
        ],
        const SectionHeader('What to expect'),
        for (final row in timeline)
          Padding(padding: const EdgeInsets.only(bottom: Space.m), child: _TimelineCard(row: row)),
        Text(
          'Everyone is different. Flat weeks are normal: the weekly check-in on the Today tab looks at the trend.',
          style: AppText.label.copyWith(color: t.muted),
        ),
      ],
    );
  }

  static Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

  /// 2 -> "2 palms", [1, 2] -> "1-2 cupped hands", [1, 1] -> "1 thumb".
  static String _count(Object? v, String unit) {
    num? lo, hi;
    if (v is num) lo = hi = v;
    if (v is List && v.length == 2 && v[0] is num && v[1] is num) {
      lo = v[0] as num;
      hi = v[1] as num;
    }
    if (lo == null || hi == null) return '';
    final amount = lo == hi ? '$lo' : '$lo–$hi';
    return '$amount $unit${hi == 1 ? '' : 's'}';
  }
}

class _PortionRow extends StatelessWidget {
  const _PortionRow({required this.icon, required this.what, required this.amount, required this.note});

  final IconData icon;
  final String what, amount;
  final Object? note;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: t.primary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$what: $amount', style: AppText.body.copyWith(color: t.onSurface, fontWeight: FontWeight.w600)),
                if (n is String) Text(n, style: AppText.label.copyWith(color: t.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.row});

  final Map<String, Object?> row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final weeks = '${row['weeks'] ?? ''}';
    final title = weeks.endsWith('_total') ? 'After ${weeks.replaceAll('_total', '')} weeks' : 'Weeks $weeks';
    Widget line(String label, Object? value) => value is String
        ? Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label: ', style: AppText.label.copyWith(color: t.muted)),
              TextSpan(text: value, style: AppText.body.copyWith(color: t.onSurface)),
            ])),
          )
        : const SizedBox.shrink();
    return FoodCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.title.copyWith(fontSize: 18, color: t.primary)),
          line('Scale (kg)', row['scale_kg']),
          line('Body', row['body']),
          line('Strength', row['strength']),
        ],
      ),
    );
  }
}
