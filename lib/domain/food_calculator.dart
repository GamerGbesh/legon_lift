// Calorie and protein calculator: the food list (`assets/data/foods.json`), search, and the
// day's running list of what was eaten.
//
// Some foods are build-ups: a base (a cup of tea, 2 eggs, a pack of Indomie) plus add-ons the
// user picks amounts of (sugar, honey, milk, onion, sausage...). Each add-on points at another
// food's serving, so its values come from one place.
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

/// Something that can be added to a build-up food, in [step]s of one [serving] of [foodId]
/// ("1 tsp" of sugar, shown as "2 tsp sugar").
class FoodAddon {
  const FoodAddon({
    required this.foodId,
    required this.name,
    required this.serving,
    required this.one,
    required this.many,
    this.step = 1,
  });

  final String foodId;

  /// Short name shown in the build-up ("Egg" rather than "Egg, boiled").
  final String name;

  /// Values for a quantity of 1.
  final FoodServing serving;

  /// Unit text for one and for more than one ("tsp sugar" / "tsp sugar", "egg" / "eggs").
  final String one, many;
  final double step;

  CalcExtra toExtra(double qty) =>
      CalcExtra(foodId: foodId, one: one, many: many, kcal: serving.kcal, proteinG: serving.proteinG, qty: qty);
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.servings,
    this.aka = const [],
    this.note,
    this.addons = const [],
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

  /// What can be added on top of the base serving (empty for a plain pick).
  final List<FoodAddon> addons;

  bool get isBuildUp => addons.isNotEmpty;

  Food _withAddons(List<FoodAddon> addons) =>
      Food(id: id, name: name, category: category, servings: servings, aka: aka, note: note, addons: addons);
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
    // Second pass: add-ons point at other foods' servings.
    final byId = {for (final f in foods) f.id: f};
    final rawById = {for (final raw in j['foods'] as List) (raw as Map)['id'] as String: raw};
    final built = [
      for (final f in foods)
        f._withAddons([
          for (final a in (rawById[f.id]!['addons'] as List? ?? const []))
            _addon(f.id, (a as Map).cast<String, dynamic>(), byId),
        ]),
    ];
    return FoodDatabase(categories: categories, foods: built, note: j['note'] as String?);
  }

  static FoodAddon _addon(String owner, Map<String, dynamic> a, Map<String, Food> byId) {
    final target = byId[a['food']];
    if (target == null) throw FormatException('food "$owner" has an add-on of unknown food "${a['food']}"');
    final index = (a['s'] as num?)?.toInt() ?? 0;
    if (index < 0 || index >= target.servings.length) {
      throw FormatException('food "$owner" add-on "${target.id}" has no serving $index');
    }
    final one = a['one'] as String;
    final step = (a['step'] as num?)?.toDouble() ?? 1;
    if (step <= 0) throw FormatException('food "$owner" add-on "${target.id}" has step $step');
    return FoodAddon(
      foodId: target.id,
      name: a['name'] as String? ?? target.name,
      serving: target.servings[index],
      one: one,
      many: a['many'] as String? ?? one,
      step: step,
    );
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

/// An add-on in a list entry ("2 tsp honey"), with its values copied in.
class CalcExtra {
  const CalcExtra({
    required this.foodId,
    required this.one,
    required this.many,
    required this.kcal,
    required this.proteinG,
    required this.qty,
  });

  factory CalcExtra.fromJson(Map<String, dynamic> j) => CalcExtra(
    foodId: j['food'] as String,
    one: j['one'] as String,
    many: j['many'] as String? ?? j['one'] as String,
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['p'] as num).toDouble(),
    qty: (j['qty'] as num).toDouble(),
  );

  final String foodId, one, many;

  /// Per 1 of [qty].
  final double kcal, proteinG;
  final double qty;

  double get totalKcal => kcal * qty;
  double get totalProteinG => proteinG * qty;

  /// "2 tsp honey", "½ onion", "3 eggs".
  String get label => '${quantityText(qty)} ${qty > 1 ? many : one}';

  Map<String, dynamic> toJson() => {
    'food': foodId,
    'one': one,
    if (many != one) 'many': many,
    'kcal': kcal,
    'p': proteinG,
    'qty': qty,
  };
}

/// 0.5 -> "½", 1.5 -> "1½", 2 -> "2", 0.25 -> "0.25".
String quantityText(double q) {
  final whole = q.floor();
  final rest = q - whole;
  if ((rest - 0.5).abs() < 1e-9) return whole == 0 ? '½' : '$whole½';
  if (rest.abs() < 1e-9) return '$whole';
  return q.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// One line of the day's list: [qty] x (a serving plus its [extras]). Values are copied in, so
/// the list stays right even if the food list changes. [foodId] is null for a food typed in by
/// hand.
class CalcEntry {
  const CalcEntry({
    this.foodId,
    required this.name,
    required this.serving,
    required this.kcal,
    required this.proteinG,
    this.qty = 1,
    this.extras = const [],
  });

  factory CalcEntry.of(Food food, FoodServing serving, {double qty = 1, List<CalcExtra> extras = const []}) =>
      CalcEntry(
        foodId: food.id,
        name: food.name,
        serving: serving.label,
        kcal: serving.kcal,
        proteinG: serving.proteinG,
        qty: qty,
        extras: extras,
      );

  factory CalcEntry.fromJson(Map<String, dynamic> j) => CalcEntry(
    foodId: j['food'] as String?,
    name: j['name'] as String,
    serving: j['serving'] as String? ?? '',
    kcal: (j['kcal'] as num).toDouble(),
    proteinG: (j['p'] as num).toDouble(),
    qty: (j['qty'] as num?)?.toDouble() ?? 1,
    extras: [
      for (final x in (j['extras'] as List? ?? const [])) CalcExtra.fromJson((x as Map).cast<String, dynamic>()),
    ],
  );

  final String? foodId;
  final String name, serving;

  /// The base serving, without [extras].
  final double kcal, proteinG;
  final double qty;

  /// Add-ons in each serving (a cup of tea's sugar and milk), multiplied by [qty] with it.
  final List<CalcExtra> extras;

  double get kcalEach => kcal + extras.fold(0.0, (s, x) => s + x.totalKcal);
  double get proteinGEach => proteinG + extras.fold(0.0, (s, x) => s + x.totalProteinG);
  double get totalKcal => kcalEach * qty;
  double get totalProteinG => proteinGEach * qty;

  /// "1 cup (tea bag) + 2 tsp honey, 2 tbsp milk powder".
  String get description => extras.isEmpty ? serving : '$serving + ${[for (final x in extras) x.label].join(', ')}';

  CalcEntry copyWith({double? qty}) => CalcEntry(
    foodId: foodId,
    name: name,
    serving: serving,
    kcal: kcal,
    proteinG: proteinG,
    qty: qty ?? this.qty,
    extras: extras,
  );

  Map<String, dynamic> toJson() => {
    if (foodId != null) 'food': foodId,
    'name': name,
    'serving': serving,
    'kcal': kcal,
    'p': proteinG,
    'qty': qty,
    if (extras.isNotEmpty) 'extras': [for (final x in extras) x.toJson()],
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
