import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_design_system.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      error: AppColors.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.page,
    useMaterial3: true,
    textTheme: GoogleFonts.montserratTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTypography.pageTitle,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: const Color(0x1A192B50),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(AppRadii.marketplaceCard),
        ),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.chipSurface,
      selectedColor: AppColors.softOrange,
      disabledColor: AppColors.disabledSurface,
      side: BorderSide(color: AppColors.border),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: TextStyle(
        color: AppColors.navy,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 46),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        minimumSize: const Size(0, 46),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Color(0x14000000),
      elevation: 2,
      height: 72,
      indicatorColor: AppColors.softOrange,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorColor: AppColors.orange,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColors.navy,
      unselectedLabelColor: AppColors.muted,
      labelStyle: TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.orange,
      linearTrackColor: AppColors.softOrange,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
  );
}
