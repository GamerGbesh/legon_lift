// Owner: WS6. Food helper (SPEC 4.9): targets, daily checklist, weekly check-in, meal ideas and
// the portion guide. Not a food logger.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../state/milestone_store.dart';
import '../../state/nutrition_store.dart';
import 'widgets/food_guide_tab.dart';
import 'widgets/food_today_tab.dart';
import 'widgets/meal_ideas_tab.dart';

/// Food screen: "Today" (targets, checklist, check-in), "Meals" (ideas, protein points) and
/// "Guide" (portions, what to expect).
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionStore _store;
  late final MilestoneStore _milestones;
  NutritionDay? _openedWith;

  @override
  void initState() {
    super.initState();
    _store = context.read<NutritionStore>();
    _milestones = context.read<MilestoneStore>();
    // Body entries and the checklist may have changed elsewhere since the store was loaded.
    unawaited(_store.load().then((_) => _openedWith = _store.today));
  }

  @override
  void dispose() {
    // Habit milestones (protein, water, steps, sleep) are evaluated after the day was saved.
    final opened = _openedWith;
    if (opened != null && opened != _store.today) unawaited(_milestones.evaluateNow());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Food'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Today', height: 56),
                Tab(text: 'Meals', height: 56),
                Tab(text: 'Guide', height: 56),
              ],
            ),
          ),
          body: const TabBarView(children: [FoodTodayTab(), MealIdeasTab(), FoodGuideTab()]),
        ),
      );
}
