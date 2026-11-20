// Owner: WS4. First-run onboarding (SPEC 4.2): 9 steps, every one pre-filled for the default
// user; Back/Next in the thumb zone, progress dots, "Skip, use defaults" after step 3.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../data/assets/asset_catalog.dart';
import '../../data/models/models.dart';
import '../../state/profile_store.dart';
import '../../state/program_store.dart';
import '../../state/settings_store.dart';
import '../../widgets/big_button.dart';
import '../program/custom_program.dart';
import 'onboarding_draft.dart';
import 'steps/body_step.dart';
import 'steps/equipment_step.dart';
import 'steps/goal_step.dart';
import 'steps/limitations_step.dart';
import 'steps/preview_step.dart';
import 'steps/safety_step.dart';
import 'steps/schedule_step.dart';
import 'steps/split_step.dart';
import 'steps/welcome_step.dart';

/// First-run onboarding (route `/onboarding`).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  /// Number of steps (SPEC 4.2 table).
  static const int stepCount = 9;

  /// Index of the first step that shows "Skip, use defaults" (after Welcome, Safety and Body).
  static const int firstSkippableStep = 3;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late OnboardingDraft _draft;
  int _step = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = OnboardingDraft.initial(
      context.read<AssetCatalog>(),
      context.read<SettingsStore>().settings,
      context.read<Clock>().now(),
    );
  }

  int get _last => OnboardingFlow.stepCount - 1;

  bool get _canGoOn {
    if (_step == 4) {
      final n = _draft.profile.workoutWeekdays.length;
      return n >= 2 && n <= 6;
    }
    return true;
  }

  void _update(OnboardingDraft d) => setState(() => _draft = d);

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step.clamp(0, _last));
  }

  Future<void> _finish() async {
    final catalog = context.read<AssetCatalog>();
    final profiles = context.read<ProfileStore>();
    final programs = context.read<ProgramStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = context.read<Clock>().now();
    final custom = _draft.profile.split == SplitKey.custom;
    setState(() => _saving = true);
    try {
      await profiles.completeOnboarding(_draft.result(catalog, now));
      if (custom) {
        await programs.createCustom(CustomPrograms.fromTemplate(catalog.template(CustomPrograms.baseTemplateId)));
      }
      if (mounted && navigator.canPop()) navigator.pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save your plan: $e')));
    }
  }

  Widget _stepView() {
    final d = _draft;
    void profile(UserProfile p) => _update(d.withProfile(p));
    return switch (_step) {
      0 => WelcomeStep(draft: d, onChanged: _update),
      1 => SafetyStep(draft: d, onChanged: _update),
      2 => BodyStep(profile: d.profile, onChanged: profile),
      3 => GoalStep(profile: d.profile, onChanged: profile),
      4 => ScheduleStep(draft: d, onChanged: _update),
      5 => SplitStep(draft: d, onChanged: _update),
      6 => EquipmentStep(draft: d, onChanged: _update),
      7 => LimitationsStep(profile: d.profile, onChanged: profile),
      _ => PreviewStep(draft: d),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final skippable = _step >= OnboardingFlow.firstSkippableStep && _step < _last;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _go(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.m, Space.page, Space.s),
                child: _ProgressDots(step: _step, count: OnboardingFlow.stepCount),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(_step), child: _stepView()),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.surface2))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.page),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (skippable)
                        TextButton(
                          onPressed: () => _go(_last),
                          child: const Text('Skip, use defaults'),
                        ),
                      Row(
                        children: [
                          if (_step > 0) ...[
                            Expanded(
                              child: BigButton(
                                label: 'Back',
                                kind: BigButtonKind.secondary,
                                height: Sizes.minTap + 8,
                                onPressed: _saving ? null : () => _go(_step - 1),
                              ),
                            ),
                            const SizedBox(width: Space.m),
                          ],
                          Expanded(
                            flex: 2,
                            child: _step == _last
                                ? BigButton(
                                    label: _saving ? 'Saving…' : "Let's go",
                                    icon: Icons.bolt,
                                    height: Sizes.minTap + 8,
                                    onPressed: _saving ? null : _finish,
                                  )
                                : BigButton(
                                    label: 'Next',
                                    icon: Icons.arrow_forward,
                                    height: Sizes.minTap + 8,
                                    onPressed: _canGoOn ? () => _go(_step + 1) : null,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.step, required this.count});

  final int step, count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Step ${step + 1} of $count',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              flex: i == step ? 3 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 6,
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : Space.xs),
                decoration: BoxDecoration(
                  color: i <= step ? t.primary : t.surface2,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          const SizedBox(width: Space.m),
          Text('${step + 1}/$count', style: AppText.tabular(AppText.label).copyWith(color: t.muted)),
        ],
      ),
    );
  }
}
