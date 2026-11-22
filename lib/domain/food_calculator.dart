// Calorie and protein calculator: the food list (`assets/data/foods.json`), search, and the
// day's running list of what was eaten.
//
// Pure Dart. The list is kept for one day; the protein it adds up to is logged to the Food >
// Today checklist as protein points (1 point = 20 g, in half points), and only the difference
// since the last log is sent, so logging twice never double-counts.
import 'dart:math' as math;

/// One way of measuring a food ("1 tin, oil drained").
class FoodServing {
  const FoodServing({required this.label, required this.kcal, required this.proteinG});

  factory FoodServing.fromJson(Map<String, dynamic> j) => FoodServing(
    label: j['label'] as String,
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['p'] as num).toDouble(),
  );

  final String label;
  final double kcal, proteinG;
}

class FoodCategory {
  const FoodCategory(this.id, this.label);

  final String id, label;
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.servings,
    this.aka = const [],
    this.note,
  });

  factory Food.fromJson(Map<String, dynamic> j) => Food(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['cat'] as String,
    servings: [for (final s in j['servings'] as List) FoodServing.fromJson((s as Map).cast<String, dynamic>())],
    aka: [for (final a in (j['aka'] as List? ?? const [])) a as String],
    note: j['note'] as String?,
  );

  final String id, name, category;
  final List<FoodServing> servings;

  /// Other names people search for ("talia", "puff puff", "pear").
  final List<String> aka;
  final String? note;
}

/// The bundled food list.
class FoodDatabase {
  FoodDatabase({required this.categories, required this.foods, this.note}) : _byId = {for (final f in foods) f.id: f};

  /// Parses `foods.json`. Throws [FormatException] on a broken file.
  factory FoodDatabase.fromJson(Map<String, dynamic> j) {
    final categories = [
      for (final c in j['categories'] as List) FoodCategory((c as Map)['id'] as String, c['label'] as String),
    ];
    final ids = {for (final c in categories) c.id};
    final foods = <Food>[];
    final seen = <String>{};
    for (final raw in j['foods'] as List) {
      final f = Food.fromJson((raw as Map).cast<String, dynamic>());
      if (!seen.add(f.id)) throw FormatException('duplicate food id "${f.id}"');
      if (!ids.contains(f.category)) throw FormatException('food "${f.id}" has unknown category "${f.category}"');
      if (f.servings.isEmpty) throw FormatException('food "${f.id}" has no servings');
      foods.add(f);
    }
    return FoodDatabase(categories: categories, foods: foods, note: j['note'] as String?);
  }

  final List<FoodCategory> categories;
  final List<Food> foods;
  final String? note;
  final Map<String, Food> _byId;

  Food? byId(String id) => _byId[id];

  /// Foods matching every word of [query] (in the name or another name), optionally in
  /// [category]. Names starting with the query come first, then alphabetical.
  List<Food> search(String query, {String? category}) {
    final words = _normalise(query).split(' ').where((w) => w.isNotEmpty).toList();
    final q = words.join(' ');
    final out = <Food>[];
    for (final f in foods) {
      if (category != null && f.category != category) continue;
      if (words.isEmpty) {
        out.add(f);
        continue;
      }
      final hay = _normalise([f.name, ...f.aka].join(' '));
      if (words.every(hay.contains)) out.add(f);
    }
    if (words.isEmpty) return out;
    int rank(Food f) {
      final name = _normalise(f.name);
      if (name.startsWith(q)) return 0;
      if (f.aka.any((a) => _normalise(a).startsWith(q))) return 1;
      return 2;
    }

    out.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return out;
  }

  static String _normalise(String s) =>
      s.toLowerCase().replaceAll('ɛ', 'e').replaceAll('ɔ', 'o').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// One line of the day's list: [qty] x a serving. The serving's values are copied in, so the
/// list stays right even if the food list changes. [foodId] is null for a food typed in by hand.
class CalcEntry {
  const CalcEntry({
    this.foodId,
    required this.name,
    required this.serving,
    required this.kcal,
    required this.proteinG,
    this.qty = 1,
  });

  factory CalcEntry.of(Food food, FoodServing serving, {double qty = 1}) => CalcEntry(
    foodId: food.id,
    name: food.name,
    serving: serving.label,
    kcal: serving.kcal,
    proteinG: serving.proteinG,
    qty: qty,
  );

  factory CalcEntry.fromJson(Map<String, dynamic> j) => CalcEntry(
    foodId: j['food'] as String?,
    name: j['name'] as String,
    serving: j['serving'] as String? ?? '',
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['p'] as num).toDouble(),
    qty: (j['qty'] as num?)?.toDouble() ?? 1,
  );

  final String? foodId;
  final String name, serving;

  /// Per serving.
  final double kcal, proteinG;
  final double qty;

  double get totalKcal => kcal * qty;
  double get totalProteinG => proteinG * qty;

  CalcEntry copyWith({double? qty}) =>
      CalcEntry(foodId: foodId, name: name, serving: serving, kcal: kcal, proteinG: proteinG, qty: qty ?? this.qty);

  Map<String, dynamic> toJson() => {
    if (foodId != null) 'food': foodId,
    'name': name,
    'serving': serving,
    'kcal': kcal,
    'p': proteinG,
    'qty': qty,
  };
}

/// Protein grams as protein points (20 g each), to the nearest half point.
double proteinPointsFor(double proteinG) => (proteinG / 20 * 2).round() / 2;

/// The calculator's list for [date] and how many protein points were already logged from it.
class FoodCalcDay {
  const FoodCalcDay({required this.date, this.entries = const [], this.loggedPoints = 0});

  factory FoodCalcDay.fromJson(Map<String, dynamic> j) => FoodCalcDay(
    date: j['date'] as String,
    entries: [
      for (final e in (j['entries'] as List? ?? const [])) CalcEntry.fromJson((e as Map).cast<String, dynamic>()),
    ],
    loggedPoints: (j['logged'] as num?)?.toDouble() ?? 0,
  );

  final String date;
  final List<CalcEntry> entries;

  /// Points already added to the Today checklist from this list.
  final double loggedPoints;

  double get kcal => entries.fold(0, (s, e) => s + e.totalKcal);
  double get proteinG => entries.fold(0, (s, e) => s + e.totalProteinG);
  double get points => proteinPointsFor(proteinG);

  /// Points still to send to the checklist (negative when food was removed after logging).
  double get pointsToLog => points - loggedPoints;

  FoodCalcDay copyWith({List<CalcEntry>? entries, double? loggedPoints}) =>
      FoodCalcDay(date: date, entries: entries ?? this.entries, loggedPoints: loggedPoints ?? this.loggedPoints);

  Map<String, dynamic> toJson() => {
    'date': date,
    'entries': [for (final e in entries) e.toJson()],
    'logged': loggedPoints,
  };
}

/// Recently used food ids, newest first, at most [max].
List<String> pushRecent(List<String> recent, String id, {int max = 8}) =>
    [id, ...recent.where((r) => r != id)].sublist(0, math.min(max, recent.where((r) => r != id).length + 1));
