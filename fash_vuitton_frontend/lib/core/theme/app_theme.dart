import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        primary: AppColors.blue,
        secondary: AppColors.coral,
        surface: AppColors.cream,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: AppColors.navy),
        bodyMedium: TextStyle(color: AppColors.navy),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.navy,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
