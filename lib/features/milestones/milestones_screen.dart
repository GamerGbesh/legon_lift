// Owner: WS6. Badge wall (SPEC 4.10): every milestone grouped by category, earned ones with their
// date, locked ones greyed with their description and progress.
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../data/models/models.dart';
import '../../domain/api.dart';
import '../../state/milestone_store.dart';
import '../../state/profile_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  static const _order = ['consistency', 'strength', 'body', 'habit'];

  @override
  void initState() {
    super.initState();
    unawaited(context.read<MilestoneStore>().refreshProgress());
  }

  static String _categoryTitle(String c) => switch (c) {
        'consistency' => 'Showing up',
        'strength' => 'Strength',
        'body' => 'Body',
        'habit' => 'Habits',
        _ => c.isEmpty ? 'Other' : c[0].toUpperCase() + c.substring(1),
      };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MilestoneStore>();
    final hasProfile = context.watch<ProfileStore>().profile != null;
    final all = store.milestones;
    final categories = [
      ..._order.where((c) => all.any((m) => m.category == c)),
      ...{for (final m in all) m.category}.where((c) => !_order.contains(c)),
    ];
    final earnedCount = all.where((m) => store.awardFor(m.id) != null).length;
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('Milestones')),
      body: !hasProfile
          ? const EmptyState(
              icon: Icons.emoji_events,
              title: 'No milestones yet',
              body: 'Finish setting up the app, then your first workout earns your first badge.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
              children: [
                Semantics(
                  label: '$earnedCount of ${all.length} milestones earned',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: '$earnedCount', style: AppText.displayStat.copyWith(color: t.primary)),
                        TextSpan(text: ' of ${all.length} earned', style: AppText.title.copyWith(color: t.onSurface)),
                      ])),
                      const SizedBox(height: Space.s),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: all.isEmpty ? 0 : earnedCount / all.length,
                          minHeight: 8,
                          color: t.primary,
                          backgroundColor: t.surface2,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final c in categories) ...[
                  SectionHeader(
                    _categoryTitle(c),
                    trailing: Text(
                      '${all.where((m) => m.category == c && store.awardFor(m.id) != null).length}/${all.where((m) => m.category == c).length}',
                      style: AppText.tabular(AppText.label).copyWith(color: t.muted),
                    ),
                  ),
                  _BadgeGrid(milestones: [for (final m in all) if (m.category == c) m], store: store),
                ],
              ],
            ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.milestones, required this.store});

  final List<Milestone> milestones;
  final MilestoneStore store;

  @override
  Widget build(BuildContext context) {
    // Earned first, so progress is visible at a glance.
    final sorted = [
      ...milestones.where((m) => store.awardFor(m.id) != null),
      ...milestones.where((m) => store.awardFor(m.id) == null),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 560 ? 3 : 2;
      final w = (c.maxWidth - Space.m * (columns - 1)) / columns;
      return Wrap(
        spacing: Space.m,
        runSpacing: Space.m,
        children: [
          for (final m in sorted)
            SizedBox(
              width: w,
              child: _BadgeTile(
                milestone: m,
                award: store.awardFor(m.id),
                progress: store.progress[m.id],
                lowEmphasis: store.isLowEmphasis(m.id),
                repeatable: store.isRepeatable(m.id),
              ),
            ),
        ],
      );
    });
  }
}

IconData _categoryIcon(String category) => switch (category) {
      'consistency' => Icons.event_available,
      'strength' => Icons.fitness_center,
      'body' => Icons.straighten,
      'habit' => Icons.water_drop,
      _ => Icons.emoji_events,
    };

String _dateOf(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.milestone,
    required this.award,
    required this.progress,
    required this.lowEmphasis,
    required this.repeatable,
  });

  final Milestone milestone;
  final MilestoneAward? award;
  final MilestoneProgress? progress;
  final bool lowEmphasis, repeatable;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final earned = award != null;
    final accent = earned ? (lowEmphasis ? t.secondary : t.primary) : t.muted;
    final pr = progress;
    final status = earned ? 'Earned ${_dateOf(award!.awardedAt)}' : milestone.desc;
    return Semantics(
      button: true,
      label: '${milestone.title}. ${earned ? status : 'Locked. ${milestone.desc}'}'
          '${!earned && pr != null ? '. ${pr.label}' : ''}',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: earned ? null : t.surface.withValues(alpha: 0.6),
        child: InkWell(
          onTap: () => unawaited(_showDetails(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 148),
            child: Padding(
              padding: const EdgeInsets.all(Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: accent.withValues(alpha: earned ? 0.18 : 0.10), shape: BoxShape.circle),
                        child: Icon(earned ? _categoryIcon(milestone.category) : Icons.lock_outline, color: accent, size: 22),
                      ),
                      const Spacer(),
                      if (earned) Icon(Icons.check_circle, color: t.success, size: 20),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    milestone.title,
                    style: AppText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: earned ? t.onSurface : t.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(status, style: AppText.label.copyWith(color: t.muted), maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (!earned && pr != null) ...[
                    const SizedBox(height: Space.s),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: pr.fraction, minHeight: 6, color: t.secondary, backgroundColor: t.surface2),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(pr.label, style: AppText.tabular(AppText.label).copyWith(color: t.muted), maxLines: 2),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final t = context.tokens;
          final earned = award != null;
          final pr = progress;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    earned ? _categoryIcon(milestone.category) : Icons.lock_outline,
                    size: 56,
                    color: earned ? (lowEmphasis ? t.secondary : t.primary) : t.muted,
                  ),
                  const SizedBox(height: Space.m),
                  Text(milestone.title, textAlign: TextAlign.center, style: AppText.headline.copyWith(color: t.onSurface)),
                  const SizedBox(height: Space.s),
                  Text(milestone.desc, textAlign: TextAlign.center, style: AppText.body.copyWith(color: t.muted)),
                  const SizedBox(height: Space.l),
                  if (earned)
                    Text(
                      repeatable ? 'First earned ${_dateOf(award!.awardedAt)}' : 'Earned ${_dateOf(award!.awardedAt)}',
                      textAlign: TextAlign.center,
                      style: AppText.title.copyWith(fontSize: 18, color: t.success),
                    )
                  else if (pr != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: pr.fraction, minHeight: 10, color: t.secondary, backgroundColor: t.surface2),
                    ),
                    const SizedBox(height: Space.s),
                    Text(pr.label, textAlign: TextAlign.center, style: AppText.tabular(AppText.body).copyWith(color: t.onSurface)),
                  ] else
                    Text('Not earned yet.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: t.onSurface)),
                  if (repeatable) ...[
                    const SizedBox(height: Space.m),
                    Text('You earn this again every time you beat a best.',
                        textAlign: TextAlign.center, style: AppText.label.copyWith(color: t.muted)),
                  ],
                  if (lowEmphasis) ...[
                    const SizedBox(height: Space.m),
                    Text('BMI is only a rough guide. Your waist and your strength say more.',
                        textAlign: TextAlign.center, style: AppText.label.copyWith(color: t.muted)),
                  ],
                ],
              ),
            ),
          );
        },
      );
}
