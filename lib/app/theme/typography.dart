// Owner: WS4. Text styles (SPEC 11.3). Numbers always use tabular figures.
import 'package:material_ui/material_ui.dart';

abstract final class AppFonts {
  /// Barlow Semi Condensed (600, 700): numbers, timers and screen titles.
  static const String barlow = 'BarlowSemiCondensed';

  /// Inter variable font: body text; weights are set with [FontVariation.weight].
  static const String inter = 'Inter';
}

/// The type scale of SPEC 11.3 plus a few derived styles. Colours are applied by the theme or
/// at the call site (`AppText.body.copyWith(color: context.tokens.muted)`).
abstract final class AppText {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Rest countdown, 96 sp.
  static const TextStyle displayTimer =
      TextStyle(fontFamily: AppFonts.barlow, fontSize: 96, fontWeight: FontWeight.w700, fontFeatures: _tabular, height: 1);

  /// Summary tiles, 56 sp.
  static const TextStyle displayStat = TextStyle(
      fontFamily: AppFonts.barlow, fontSize: 56, fontWeight: FontWeight.w700, fontFeatures: _tabular, height: 1.05);

  /// Stepper values, 40 sp.
  static const TextStyle value =
      TextStyle(fontFamily: AppFonts.barlow, fontSize: 40, fontWeight: FontWeight.w600, fontFeatures: _tabular, height: 1.1);

  /// Screen titles, 28 sp.
  static const TextStyle headline =
      TextStyle(fontFamily: AppFonts.barlow, fontSize: 28, fontWeight: FontWeight.w700, fontFeatures: _tabular, height: 1.15);

  /// Exercise names (24 in the player), 22 sp.
  static const TextStyle title = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation.weight(600)],
      height: 1.25);

  /// Body text, 16 sp.
  static const TextStyle body = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontVariations: [FontVariation.weight(400)],
      height: 1.4);

  /// Body text, 16 sp semi-bold (list titles, card titles).
  static const TextStyle bodyStrong = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation.weight(600)],
      height: 1.35);

  /// Chips and small buttons, 14 sp.
  static const TextStyle label = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontVariations: [FontVariation.weight(500)],
      height: 1.3);

  /// Captions, 12 sp (never inside the player; player minimum is 14).
  static const TextStyle caption = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontVariations: [FontVariation.weight(400)],
      height: 1.3);

  /// Primary button text, 18 sp semi-bold (SPEC 11.2).
  static const TextStyle button = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation.weight(600)],
      height: 1.2);

  /// Small all-caps section kicker ("NEXT WORKOUT"), 13 sp with letter spacing.
  static const TextStyle overline = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation.weight(600)],
      letterSpacing: 1.2,
      height: 1.2);

  /// Inter body text with tabular figures (lists of numbers).
  static TextStyle tabular(TextStyle s) => s.copyWith(fontFeatures: _tabular);
}
