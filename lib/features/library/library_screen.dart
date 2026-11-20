// Owner: WS5. Exercise library: search and filter chips (SPEC 4.6).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../data/models/models.dart';
import '../../state/library_store.dart';
import '../../state/settings_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exercise_thumb.dart';
import 'exercise_detail_screen.dart';
import 'muscle_groups.dart';

/// Library screen (tab).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final TextEditingController _search =
      TextEditingController(text: context.read<LibraryStore>().query.text);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearAll(LibraryStore store) {
    _search.clear();
    store.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final q = store.query;
    final results = store.results;
    final t = context.tokens;
    final filtersOn = q.muscles.isNotEmpty || q.equipment.isNotEmpty || q.favoritesOnly || store.mobility;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.s),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                style: AppText.body.copyWith(color: t.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search exercises',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            store.setQuery(q.copyWith(text: ''));
                          },
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.button)),
                  contentPadding: const EdgeInsets.symmetric(vertical: Space.l),
                ),
                onChanged: (text) => store.setQuery(store.query.copyWith(text: text)),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FilterRows(store: store)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${results.length} ${results.length == 1 ? 'exercise' : 'exercises'}',
                      style: AppText.label.copyWith(color: t.muted),
                    ),
                  ),
                  if (filtersOn || q.text.isNotEmpty || !q.beginnerOnly || q.showAllEquipment)
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () => _clearAll(store),
                      child: const Text('Reset filters'),
                    ),
                ],
              ),
            ),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off,
                title: 'No exercises match',
                body: q.beginnerOnly
                    ? 'Try fewer filters, or turn off "Beginner friendly".'
                    : 'Try fewer filters or another word.',
                action: BigButton(
                  label: 'Reset filters',
                  kind: BigButtonKind.secondary,
                  height: Sizes.minTap,
                  onPressed: () => _clearAll(store),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
              sliver: SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, i) => _ExerciseRow(
                  exercise: results[i],
                  favorite: store.isFavorite(results[i].id),
                  onFavorite: () => store.toggleFavorite(results[i].id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two horizontally scrolling chip rows: general + muscles, then equipment.
class _FilterRows extends StatelessWidget {
  const _FilterRows({required this.store});

  final LibraryStore store;

  @override
  Widget build(BuildContext context) {
    final q = store.query;
    final settings = context.watch<SettingsStore>().settings;
    final ticked = settings.equipment.available;
    final equipment = [
      for (final e in Equipment.values)
        if (e != Equipment.bodyweight && (q.showAllEquipment || ticked.contains(e) || q.equipment.contains(e))) e,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChipRow(children: [
          _Chip(
            label: 'Beginner friendly',
            selected: q.beginnerOnly,
            onSelected: (v) => store.setQuery(q.copyWith(beginnerOnly: v)),
          ),
          _Chip(
            label: 'Favourites',
            icon: Icons.star,
            selected: q.favoritesOnly,
            onSelected: (v) => store.setQuery(q.copyWith(favoritesOnly: v)),
          ),
          for (final g in muscleGroups)
            _Chip(
              label: g.label,
              selected: g.muscles.every(q.muscles.contains),
              onSelected: (v) => store.setQuery(q.copyWith(
                muscles: v ? {...q.muscles, ...g.muscles} : q.muscles.difference(g.muscles),
              )),
            ),
          _Chip(label: 'Mobility', selected: store.mobility, onSelected: store.setMobility),
        ]),
        _ChipRow(children: [
          _Chip(
            label: 'Show all equipment',
            icon: Icons.visibility,
            selected: q.showAllEquipment,
            onSelected: (v) => store.setQuery(q.copyWith(showAllEquipment: v)),
          ),
          for (final e in equipment)
            _Chip(
              label: equipmentLabel(e),
              selected: q.equipment.contains(e),
              onSelected: (v) => store.setQuery(q.copyWith(
                equipment: v ? {...q.equipment, e} : ({...q.equipment}..remove(e)),
              )),
            ),
        ]),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: Sizes.minTap,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: Space.s),
          itemBuilder: (_, i) => Center(child: children[i]),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onSelected, this.icon});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        avatar: icon == null || selected ? null : Icon(icon, size: 18),
        selected: selected,
        onSelected: onSelected,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.s),
      );
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.favorite, required this.onFavorite});

  final Exercise exercise;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final muscle = exercise.primaryMuscles.isEmpty ? '' : exercise.primaryMuscles.first.label;
    final equipment = mainEquipmentLabel(exercise);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: '${exercise.name}. $muscle, $equipment.',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => Navigator.of(context)
                  .pushNamed(Routes.exercise, arguments: ExerciseDetailArgs(exerciseId: exercise.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Row(
                  children: [
                    ExerciseThumb(exercise: exercise),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: AppText.body.copyWith(color: t.onSurface, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  muscle,
                                  style: AppText.label.copyWith(color: t.muted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: Space.s),
                              Icon(equipmentIcon(exercise), size: 16, color: t.muted),
                              const SizedBox(width: Space.xs),
                              Flexible(
                                child: Text(
                                  equipment,
                                  style: AppText.label.copyWith(color: t.muted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: favorite ? 'Remove ${exercise.name} from favourites' : 'Add ${exercise.name} to favourites',
          constraints: const BoxConstraints.tightFor(width: Sizes.minTap, height: Sizes.minTap),
          onPressed: onFavorite,
          icon: Icon(favorite ? Icons.star : Icons.star_border, color: favorite ? t.primary : t.muted),
        ),
      ],
    );
  }
}
