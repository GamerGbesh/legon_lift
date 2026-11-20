// Owner: WS6. Re-answering the PAR-Q (SPEC 4.11) from the Safety screen, plus the advice text for
// the three Ghana questions (shared with the Safety screen card).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../data/assets/asset_catalog.dart';
import '../../state/profile_store.dart';
import '../../widgets/big_button.dart';
import '../onboarding/onboarding_draft.dart';
import '../onboarding/widgets/form_widgets.dart';

/// Advice lines for the Ghana questions the user answered with anything other than "no".
/// [questions] is `safety.parq.ghana_extra_questions` from personalization.json.
List<String> ghanaAdvice(Map<String, String> answers, List<Object?> questions) {
  final out = <String>[];
  for (final q in questions) {
    if (q is! Map) continue;
    final id = '${q['id']}';
    final answer = answers[id] ?? GhanaQuestions.no;
    if (answer == GhanaQuestions.no) continue;
    final advice = q['advice'];
    if (advice is Map) {
      final key = answer == GhanaQuestions.disease ? 'disease' : 'trait';
      final text = advice[key];
      if (text != null) out.add(answer == GhanaQuestions.unsure ? 'Not sure? Until you know: $text' : '$text');
    } else if (advice != null) {
      out.add('$advice');
    }
  }
  return out;
}

/// Shows the PAR-Q sheet and saves the new answers to the profile.
Future<void> showParqSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ParqSheet(),
    );

class _ParqSheet extends StatefulWidget {
  const _ParqSheet();

  @override
  State<_ParqSheet> createState() => _ParqSheetState();
}

class _ParqSheetState extends State<_ParqSheet> {
  final Map<String, bool> _answers = {};
  late Map<String, String> _ghana;

  @override
  void initState() {
    super.initState();
    _ghana = {...GhanaQuestions.defaults, ...?context.read<ProfileStore>().profile?.ghanaAnswers};
  }

  bool get _anyYes => _answers.values.any((v) => v);

  Future<void> _save() async {
    final store = context.read<ProfileStore>();
    final p = store.profile;
    if (p == null) return;
    final anyYes = _anyYes;
    await store.save(p.copyWith(
      parqAnyYes: anyYes,
      // A fresh "yes" needs a fresh doctor's clearance; all "no" clears the block.
      parqCleared: anyYes ? false : p.parqCleared,
      ghanaAnswers: _ghana,
      parqAnsweredAt: context.read<Clock>().now(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>().personalization;
    final parq = (catalog.safety['parq'] as Map?)?.cast<String, Object?>() ?? const {};
    final ghanaQs = [
      for (final q in (parq['ghana_extra_questions'] as List?) ?? const <Object?>[])
        if (q is Map) q.cast<String, Object?>(),
    ];
    final onYes = (parq['on_any_yes'] as Map?)?.cast<String, Object?>() ?? const {};

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Space.page, Space.l, Space.page, Space.xxl),
        children: [
          Text('Health check', style: AppText.title.copyWith(color: t.onSurface)),
          const SizedBox(height: Space.xs),
          Text('7 questions from the PAR-Q+. Answer honestly.', style: AppText.body.copyWith(color: t.muted)),
          const SizedBox(height: Space.l),
          for (final (i, q) in catalog.parq.indexed)
            _QuestionCard(
              text: '${i + 1}. ${q.text}',
              note: q.note,
              child: YesNoToggle(
                value: _answers[q.id] ?? false,
                onChanged: (v) => setState(() => _answers[q.id] = v),
              ),
            ),
          if (_anyYes)
            NoticeBox(
              icon: Icons.medical_services_outlined,
              text: '${onYes['message'] ?? 'Please talk to a doctor before starting.'}',
            ),
          const SizedBox(height: Space.m),
          for (final q in ghanaQs) _ghanaCard(q),
          const SizedBox(height: Space.l),
          BigButton(label: 'Save answers', icon: Icons.check, height: Sizes.heroButton, onPressed: _save),
        ],
      ),
    );
  }

  Widget _ghanaCard(Map<String, Object?> q) {
    final id = '${q['id']}';
    final answer = _ghana[id] ?? GhanaQuestions.no;
    void set(String v) => setState(() => _ghana[id] = v);
    if (id == GhanaQuestions.sickle) {
      return _QuestionCard(
        text: '${q['text']}',
        child: Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final (value, label) in const [
              (GhanaQuestions.no, 'No'),
              (GhanaQuestions.trait, 'Trait (AS)'),
              (GhanaQuestions.disease, 'Disease (SS/SC)'),
              (GhanaQuestions.unsure, 'Not sure'),
            ])
              ChoiceChip(label: Text(label), selected: answer == value, onSelected: (_) => set(value)),
          ],
        ),
      );
    }
    return _QuestionCard(
      text: '${q['text']}',
      child: YesNoToggle(
        value: answer == GhanaQuestions.yes,
        onChanged: (v) => set(v ? GhanaQuestions.yes : GhanaQuestions.no),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.text, this.note, required this.child});

  final String text;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Card(
      margin: const EdgeInsets.only(bottom: Space.m),
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: AppText.body.copyWith(color: t.onSurface)),
            if (note != null) ...[
              const SizedBox(height: Space.xs),
              Text(note!, style: AppText.label.copyWith(color: t.muted)),
            ],
            const SizedBox(height: Space.m),
            child,
          ],
        ),
      ),
    );
  }
}
