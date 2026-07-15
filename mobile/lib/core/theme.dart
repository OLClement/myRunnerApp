import 'package:flutter/material.dart';

/// Palette validée (contraste + daltonisme) — voir le résumé dans le README
/// mobile si besoin de la réutiliser ailleurs (ex. graphes du dashboard).
class AppColors {
  AppColors._();

  // Marque
  static const orangeLight = Color(0xFFEB6834);
  static const orangeDark = Color(0xFFD95926);

  // Surfaces
  static const surfaceLight = Color(0xFFFCFCFB);
  static const pageLight = Color(0xFFF9F9F7);
  static const surfaceDark = Color(0xFF1A1A19);
  static const pageDark = Color(0xFF0D0D0D);

  // Encre
  static const inkPrimaryLight = Color(0xFF0B0B0B);
  static const inkSecondaryLight = Color(0xFF52514E);
  static const inkPrimaryDark = Color(0xFFFFFFFF);
  static const inkSecondaryDark = Color(0xFFC3C2B7);
  static const inkMuted = Color(0xFF898781);

  // Palette catégorielle (ordre fixe — ne jamais réordonner selon les filtres)
  static const categoricalLight = [
    Color(0xFF2A78D6), // 1 blue
    Color(0xFF1BAF7A), // 2 aqua
    Color(0xFFEDA100), // 3 yellow
    Color(0xFF008300), // 4 green
    Color(0xFF4A3AA7), // 5 violet
    Color(0xFFE34948), // 6 red
    Color(0xFFE87BA4), // 7 magenta
    orangeLight, // 8 orange
  ];

  static const categoricalDark = [
    Color(0xFF3987E5),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
    Color(0xFFD55181),
    orangeDark,
  ];

  static const statusGood = Color(0xFF0CA30C);
  static const statusWarning = Color(0xFFFAB219);
  static const statusSerious = Color(0xFFEC835A);
  static const statusCritical = Color(0xFFD03B3B);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = isDark ? AppColors.orangeDark : AppColors.orangeLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.pageDark : AppColors.pageLight,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.pageDark : AppColors.pageLight,
        foregroundColor: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: Typography.material2021().englishLike.apply(
            bodyColor: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
            displayColor: isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight,
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
      ),
    );
  }
}
