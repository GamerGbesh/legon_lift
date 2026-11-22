// Owner: WS6. Food helper (SPEC 4.9): targets, daily checklist, weekly check-in, a calorie and
// protein calculator, meal ideas and the portion guide.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/clock.dart';
import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';
import '../../state/food_calculator_store.dart';
import '../../state/milestone_store.dart';
import '../../state/nutrition_store.dart';
import 'widgets/food_calculator_tab.dart';
import 'widgets/food_guide_tab.dart';
import 'widgets/food_today_tab.dart';
import 'widgets/meal_ideas_tab.dart';

/// Food screen: "Today" (targets, checklist, check-in), "Calories" (calculator for what you
/// ate), "Meals" (ideas, protein points) and "Guide" (portions, what to expect).
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionStore _store;
  late final MilestoneStore _milestones;
  late final FoodCalculatorStore _calculator;
  NutritionDay? _openedWith;

  @override
  void initState() {
    super.initState();
    _store = context.read<NutritionStore>();
    _milestones = context.read<MilestoneStore>();
    _calculator = FoodCalculatorStore(
      settings: context.read<SettingsRepository>(),
      nutrition: _store,
      clock: context.read<Clock>(),
    );
    unawaited(_calculator.load());
    // Body entries and the checklist may have changed elsewhere since the store was loaded.
    unawaited(_store.load().then((_) => _openedWith = _store.today));
  }

  @override
  void dispose() {
    // Habit milestones (protein, water, steps, sleep) are evaluated after the day was saved.
    final opened = _openedWith;
    if (opened != null && opened != _store.today) unawaited(_milestones.evaluateNow());
    _calculator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<FoodCalculatorStore>.value(
    value: _calculator,
    child: DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Food'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Today', height: 56),
              Tab(text: 'Calories', height: 56),
              Tab(text: 'Meals', height: 56),
              Tab(text: 'Guide', height: 56),
            ],
          ),
        ),
        body: const TabBarView(children: [FoodTodayTab(), FoodCalculatorTab(), MealIdeasTab(), FoodGuideTab()]),
      ),
    ),
  );
}
