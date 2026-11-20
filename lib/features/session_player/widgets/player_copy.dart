// Owner: WS3. Player wording (plain language, SPEC 0.5 / 12.1) and small text helpers.
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/models/models.dart';
import '../../../domain/api.dart';

/// Route names used by the player (SPEC 3.2). Kept as plain strings so the player does not
/// import every screen of the app through `routes.dart`.
abstract final class PlayerRoutes {
  static const String summary = '/session/summary';
  static const String safety = '/safety';
}

abstract final class PlayerCopy {
  static const String rirQuestion = 'Nice. How many more could you have done?';
  static const String sipWater = 'Sip some water';
  static const String upNextWater = 'Sip some water before you start.';
  static const String waitEtiquette = 'Busy gym? Ask "Can I work in?" and take turns between sets.';
  static const String hotDay = 'Hot today: rest 30 seconds more if you need it.';
  static const String warmupCardio = 'Bike or treadmill, easy pace. You should be lightly sweating by the end.';
  static const String findWeightIntro = 'Find your weight: pick something you could lift 15 times.';
  static const String calibrationIntro =
      'Calibration set: do your reps, tell us how many you think are left, then keep going until you can\'t do another clean rep.';
  static const String retestIntro = 'Test set: as many good reps as you can, stopping with about 1 left.';
  static const String extrasIntro = 'Extras if you have time. Skip them when you need to go.';
  static const String endBody =
      'Finished exercises still count. Exercises you did not start stay in your program for next time.';

  /// The pain rule (SPEC 12.2 "3/10 rule").
  static const String painTitle = 'Pain check';
  static const List<String> painRule = [
    'Mild discomfort up to 3 out of 10 that does not get worse is OK. Go lighter and keep the movement smooth.',
    'Sharp pain, pain above 3 out of 10, or pain that changes how you move: stop this exercise now.',
    'Pain that is still there tomorrow, or swelling: rest it and get it checked.',
  ];

  /// "3 × 8–12 · rest 2:00 · leave 3 in the tank".
  static String prescriptionLine(ProgramItem item, Prescription rx, Exercise ex) {
    final sets = rx.working.length;
    final range = item.repRange ?? ex.repRange;
    final amount = switch (ex.tracking) {
      Tracking.time => Fmt.clock(item.durationSeconds ?? ex.durationSeconds ?? rx.working.firstOrNull?.durationSec ?? 0),
      _ => range == null ? '${rx.working.firstOrNull?.reps ?? 0}' : (range.$1 == range.$2 ? '${range.$1}' : '${range.$1}–${range.$2}'),
    };
    final perSide = item.perSide || ex.unilateral ? ' each side' : '';
    final parts = [
      '$sets × $amount$perSide',
      'rest ${Fmt.clock(rx.restSec)}',
      if (rx.targetRir != null && ex.tracking != Tracking.time) Fmt.rirTarget(rx.targetRir!),
    ];
    return parts.join(' · ');
  }

  /// "20 × 12" (weight × reps), "45 s" for timed sets, "12" for bodyweight reps.
  static String setText(double kg, int reps, Exercise ex, {int? durationSec}) {
    if (ex.tracking == Tracking.time) return Fmt.clock(durationSec ?? 0);
    if (!ex.isLoaded) return '$reps';
    return '${Fmt.number(kg)} × $reps';
  }

  /// RIR answer buttons: value, label, caption.
  static const List<(int, String, String?)> rirOptions = [
    (0, '0', 'none left'),
    (1, '1', null),
    (2, '2', null),
    (3, '3', null),
    (4, '4+', 'easy'),
  ];

  static String skipReasonLabel(SkipReason r) => switch (r) {
        SkipReason.busy => 'machine busy',
        SkipReason.pain => 'pain',
        SkipReason.noTime => 'no time',
        SkipReason.other => 'skipped',
      };
}

/// Text styles of the player (minimum 14 sp, SPEC 11.3).
abstract final class PlayerText {
  static TextStyle strong(TextStyle s) =>
      s.copyWith(fontWeight: FontWeight.w600, fontVariations: const [FontVariation.weight(600)]);

  static final TextStyle exerciseName = AppText.title.copyWith(fontSize: 24);
  static final TextStyle tableHeader = AppText.label.copyWith(letterSpacing: 0.6);
  static final TextStyle tableCell = AppText.tabular(AppText.body);
}
