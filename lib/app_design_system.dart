import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF192B50);
  static const ink = Color(0xFF101B33);
  static const orange = Color(0xFFFF8200);
  static const page = Color(0xFFF7F9FC);
  static const muted = Color(0xFF68748A);
  static const border = Color(0xFFE2E7EF);
  static const borderSubtle = Color(0xFFE6EAF0);
  static const softOrange = Color(0xFFFFE8D2);
  static const softOrangeAlt = Color(0xFFFFF1E4);
  static const softStatus = Color(0xFFFFF1E3);
  static const softSurface = Color(0xFFEFF2F7);
  static const chipSurface = Color(0xFFF3F5F8);
  static const disabledSurface = Color(0xFFEFF2F5);
  static const error = Color(0xFFB42318);
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

abstract final class AppRadii {
  static const control = 12.0;
  static const button = 12.0;
  static const merchantCard = 16.0;
  static const marketplaceCard = 18.0;
  static const dialog = 14.0;
}

abstract final class AppTypography {
  static const filterTitle = TextStyle(
    color: AppColors.ink,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );
  static const pageTitle = TextStyle(
    color: AppColors.ink,
    fontSize: 20,
    fontWeight: FontWeight.w800,
  );
  static const sectionTitle = TextStyle(
    color: AppColors.ink,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );
  static const body = TextStyle(
    color: AppColors.ink,
    fontSize: 14,
    height: 1.4,
  );
  static const supporting = TextStyle(
    color: AppColors.muted,
    fontSize: 13,
    height: 1.35,
  );
  static const label = TextStyle(
    color: AppColors.ink,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
  static const overline = TextStyle(
    color: AppColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: .8,
  );
}
