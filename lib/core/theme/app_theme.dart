import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static const fontFamily = 'Open Sans';
  static final ThemeData light = _light();

  static ThemeData _light() {
    // The theme initializes once; load the bundled license only when requested.
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'Open Sans',
      ], await rootBundle.loadString('assets/fonts/open_sans/OFL.txt'));
    });
    const colors = ColorScheme.light(
      primary: AppColors.brandBlue,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.brandMist,
      onPrimaryContainer: AppColors.brandMidnight,
      secondary: AppColors.brandNavy,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.brandMist,
      onSecondaryContainer: AppColors.brandNavy,
      tertiary: AppColors.brandPurple,
      onTertiary: AppColors.ink,
      tertiaryContainer: AppColors.brandMist,
      onTertiaryContainer: AppColors.brandMidnight,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.brandMist,
      surfaceContainer: AppColors.brandMist,
      surfaceContainerHigh: AppColors.brandMist,
      surfaceContainerHighest: AppColors.brandMist,
      onSurfaceVariant: AppColors.brandNavy,
      outline: AppColors.outline,
      outlineVariant: AppColors.brandMist,
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
          displaySmall: const TextStyle(
            fontSize: 36,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: const TextStyle(
            fontSize: 32,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          bodySmall: const TextStyle(fontSize: 12, height: 1.5),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          fontFamily: fontFamily,
          bodyColor: AppColors.ink,
          displayColor: AppColors.brandMidnight,
        );
    const field = OutlineInputBorder(
      borderRadius: AppShape.field,
      borderSide: BorderSide(color: AppColors.outline),
    );
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppLayout.minTouchTarget, AppLayout.minTouchTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppShape.field),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: AppColors.brandMist,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: AppColors.brandMidnight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(
          color: AppColors.brandMidnight,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(borderRadius: AppShape.card),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: button),
      elevatedButtonTheme: ElevatedButtonThemeData(style: button),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: field,
        enabledBorder: field,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShape.field,
          borderSide: BorderSide(color: AppColors.brandBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppShape.field,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppShape.field,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: EdgeInsets.all(AppSpacing.lg),
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
        shape: RoundedRectangleBorder(borderRadius: AppShape.card),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brandMidnight,
        contentTextStyle: TextStyle(
          color: AppColors.white,
          fontFamily: fontFamily,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandBlue,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 0.5,
        space: AppSpacing.xl,
      ),
    );
  }
}
