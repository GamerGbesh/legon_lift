// Owner: WS4. Shared widget; constructor frozen (SPEC 12.3). Behaviour: SPEC 11.4.
import 'package:material_ui/material_ui.dart';

import '../app/theme/tokens.dart';

/// Two-frame exercise animation: the second photo fades in and out over the first on a 2.4 s
/// loop, with a gentle 1.00 -> 1.02 zoom while it is visible.
///
/// - Two neutral dots show which frame is up (never labelled "start" / "end").
/// - Tap pauses on the frame that is showing; each further tap flips to the other frame; the play
///   button resumes the loop.
/// - With reduced motion (`MediaQuery.disableAnimationsOf`) both frames are shown side by side.
/// - The loop stops while the widget is under a disabled [TickerMode] (rest sheet, background tab).
/// - Photos sit on the light `imageCard` colour with `BoxFit.contain`, radius 16.
///
/// Callers show `PlaceholderFigure` for exercises without photos; with no [assetPaths] this widget
/// only shows a neutral icon.
class FrameAnimator extends StatefulWidget {
  const FrameAnimator({super.key, required this.assetPaths, this.aspectRatio = 1.6, this.large = false});

  /// Asset keys (usually 2). The first two are used.
  final List<String> assetPaths;

  /// Width / height of the image card (16:10 by default).
  final double aspectRatio;

  /// Larger dots and padding (exercise detail, player).
  final bool large;

  /// Frame 1 opacity over one loop: hidden 700 ms, fade in 500 ms, shown 700 ms, fade out 500 ms.
  static final Animatable<double> frameOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0), weight: 700),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 500),
    TweenSequenceItem(tween: ConstantTween(1), weight: 700),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 500),
  ]);

  /// Decodes the photos ahead of time (call for the current and the next exercise).
  static Future<void> precache(BuildContext context, List<String> assetPaths) async {
    for (final path in assetPaths.take(2)) {
      await precacheImage(AssetImage(path), context, onError: (_, _) {});
    }
  }

  @override
  State<FrameAnimator> createState() => _FrameAnimatorState();
}

class _FrameAnimatorState extends State<FrameAnimator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.frameLoop);
  late final Animation<double> _opacity = FrameAnimator.frameOpacity.animate(_controller);
  late final Animation<double> _scale = _opacity.drive(Tween(begin: 1.0, end: 1.02));

  /// Paused by the user; the loop resumes only when they tap play.
  bool _paused = false;

  /// While paused: which frame is shown (0 or 1).
  int _manualFrame = 0;

  bool get _hasTwo => widget.assetPaths.length > 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final path in widget.assetPaths.take(2)) {
      precacheImage(AssetImage(path), context, onError: (_, _) {});
    }
    _syncRunning();
  }

  @override
  void didUpdateWidget(FrameAnimator old) {
    super.didUpdateWidget(old);
    if (old.assetPaths.join('|') != widget.assetPaths.join('|')) {
      _paused = false;
      _manualFrame = 0;
      _controller.value = 0;
    }
    _syncRunning();
  }

  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  void _syncRunning() {
    final run = _hasTwo && !_paused && !_reducedMotion;
    if (run && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!run && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _onTap() {
    if (!_hasTwo) return;
    setState(() {
      if (_paused) {
        _manualFrame = 1 - _manualFrame;
      } else {
        _paused = true;
        _manualFrame = _opacity.value >= 0.5 ? 1 : 0;
      }
      _controller.value = _manualFrame == 1 ? _frameShownValue : 0;
    });
    _syncRunning();
  }

  void _resume() {
    setState(() => _paused = false);
    _syncRunning();
  }

  /// Controller value at which frame 1 is fully shown (middle of the 700 ms hold).
  static const double _frameShownValue = (700 + 500 + 350) / 2400;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _image(String path) => Image.asset(
        path,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => Icon(Icons.image_not_supported_outlined, color: context.tokens.muted),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final paths = widget.assetPaths;
    final pad = widget.large ? Space.m : Space.s;

    Widget card(Widget child, {double? aspect}) => AspectRatio(
          aspectRatio: aspect ?? widget.aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(color: t.imageCard, borderRadius: BorderRadius.circular(Radii.imageCard)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.imageCard),
              child: Padding(padding: EdgeInsets.all(pad), child: child),
            ),
          ),
        );

    if (paths.isEmpty) {
      return card(Center(child: Icon(Icons.image_not_supported_outlined, color: t.muted, size: 40)));
    }
    if (!_hasTwo) return Semantics(image: true, label: 'Exercise photo', child: card(_image(paths.first)));

    if (_reducedMotion) {
      return Semantics(
        image: true,
        label: 'Exercise photos, two positions',
        child: card(
          Row(
            children: [
              Expanded(child: _image(paths[0])),
              SizedBox(width: pad),
              Expanded(child: _image(paths[1])),
            ],
          ),
        ),
      );
    }

    final dotSize = widget.large ? 10.0 : 8.0;
    return Semantics(
      image: true,
      label: _paused ? 'Exercise photos, paused. Tap to switch position.' : 'Exercise animation. Tap to pause.',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: card(
          Stack(
            fit: StackFit.expand,
            children: [
              _image(paths[0]),
              FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(scale: _scale, child: _image(paths[1])),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _opacity,
                  builder: (context, _) {
                    final second = _opacity.value;
                    Widget dot(double on) => Container(
                          width: dotSize,
                          height: dotSize,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(const Color(0x33000000), const Color(0xB3000000), on),
                          ),
                        );
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [dot(1 - second), dot(second)],
                    );
                  },
                ),
              ),
              if (_paused)
                Positioned(
                  right: 0,
                  top: 0,
                  child: SizedBox.square(
                    dimension: Sizes.minTap,
                    child: IconButton(
                      tooltip: 'Play',
                      onPressed: _resume,
                      style: IconButton.styleFrom(backgroundColor: const Color(0x99000000)),
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
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
