// Owner: WS4. Everything onboarding collects before "Let's go" (SPEC 4.2). The step widgets edit
// it; the You hub reuses the same steps to edit the saved profile.
import 'package:flutter/foundation.dart';

import '../../app/copy.dart';
import '../../core/equality.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/types.dart';
import '../program/custom_program.dart';

/// Ghana safety question ids (`safety.parq.ghana_extra_questions`) and their answers.
abstract final class GhanaQuestions {
  static const String sickle = 'gh_sickle';
  static const String fever = 'gh_recent_fever';
  static const String diabetes = 'gh_diabetes_meds';

  /// Answers of the sickle-cell question.
  static const String no = 'no', yes = 'yes', trait = 'trait', disease = 'disease', unsure = 'unsure';

  static const Map<String, String> defaults = {sickle: no, fever: no, diabetes: no};
}

@immutable
class OnboardingDraft {
  const OnboardingDraft({
    required this.profile,
    required this.settings,
    this.parq = const {},
    this.weekdaysEdited = false,
  });

  /// The SPEC default user and first-run settings, with workout weekdays from the default program
  /// and the default weigh-in reminder.
  factory OnboardingDraft.initial(AssetCatalog catalog, AppSettings settings, DateTime now) {
    final p = catalog.personalization;
    final base = UserProfile.defaults(now).copyWith(ghanaAnswers: GhanaQuestions.defaults);
    final weekdays = _recommendedWeekdays(catalog, base.split, base.daysPerWeek);
    final reminders = Copy.field(p, 'reminders')?['default'];
    final weighIn = reminders is Map ? reminders['weigh_in_time'] : null;
    return OnboardingDraft(
      profile: base.copyWith(workoutWeekdays: weekdays),
      settings: settings.copyWith(
        reminderTime: () => settings.reminderTime ?? Copy.reminderTimeFor(base.trainingTime),
        weighInTime: () => settings.weighInTime ?? (weighIn is String ? weighIn : '06:30'),
      ),
      parq: {for (final q in p.parq) q.id: false},
    );
  }

  final UserProfile profile;
  final AppSettings settings;

  /// PAR-Q question id -> answered "yes".
  final Map<String, bool> parq;

  /// The user changed the weekday chips by hand (changing days per week then keeps them in sync
  /// only when they still fit).
  final bool weekdaysEdited;

  bool get parqAnyYes => parq.values.any((v) => v);

  /// The template for the chosen split and days (custom programs start from PPL).
  String templateId(AssetCatalog catalog) => profile.split == SplitKey.custom
      ? CustomPrograms.baseTemplateId
      : catalog.personalization.programIdFor(profile.split, profile.daysPerWeek);

  ProgramTemplate template(AssetCatalog catalog) => catalog.template(templateId(catalog));

  /// The weekdays a program for [split] x [days] recommends, or an even spread.
  static List<int> _recommendedWeekdays(AssetCatalog catalog, SplitKey split, int days) {
    final id = split == SplitKey.custom ? CustomPrograms.baseTemplateId : catalog.personalization.programIdFor(split, days);
    final rec = catalog.templates.where((t) => t.programId == id).firstOrNull?.recommendedWeekdays ?? const <int>[];
    return rec.length == days ? List.of(rec) : CustomPrograms.defaultWeekdays(days);
  }

  OnboardingDraft withProfile(UserProfile p) => copyWith(profile: p);

  /// Sets days per week and, unless the user picked weekdays that still fit, the weekdays too.
  OnboardingDraft withDaysPerWeek(AssetCatalog catalog, int days) {
    final keep = weekdaysEdited && profile.workoutWeekdays.length == days;
    return copyWith(
      profile: profile.copyWith(
        daysPerWeek: days,
        workoutWeekdays: keep ? null : _recommendedWeekdays(catalog, profile.split, days),
      ),
    );
  }

  /// Toggles one weekday chip; days per week follows the number of chips (2-6).
  OnboardingDraft toggleWeekday(int weekday) {
    final days = {...profile.workoutWeekdays};
    days.contains(weekday) ? days.remove(weekday) : days.add(weekday);
    final sorted = days.toList()..sort();
    return copyWith(
      weekdaysEdited: true,
      profile: profile.copyWith(
        workoutWeekdays: sorted,
        daysPerWeek: sorted.length.clamp(2, 6),
      ),
    );
  }

  /// What "Let's go" saves (SPEC 4.2 step 9).
  OnboardingResult result(AssetCatalog catalog, DateTime now) => OnboardingResult(
        profile: profile.copyWith(
          parqAnyYes: parqAnyYes,
          parqCleared: parqAnyYes && profile.parqCleared,
          parqAnsweredAt: now,
          createdAt: now,
        ),
        settings: settings,
        templateId: templateId(catalog),
      );

  OnboardingDraft copyWith({
    UserProfile? profile,
    AppSettings? settings,
    Map<String, bool>? parq,
    bool? weekdaysEdited,
  }) =>
      OnboardingDraft(
        profile: profile ?? this.profile,
        settings: settings ?? this.settings,
        parq: parq ?? this.parq,
        weekdaysEdited: weekdaysEdited ?? this.weekdaysEdited,
      );

  List<Object?> get _props => [profile, settings, parq, weekdaysEdited];
  @override
  bool operator ==(Object other) => other is OnboardingDraft && propsEqual(_props, other._props);
  @override
  int get hashCode => propsHash(_props);
}
