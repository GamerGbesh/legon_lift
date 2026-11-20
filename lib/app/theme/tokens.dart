// Owner: WS4. Design tokens (SPEC 11.1, 11.2). Palette values are exact; do not tweak casually.
import 'package:material_ui/material_ui.dart';

import '../../data/models/enums.dart';

/// Colour roles of one palette. Registered as a [ThemeExtension]; read with `context.tokens`.
@immutable
class ColorTokens extends ThemeExtension<ColorTokens> {
  const ColorTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.onSurface,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.warmup,
    required this.imageCard,
  });

  final Color bg, surface, surface2, onSurface, muted, primary, onPrimary, secondary, success, warning, danger, warmup,
      imageCard;

  @override
  ColorTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? onSurface,
    Color? muted,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? warmup,
    Color? imageCard,
  }) =>
      ColorTokens(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surface2: surface2 ?? this.surface2,
        onSurface: onSurface ?? this.onSurface,
        muted: muted ?? this.muted,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        secondary: secondary ?? this.secondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        warmup: warmup ?? this.warmup,
        imageCard: imageCard ?? this.imageCard,
      );

  @override
  ColorTokens lerp(ThemeExtension<ColorTokens>? other, double t) {
    if (other is! ColorTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ColorTokens(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      onSurface: l(onSurface, other.onSurface),
      muted: l(muted, other.muted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      secondary: l(secondary, other.secondary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      warmup: l(warmup, other.warmup),
      imageCard: l(imageCard, other.imageCard),
    );
  }

  /// The dark palette for [id].
  static ColorTokens dark(PaletteId id) => switch (id) {
        PaletteId.legonNight => legonNight,
        PaletteId.kenteEnergy => kenteEnergy,
        PaletteId.voltTeal => voltTeal,
      };

  /// The light variant for [id] (secondary priority, SPEC 11.1).
  static ColorTokens light(PaletteId id) => switch (id) {
        PaletteId.legonNight => legonNightLight,
        PaletteId.kenteEnergy => kenteEnergyLight,
        PaletteId.voltTeal => voltTealLight,
      };
}

/// DEFAULT palette.
const legonNight = ColorTokens(
  bg: Color(0xFF0B0F14), surface: Color(0xFF151B23), surface2: Color(0xFF1E2630),
  onSurface: Color(0xFFF2F5F8), muted: Color(0xFF9AA7B4), primary: Color(0xFFFFC629),
  onPrimary: Color(0xFF0B0F14), secondary: Color(0xFF4C8DFF), success: Color(0xFF2ED47A),
  warning: Color(0xFFFFB020), danger: Color(0xFFFF5A5F), warmup: Color(0x999AA7B4), imageCard: Color(0xFFE9EDF1));

/// Kente `danger` is 5.0:1: use only for icons and large text.
const kenteEnergy = ColorTokens(
  bg: Color(0xFF0D0D0F), surface: Color(0xFF18181C), surface2: Color(0xFF232329),
  onSurface: Color(0xFFF5F5F0), muted: Color(0xFFA3A39A), primary: Color(0xFFF5B700),
  onPrimary: Color(0xFF0D0D0F), secondary: Color(0xFF00B37A), success: Color(0xFF00B37A),
  warning: Color(0xFFFF8A3D), danger: Color(0xFFE5484D), warmup: Color(0x99A3A39A), imageCard: Color(0xFFEDEDE8));

const voltTeal = ColorTokens(
  bg: Color(0xFF07110F), surface: Color(0xFF0F1E1B), surface2: Color(0xFF172A26),
  onSurface: Color(0xFFE8FFF9), muted: Color(0xFF8FB3AA), primary: Color(0xFF2DE1C2),
  onPrimary: Color(0xFF07110F), secondary: Color(0xFFFFB020), success: Color(0xFF7AE582),
  warning: Color(0xFFFFB020), danger: Color(0xFFFF6B6B), warmup: Color(0x998FB3AA), imageCard: Color(0xFFE6F2EF));

// Light variants: shared neutrals; primary darkened 25%; other hues darkened to >= 4.5:1 on white.
const legonNightLight = ColorTokens(
  bg: Color(0xFFF6F8FA), surface: Color(0xFFFFFFFF), surface2: Color(0xFFEEF1F4),
  onSurface: Color(0xFF0B0F14), muted: Color(0xFF4A5561), primary: Color(0xFFB88A00),
  onPrimary: Color(0xFFFFFFFF), secondary: Color(0xFF1F5BD6), success: Color(0xFF12804A),
  warning: Color(0xFFA35F00), danger: Color(0xFFC8282D), warmup: Color(0x994A5561), imageCard: Color(0xFFE9EDF1));

const kenteEnergyLight = ColorTokens(
  bg: Color(0xFFF6F8FA), surface: Color(0xFFFFFFFF), surface2: Color(0xFFEEF1F4),
  onSurface: Color(0xFF0B0F14), muted: Color(0xFF4A5561), primary: Color(0xFFB88900),
  onPrimary: Color(0xFFFFFFFF), secondary: Color(0xFF007A53), success: Color(0xFF007A53),
  warning: Color(0xFFB5500C), danger: Color(0xFFC42A30), warmup: Color(0x994A5561), imageCard: Color(0xFFEDEDE8));

const voltTealLight = ColorTokens(
  bg: Color(0xFFF6F8FA), surface: Color(0xFFFFFFFF), surface2: Color(0xFFEEF1F4),
  onSurface: Color(0xFF0B0F14), muted: Color(0xFF4A5561), primary: Color(0xFF22A992),
  onPrimary: Color(0xFF07110F), secondary: Color(0xFFA35F00), success: Color(0xFF237A2B),
  warning: Color(0xFFA35F00), danger: Color(0xFFC42B2B), warmup: Color(0x994A5561), imageCard: Color(0xFFE6F2EF));

abstract final class Space {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0;

  /// Page padding.
  static const page = 16.0;
}

abstract final class Radii {
  static const card = 16.0, sheet = 24.0, button = 14.0, chip = 12.0, imageCard = 16.0;
}

abstract final class Sizes {
  static const minTap = 56.0,
      stepper = 64.0,
      primaryButton = 72.0,
      heroButton = 64.0,
      topBar = 56.0,
      resumeBanner = 72.0,
      rirButton = 56.0;
}

abstract final class Motion {
  static const frameLoop = Duration(milliseconds: 2400), snackUndo = Duration(seconds: 5);
}

/// `context.tokens`: the active palette.
extension ColorTokensContext on BuildContext {
  ColorTokens get tokens => Theme.of(this).extension<ColorTokens>() ?? legonNight;
}
