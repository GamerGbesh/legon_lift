// Owner: WS4. Route names and onGenerateRoute (SPEC 3.2).
import 'package:material_ui/material_ui.dart';

import '../features/backup/backup_screen.dart';
import '../features/body/body_screen.dart';
import '../features/library/exercise_detail_screen.dart';
import '../features/milestones/milestones_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/program/day_editor_screen.dart';
import '../features/program/split_picker_screen.dart';
import '../features/progress/session_detail_screen.dart';
import '../features/safety/safety_screen.dart';
import '../features/session_player/player_screen.dart';
import '../features/session_player/summary_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

abstract final class Routes {
  static const root = '/';
  static const onboarding = '/onboarding';

  /// Args: [PlayerArgs].
  static const session = '/session';

  /// Args: `String sessionId`.
  static const sessionSummary = '/session/summary';

  /// The same summary reopened from History. Args: `String sessionId`.
  static const historySummary = '/history/summary';

  /// Args: [ExerciseDetailArgs].
  static const exercise = '/exercise';

  /// Args: `String dayId`.
  static const programDay = '/program/day';
  static const programSplit = '/program/split';

  /// Args: `String sessionId`.
  static const historySession = '/history/session';
  static const body = '/body';
  static const nutrition = '/nutrition';
  static const milestones = '/milestones';
  static const safety = '/safety';
  static const settings = '/settings';
  static const backup = '/backup';
}

/// Builds the page for [settings]; unknown names return null (Flutter shows its error page).
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final args = settings.arguments;
  final Widget? page = switch (settings.name) {
    Routes.root => const Shell(),
    Routes.onboarding => const OnboardingFlow(),
    Routes.session => PlayerScreen(args: args is PlayerArgs ? args : const PlayerArgs()),
    Routes.sessionSummary => SummaryScreen(sessionId: args! as String),
    Routes.historySummary => SummaryScreen(sessionId: args! as String, fromHistory: true),
    Routes.exercise => ExerciseDetailScreen(args: args! as ExerciseDetailArgs),
    Routes.programDay => DayEditorScreen(dayId: args! as String),
    Routes.programSplit => const SplitPickerScreen(),
    Routes.historySession => SessionDetailScreen(sessionId: args! as String),
    Routes.body => const BodyScreen(),
    Routes.nutrition => const NutritionScreen(),
    Routes.milestones => const MilestonesScreen(),
    Routes.safety => const SafetyScreen(),
    Routes.settings => const SettingsScreen(),
    Routes.backup => const BackupScreen(),
    _ => null,
  };
  if (page == null) return null;
  return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => page);
}
