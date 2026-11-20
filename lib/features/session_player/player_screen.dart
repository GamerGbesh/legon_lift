// Owner: WS3. The full-screen session player (SPEC 4.4, 8): top bar with segmented progress, the
// current stop, the rest panel, snackbar messages, app-lifecycle resume and the hand-off to the
// summary.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../data/repositories/repositories.dart';
import '../../services/api.dart';
import '../../state/milestone_store.dart';
import '../../state/session_player_controller.dart';
import '../../state/settings_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import 'widgets/player_copy.dart';
import 'widgets/player_sheets.dart';
import 'widgets/rest_panel.dart';
import 'widgets/stop_views.dart';

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

class _PlayerBody extends StatefulWidget {
  const _PlayerBody();

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody> with WidgetsBindingObserver {
  late final SessionPlayerController _c;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _c = context.read<SessionPlayerController>();
    _c.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_onChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_c.appResumed());
  }

  void _onChange() {
    if (!mounted || _left) return;
    final message = _c.takeMessage();
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    switch (_c.status) {
      case PlayerStatus.completed:
        _left = true;
        unawaited(Navigator.of(context).pushReplacementNamed(PlayerRoutes.summary, arguments: _c.sessionId));
      case PlayerStatus.discarded:
        _left = true;
        Navigator.of(context).pop();
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = context.watch<SessionPlayerController>();
    final stop = c.currentStop;
    final rest = c.rest;

    final Widget body = switch (c.status) {
      PlayerStatus.loading => const Center(child: CircularProgressIndicator()),
      PlayerStatus.missing => EmptyState(
          icon: Icons.search_off,
          title: 'Workout not found',
          body: 'It may have been finished or discarded.',
          action: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
        ),
      PlayerStatus.finishing || PlayerStatus.completed => const _Finishing(),
      _ when stop == null => Padding(
          padding: const EdgeInsets.all(Space.page),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('All done!', style: AppText.headline.copyWith(color: t.onSurface)),
              const SizedBox(height: Space.xl),
              BigButton(label: 'Finish and save', icon: Icons.check, onPressed: () => unawaited(c.endWorkout(save: true))),
            ],
          ),
        ),
      _ => KeyedSubtree(
          key: ValueKey('stop-${stop.id}'),
          child: stop.kind.hasSets ? ExerciseStopView(stop: stop) : TimedStopView(stop: stop),
        ),
    };

    return PopScope(
      canPop: c.status != PlayerStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && c.status == PlayerStatus.playing) unawaited(showEndWorkoutSheet(context, c));
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  if (c.status == PlayerStatus.playing) _TopBar(controller: c),
                  Expanded(child: body),
                ],
              ),
              if (rest != null)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {},
                    child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
                  ),
                ),
              if (rest != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
                    child: RestPanel(rest: rest),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final SessionPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = controller;
    final (done, total) = c.progress;
    final current = c.currentStop?.id;
    return Column(
      children: [
        SizedBox(
          height: Sizes.topBar,
          child: Row(
            children: [
              IconButton(
                tooltip: 'End workout',
                iconSize: 28,
                onPressed: () => unawaited(showEndWorkoutSheet(context, c)),
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  c.session?.dayName ?? 'Workout',
                  overflow: TextOverflow.ellipsis,
                  style: PlayerText.strong(AppText.body).copyWith(color: t.onSurface, fontSize: 18),
                ),
              ),
              Icon(Icons.timer_outlined, size: 18, color: t.muted),
              const SizedBox(width: Space.xs),
              Text(Fmt.clock(c.elapsed.inSeconds), style: AppText.tabular(AppText.body).copyWith(color: t.muted)),
              const SizedBox(width: Space.m),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: '$done of $total steps done. Show the plan.',
          child: InkWell(
            onTap: () => unawaited(showStepListSheet(context, c)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.m),
              child: Row(
                children: [
                  for (final (i, s) in c.stops.indexed) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: switch (s.state) {
                            StopState.done => t.primary,
                            StopState.skipped => t.muted,
                            StopState.pending => s.id == current ? t.secondary : t.surface2,
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Finishing extends StatelessWidget {
  const _Finishing();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Space.l),
            Text('Saving your workout…', style: AppText.body.copyWith(color: context.tokens.muted)),
          ],
        ),
      );
}
