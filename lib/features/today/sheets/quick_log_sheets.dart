// Owner: WS4. Quick logs on Today (SPEC 4.3): body weight and rest-day cardio.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/clock.dart';
import '../../../core/format.dart';
import '../../../core/units.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../state/body_store.dart';
import '../../../state/profile_store.dart';
import '../../../state/today_store.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/option_card.dart';
import '../../onboarding/widgets/form_widgets.dart';

/// Body-weight entry for today (one entry per date; saving again replaces it, waist is kept).
Future<void> showWeightLogSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _WeightSheet(),
    );

class _WeightSheet extends StatefulWidget {
  const _WeightSheet();

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late final bool _lb = context.read<ProfileStore>().profile?.useLb ?? false;
  late double _shown = _initial();

  double _initial() {
    final entries = context.read<BodyStore>().entries;
    final last = entries.lastWhere((e) => e.weightKg != null, orElse: () => const BodyEntry(date: ''));
    final kg = last.weightKg ?? context.read<ProfileStore>().profile?.weightKg ?? 80;
    return double.parse(Units.displayWeight(kg, useLb: _lb).toStringAsFixed(1));
  }

  Future<void> _save() async {
    final body = context.read<BodyStore>();
    final navigator = Navigator.of(context);
    final date = Fmt.dateKey(context.read<Clock>().now());
    final existing = body.entries.where((e) => e.date == date).firstOrNull;
    final kg = double.parse(Units.weightToKg(_shown, useLb: _lb).toStringAsFixed(2));
    await body.upsert(BodyEntry(date: date, weightKg: kg, waistCm: existing?.waistCm, note: existing?.note));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final weighIn = (context.read<AssetCatalog>().personalization.raw['progress_tracking'] as Map?)?['weigh_in'];
    final message = weighIn is Map ? weighIn['message'] : null;
    final unit = Units.weightUnit(useLb: _lb);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Today's weight", style: AppText.headline.copyWith(color: t.onSurface)),
            Text(
              message is String ? message : 'Weigh in the morning, after the toilet, before eating.',
              style: AppText.body.copyWith(color: t.muted),
            ),
            const SizedBox(height: Space.l),
            StepperField(
              title: "Today's weight",
              value: _shown,
              step: _lb ? 0.2 : 0.1,
              unit: unit,
              min: _lb ? 88 : 40,
              max: _lb ? 551 : 250,
              decimals: 1,
              onChanged: (v) => setState(() => _shown = v),
            ),
            const SizedBox(height: Space.xl),
            BigButton(label: 'Save', icon: Icons.check, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// The rest-day cardio choices (exercise id, label, icon).
const List<(String, String, IconData)> cardioChoices = [
  ('treadmill_brisk_walk', 'Brisk walk', Icons.directions_walk),
  ('bike_steady_state', 'Exercise bike', Icons.directions_bike),
  ('treadmill_incline_walk', 'Incline walk', Icons.trending_up),
];

/// "Log cardio" (SPEC 4.3): writes a `cardio_logs` row.
Future<void> showCardioLogSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CardioSheet(),
    );

class _CardioSheet extends StatefulWidget {
  const _CardioSheet();

  @override
  State<_CardioSheet> createState() => _CardioSheetState();
}

class _CardioSheetState extends State<_CardioSheet> {
  String _exerciseId = cardioChoices.first.$1;
  double _minutes = 20;

  Future<void> _save() async {
    final today = context.read<TodayStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final label = cardioChoices.firstWhere((c) => c.$1 == _exerciseId).$2.toLowerCase();
    await today.logCardio(exerciseId: _exerciseId, minutes: _minutes.round());
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text('Logged ${_minutes.round()} min $label. Nice.')));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log cardio', style: AppText.headline.copyWith(color: t.onSurface)),
            Text('An easy walk or ride on a rest day helps recovery and fat loss.',
                style: AppText.body.copyWith(color: t.muted)),
            const SizedBox(height: Space.l),
            for (final (id, label, icon) in cardioChoices)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: OptionCard(
                  icon: icon,
                  title: label,
                  selected: _exerciseId == id,
                  onTap: () => setState(() => _exerciseId = id),
                ),
              ),
            const FieldLabel('How long?'),
            StepperField(
              title: 'Minutes',
              value: _minutes,
              step: 5,
              unit: 'min',
              min: 5,
              max: 180,
              onChanged: (v) => setState(() => _minutes = v),
            ),
            const SizedBox(height: Space.xl),
            BigButton(label: 'Save', icon: Icons.check, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
