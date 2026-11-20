// Owner: WS4. Today (SPEC 4.3): the first thing he sees in the gym. Resume banner, the next
// workout with a big START, the week strip and streak, quick logs and suggestions.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/copy.dart';
import '../../app/shell.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/body_store.dart';
import '../../state/nutrition_store.dart';
import '../../state/profile_store.dart';
import '../../state/today_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import 'widgets/hero_card.dart';
import 'widgets/quick_logs.dart';
import 'widgets/resume_banner.dart';
import 'widgets/suggestion_cards.dart';
import 'widgets/week_card.dart';

/// Today screen.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the background (maybe the next day, or after the player): reload.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_reload()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final today = context.read<TodayStore>();
    final body = context.read<BodyStore>();
    final nutrition = context.read<NutritionStore>();
    await Future.wait([today.refresh(), body.load(), nutrition.load()]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = context.watch<TodayStore>();
    final profile = context.watch<ProfileStore>().profile;
    final plan = today.preview;
    final inProgress = today.inProgress;
    final blocked = profile?.programBlocked ?? false;

    final children = <Widget>[
      _Header(name: profile?.name, streakWeeks: today.streak.weeks),
      const SizedBox(height: Space.l),
      if (inProgress != null) ...[
        ResumeBanner(key: ValueKey(inProgress.id), session: inProgress),
        const SizedBox(height: Space.l),
      ],
      if (blocked && profile != null) ...[
        _BlockedCard(profile: profile),
        const SizedBox(height: Space.l),
      ],
      if (plan != null)
        HeroCard(plan: plan, blocked: blocked)
      else if (today.loaded)
        Card(
          child: EmptyState(
            icon: Icons.event_busy,
            title: 'No program yet',
            body: 'Pick a program to get your next workout here.',
            action: BigButton(
              label: 'Choose a program',
              height: Sizes.minTap,
              onPressed: () => Shell.goTo(context, ShellTab.program),
            ),
          ),
        )
      else
        const SizedBox(height: 280, child: Center(child: CircularProgressIndicator())),
      const SizedBox(height: Space.l),
      const WeekCard(),
      const SectionHeader('Quick log'),
      const QuickLogs(),
      if (today.cards.isNotEmpty) ...[
        const SectionHeader('For you'),
        for (final c in today.cards)
          Padding(padding: const EdgeInsets.only(bottom: Space.m), child: SuggestionCard(card: c)),
      ],
      const SizedBox(height: Space.xl),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: t.primary,
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.page),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.streakWeeks});

  final String? name;
  final int streakWeeks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = context.read<Clock>().now();
    final hello = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Copy.longDate(now).toUpperCase(), style: AppText.overline.copyWith(color: t.muted)),
              const SizedBox(height: Space.xs),
              Semantics(
                header: true,
                child: Text(
                  name == null ? hello : '$hello, $name',
                  style: AppText.headline.copyWith(color: t.onSurface),
                ),
              ),
            ],
          ),
        ),
        if (streakWeeks > 0)
          Semantics(
            label: '$streakWeeks-week streak',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.chip * 2),
                border: Border.all(color: t.primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: t.primary, size: 22),
                  const SizedBox(width: Space.xs),
                  Text('$streakWeeks', style: AppText.headline.copyWith(fontSize: 22, color: t.onSurface)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// PAR-Q "yes" not yet acknowledged: workouts stay locked (SPEC 4.2 step 2), browsing is fine.
class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parq = context.read<AssetCatalog>().personalization.safety['parq'];
    final onYes = parq is Map ? parq['on_any_yes'] : null;
    final message = onYes is Map ? onYes['message'] : null;
    final ack = onYes is Map ? onYes['ack_label'] : null;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: Color.alphaBlend(t.warning.withValues(alpha: 0.12), t.surface),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services_outlined, color: t.warning),
              const SizedBox(width: Space.s),
              Expanded(child: Text('See a doctor first', style: AppText.bodyStrong.copyWith(color: t.onSurface))),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(
            message is String ? message : 'Please talk to a doctor before starting. You can still browse the app.',
            style: AppText.body.copyWith(color: t.onSurface),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(ack is String ? ack : "I've been cleared by a doctor to exercise",
                style: AppText.bodyStrong.copyWith(color: t.onSurface)),
            value: false,
            onChanged: (v) {
              if (v ?? false) context.read<ProfileStore>().save(profile.copyWith(parqCleared: true));
            },
          ),
        ],
      ),
    );
  }
}
