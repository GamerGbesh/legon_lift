// Owner: WS4. ThemeData builders wired to the design tokens (SPEC 11).
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class AppTheme {
  /// Theme for one palette; [tokens] is also registered as a ThemeExtension (`context.tokens`).
  ///
  /// Gym-floor rules (SPEC 4.1, 11.2): 56 dp minimum tap targets, flat cards with a 1 px border,
  /// sheets with a 24 dp top radius, high-contrast text, tabular figures for numbers.
  static ThemeData build(ColorTokens tokens, {Brightness brightness = Brightness.dark}) {
    final t = tokens;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: Color.alphaBlend(t.primary.withValues(alpha: 0.18), t.surface),
      onPrimaryContainer: t.onSurface,
      secondary: t.secondary,
      onSecondary: t.bg,
      secondaryContainer: Color.alphaBlend(t.primary.withValues(alpha: 0.18), t.surface2),
      onSecondaryContainer: t.onSurface,
      tertiary: t.success,
      onTertiary: t.bg,
      error: t.danger,
      onError: t.bg,
      surface: t.surface,
      onSurface: t.onSurface,
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surface2,
      surfaceContainerHighest: t.surface2,
      onSurfaceVariant: t.muted,
      outline: t.muted,
      outlineVariant: t.surface2,
      inverseSurface: t.onSurface,
      onInverseSurface: t.bg,
      shadow: Colors.black,
      scrim: Colors.black,
    );
    final text = const TextTheme(
      displayLarge: AppText.displayTimer,
      displayMedium: AppText.displayStat,
      displaySmall: AppText.value,
      headlineLarge: AppText.headline,
      headlineMedium: AppText.headline,
      headlineSmall: AppText.headline,
      titleLarge: AppText.title,
      titleMedium: AppText.bodyStrong,
      titleSmall: AppText.label,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelLarge: AppText.label,
      labelMedium: AppText.label,
      labelSmall: AppText.caption,
    ).apply(bodyColor: t.onSurface, displayColor: t.onSurface);

    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
    );
    const buttonMin = WidgetStatePropertyAll(Size(Sizes.minTap, Sizes.minTap));
    const buttonText = WidgetStatePropertyAll(AppText.button);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      fontFamily: AppFonts.inter,
      textTheme: text,
      extensions: [t],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: t.surface2, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.onSurface, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        foregroundColor: t.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: Sizes.topBar,
        titleTextStyle: AppText.headline.copyWith(fontSize: 24, color: t.onSurface),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: t.surface2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: t.muted,
        dragHandleSize: const Size(32, 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
        titleTextStyle: AppText.title.copyWith(color: t.onSurface),
        contentTextStyle: AppText.body.copyWith(color: t.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.primary.withValues(alpha: 0.20),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? t.primary : t.muted, size: 26),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.label.copyWith(
            color: s.contains(WidgetState.selected) ? t.onSurface : t.muted,
            fontVariations: [FontVariation.weight(s.contains(WidgetState.selected) ? 600 : 500)],
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMin,
          shape: buttonShape,
          textStyle: buttonText,
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? t.surface2 : t.primary),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? t.muted : t.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMin,
          shape: buttonShape,
          textStyle: buttonText,
          foregroundColor: WidgetStatePropertyAll(t.onSurface),
          side: WidgetStateProperty.resolveWith(
            (s) => BorderSide(color: s.contains(WidgetState.disabled) ? t.surface2 : t.muted),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMin,
          shape: buttonShape,
          textStyle: WidgetStatePropertyAll(AppText.label.copyWith(fontSize: 16)),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? t.muted : t.primary),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMin,
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? t.surface2 : null),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: buttonMin,
          textStyle: WidgetStatePropertyAll(AppText.label.copyWith(fontSize: 15)),
          side: WidgetStatePropertyAll(BorderSide(color: t.surface2)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.primary.withValues(alpha: 0.18) : t.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.onSurface : t.muted,
          ),
          iconColor: WidgetStatePropertyAll(t.primary),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.primary.withValues(alpha: 0.20),
        disabledColor: t.surface2,
        checkmarkColor: t.primary,
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? t.primary : t.surface2),
        ),
        labelStyle: AppText.label.copyWith(color: t.onSurface),
        secondaryLabelStyle: AppText.label.copyWith(color: t.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.onPrimary : t.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.surface2),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.muted,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : null),
        checkColor: WidgetStatePropertyAll(t.onPrimary),
        side: BorderSide(color: t.muted, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? t.primary : t.muted),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.primary,
        inactiveTrackColor: t.surface2,
        thumbColor: t.primary,
        overlayColor: t.primary.withValues(alpha: 0.16),
        valueIndicatorColor: t.surface2,
        valueIndicatorTextStyle: AppText.label.copyWith(color: t.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: Sizes.minTap,
        iconColor: t.muted,
        textColor: t.onSurface,
        titleTextStyle: AppText.body.copyWith(color: t.onSurface),
        subtitleTextStyle: AppText.label.copyWith(color: t.muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface2,
        labelStyle: AppText.body.copyWith(color: t.muted),
        hintStyle: AppText.body.copyWith(color: t.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.l),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.button),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.surface2,
        circularTrackColor: t.surface2,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.surface,
        dialBackgroundColor: t.surface2,
        hourMinuteColor: t.surface2,
        dayPeriodColor: t.primary.withValues(alpha: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surface2,
        contentTextStyle: AppText.body.copyWith(color: t.onSurface),
        actionTextColor: t.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.label.copyWith(color: t.onSurface),
      ),
    );
  }
}
