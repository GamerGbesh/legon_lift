// Owner: WS4. Picks an exercise for a custom day (SPEC 4.5 "add (Library in pick mode)"):
// searchable list of exercises the gym can do; the info button opens the Library detail in
// pick mode, whose "Add" returns the id.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../state/settings_store.dart';
import '../../../widgets/exercise_thumb.dart';
import '../../library/exercise_detail_screen.dart';

/// Returns the chosen exercise id (null when dismissed).
Future<String?> showExercisePicker(BuildContext context, {Set<String> exclude = const {}}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (context, controller) => _Picker(controller: controller, exclude: exclude),
      ),
    );

class _Picker extends StatefulWidget {
  const _Picker({required this.controller, required this.exclude});

  final ScrollController controller;
  final Set<String> exclude;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  String _query = '';
  bool _showAll = false;

  static String _fold(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    final eq = context.read<SettingsStore>().settings.equipment;
    final q = _fold(_query.trim());
    bool fits(Exercise e) =>
        e.equipment.every(eq.available.contains) ||
        (e.equipment.contains(Equipment.bike) && e.equipment.contains(Equipment.treadmill));
    final list = [
      for (final e in catalog.exercises)
        if (!widget.exclude.contains(e.id) &&
            e.category != ExerciseCategory.warmup &&
            e.category != ExerciseCategory.mobility &&
            (_showAll || fits(e)) &&
            (q.isEmpty || _fold([e.name, ...e.aliases].join(' ')).contains(q)))
          e,
    ]..sort((a, b) => a.difficulty != b.difficulty ? a.difficulty.compareTo(b.difficulty) : a.name.compareTo(b.name));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add an exercise', style: AppText.headline.copyWith(color: t.onSurface)),
              const SizedBox(height: Space.s),
              TextField(
                autofocus: false,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search exercises'),
                onChanged: (v) => setState(() => _query = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Include equipment the gym does not have', style: AppText.label.copyWith(color: t.onSurface)),
                value: _showAll,
                onChanged: (v) => setState(() => _showAll = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No exercise matches.', style: AppText.body.copyWith(color: t.muted)))
              : ListView.builder(
                  controller: widget.controller,
                  padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.s, Space.page),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 72,
                      leading: ExerciseThumb(exercise: e, size: 52),
                      title: Text(e.name, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
                      subtitle: Text(e.primaryMuscles.map((m) => m.label).join(', '),
                          style: AppText.label.copyWith(color: t.muted)),
                      trailing: IconButton(
                        tooltip: 'How to do it',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final picked = await navigator.pushNamed<Object?>(
                            Routes.exercise,
                            arguments: ExerciseDetailArgs(exerciseId: e.id, pickMode: true),
                          );
                          if (picked is String) navigator.pop(picked);
                        },
                      ),
                      onTap: () => Navigator.of(context).pop(e.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
