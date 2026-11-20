// Owner: WS3. Phase 0 stub (SPEC 4.4, 8): shows the controller wiring; the owner builds the player.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../core/clock.dart';
import '../../data/repositories/repositories.dart';
import '../../services/api.dart';
import '../../state/milestone_store.dart';
import '../../state/session_player_controller.dart';
import '../../state/settings_store.dart';
import '../../widgets/empty_state.dart';

/// Arguments of the `/session` route.
@immutable
class PlayerArgs {
  const PlayerArgs({this.sessionId, this.dayId});

  /// The session to play/resume.
  final String? sessionId;

  /// A day to start when there is no session yet.
  final String? dayId;
}

/// The full-screen session player (route `/session`).
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.args});

  final PlayerArgs args;

  @override
  Widget build(BuildContext context) {
    final sessionId = args.sessionId;
    if (sessionId == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.fitness_center, title: 'No workout selected'),
      );
    }
    return ChangeNotifierProvider<SessionPlayerController>(
      create: (context) => SessionPlayerController(
        sessionId: sessionId,
        catalog: context.read<AssetCatalog>(),
        sessions: context.read<SessionRepository>(),
        states: context.read<ExerciseStateRepository>(),
        programs: context.read<ProgramRepository>(),
        settings: context.read<SettingsStore>(),
        milestones: context.read<MilestoneStore>(),
        restAlarm: context.read<RestAlarm>(),
        sound: context.read<SoundService>(),
        haptics: context.read<HapticsService>(),
        wakelock: context.read<WakelockService>(),
        clock: context.read<Clock>(),
      )..load(),
      child: const _PlayerBody(),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  const _PlayerBody();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SessionPlayerController>();
    final session = c.session;
    return Scaffold(
      appBar: AppBar(title: Text(session?.dayName ?? 'Workout')),
      body: Padding(
        padding: const EdgeInsets.all(Space.page),
        child: c.loading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.construction,
                title: session == null ? 'Workout not found' : session.dayName,
                body: 'The workout player is being built.',
              ),
      ),
    );
  }
}
