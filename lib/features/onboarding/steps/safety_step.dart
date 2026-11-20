// Owner: WS4. Onboarding step 2 (SPEC 4.2): PAR-Q (7 yes/no) plus 3 Ghana questions. Any PAR-Q
// "yes" shows the doctor message with an acknowledgement; the program stays blocked until it is
// ticked (browsing is allowed). The Safety screen holds the full guidance.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../onboarding_draft.dart';
import '../widgets/form_widgets.dart';

class SafetyStep extends StatelessWidget {
  const SafetyStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final ValueChanged<OnboardingDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = context.read<AssetCatalog>().personalization;
    final parq = (p.safety['parq'] as Map?)?.cast<String, dynamic>() ?? const {};
    final onYes = (parq['on_any_yes'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ghana = [
      for (final q in (parq['ghana_extra_questions'] as List?) ?? const <Object?>[])
        if (q is Map) q.cast<String, dynamic>(),
    ];
    final profile = draft.profile;

    void setGhana(String id, String answer) =>
        onChanged(draft.withProfile(profile.copyWith(ghanaAnswers: {...profile.ghanaAnswers, id: answer})));

    Widget question(String text, String? note, Widget answer) => Card(
          margin: const EdgeInsets.only(bottom: Space.m),
          child: Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(text, style: AppText.body.copyWith(color: t.onSurface)),
                if (note != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(note, style: AppText.label.copyWith(color: t.muted)),
                ],
                const SizedBox(height: Space.m),
                answer,
              ],
            ),
          ),
        );

    final children = <Widget>[
      for (final (i, q) in p.parq.indexed)
        question(
          '${i + 1}. ${q.text}',
          q.note,
          YesNoToggle(
            value: draft.parq[q.id] ?? false,
            onChanged: (v) => onChanged(draft.copyWith(parq: {...draft.parq, q.id: v})),
          ),
        ),
      if (draft.parqAnyYes)
        NoticeBox(
          icon: Icons.medical_services_outlined,
          text: '${onYes['message'] ?? 'Please talk to a doctor before starting.'}',
          child: Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('${onYes['ack_label'] ?? "I've been cleared by a doctor to exercise"}',
                  style: AppText.bodyStrong.copyWith(color: t.onSurface)),
              subtitle: profile.parqCleared
                  ? null
                  : Text('Until this is ticked the workouts stay locked. You can still look around.',
                      style: AppText.label.copyWith(color: t.muted)),
              value: profile.parqCleared,
              onChanged: (v) => onChanged(draft.withProfile(profile.copyWith(parqCleared: v ?? false))),
            ),
          ),
        ),
      const FieldLabel('Three more for Ghana', hint: 'These never lock the app; they change the advice you get.'),
      for (final q in ghana) _ghanaQuestion(context, q, profile, setGhana, question),
      const SizedBox(height: Space.s),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed(Routes.safety),
          icon: const Icon(Icons.health_and_safety_outlined),
          label: const Text('Read the safety guide'),
        ),
      ),
    ];

    return StepBody(
      title: 'Quick safety check',
      subtitle: '7 questions from the PAR-Q+, a standard health check before exercise. Answer honestly.',
      children: children,
    );
  }

  Widget _ghanaQuestion(
    BuildContext context,
    Map<String, dynamic> q,
    UserProfile profile,
    void Function(String id, String answer) set,
    Widget Function(String text, String? note, Widget answer) question,
  ) {
    final t = context.tokens;
    final id = '${q['id']}';
    final text = '${q['text']}';
    final answer = profile.ghanaAnswers[id] ?? GhanaQuestions.no;
    final advice = q['advice'];
    if (id == GhanaQuestions.sickle) {
      final map = advice is Map ? advice : const {};
      final shown = switch (answer) {
        GhanaQuestions.trait => map['trait'],
        GhanaQuestions.disease => map['disease'],
        GhanaQuestions.unsure => 'Not sure? Follow this until you know: ${map['trait']}',
        _ => null,
      };
      return question(
        text,
        null,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final (value, label) in const [
                  (GhanaQuestions.no, 'No'),
                  (GhanaQuestions.trait, 'Trait (AS)'),
                  (GhanaQuestions.disease, 'Disease (SS/SC)'),
                  (GhanaQuestions.unsure, 'Not sure'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: answer == value,
                    onSelected: (_) => set(id, value),
                  ),
              ],
            ),
            if (shown != null) NoticeBox(icon: Icons.info_outline, text: '$shown', color: t.secondary),
          ],
        ),
      );
    }
    final yes = answer == GhanaQuestions.yes;
    return question(
      text,
      null,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          YesNoToggle(value: yes, onChanged: (v) => set(id, v ? GhanaQuestions.yes : GhanaQuestions.no)),
          if (yes && advice != null) NoticeBox(icon: Icons.info_outline, text: '$advice', color: t.secondary),
        ],
      ),
    );
  }
}
