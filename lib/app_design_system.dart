import 'package:flutter/material.dart';

import 'app_preferences.dart';

abstract final class AppColors {
  static const navy = Color(0xFF192B50);
  static const lightInk = Color(0xFF101B33);
  static const darkInk = Color(0xFFF2F4F8);
  static Color get ink => AppPreferences.instance.darkMode ? darkInk : lightInk;
  static const orange = Color(0xFFFF8200);
  static Color get accent => AppPreferences.instance.palette.color;
  static const lightPage = Color(0xFFF7F9FC);
  static const darkPage = Color(0xFF101116);
  static Color get page =>
      AppPreferences.instance.darkMode ? darkPage : lightPage;
  static const darkSurface = Color(0xFF191B22);
  static Color get surface =>
      AppPreferences.instance.darkMode ? darkSurface : Colors.white;
  static const lightMuted = Color(0xFF68748A);
  static const darkMuted = Color(0xFFA6ADBB);
  static Color get muted =>
      AppPreferences.instance.darkMode ? darkMuted : lightMuted;
  static const lightBorder = Color(0xFFE2E7EF);
  static const darkBorder = Color(0xFF343740);
  static Color get border =>
      AppPreferences.instance.darkMode ? darkBorder : lightBorder;
  static const lightBorderSubtle = Color(0xFFE6EAF0);
  static Color get borderSubtle =>
      AppPreferences.instance.darkMode ? darkBorder : lightBorderSubtle;
  static Color get softOrange => accent.withValues(
    alpha: AppPreferences.instance.darkMode ? .28 : .14,
  );
  static Color get softOrangeAlt => accent.withValues(
    alpha: AppPreferences.instance.darkMode ? .2 : .09,
  );
  static const darkSoftOrangeAlt = Color(0xFF33271D);
  static const lightSoftStatus = Color(0xFFFFF1E3);
  static Color get softStatus =>
      AppPreferences.instance.darkMode ? darkSoftOrangeAlt : lightSoftStatus;
  static const lightSoftSurface = Color(0xFFEFF2F7);
  static const darkSoftSurface = Color(0xFF24262E);
  static Color get softSurface =>
      AppPreferences.instance.darkMode ? darkSoftSurface : lightSoftSurface;
  static const lightChipSurface = Color(0xFFF3F5F8);
  static const darkChipSurface = Color(0xFF292B34);
  static Color get chipSurface =>
      AppPreferences.instance.darkMode ? darkChipSurface : lightChipSurface;
  static const lightDisabledSurface = Color(0xFFEFF2F5);
  static const darkDisabledSurface = Color(0xFF30323A);
  static Color get disabledSurface => AppPreferences.instance.darkMode
      ? darkDisabledSurface
      : lightDisabledSurface;
  static const darkSurfaceVariant = Color(0xFF24262E);
  static Color get surfaceVariant => AppPreferences.instance.darkMode
      ? darkSurfaceVariant
      : const Color(0xFFF1F3F7);
  static const error = Color(0xFFB42318);
  static const darkError = Color(0xFFFF7777);
  static Color get errorText =>
      AppPreferences.instance.darkMode ? darkError : error;
  static const lightSuccess = Color(0xFF168B69);
  static const darkSuccess = Color(0xFF65D6A5);
  static Color get success =>
      AppPreferences.instance.darkMode ? darkSuccess : lightSuccess;
  static const lightSuccessSurface = Color(0xFFE9FBF2);
  static const darkSuccessSurface = Color(0xFF18392F);
  static Color get successSurface => AppPreferences.instance.darkMode
      ? darkSuccessSurface
      : lightSuccessSurface;
  static const lightWarning = Color(0xFF8A4C00);
  static const darkWarning = Color(0xFFFFBD69);
  static Color get warning =>
      AppPreferences.instance.darkMode ? darkWarning : lightWarning;
}

abstract final class AppGradients {
  static const imageBottomFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x12000000), Color(0x26000000)],
    stops: [0, .58, 1],
  );

  static const navyHeroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x94192B50),
      Color(0xB3192B50),
      Color(0xD1192B50),
      Color(0xF0192B50),
    ],
    stops: [0, .32, .7, 1],
  );

  static const navyImageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x33192B50),
      Color(0x99192B50),
      Color(0xEB192B50),
    ],
    stops: [0, .36, .74, 1],
  );

  static const authBackdropOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x150A1730),
      Color(0x280A1730),
      Color(0x500A1730),
      Color(0x800A1730),
      Color(0xB30A1730),
    ],
    stops: [0, .28, .55, .8, 1],
  );

  static const navyBrand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF192B50),
      Color(0xFF21365D),
      Color(0xFF29426A),
      Color(0xFF304B7A),
    ],
    stops: [0, .34, .68, 1],
  );

  static const _lightWarmSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFFBF9F5),
      Color(0xFFFDF8F1),
      Color(0xFFFFF7ED),
    ],
    stops: [0, .34, .68, 1],
  );

  static const _darkWarmSurface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF191B22),
      Color(0xFF1D1F27),
      Color(0xFF20222A),
      Color(0xFF24262E),
    ],
    stops: [0, .34, .68, 1],
  );

  static LinearGradient get warmSurface =>
      AppPreferences.instance.darkMode ? _darkWarmSurface : _lightWarmSurface;

  static const horizontalEdgeShade = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Colors.transparent,
      Color(0x10000000),
      Color(0x10000000),
      Colors.transparent,
    ],
    stops: [0, .35, .65, 1],
  );
}

abstract final class AppSpacing {
  static const xSmall = 4.0;
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const panelInset = 20.0;
  static const xLarge = 24.0;
  static const xxLarge = 32.0;
}

abstract final class AppResponsive {
  static const compactPhone = 360.0;
  static const narrowPhone = 320.0;
  static const singleColumn = 380.0;

  static bool isCompact(double width) => width < compactPhone;

  static double pageInset(double width) => isCompact(width) ? 12 : 20;
}

abstract final class AppRadii {
  static const control = 12.0;
  static const button = 12.0;
  static const merchantCard = 16.0;
  static const marketplaceCard = 18.0;
  static const dialog = 14.0;
}

abstract final class AppTypography {
  static TextStyle get filterTitle => TextStyle(
    color: AppColors.ink,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );
  static TextStyle get pageTitle => TextStyle(
    color: AppColors.ink,
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );
  static TextStyle get sectionTitle => TextStyle(
    color: AppColors.ink,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );
  static TextStyle get body =>
      TextStyle(color: AppColors.ink, fontSize: 14, height: 1.4);
  static TextStyle get supporting =>
      TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35);
  static TextStyle get label => TextStyle(
    color: AppColors.ink,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
  static TextStyle get overline => TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: .8,
  );
}
