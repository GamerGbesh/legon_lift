import 'package:flutter/foundation.dart';

import '../../core/equality.dart';
import 'enums.dart';
import 'json_read.dart';

/// The user's profile (kv key `profile`). Metric storage; [useLb]/[useFtIn] only change the display.
///
/// Nullable fields in [copyWith] take a closure so they can be cleared: `copyWith(name: () => null)`.
@immutable
class UserProfile {
  const UserProfile({
    this.name,
    required this.sex,
    required this.ageY,
    required this.heightCm,
    required this.weightKg,
    this.goalWeightKg,
    this.startWaistCm,
    required this.activityLevel,
    required this.goal,
    required this.experience,
    required this.daysPerWeek,
    required this.sessionMinutes,
    required this.workoutWeekdays,
    required this.trainingTime,
    required this.split,
    this.limitations = const [],
    required this.budget,
    this.dietNotes = const [],
    this.baselineSteps,
    this.parqAnyYes = false,
    this.parqCleared = false,
    this.ghanaAnswers = const {},
    required this.parqAnsweredAt,
    this.emergencyName,
    this.emergencyPhone,
    this.useLb = false,
    this.useFtIn = false,
    required this.createdAt,
  });

  /// The default user of SPEC (male, 22 y, 172 cm, 95 kg, beginner, recomp, Mon/Wed/Fri, 60 min, PPL).
  factory UserProfile.defaults(DateTime now) => UserProfile(
        sex: Sex.male,
        ageY: 22,
        heightCm: 172,
        weightKg: 95,
        activityLevel: ActivityLevel.lightlyActive,
        goal: Goal.recomp,
        experience: Experience.never,
        daysPerWeek: 3,
        sessionMinutes: 60,
        workoutWeekdays: const [1, 3, 5],
        trainingTime: 'evening',
        split: SplitKey.pushPullLegs,
        budget: 'tight',
        parqAnsweredAt: now,
        createdAt: now,
      );

  final String? name;
  final Sex sex;
  final int ageY;
  final double heightCm, weightKg;
  final double? goalWeightKg, startWaistCm;
  final ActivityLevel activityLevel;
  final Goal goal;
  final Experience experience;
  final int daysPerWeek, sessionMinutes;

  /// 1 = Monday ... 7 = Sunday.
  final List<int> workoutWeekdays;

  /// `morning`, `midday`, `evening` ... (personalization.onboarding `training_time`).
  final String trainingTime;
  final SplitKey split;

  /// `knee lower_back shoulder wrist_elbow hip ankle other`.
  final List<String> limitations;
  final String budget;
  final List<String> dietNotes;
  final int? baselineSteps;
  final bool parqAnyYes, parqCleared;

  /// Ghana question id -> answer.
  final Map<String, String> ghanaAnswers;
  final DateTime parqAnsweredAt;
  final String? emergencyName, emergencyPhone;
  final bool useLb, useFtIn;
  final DateTime createdAt;

  /// The program is blocked until a PAR-Q "yes" is acknowledged (SPEC 4.2 step 2).
  bool get programBlocked => parqAnyYes && !parqCleared;

  factory UserProfile.fromJson(Json j) => UserProfile(
        name: readStringOrNull(j, 'name'),
        sex: Sex.fromWire(readString(j, 'sex')),
        ageY: readInt(j, 'ageY'),
        heightCm: readDouble(j, 'heightCm'),
        weightKg: readDouble(j, 'weightKg'),
        goalWeightKg: readDoubleOrNull(j, 'goalWeightKg'),
        startWaistCm: readDoubleOrNull(j, 'startWaistCm'),
        activityLevel: ActivityLevel.fromWire(readString(j, 'activityLevel')),
        goal: Goal.fromWire(readString(j, 'goal')),
        experience: Experience.fromWire(readString(j, 'experience')),
        daysPerWeek: readInt(j, 'daysPerWeek'),
        sessionMinutes: readInt(j, 'sessionMinutes'),
        workoutWeekdays: readIntList(j, 'workoutWeekdays'),
        trainingTime: readString(j, 'trainingTime'),
        split: SplitKey.fromWire(readString(j, 'split')),
        limitations: readStringList(j, 'limitations', optional: true),
        budget: readString(j, 'budget'),
        dietNotes: readStringList(j, 'dietNotes', optional: true),
        baselineSteps: readIntOrNull(j, 'baselineSteps'),
        parqAnyYes: readBool(j, 'parqAnyYes', fallback: false),
        parqCleared: readBool(j, 'parqCleared', fallback: false),
        ghanaAnswers: (readMapOrNull(j, 'ghanaAnswers') ?? const {}).map((k, v) => MapEntry(k, '$v')),
        parqAnsweredAt: readInstant(j, 'parqAnsweredAt'),
        emergencyName: readStringOrNull(j, 'emergencyName'),
        emergencyPhone: readStringOrNull(j, 'emergencyPhone'),
        useLb: readBool(j, 'useLb', fallback: false),
        useFtIn: readBool(j, 'useFtIn', fallback: false),
        createdAt: readInstant(j, 'createdAt'),
      );

  Json toJson() => {
        'name': name,
        'sex': sex.wire,
        'ageY': ageY,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goalWeightKg': goalWeightKg,
        'startWaistCm': startWaistCm,
        'activityLevel': activityLevel.wire,
        'goal': goal.wire,
        'experience': experience.wire,
        'daysPerWeek': daysPerWeek,
        'sessionMinutes': sessionMinutes,
        'workoutWeekdays': workoutWeekdays,
        'trainingTime': trainingTime,
        'split': split.wire,
        'limitations': limitations,
        'budget': budget,
        'dietNotes': dietNotes,
        'baselineSteps': baselineSteps,
        'parqAnyYes': parqAnyYes,
        'parqCleared': parqCleared,
        'ghanaAnswers': ghanaAnswers,
        'parqAnsweredAt': instantToJson(parqAnsweredAt),
        'emergencyName': emergencyName,
        'emergencyPhone': emergencyPhone,
        'useLb': useLb,
        'useFtIn': useFtIn,
        'createdAt': instantToJson(createdAt),
      };

  UserProfile copyWith({
    String? Function()? name,
    Sex? sex,
    int? ageY,
    double? heightCm,
    double? weightKg,
    double? Function()? goalWeightKg,
    double? Function()? startWaistCm,
    ActivityLevel? activityLevel,
    Goal? goal,
    Experience? experience,
    int? daysPerWeek,
    int? sessionMinutes,
    List<int>? workoutWeekdays,
    String? trainingTime,
    SplitKey? split,
    List<String>? limitations,
    String? budget,
    List<String>? dietNotes,
    int? Function()? baselineSteps,
    bool? parqAnyYes,
    bool? parqCleared,
    Map<String, String>? ghanaAnswers,
    DateTime? parqAnsweredAt,
    String? Function()? emergencyName,
    String? Function()? emergencyPhone,
    bool? useLb,
    bool? useFtIn,
    DateTime? createdAt,
  }) =>
      UserProfile(
        name: name != null ? name() : this.name,
        sex: sex ?? this.sex,
        ageY: ageY ?? this.ageY,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        goalWeightKg: goalWeightKg != null ? goalWeightKg() : this.goalWeightKg,
        startWaistCm: startWaistCm != null ? startWaistCm() : this.startWaistCm,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        experience: experience ?? this.experience,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        sessionMinutes: sessionMinutes ?? this.sessionMinutes,
        workoutWeekdays: workoutWeekdays ?? this.workoutWeekdays,
        trainingTime: trainingTime ?? this.trainingTime,
        split: split ?? this.split,
        limitations: limitations ?? this.limitations,
        budget: budget ?? this.budget,
        dietNotes: dietNotes ?? this.dietNotes,
        baselineSteps: baselineSteps != null ? baselineSteps() : this.baselineSteps,
        parqAnyYes: parqAnyYes ?? this.parqAnyYes,
        parqCleared: parqCleared ?? this.parqCleared,
        ghanaAnswers: ghanaAnswers ?? this.ghanaAnswers,
        parqAnsweredAt: parqAnsweredAt ?? this.parqAnsweredAt,
        emergencyName: emergencyName != null ? emergencyName() : this.emergencyName,
        emergencyPhone: emergencyPhone != null ? emergencyPhone() : this.emergencyPhone,
        useLb: useLb ?? this.useLb,
        useFtIn: useFtIn ?? this.useFtIn,
        createdAt: createdAt ?? this.createdAt,
      );

  List<Object?> get _props => [
        name, sex, ageY, heightCm, weightKg, goalWeightKg, startWaistCm, activityLevel, goal, experience, //
        daysPerWeek, sessionMinutes, workoutWeekdays, trainingTime, split, limitations, budget, dietNotes,
        baselineSteps, parqAnyYes, parqCleared, ghanaAnswers, parqAnsweredAt, emergencyName, emergencyPhone,
        useLb, useFtIn, createdAt,
      ];
  @override
  bool operator ==(Object other) => other is UserProfile && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
