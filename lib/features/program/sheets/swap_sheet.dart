// Owner: WS4. "Replace in my program" for one slot of a template day (SPEC 4.5): the swap
// suggester's alternatives (SPEC 6.9), plus the original exercise when the slot was replaced.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../domain/api.dart';
import '../../../state/program_store.dart';
import '../../../state/settings_store.dart';
import '../../../widgets/exercise_thumb.dart';

/// Returns the chosen exercise id (null when dismissed).
Future<String?> showSwapSheet(BuildContext context, {required String dayId, required DaySlot slot}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SwapSheet(dayId: dayId, slot: slot),
    );

class _SwapSheet extends StatefulWidget {
  const _SwapSheet({required this.dayId, required this.slot});

  final String dayId;
  final DaySlot slot;

  @override
  State<_SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<_SwapSheet> {
  late final Future<List<SwapOption>> _options = context
      .read<ProgramStore>()
      .swapOptions(widget.dayId, widget.slot, context.read<SettingsStore>().settings.equipment,
          smithEarly: context.read<SettingsStore>().settings.smithEarly);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    final current = catalog.tryExercise(widget.slot.exerciseId);
    final original = widget.slot.replaced ? catalog.tryExercise(widget.slot.item.exerciseId) : null;
    Widget row(Exercise ex, String why, {bool history = false}) => ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 72,
          leading: ExerciseThumb(exercise: ex, size: 52),
          title: Text(ex.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
          subtitle: Text(history ? '$why · you have done this before' : why, style: AppText.label.copyWith(color: t.muted)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pop(ex.id),
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.page),
        child: FutureBuilder<List<SwapOption>>(
          future: _options,
          builder: (context, snap) {
            final options = snap.data ?? const <SwapOption>[];
            return ListView(
              shrinkWrap: true,
              children: [
                Text('Replace in my program', style: AppText.headline.copyWith(color: t.onSurface)),
                Text(
                  current == null
                      ? 'Pick an alternative.'
                      : 'Instead of ${current.name}, in every phase of this program. Weights carry over per exercise.',
                  style: AppText.body.copyWith(color: t.muted),
                ),
                const SizedBox(height: Space.m),
                if (original != null) row(original, 'Back to the original'),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(Space.xl), child: Center(child: CircularProgressIndicator()))
                else if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.l),
                    child: Text('No alternative fits your equipment. Tick more equipment in Settings.',
                        style: AppText.body.copyWith(color: t.muted)),
                  )
                else
                  for (final o in options) row(o.exercise, o.why, history: o.hasHistory),
              ],
            );
          },
        ),
      ),
    );
  }
}
