// Owner: WS4. "You" hub (SPEC 4.12): profile summary + edit (reuses the onboarding step widgets),
// daily targets, links to Body, Food, Milestones, Safety, Settings, Backup, and credits.
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';
import '../../data/models/models.dart';
import '../../state/body_store.dart';
import '../../state/milestone_store.dart';
import '../../state/nutrition_store.dart';
import '../../state/profile_store.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../onboarding/steps/body_step.dart';
import '../onboarding/steps/goal_step.dart';
import '../onboarding/steps/limitations_step.dart';

/// "You" tab: profile and links to Body, Food, Milestones, Safety, Settings, Backup.
class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  static String goalLabel(Goal g) => switch (g) {
        Goal.recomp => 'Lose fat, build muscle',
        Goal.fatLoss => 'Lose fat',
        Goal.muscleGain => 'Build muscle',
        Goal.maintain => 'Stay fit',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = context.watch<ProfileStore>().profile;
    final body = context.watch<BodyStore>();
    final nutrition = context.watch<NutritionStore>();
    final milestones = context.watch<MilestoneStore>();
    final latest = body.latestWeight?.weightKg ?? profile?.weightKg;
    final start = profile?.weightKg;
    final change = latest != null && start != null ? latest - start : null;

    const links = [
      (Icons.monitor_weight_outlined, 'Body', 'Weight and waist', Routes.body),
      (Icons.restaurant, 'Food', 'Calories, protein, Ghanaian meal ideas', Routes.nutrition),
      (Icons.emoji_events_outlined, 'Milestones', 'Your badges and what is next', Routes.milestones),
      (Icons.health_and_safety_outlined, 'Safety', 'Heat, pain rule, emergency numbers', Routes.safety),
      (Icons.settings_outlined, 'Settings', 'Equipment, rest timer, reminders', Routes.settings),
      (Icons.backup_outlined, 'Backup', 'Save or restore your data', Routes.backup),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('You')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
        children: [
          if (profile != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: t.primary,
                          foregroundColor: t.onPrimary,
                          child: Text(
                            (profile.name?.isNotEmpty ?? false) ? profile.name!.characters.first.toUpperCase() : 'L',
                            style: AppText.title,
                          ),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile.name?.isNotEmpty ?? false ? profile.name! : 'Your profile',
                                  style: AppText.title.copyWith(color: t.onSurface)),
                              Text(
                                '${profile.ageY} y · ${Fmt.height(profile.heightCm, useFtIn: profile.useFtIn)} · '
                                '${goalLabel(profile.goal)}',
                                style: AppText.label.copyWith(color: t.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: () => unawaited(Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => const _EditProfileScreen()))),
                          icon: Icon(Icons.edit_outlined, color: t.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.l),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'Weight',
                            value: latest == null ? '—' : Fmt.weight(latest, useLb: profile.useLb, maxDecimals: 1),
                            delta: change == null || change.abs() < 0.05
                                ? null
                                : Fmt.weightDelta(change, useLb: profile.useLb),
                          ),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: StatTile(label: 'Calories / day', value: '${nutrition.targets.calorieTargetKcal}'),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: StatTile(label: 'Protein / day', value: '${nutrition.targets.proteinTargetG} g'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.m),
                    Text(
                      '${profile.daysPerWeek} days a week · ${profile.sessionMinutes} min sessions · '
                      '${milestones.awards.length} milestones earned',
                      style: AppText.label.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.s),
          for (final (icon, label, sub, route) in links)
            ListTile(
              minTileHeight: Sizes.minTap + 8,
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.s),
              leading: Icon(icon, color: t.primary),
              title: Text(label, style: AppText.bodyStrong.copyWith(color: t.onSurface)),
              subtitle: Text(sub, style: AppText.label.copyWith(color: t.muted)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed(route),
            ),
          const SectionHeader('About'),
          Text(
            'Legon Lift · built for the University of Ghana gym.\n'
            'Exercise photos: free-exercise-db (public domain, Unlicense). Form videos open on YouTube and belong '
            'to their creators. Fonts: Barlow Semi Condensed and Inter (SIL Open Font License).\n'
            'This app gives general fitness guidance, not medical advice.',
            style: AppText.label.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen();

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late UserProfile _profile = context.read<ProfileStore>().profile!;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await context.read<ProfileStore>().save(_profile);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Edit profile'),
            actions: [
              TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
            ],
            bottom: const TabBar(tabs: [Tab(text: 'Body'), Tab(text: 'Goal'), Tab(text: 'Limits')]),
          ),
          body: TabBarView(
            children: [
              BodyStep(profile: _profile, onChanged: (p) => setState(() => _profile = p)),
              GoalStep(profile: _profile, onChanged: (p) => setState(() => _profile = p)),
              LimitationsStep(profile: _profile, onChanged: (p) => setState(() => _profile = p)),
            ],
          ),
        ),
      );
}
