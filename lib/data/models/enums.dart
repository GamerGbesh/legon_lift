// Enums used across the app (SPEC 5.1). Each enum has a `wire` string (the JSON/DB value) and a
// static `fromWire` that throws a FormatException on unknown values.

T _fromWire<T extends Enum>(List<T> values, String wire, String Function(T) wireOf, String type) {
  for (final v in values) {
    if (wireOf(v) == wire) return v;
  }
  throw FormatException('Unknown $type value "$wire"');
}

enum ExerciseCategory {
  push, pull, legs, core, cardio, warmup, mobility;

  String get wire => name;
  static ExerciseCategory fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'ExerciseCategory');
}

enum Muscle {
  chest('chest'),
  frontDelts('front_delts'),
  sideDelts('side_delts'),
  rearDelts('rear_delts'),
  triceps('triceps'),
  biceps('biceps'),
  forearms('forearms'),
  lats('lats'),
  upperBack('upper_back'),
  traps('traps'),
  lowerBack('lower_back'),
  abs('abs'),
  obliques('obliques'),
  quads('quads'),
  hamstrings('hamstrings'),
  glutes('glutes'),
  adductors('adductors'),
  abductors('abductors'),
  calves('calves'),
  cardio('cardio');

  const Muscle(this.wire);
  final String wire;
  static Muscle fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Muscle');

  /// Plain-language label for chips ("Front delts").
  String get label => switch (this) {
        Muscle.frontDelts => 'Front shoulders',
        Muscle.sideDelts => 'Side shoulders',
        Muscle.rearDelts => 'Rear shoulders',
        Muscle.upperBack => 'Upper back',
        Muscle.lowerBack => 'Lower back',
        Muscle.lats => 'Lats',
        Muscle.abs => 'Abs',
        _ => '${wire[0].toUpperCase()}${wire.substring(1).replaceAll('_', ' ')}',
      };
}

enum Equipment {
  cable('cable'),
  latPulldownMachine('lat_pulldown_machine'),
  shoulderPressMachine('shoulder_press_machine'),
  chestPressMachine('chest_press_machine'),
  bike('bike'),
  treadmill('treadmill'),
  barbell('barbell'),
  dumbbell('dumbbell'),
  legPress('leg_press'),
  plates('plates'),
  calfRaiseMachine('calf_raise_machine'),
  legCurlMachine('leg_curl_machine'),
  legExtensionMachine('leg_extension_machine'),
  smithMachine('smith_machine'),
  bench('bench'),
  bodyweight('bodyweight'),
  ankleStrap('ankle_strap');

  const Equipment(this.wire);
  final String wire;
  static Equipment fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Equipment');
}

enum Mechanic {
  compound, isolation;

  String get wire => name;
  static Mechanic fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Mechanic');
}

enum LoadType {
  dumbbell('dumbbell'),
  cable('cable'),
  time('time'),
  bodyweight('bodyweight'),
  stack('stack'),
  smith('smith'),
  barbell('barbell'),
  plateLoaded('plate_loaded');

  const LoadType(this.wire);
  final String wire;
  static LoadType fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'LoadType');
}

enum MovementPattern {
  horizontalPush('horizontal_push'),
  inclinePush('incline_push'),
  verticalPush('vertical_push'),
  chestFly('chest_fly'),
  horizontalPull('horizontal_pull'),
  verticalPull('vertical_pull'),
  straightArmPull('straight_arm_pull'),
  rearDelt('rear_delt'),
  lateralRaise('lateral_raise'),
  frontRaise('front_raise'),
  elbowFlexion('elbow_flexion'),
  elbowExtension('elbow_extension'),
  shrug('shrug'),
  backExtension('back_extension'),
  squat('squat'),
  lunge('lunge'),
  hinge('hinge'),
  hipThrust('hip_thrust'),
  kneeExtension('knee_extension'),
  kneeFlexion('knee_flexion'),
  calfRaise('calf_raise'),
  gluteIsolation('glute_isolation'),
  core('core'),
  cardio('cardio'),
  mobility('mobility'),
  stretch('stretch');

  const MovementPattern(this.wire);
  final String wire;
  static MovementPattern fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'MovementPattern');
}

enum Tracking {
  weightReps('weight_reps'),
  reps('reps'),
  time('time');

  const Tracking(this.wire);
  final String wire;
  static Tracking fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Tracking');
}

enum BlockType {
  warmup, main, superset, finisher, cooldown;

  String get wire => name;
  static BlockType fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'BlockType');
}

enum ItemRole {
  primary, secondary, accessory, core, warmup, cardio, cooldown, stretch;

  String get wire => name;
  static ItemRole fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'ItemRole');
}

enum PhaseId {
  foundation, build, progress, deload, retest, custom;

  String get wire => name;
  static PhaseId fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'PhaseId');
}

/// `ramp` = find-weight sets (SPEC 6.2).
enum SetKind {
  warmup, ramp, working, test, calibration;

  String get wire => name;
  static SetKind fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'SetKind');
}

enum SessionStatus {
  inProgress('in_progress'),
  completed('completed'),
  discarded('discarded');

  const SessionStatus(this.wire);
  final String wire;
  static SessionStatus fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'SessionStatus');
}

enum SessionExerciseStatus {
  pending, active, done, skipped;

  String get wire => name;
  static SessionExerciseStatus fromWire(String w) =>
      _fromWire(values, w, (v) => v.wire, 'SessionExerciseStatus');
}

enum SkipReason {
  busy('busy'),
  pain('pain'),
  noTime('no_time'),
  other('other');

  const SkipReason(this.wire);
  final String wire;
  static SkipReason fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'SkipReason');
}

enum Trend {
  up, same, down, calibrate, deload;

  String get wire => name;
  static Trend fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Trend');
}

enum Sex {
  male, female;

  String get wire => name;
  static Sex fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Sex');
}

enum Goal {
  recomp('recomp'),
  fatLoss('fat_loss'),
  muscleGain('muscle_gain'),
  maintain('maintain');

  const Goal(this.wire);
  final String wire;
  static Goal fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Goal');
}

enum Experience {
  never('never'),
  lt3Months('lt_3_months'),
  m3to12('3_to_12_months'),
  gt1Year('gt_1_year');

  const Experience(this.wire);
  final String wire;
  static Experience fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'Experience');
}

enum ActivityLevel {
  sedentary('sedentary'),
  lightlyActive('lightly_active'),
  moderatelyActive('moderately_active'),
  veryActive('very_active'),
  extraActive('extra_active');

  const ActivityLevel(this.wire);
  final String wire;
  static ActivityLevel fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'ActivityLevel');
}

enum SplitKey {
  pushPullLegs('push_pull_legs'),
  upperLower('upper_lower'),
  chestbackLegsArmsshoulders('chestback_legs_armsshoulders'),
  fullBody('full_body'),
  custom('custom');

  const SplitKey(this.wire);
  final String wire;
  static SplitKey fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'SplitKey');
}

enum LegCurlType {
  seated, lying;

  String get wire => name;
  static LegCurlType fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'LegCurlType');
}

enum RirPrompt {
  every, last, never;

  String get wire => name;
  static RirPrompt fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'RirPrompt');
}

enum ThemeModePref {
  dark, light, system;

  String get wire => name;
  static ThemeModePref fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'ThemeModePref');
}

enum PaletteId {
  legonNight('legon_night'),
  kenteEnergy('kente_energy'),
  voltTeal('volt_teal');

  const PaletteId(this.wire);
  final String wire;
  static PaletteId fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'PaletteId');
}

enum PrType {
  e1rm('e1rm'),
  maxWeight('max_weight'),
  bestVolume('best_volume');

  const PrType(this.wire);
  final String wire;
  static PrType fromWire(String w) => _fromWire(values, w, (v) => v.wire, 'PrType');
}
