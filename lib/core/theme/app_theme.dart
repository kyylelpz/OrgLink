import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static const fontFamily = AppTypography.fontFamily;
  static final ThemeData light = _light();

  static ThemeData _light() {
    // The theme initializes once; load the bundled license only when requested.
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        fontFamily,
      ], await rootBundle.loadString('assets/fonts/inter/OFL.txt'));
    });
    const colors = ColorScheme.light(
      primary: AppColors.brandBlue,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.tonal,
      onPrimaryContainer: AppColors.brandBlue,
      secondary: AppColors.brandNavy,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.tonal,
      onSecondaryContainer: AppColors.brandBlue,
      tertiary: AppColors.brandPurple,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.purpleSurface,
      onTertiaryContainer: AppColors.brandMidnight,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.brandMist,
      surfaceContainer: AppColors.brandMist,
      surfaceContainerHigh: AppColors.brandMist,
      surfaceContainerHighest: AppColors.brandMist,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.outline,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: AppColors.white,
      errorContainer: AppColors.errorSurface,
      onErrorContainer: AppColors.error,
      shadow: AppColors.black,
      scrim: AppColors.black,
      inverseSurface: AppColors.brandMidnight,
      onInverseSurface: AppColors.white,
      inversePrimary: AppColors.brandMist,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: fontFamily,
    );
    final text = base.textTheme
        .copyWith(
          displayLarge: const TextStyle(
            letterSpacing: 0,
            fontSize: 44,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
          displayMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 36,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
          displaySmall: AppTypography.hero,
          headlineLarge: AppTypography.title,
          headlineMedium: AppTypography.title,
          headlineSmall: const TextStyle(
            letterSpacing: 0,
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: AppTypography.section,
          titleMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: AppTypography.button,
          bodyLarge: AppTypography.body,
          bodyMedium: const TextStyle(
            letterSpacing: 0,
            fontSize: 14,
            height: 1.5,
          ),
          bodySmall: AppTypography.supporting,
          labelLarge: AppTypography.button,
          labelMedium: AppTypography.label,
          labelSmall: const TextStyle(
            letterSpacing: 0,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(
          fontFamily: fontFamily,
          bodyColor: AppColors.ink,
          displayColor: AppColors.brandMidnight,
        );
    const field = OutlineInputBorder(
      borderRadius: AppShape.field,
      borderSide: BorderSide(color: AppColors.border),
    );
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppLayout.minTouchTarget, AppLayout.minTouchTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonHorizontal,
          vertical: AppSpacing.md,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppShape.button),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(
      textTheme: text,
      iconTheme: const IconThemeData(
        size: AppIconSize.standard,
        color: AppColors.brandNavy,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppLayout.minTouchTarget),
          foregroundColor: AppColors.brandBlue,
          shape: const RoundedRectangleBorder(borderRadius: AppShape.button),
        ),
      ),
      scaffoldBackgroundColor: AppColors.brandMist,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: AppColors.brandMidnight,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.surface,
        titleTextStyle: text.titleLarge?.copyWith(
          color: AppColors.brandMidnight,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.surface,
        margin: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: AppShape.card),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.border;
            // FilledButton.tonal shares this theme; keep its Material 3 tonal roles.
            return null;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? AppColors.muted : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          backgroundColor: const WidgetStatePropertyAll(AppColors.white),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(
          elevation: const WidgetStatePropertyAll(AppElevation.surface),
          backgroundColor: const WidgetStatePropertyAll(AppColors.tonal),
          foregroundColor: const WidgetStatePropertyAll(AppColors.brandBlue),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.brandBlue,
        disabledColor: AppColors.brandMist,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppShape.pill),
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.white
                : AppColors.muted,
          ),
        ),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: AppColors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.chipHorizontal,
          vertical: AppSpacing.chipVertical,
        ),
        showCheckmark: false,
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.brandMist
              : states.contains(WidgetState.selected)
              ? AppColors.brandBlue
              : AppColors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.brandMist
              : AppColors.white,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: AppColors.muted),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.muted),
        errorStyle: text.bodySmall?.copyWith(color: AppColors.error),
        border: field,
        enabledBorder: field,
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppShape.field,
          borderSide: BorderSide(color: AppColors.brandBlue, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppShape.field,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppShape.field,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        disabledBorder: field,
        errorMaxLines: 4,
        helperMaxLines: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.brandMist,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(color: AppColors.brandNavy),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: AppColors.brandNavy),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.overlay,
        shape: RoundedRectangleBorder(borderRadius: AppShape.card),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brandMidnight,
        contentTextStyle: TextStyle(
          letterSpacing: 0,
          color: AppColors.white,
          fontFamily: fontFamily,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandBlue,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: AppSpacing.xl,
      ),
    );
  }
}
