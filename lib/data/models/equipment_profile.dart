import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'json_read.dart';
import 'personalization.dart';

/// What the user's gym has (Settings > Equipment, onboarding step 7). Stored inside AppSettings.
@immutable
class EquipmentProfile {
  const EquipmentProfile({
    required this.available,
    required this.platesKg,
    required this.barKg,
    required this.smithBarKg,
    this.smithBarKnown = false,
    this.legPressSledKg = 0,
    this.legPressSledKnown = false,
    this.legCurlType = LegCurlType.seated,
    required this.dumbbellsKg,
    this.hasBenchUprights = false,
  });

  /// Defaults from personalization.gym: default equipment ticked, optional (ankle strap) unticked.
  factory EquipmentProfile.fromDefaults(GymProfileDefaults d) => EquipmentProfile(
        available: d.equipment.toSet(),
        platesKg: List.of(d.platesKg),
        barKg: d.barKg,
        smithBarKg: d.smithBarKg,
        smithBarKnown: d.smithBarKnown,
        legPressSledKg: d.legPressSledKg,
        legPressSledKnown: d.legPressSledKnown,
        legCurlType: d.legCurlType,
        dumbbellsKg: d.defaultDumbbellsKg,
      );

  final Set<Equipment> available;
  final List<double> platesKg;
  final double barKg, smithBarKg;
  final bool smithBarKnown;
  final double legPressSledKg;
  final bool legPressSledKnown;
  final LegCurlType legCurlType;

  /// Single-dumbbell weights available, ascending.
  final List<double> dumbbellsKg;

  /// "Bench with uprights + spotter available" (unlocks barbell_bench_press as a substitute).
  final bool hasBenchUprights;

  bool has(Equipment e) => available.contains(e);

  factory EquipmentProfile.fromJson(Json j) => EquipmentProfile(
        available: readEnumList(j, 'available', Equipment.fromWire).toSet(),
        platesKg: readDoubleList(j, 'platesKg'),
        barKg: readDouble(j, 'barKg'),
        smithBarKg: readDouble(j, 'smithBarKg'),
        smithBarKnown: readBool(j, 'smithBarKnown', fallback: false),
        legPressSledKg: readDoubleOrNull(j, 'legPressSledKg') ?? 0,
        legPressSledKnown: readBool(j, 'legPressSledKnown', fallback: false),
        legCurlType: LegCurlType.fromWire(readStringOrNull(j, 'legCurlType') ?? 'seated'),
        dumbbellsKg: readDoubleList(j, 'dumbbellsKg'),
        hasBenchUprights: readBool(j, 'hasBenchUprights', fallback: false),
      );

  Json toJson() => {
        'available': [for (final e in Equipment.values) if (available.contains(e)) e.wire],
        'platesKg': platesKg,
        'barKg': barKg,
        'smithBarKg': smithBarKg,
        'smithBarKnown': smithBarKnown,
        'legPressSledKg': legPressSledKg,
        'legPressSledKnown': legPressSledKnown,
        'legCurlType': legCurlType.wire,
        'dumbbellsKg': dumbbellsKg,
        'hasBenchUprights': hasBenchUprights,
      };

  EquipmentProfile copyWith({
    Set<Equipment>? available,
    List<double>? platesKg,
    double? barKg,
    double? smithBarKg,
    bool? smithBarKnown,
    double? legPressSledKg,
    bool? legPressSledKnown,
    LegCurlType? legCurlType,
    List<double>? dumbbellsKg,
    bool? hasBenchUprights,
  }) =>
      EquipmentProfile(
        available: available ?? this.available,
        platesKg: platesKg ?? this.platesKg,
        barKg: barKg ?? this.barKg,
        smithBarKg: smithBarKg ?? this.smithBarKg,
        smithBarKnown: smithBarKnown ?? this.smithBarKnown,
        legPressSledKg: legPressSledKg ?? this.legPressSledKg,
        legPressSledKnown: legPressSledKnown ?? this.legPressSledKnown,
        legCurlType: legCurlType ?? this.legCurlType,
        dumbbellsKg: dumbbellsKg ?? this.dumbbellsKg,
        hasBenchUprights: hasBenchUprights ?? this.hasBenchUprights,
      );

  List<Object?> get _props => [
        available, platesKg, barKg, smithBarKg, smithBarKnown, legPressSledKg, legPressSledKnown, //
        legCurlType, dumbbellsKg, hasBenchUprights,
      ];
  @override
  bool operator ==(Object other) => other is EquipmentProfile && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
