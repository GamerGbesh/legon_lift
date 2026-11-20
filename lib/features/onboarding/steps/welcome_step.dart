// Owner: WS4. Onboarding step 1 (SPEC 4.2): welcome and optional first name.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../onboarding_draft.dart';
import '../widgets/form_widgets.dart';

class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key, required this.draft, required this.onChanged});

  final OnboardingDraft draft;
  final ValueChanged<OnboardingDraft> onChanged;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep> {
  late final TextEditingController _name = TextEditingController(text: widget.draft.profile.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget promise(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(Radii.chip)),
                child: Icon(icon, color: t.primary),
              ),
              const SizedBox(width: Space.m),
              Expanded(child: Text(text, style: AppText.body.copyWith(color: t.onSurface))),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.xl),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [Color(0xFF16294A), Color(0xFF0B0F14)], center: Alignment(0, -0.2)),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: t.surface2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 40),
                // Material Symbols draw this barbell diagonally; level it to match the app icon.
                Transform.rotate(angle: -math.pi / 4, child: Icon(Icons.fitness_center, color: t.primary, size: 40)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.xl),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Legon Lift', style: TextStyle(color: t.primary)),
              const TextSpan(text: ': your step-by-step coach for the UG gym.'),
            ]),
            style: AppText.headline.copyWith(fontSize: 32, color: t.onSurface),
          ),
        ),
        const SizedBox(height: Space.xl),
        promise(Icons.format_list_numbered, 'Every session laid out for you, from warm-up to cool-down.'),
        promise(Icons.tune, 'We find your starting weights together. No guessing.'),
        promise(Icons.wifi_off, 'Works offline in the gym. Your data stays on your phone.'),
        const FieldLabel('What should we call you?', hint: 'Optional'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: AppText.body.copyWith(color: t.onSurface),
          decoration: const InputDecoration(hintText: 'First name'),
          onChanged: (v) {
            final name = v.trim();
            widget.onChanged(widget.draft.withProfile(widget.draft.profile.copyWith(name: () => name.isEmpty ? null : name)));
          },
        ),
        const SizedBox(height: Space.l),
        Text('Setup takes about 2 minutes. Everything is already filled in; change what is not you.',
            style: AppText.label.copyWith(color: t.muted)),
      ],
    );
  }
}
