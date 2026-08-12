import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme chung: đặt sẵn màu nền, AppBar, dialog, FAB... để các trang
/// không phải hard-code màu lặp lại.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.gold,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: AppColors.surface),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.gold),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: Colors.black,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
