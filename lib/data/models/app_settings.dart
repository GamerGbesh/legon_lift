import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'equipment_profile.dart';
import 'json_read.dart';
import 'personalization.dart';

/// All user settings (kv key `settings`, SPEC 4.12 / 9.1). Times are `HH:mm` local strings.
///
/// Nullable fields in [copyWith] take a closure so they can be cleared: `copyWith(reminderTime: () => null)`.
@immutable
class AppSettings {
  const AppSettings({
    this.keepAwake = true,
    this.sound = true,
    this.vibration = true,
    this.restNotification = true,
    this.autoRest = true,
    this.warmupSets = true,
    this.warmupBlock = true,
    this.cooldownBlock = true,
    this.hydrationNudges = true,
    this.hotDayAuto = true,
    this.largeText = false,
    this.rirPrompt = RirPrompt.every,
    this.restCompoundSec = 120,
    this.restIsolationSec = 75,
    this.themeMode = ThemeModePref.dark,
    this.palette = PaletteId.legonNight,
    this.reminderTime,
    this.weighInTime,
    this.gymBagReminder = true,
    required this.equipment,
  });

  /// First-run settings: every switch at its default, equipment from the gym defaults.
  factory AppSettings.defaults(GymProfileDefaults gym) => AppSettings(equipment: EquipmentProfile.fromDefaults(gym));

  final bool keepAwake, sound, vibration, restNotification, autoRest, warmupSets, warmupBlock, cooldownBlock,
      hydrationNudges, hotDayAuto, largeText;
  final RirPrompt rirPrompt;
  final int restCompoundSec, restIsolationSec;
  final ThemeModePref themeMode;
  final PaletteId palette;

  /// `HH:mm`; null = reminder off.
  final String? reminderTime, weighInTime;
  final bool gymBagReminder;
  final EquipmentProfile equipment;

  factory AppSettings.fromJson(Json j) => AppSettings(
        keepAwake: readBool(j, 'keepAwake', fallback: true),
        sound: readBool(j, 'sound', fallback: true),
        vibration: readBool(j, 'vibration', fallback: true),
        restNotification: readBool(j, 'restNotification', fallback: true),
        autoRest: readBool(j, 'autoRest', fallback: true),
        warmupSets: readBool(j, 'warmupSets', fallback: true),
        warmupBlock: readBool(j, 'warmupBlock', fallback: true),
        cooldownBlock: readBool(j, 'cooldownBlock', fallback: true),
        hydrationNudges: readBool(j, 'hydrationNudges', fallback: true),
        hotDayAuto: readBool(j, 'hotDayAuto', fallback: true),
        largeText: readBool(j, 'largeText', fallback: false),
        rirPrompt: RirPrompt.fromWire(readStringOrNull(j, 'rirPrompt') ?? 'every'),
        restCompoundSec: readIntOrNull(j, 'restCompoundSec') ?? 120,
        restIsolationSec: readIntOrNull(j, 'restIsolationSec') ?? 75,
        themeMode: ThemeModePref.fromWire(readStringOrNull(j, 'themeMode') ?? 'dark'),
        palette: PaletteId.fromWire(readStringOrNull(j, 'palette') ?? 'legon_night'),
        reminderTime: readStringOrNull(j, 'reminderTime'),
        weighInTime: readStringOrNull(j, 'weighInTime'),
        gymBagReminder: readBool(j, 'gymBagReminder', fallback: true),
        equipment: EquipmentProfile.fromJson(readMap(j, 'equipment')),
      );

  Json toJson() => {
        'keepAwake': keepAwake,
        'sound': sound,
        'vibration': vibration,
        'restNotification': restNotification,
        'autoRest': autoRest,
        'warmupSets': warmupSets,
        'warmupBlock': warmupBlock,
        'cooldownBlock': cooldownBlock,
        'hydrationNudges': hydrationNudges,
        'hotDayAuto': hotDayAuto,
        'largeText': largeText,
        'rirPrompt': rirPrompt.wire,
        'restCompoundSec': restCompoundSec,
        'restIsolationSec': restIsolationSec,
        'themeMode': themeMode.wire,
        'palette': palette.wire,
        'reminderTime': reminderTime,
        'weighInTime': weighInTime,
        'gymBagReminder': gymBagReminder,
        'equipment': equipment.toJson(),
      };

  AppSettings copyWith({
    bool? keepAwake,
    bool? sound,
    bool? vibration,
    bool? restNotification,
    bool? autoRest,
    bool? warmupSets,
    bool? warmupBlock,
    bool? cooldownBlock,
    bool? hydrationNudges,
    bool? hotDayAuto,
    bool? largeText,
    RirPrompt? rirPrompt,
    int? restCompoundSec,
    int? restIsolationSec,
    ThemeModePref? themeMode,
    PaletteId? palette,
    String? Function()? reminderTime,
    String? Function()? weighInTime,
    bool? gymBagReminder,
    EquipmentProfile? equipment,
  }) =>
      AppSettings(
        keepAwake: keepAwake ?? this.keepAwake,
        sound: sound ?? this.sound,
        vibration: vibration ?? this.vibration,
        restNotification: restNotification ?? this.restNotification,
        autoRest: autoRest ?? this.autoRest,
        warmupSets: warmupSets ?? this.warmupSets,
        warmupBlock: warmupBlock ?? this.warmupBlock,
        cooldownBlock: cooldownBlock ?? this.cooldownBlock,
        hydrationNudges: hydrationNudges ?? this.hydrationNudges,
        hotDayAuto: hotDayAuto ?? this.hotDayAuto,
        largeText: largeText ?? this.largeText,
        rirPrompt: rirPrompt ?? this.rirPrompt,
        restCompoundSec: restCompoundSec ?? this.restCompoundSec,
        restIsolationSec: restIsolationSec ?? this.restIsolationSec,
        themeMode: themeMode ?? this.themeMode,
        palette: palette ?? this.palette,
        reminderTime: reminderTime != null ? reminderTime() : this.reminderTime,
        weighInTime: weighInTime != null ? weighInTime() : this.weighInTime,
        gymBagReminder: gymBagReminder ?? this.gymBagReminder,
        equipment: equipment ?? this.equipment,
      );

  List<Object?> get _props => [
        keepAwake, sound, vibration, restNotification, autoRest, warmupSets, warmupBlock, cooldownBlock, //
        hydrationNudges, hotDayAuto, largeText, rirPrompt, restCompoundSec, restIsolationSec, themeMode, palette,
        reminderTime, weighInTime, gymBagReminder, equipment,
      ];
  @override
  bool operator ==(Object other) => other is AppSettings && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
