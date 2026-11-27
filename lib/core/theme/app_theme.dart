import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the two Material 3 themes. Everything downstream reads from
/// `Theme.of(context)` — no hard-coded colours in feature widgets.
class AppTheme {
  const AppTheme._();

  // ── DARK (Safely mapped to light to ensure high quality light theme everywhere) ──
  static ThemeData dark() => light();

  // ── LIGHT ────────────────────────────────────────────────────────
  static ThemeData light() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDFE5FF),
      onPrimaryContainer: Color(0xFF16205C),
      secondary: AppColors.signalDeep,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCFF7FE),
      onSecondaryContainer: Color(0xFF04353F),
      tertiary: Color(0xFF7C5CE0),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE9E2FF),
      onTertiaryContainer: Color(0xFF241456),
      error: Color(0xFFD32F4F),
      onError: Colors.white,
      errorContainer: Color(0xFFFFE0E6),
      onErrorContainer: Color(0xFF540016),
      surface: Colors.white,
      onSurface: AppColors.textOnDayHigh,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.day1,
      surfaceContainer: AppColors.day2,
      surfaceContainerHigh: AppColors.day3,
      surfaceContainerHighest: Color(0xFFD9E1F1),
      onSurfaceVariant: AppColors.textOnDayMed,
      outline: AppColors.dayBorder,
      outlineVariant: Color(0xFFE7ECF6),
      inverseSurface: AppColors.night2,
      onInverseSurface: AppColors.textOnNightHigh,
      inversePrimary: AppColors.brandBright,
      scrim: Color(0x99101728),
      shadow: Color(0xFF98A2B8),
    );

    return _build(
      scheme,
      AppTypography.textTheme(AppColors.textOnDayHigh, AppColors.textOnDayMed),
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ── Shared component theming ─────────────────────────────────────
  static ThemeData _build(
    ColorScheme scheme,
    TextTheme text,
    SystemUiOverlayStyle overlay,
  ) {
    final bool isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: kIsWeb ? InkRipple.splashFactory : InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: Corners.rLg,
          side: BorderSide(color: Color(0xFFF1F5F9), width: 0.8),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
          textStyle: text.labelLarge?.copyWith(fontSize: 15.5),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
          textStyle: text.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: const RoundedRectangleBorder(borderRadius: Corners.rSm),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainer
            : scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        hintStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withOpacity(0.7),
        ),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Corners.rMd,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary.withOpacity(isDark ? 0.22 : 0.14),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium!,
        secondaryLabelStyle: text.labelMedium!,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 8),
        shape: const RoundedRectangleBorder(borderRadius: Corners.rPill),
        showCheckmark: false,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(borderRadius: Corners.sheet),
        clipBehavior: Clip.antiAlias,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Corners.rXl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
        insetPadding: const EdgeInsets.all(Gap.lg),
        elevation: 0,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(isDark ? 0.20 : 0.12),
        indicatorShape:
            const RoundedRectangleBorder(borderRadius: Corners.rPill),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? text.labelSmall!.copyWith(
                  color: scheme.primary,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w700,
                )
              : text.labelSmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w500,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => IconThemeData(
            size: 23,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderRadius: Corners.rPill,
          borderSide: BorderSide(color: scheme.primary, width: 3),
          insets: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurfaceVariant,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor:
            WidgetStateProperty.all(scheme.outline.withOpacity(0.6)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withOpacity(0.12),
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: Corners.rXs,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(text.labelMedium),
          side: WidgetStateProperty.all(BorderSide(color: scheme.outline)),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(borderRadius: Corners.rSm),
          ),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: const RoundedRectangleBorder(borderRadius: Corners.rMd),
        textStyle: text.bodyMedium,
      ),
    );
  }
}
