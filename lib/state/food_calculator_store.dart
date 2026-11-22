// The Food > Calculator list for today, saved in the kv table so it survives closing the app,
// and starting fresh each day.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/clock.dart';
import '../core/format.dart';
import '../data/repositories/settings_repository.dart';
import '../domain/food_calculator.dart';
import 'nutrition_store.dart';

class FoodCalculatorStore extends ChangeNotifier {
  FoodCalculatorStore({required this._settings, required this._nutrition, required this._clock, this._bundle});

  final SettingsRepository _settings;
  final NutritionStore _nutrition;
  final Clock _clock;
  final AssetBundle? _bundle;

  static const String foodsAsset = 'assets/data/foods.json';
  static const String _dayFlag = 'food_calc.day';
  static const String _recentFlag = 'food_calc.recent';

  /// Parsed once per app run.
  static FoodDatabase? _cachedDb;

  /// Lets tests supply the food list without an asset bundle.
  @visibleForTesting
  static set debugDatabase(FoodDatabase? db) => _cachedDb = db;

  FoodDatabase? _db;
  FoodCalcDay? _day;
  List<String> _recent = const [];
  bool _disposed = false;

  FoodDatabase? get db => _db;
  bool get loaded => _db != null && _day != null;
  List<String> get recent => _recent;

  String get _today => Fmt.dateKey(_clock.now());

  /// Today's list (an empty one after midnight).
  FoodCalcDay get day {
    final d = _day;
    return d == null || d.date != _today ? FoodCalcDay(date: _today) : d;
  }

  Future<void> load() async {
    _db = _cachedDb ??= FoodDatabase.fromJson(
      (jsonDecode(await (_bundle ?? rootBundle).loadString(foodsAsset)) as Map).cast<String, dynamic>(),
    );
    final raw = await _settings.getFlag(_dayFlag);
    FoodCalcDay? saved;
    if (raw != null) {
      try {
        saved = FoodCalcDay.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
      } on Object {
        saved = null; // A broken saved list just starts over.
      }
    }
    _day = saved != null && saved.date == _today ? saved : FoodCalcDay(date: _today);
    final recentRaw = await _settings.getFlag(_recentFlag);
    _recent = recentRaw == null || recentRaw.isEmpty ? const [] : recentRaw.split(',');
    _notify();
  }

  Future<void> add(CalcEntry e) async {
    final id = e.foodId;
    if (id != null) {
      _recent = pushRecent(_recent, id);
      await _settings.setFlag(_recentFlag, _recent.join(','));
    }
    await _save(day.copyWith(entries: [...day.entries, e]));
  }

  Future<void> replace(int index, CalcEntry e) =>
      _save(day.copyWith(entries: [for (final (i, x) in day.entries.indexed) i == index ? e : x]));

  Future<void> removeAt(int index) => _save(
    day.copyWith(
      entries: [
        for (final (i, x) in day.entries.indexed)
          if (i != index) x,
      ],
    ),
  );

  /// Puts back an entry removed by [removeAt] (snackbar undo).
  Future<void> insertAt(int index, CalcEntry e) {
    final list = [...day.entries]..insert(index.clamp(0, day.entries.length), e);
    return _save(day.copyWith(entries: list));
  }

  /// Empties the list. Points already logged stay on the Today checklist.
  Future<void> clear() => _save(FoodCalcDay(date: _today));

  /// Sends the points not yet logged to the Today checklist; returns how many (may be negative).
  Future<double> logPoints() async {
    final d = day;
    final delta = d.pointsToLog;
    if (delta == 0) return 0;
    await _nutrition.addProtein(delta);
    await _save(d.copyWith(loggedPoints: d.points));
    return delta;
  }

  Future<void> _save(FoodCalcDay d) async {
    _day = d;
    _notify();
    await _settings.setFlag(_dayFlag, jsonEncode(d.toJson()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
