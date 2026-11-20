// Owner: WS2. Plate calculator for the Smith machine and barbells (SPEC 4.4, 6.1).
import '../core/format.dart';
import '../data/models/models.dart';
import 'api.dart';

/// Plates per side to load [totalKg] on a bar of [barKg] with the plate sizes [platesKg]
/// (each size up to 4 times per side, SPEC 6.1).
///
/// When the target can be made exactly, [PlateResult.perSide] is the combination with the fewest
/// plates (heaviest first). Otherwise the result loads the nearest lower total (safer for a
/// beginner), or the lightest possible total when the target is below it, and reports both
/// neighbours in [PlateResult.lowerKg] / [PlateResult.higherKg].
PlateResult calculatePlates(double totalKg, double barKg, List<double> platesKg) {
  final perSideOptions = achievablePerSide(platesKg);
  final targetPerSide = (totalKg - barKg) / 2;

  double? lower, higher;
  for (final s in perSideOptions) {
    if ((s - targetPerSide).abs() <= loadEpsilon) {
      return PlateResult(totalKg: _total(barKg, s), perSide: _combination(s, platesKg), exact: true);
    }
    if (s < targetPerSide) lower = s;
    if (s > targetPerSide && higher == null) higher = s;
  }
  final chosen = lower ?? higher ?? 0;
  return PlateResult(
    totalKg: _total(barKg, chosen),
    perSide: _combination(chosen, platesKg),
    exact: false,
    lowerKg: lower == null ? null : _total(barKg, lower),
    higherKg: higher == null ? null : _total(barKg, higher),
  );
}

/// Plate text for one side: "20 + 5 + 1.25" ("Nothing" for an empty bar).
String plateListText(List<double> perSide) =>
    perSide.isEmpty ? 'Nothing' : perSide.map(Fmt.number).join(' + ');

double _total(double barKg, double perSide) => ((barKg + 2 * perSide) * 1000).round() / 1000;

/// Fewest plates making exactly [perSideKg] (each size at most 4 times), heaviest first. On a
/// tie in plate count, the combination using heavier plates wins.
List<double> _combination(double perSideKg, List<double> platesKg) {
  final sizes = platesKg.where((p) => p > 0).toSet().toList()..sort((a, b) => b.compareTo(a));
  final units = [for (final p in sizes) (p * 100).round()];
  final target = (perSideKg * 100).round();
  final memo = <(int, int), List<int>?>{};

  // Best count vector for `remaining` using sizes from index i on; null when impossible.
  List<int>? solve(int i, int remaining) {
    if (remaining == 0) return List.filled(sizes.length - i, 0);
    if (i >= sizes.length) return null;
    final key = (i, remaining);
    if (memo.containsKey(key)) return memo[key];
    List<int>? best;
    var bestCount = 1 << 30;
    for (var n = maxPlatesPerSizePerSide; n >= 0; n--) {
      final left = remaining - n * units[i];
      if (left < 0) continue;
      final rest = solve(i + 1, left);
      if (rest == null) continue;
      final count = n + rest.fold<int>(0, (a, b) => a + b);
      // Counts are tried from most to fewest of the heavier plate, so a strict "<" keeps the
      // heavier combination on ties.
      if (count < bestCount) {
        bestCount = count;
        best = [n, ...rest];
      }
    }
    memo[key] = best;
    return best;
  }

  final counts = solve(0, target);
  if (counts == null) return const [];
  return [
    for (var i = 0; i < sizes.length; i++)
      for (var k = 0; k < counts[i]; k++) sizes[i],
  ];
}

/// Plate math for a Smith or barbell exercise: the bar weight from the equipment profile.
PlateResult platesFor(double totalKg, Exercise ex, EquipmentProfile eq) =>
    calculatePlates(totalKg, ex.loadType == LoadType.smith ? eq.smithBarKg : eq.barKg, eq.platesKg);
