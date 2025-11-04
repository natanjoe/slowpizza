import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

ThemeData buildTheme() {
  return ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textSecondary,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textSecondary,
        textStyle: AppTextStyles.button,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textTheme: const TextTheme(
      // substituindo os nomes antigos pelos novos
      headlineSmall: AppTextStyles.heading,
      titleMedium: AppTextStyles.subheading,
      bodyMedium: AppTextStyles.body,
    ),
  );
}
