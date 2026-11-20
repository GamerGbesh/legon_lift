// Owner: WS4. Split picker (`/program/split`, SPEC 4.5): the 5 templates, "Custom from blank" and
// "Custom from PPL". Switching keeps all history; weights carry over per exercise. The new program
// starts at week 1 unless the user picks "Start at Phase 2" (offered from 8 completed sessions).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/program_store.dart';
import '../../widgets/option_card.dart';
import '../../widgets/section_header.dart';
import 'custom_program.dart';

/// Split picker screen.
class SplitPickerScreen extends StatelessWidget {
  const SplitPickerScreen({super.key});

  static const int phase2MinSessions = 8;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final store = context.watch<ProgramStore>();
    final catalog = context.read<AssetCatalog>();
    final current = store.active;

    Future<void> pick(ProgramTemplate tpl) async {
      final navigator = Navigator.of(context);
      final build = tpl.phases.where((p) => p.phaseId == PhaseId.build).firstOrNull;
      final canSkip = build != null && build.weeks.isNotEmpty && store.completedSessions >= phase2MinSessions;
      final startWeek = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Switch to ${tpl.name}?'),
          content: Text(
            'Your history and weights are kept: every exercise remembers its own progress. '
            '${tpl.daysPerWeek} days a week.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            if (canSkip)
              TextButton(
                onPressed: () => Navigator.of(context).pop(build.weeks.first),
                child: const Text('Start at Phase 2'),
              ),
            FilledButton(onPressed: () => Navigator.of(context).pop(1), child: const Text('Start at week 1')),
          ],
        ),
      );
      if (startWeek == null) return;
      await store.switchTemplate(tpl.programId, startWeek: startWeek);
      navigator.pop();
    }

    Future<void> custom(ProgramTemplate tpl) async {
      final navigator = Navigator.of(context);
      await store.createCustom(tpl);
      navigator.pop();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose your split')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
        children: [
          Text(
            'Switching never deletes anything. Each exercise keeps its weights, so you pick up where you left off.',
            style: AppText.body.copyWith(color: t.muted),
          ),
          const SectionHeader('Ready-made programs'),
          for (final tpl in catalog.templates)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: OptionCard(
                title: tpl.name,
                subtitle: tpl.description,
                icon: Icons.calendar_view_week,
                badge: tpl.isDefault ? 'Recommended' : null,
                selected: current?.templateId == tpl.programId && !(current?.isCustom ?? false),
                onTap: current?.templateId == tpl.programId && !(current?.isCustom ?? false)
                    ? null
                    : () => unawaited(pick(tpl)),
              ),
            ),
          const SectionHeader('Build your own'),
          Padding(
            padding: const EdgeInsets.only(bottom: Space.m),
            child: OptionCard(
              title: 'Custom from Push / Pull / Legs',
              subtitle: 'Start from the recommended plan and change anything.',
              icon: Icons.edit_note,
              selected: false,
              onTap: () => unawaited(custom(CustomPrograms.fromTemplate(catalog.template(CustomPrograms.baseTemplateId)))),
            ),
          ),
          OptionCard(
            title: 'Custom from blank',
            subtitle: '3 empty days with warm-up and cool-down. Add your own exercises.',
            icon: Icons.add_box_outlined,
            selected: false,
            onTap: () => unawaited(custom(CustomPrograms.blank(catalog))),
          ),
        ],
      ),
    );
  }
}
