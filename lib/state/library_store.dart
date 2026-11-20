// Owner: WS5. Library search, filters and favourites (SPEC 4.6).
import 'package:flutter/foundation.dart';

import '../data/assets/asset_catalog.dart';
import '../data/models/models.dart';
import '../data/repositories/exercise_state_repository.dart';
import 'settings_store.dart';
import 'types.dart';

/// Library search, filters, favourites and per-exercise notes (SPEC 4.6).
///
/// Filters combine with AND, except that the selected muscle groups and the Mobility chip are
/// alternatives (an exercise matches any of them). Equipment availability follows SPEC 2.1: every
/// listed item is needed, but `bike` + `treadmill` on a cardio entry means either one.
class LibraryStore extends ChangeNotifier {
  LibraryStore({required this._catalog, required this._states, required this._settings}) {
    _settings.addListener(_onSettingsChanged);
  }

  final AssetCatalog _catalog;
  final ExerciseStateRepository _states;
  final SettingsStore _settings;
  LibraryQuery _query = LibraryQuery.initial;
  bool _mobility = false;
  Map<String, ExercisePrefs> _prefs = const {};
  List<Exercise>? _results;
  bool _disposed = false;

  LibraryQuery get query => _query;

  /// The "Mobility" chip: stretches and warm-up drills (categories `mobility` and non-cardio
  /// `warmup`). [LibraryQuery] has no category filter, so the store keeps this one itself.
  bool get mobility => _mobility;

  bool isFavorite(String id) => _prefs[id]?.favorite ?? false;

  /// Saved preferences of [id] (favourite, machine note ...); defaults when none were saved.
  ExercisePrefs prefsFor(String id) => _prefs[id] ?? ExercisePrefs.empty(id);

  /// Exercises matching [query], sorted by name (best name matches first while searching).
  List<Exercise> get results => _results ??= _compute();

  /// Whether [ex] can be done with the ticked equipment (SPEC 2.1, 2.2).
  bool isAvailable(Exercise ex) => exerciseAvailable(ex, _settings.settings.equipment);

  Future<void> load() async {
    final prefs = await _states.allPrefs();
    if (_disposed) return;
    _prefs = prefs;
    _changed();
  }

  void setQuery(LibraryQuery q) {
    if (q == _query) return;
    _query = q;
    _changed();
  }

  void setMobility(bool on) {
    if (on == _mobility) return;
    _mobility = on;
    _changed();
  }

  /// Clears search text and every filter chip ("Beginner friendly" goes back on).
  void clearFilters() {
    _query = LibraryQuery.initial;
    _mobility = false;
    _changed();
  }

  Future<void> toggleFavorite(String id) async {
    final next = prefsFor(id).copyWith(favorite: !isFavorite(id));
    await _states.putPrefs(next);
    _prefs = {..._prefs, id: next};
    _changed();
  }

  /// Saves the user's note about the gym's machine (seat height, pin ...). Blank clears it.
  Future<void> setMachineNote(String id, String? note) async {
    final trimmed = note?.trim();
    final next = prefsFor(id).copyWith(machineNote: () => (trimmed == null || trimmed.isEmpty) ? null : trimmed);
    await _states.putPrefs(next);
    _prefs = {..._prefs, id: next};
    _changed();
  }

  void _onSettingsChanged() => _changed();

  void _changed() {
    _results = null;
    if (!_disposed) notifyListeners();
  }

  List<Exercise> _compute() {
    final q = _query;
    final tokens = searchTokens(q.text);
    final eq = _settings.settings.equipment;
    final scored = <(Exercise, int)>[];
    for (final e in _catalog.exercises) {
      if (q.beginnerOnly && e.difficulty != 1) continue;
      if (q.favoritesOnly && !isFavorite(e.id)) continue;
      if (!q.showAllEquipment && !exerciseAvailable(e, eq)) continue;
      if (q.equipment.isNotEmpty && !e.equipment.any(q.equipment.contains)) continue;
      if (q.muscles.isNotEmpty || _mobility) {
        final muscleHit = e.primaryMuscles.any(q.muscles.contains);
        if (!muscleHit && !(_mobility && isMobilityExercise(e))) continue;
      }
      final score = tokens.isEmpty ? 0 : matchScore(e, tokens);
      if (score < 0) continue;
      scored.add((e, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    });
    return List.unmodifiable([for (final (e, _) in scored) e]);
  }

  @override
  void dispose() {
    _disposed = true;
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }
}

/// Stretches and warm-up drills (the Library's "Mobility" chip).
bool isMobilityExercise(Exercise e) =>
    e.category == ExerciseCategory.mobility ||
    (e.category == ExerciseCategory.warmup && !e.primaryMuscles.contains(Muscle.cardio));

/// Whether [e] can be done with [eq] (SPEC 2.1): all equipment ticked, `bike` + `treadmill` on a
/// cardio entry means either, bodyweight is always possible, and the barbell bench press also
/// needs uprights or a spotter (SPEC 2.1 data facts).
bool exerciseAvailable(Exercise e, EquipmentProfile eq) {
  bool has(Equipment x) => x == Equipment.bodyweight || eq.available.contains(x);
  final needs = e.equipment;
  final eitherCardio = needs.contains(Equipment.bike) && needs.contains(Equipment.treadmill);
  for (final x in needs) {
    if (eitherCardio && (x == Equipment.bike || x == Equipment.treadmill)) continue;
    if (!has(x)) return false;
  }
  if (eitherCardio && !has(Equipment.bike) && !has(Equipment.treadmill)) return false;
  if (e.id == 'barbell_bench_press' && !eq.hasBenchUprights) return false;
  return true;
}

/// Lower-case, accent-free words of [text] ("Front-Raise Élevé" -> [front, raise, eleve]).
List<String> searchTokens(String text) =>
    foldForSearch(text).split(' ').where((t) => t.isNotEmpty).toList(growable: false);

/// Lower-cases [text], strips accents and turns every non-alphanumeric run into one space.
String foldForSearch(String text) {
  final out = StringBuffer();
  var lastSpace = true;
  for (final rune in text.toLowerCase().runes) {
    final ch = _accentFold[rune] ?? String.fromCharCode(rune);
    final c = ch.codeUnitAt(0);
    final isWord = ch.length == 1 && ((c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39));
    if (isWord) {
      out.write(ch);
      lastSpace = false;
    } else if (!lastSpace) {
      out.write(' ');
      lastSpace = true;
    }
  }
  return out.toString().trim();
}

/// How well [e] matches the search [tokens]: -1 = no match; higher = better. Every token must
/// prefix a word of the name or of one alias (so "db press" finds "DB Bench Press").
int matchScore(Exercise e, List<String> tokens) {
  final name = foldForSearch(e.name);
  final nameWords = name.split(' ');
  final aliasWords = [for (final a in e.aliases) ...foldForSearch(a).split(' ')];
  var score = 0;
  for (final t in tokens) {
    if (nameWords.any((w) => w.startsWith(t))) {
      score += 2;
    } else if (aliasWords.any((w) => w.startsWith(t)) || name.contains(t)) {
      score += 1;
    } else {
      return -1;
    }
  }
  if (name.startsWith(tokens.join(' '))) score += 3;
  return score;
}

/// Accented Latin letters to their base letter (enough for exercise names and aliases).
final Map<int, String> _accentFold = {
  for (final (chars, base) in const [
    ('àáâãäåāăą', 'a'),
    ('çćĉċč', 'c'),
    ('ďđ', 'd'),
    ('èéêëēĕėęě', 'e'),
    ('ĝğġģ', 'g'),
    ('ĥħ', 'h'),
    ('ìíîïĩīĭįı', 'i'),
    ('ĵ', 'j'),
    ('ķ', 'k'),
    ('ĺļľŀł', 'l'),
    ('ñńņňŉ', 'n'),
    ('òóôõöøōŏő', 'o'),
    ('ŕŗř', 'r'),
    ('śŝşšß', 's'),
    ('ţťŧ', 't'),
    ('ùúûüũūŭůűų', 'u'),
    ('ŵ', 'w'),
    ('ýÿŷ', 'y'),
    ('źżž', 'z'),
    ('ɛ', 'e'),
    ('ɔ', 'o'),
  ])
    for (final r in chars.runes) r: base,
};
