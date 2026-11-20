// Owner: WS4. Plain-language labels shared by the WS4 screens (SPEC 0.5, 12.1). Pure Dart.
import '../core/format.dart';
import '../data/models/models.dart';

abstract final class Copy {
  /// A day focus entry ("chest", "front_delts", "arms") as a chip label.
  static String focus(String key) {
    for (final m in Muscle.values) {
      if (m.wire == key) return m.label;
    }
    return capitalize(key.replaceAll('_', ' '));
  }

  static String capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// "Push (chest, shoulders, triceps)" -> "Push".
  static String dayShort(String dayName) {
    final i = dayName.indexOf(' (');
    return i > 0 ? dayName.substring(0, i) : dayName;
  }

  /// Short phase name ("Foundation", "Easy week").
  static String phase(Phase p) => switch (p.phaseId) {
        PhaseId.foundation => 'Foundation',
        PhaseId.build => 'Build',
        PhaseId.progress => 'Progress',
        PhaseId.deload => 'Easy week',
        PhaseId.retest => 'Re-test week',
        PhaseId.custom => 'Custom',
      };

  /// "Week 2 of 14 · Foundation" (template) or "Your custom program".
  static String weekLine(ProgramTemplate t, int week, Phase? p) {
    final total = t.totalWeeks;
    if (total == null) return 'Your custom program';
    return p == null ? 'Week $week of $total' : 'Week $week of $total · ${phase(p)}';
  }

  /// Rep target of an item: "8–12 reps", "10 reps", "30 s", "per side" when unilateral.
  static String target(ProgramItem item) {
    final r = item.repRange;
    final side = item.perSide ? ' per side' : '';
    if (r != null) return r.$1 == r.$2 ? '${r.$1} reps$side' : '${r.$1}–${r.$2} reps$side';
    final d = item.durationSeconds;
    if (d != null) return d >= 60 && d % 60 == 0 ? '${d ~/ 60} min$side' : '$d s$side';
    return '';
  }

  /// "3 × 8–12" style line for a working item.
  static String setsLine(ProgramItem item) {
    final t = target(item);
    return item.sets > 1 ? '${item.sets} × $t' : t;
  }

  /// Rest as "2:00 rest".
  static String rest(int seconds) => '${Fmt.clock(seconds)} rest';

  /// Plain-language reps in reserve target, or null when the item has none.
  static String? tank(int? rir) => rir == null ? null : Fmt.rirTarget(rir);

  static const Map<Goal, String> _goalFallback = {
    Goal.recomp: 'Lose fat & build muscle',
    Goal.fatLoss: 'Lose fat',
    Goal.muscleGain: 'Build muscle',
    Goal.maintain: 'Maintain & get fit',
  };

  /// Goal label from `onboarding.fields[goal].labels` (falls back to built-in copy).
  static String goal(Goal g, Personalization p) {
    final labels = field(p, 'goal')?['labels'];
    final v = labels is Map ? labels[g.wire] : null;
    return v is String ? v : _goalFallback[g]!;
  }

  static String goalHint(Goal g) => switch (g) {
        Goal.recomp => 'Best for a beginner with weight to lose: get stronger while the waist shrinks.',
        Goal.fatLoss => 'A bigger calorie gap. Lifting keeps your muscle.',
        Goal.muscleGain => 'A small calorie surplus to grow faster.',
        Goal.maintain => 'Eat at maintenance and build the habit.',
      };

  static String experience(Experience e) => switch (e) {
        Experience.never => 'Never trained',
        Experience.lt3Months => 'Less than 3 months',
        Experience.m3to12 => '3 to 12 months',
        Experience.gt1Year => 'More than a year',
      };

  static String activity(ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => 'Mostly sitting',
        ActivityLevel.lightlyActive => 'Lightly active',
        ActivityLevel.moderatelyActive => 'Moderately active',
        ActivityLevel.veryActive => 'Very active',
        ActivityLevel.extraActive => 'Extremely active',
      };

  static String activityHint(ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => 'Desk, lectures, little walking',
        ActivityLevel.lightlyActive => 'Walking between lectures, some errands',
        ActivityLevel.moderatelyActive => 'On your feet most of the day',
        ActivityLevel.veryActive => 'Physical job or sport most days',
        ActivityLevel.extraActive => 'Hard physical work every day',
      };

  static String split(SplitKey s) => switch (s) {
        SplitKey.pushPullLegs => 'Push / Pull / Legs',
        SplitKey.upperLower => 'Upper / Lower',
        SplitKey.chestbackLegsArmsshoulders => 'Chest+Back / Legs / Arms+Shoulders',
        SplitKey.fullBody => 'Full body',
        SplitKey.custom => 'Custom',
      };

  static String splitHint(SplitKey s) => switch (s) {
        SplitKey.pushPullLegs => 'Each muscle trained hard once a week. Simple and proven.',
        SplitKey.upperLower => 'Each muscle about 1.5 times a week. More practice per lift.',
        SplitKey.chestbackLegsArmsshoulders => 'Classic gym layout with extra arm work.',
        SplitKey.fullBody => 'Whole body every session.',
        SplitKey.custom => 'Build your own days, starting from Push / Pull / Legs.',
      };

  static String limitation(String id) => switch (id) {
        'knee' => 'Knee',
        'lower_back' => 'Lower back',
        'shoulder' => 'Shoulder',
        'wrist_elbow' => 'Wrist or elbow',
        'hip' => 'Hip',
        'ankle' => 'Ankle',
        'other' => 'Other',
        _ => capitalize(id.replaceAll('_', ' ')),
      };

  static String diet(String id) => switch (id) {
        'no_pork' => 'No pork',
        'vegetarian' => 'Vegetarian',
        'lactose_intolerant' => 'Lactose intolerant',
        'groundnut_allergy' => 'Groundnut allergy',
        'fish_allergy' => 'Fish allergy',
        _ => capitalize(id.replaceAll('_', ' ')),
      };

  static String budget(String id) => switch (id) {
        'tight' => 'Tight',
        'moderate' => 'Moderate',
        'comfortable' => 'Comfortable',
        _ => capitalize(id),
      };

  static String trainingTime(String id) => switch (id) {
        'morning' => 'Morning',
        'afternoon' => 'Afternoon',
        'evening' => 'Evening',
        _ => capitalize(id),
      };

  /// Default workout-reminder time for a usual training time.
  static String reminderTimeFor(String trainingTime) => switch (trainingTime) {
        'morning' => '06:00',
        'afternoon' => '11:00',
        _ => '15:00',
      };

  static const List<String> weekdaysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static const List<String> monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "Monday 16 November".
  static String longDate(DateTime d) => '${weekdaysLong[d.weekday - 1]} ${d.day} ${monthsLong[d.month - 1]}';

  /// One field of `personalization.onboarding.fields` by id.
  static Map<String, dynamic>? field(Personalization p, String id) {
    final fields = (p.raw['onboarding'] as Map?)?['fields'];
    if (fields is! List) return null;
    for (final f in fields.whereType<Map<dynamic, dynamic>>()) {
      if (f['id'] == id) return f.cast<String, dynamic>();
    }
    return null;
  }

  /// String options of an enum / multi-enum onboarding field (empty when missing).
  static List<String> options(Personalization p, String id) {
    final o = field(p, id)?['options'];
    return o is List ? [for (final x in o) '$x'] : const [];
  }
}
