// Owner: WS4. Starting and resuming workouts from Today.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/copy.dart';
import '../../app/routes.dart';
import '../../state/today_store.dart';
import '../session_player/player_screen.dart';
import 'sheets/pre_start_sheet.dart';

/// Opens the player on an existing session.
Future<void> openSession(BuildContext context, String sessionId) =>
    Navigator.of(context).pushNamed(Routes.session, arguments: PlayerArgs(sessionId: sessionId));

/// Start tapped: pre-start sheet, then build and start the session and open the player.
Future<void> startWorkout(BuildContext context, {String? dayId, required String dayName}) async {
  final today = context.read<TodayStore>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showPreStartSheet(context, dayId: dayId, dayName: Copy.dayShort(dayName));
  if (choice == null) return;
  try {
    final id = await today.startSession(
      dayId: dayId,
      hotDay: choice.hotDay,
      readiness: choice.readiness,
      recentIllness: choice.recentIllness,
      cardioOff: choice.cardioOff,
    );
    await navigator.pushNamed(Routes.session, arguments: PlayerArgs(sessionId: id));
  } on StateError catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not start the workout: ${e.message}')));
  }
}
