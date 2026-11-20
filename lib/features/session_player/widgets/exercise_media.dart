// Owner: WS3. Exercise pictures and the tap-to-advance cue carousel used across the player.
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../data/models/models.dart';
import '../../../widgets/frame_animator.dart';
import '../../../widgets/placeholder_figure.dart';

/// The two-frame animator card (16:10), or the placeholder figure when there are no pictures.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({super.key, required this.exercise, this.large = false});

  final Exercise exercise;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (exercise.localImages.isEmpty) {
      return AspectRatio(aspectRatio: 1.6, child: PlaceholderFigure(exercise: exercise));
    }
    return FrameAnimator(assetPaths: exercise.localImages, large: large);
  }
}

/// One coaching cue at a time; tapping shows the next one (SPEC 4.4 "cue carousel").
class CueCarousel extends StatefulWidget {
  const CueCarousel({super.key, required this.cues});

  final List<String> cues;

  @override
  State<CueCarousel> createState() => _CueCarouselState();
}

class _CueCarouselState extends State<CueCarousel> {
  int _i = 0;

  @override
  void didUpdateWidget(CueCarousel old) {
    super.didUpdateWidget(old);
    if (old.cues != widget.cues) _i = 0;
  }

  @override
  Widget build(BuildContext context) {
    final cues = widget.cues;
    if (cues.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    final i = _i % cues.length;
    return Semantics(
      button: cues.length > 1,
      label: 'Coaching cue ${i + 1} of ${cues.length}',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: cues.length > 1 ? () => setState(() => _i = (i + 1) % cues.length) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: Sizes.minTap),
          padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border(left: BorderSide(color: t.primary, width: 4)),
          ),
          child: Row(
            children: [
              Icon(Icons.record_voice_over_outlined, color: t.primary),
              const SizedBox(width: Space.m),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text('"${cues[i]}"',
                      key: ValueKey(i), style: AppText.body.copyWith(color: t.onSurface, fontStyle: FontStyle.italic)),
                ),
              ),
              if (cues.length > 1) ...[
                const SizedBox(width: Space.s),
                Text('${i + 1}/${cues.length}', style: AppText.label.copyWith(color: t.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable chip-sized tool button (56 dp tall) for the exercise tools row.
class ToolButton extends StatelessWidget {
  const ToolButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(Sizes.minTap, Sizes.minTap),
        padding: const EdgeInsets.symmetric(horizontal: Space.m),
        side: BorderSide(color: t.surface2, width: 1.5),
        backgroundColor: t.surface,
        foregroundColor: t.onSurface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: t.primary),
          const SizedBox(width: Space.s),
          Text(label, style: AppText.label.copyWith(color: t.onSurface, fontSize: 15)),
        ],
      ),
    );
  }
}
