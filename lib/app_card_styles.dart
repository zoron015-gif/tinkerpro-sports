import 'package:flutter/material.dart';

import 'app_design_system.dart';

abstract final class AppCardStyles {
  static Color get borderColor => AppColors.border;
  static const marketplaceRadius = AppRadii.marketplaceCard;
  static const merchantRadius = AppRadii.merchantCard;
  static const marketplaceImageAspectRatio = 16 / 10;
  static const merchantImageHeight = 150.0;
  static const elevation = 3.0;

  static List<BoxShadow> get raisedShadows => [
    BoxShadow(
      color: AppColors.neumorphicShadow,
      blurRadius: 14,
      offset: const Offset(6, 6),
    ),
    BoxShadow(
      color: AppColors.neumorphicHighlight,
      blurRadius: 14,
      offset: const Offset(-6, -6),
    ),
  ];

  static List<BoxShadow> get insetShadows => [
    BoxShadow(
      color: AppColors.neumorphicShadow.withValues(alpha: .55),
      blurRadius: 7,
      offset: const Offset(3, 3),
    ),
    BoxShadow(
      color: AppColors.neumorphicHighlight.withValues(alpha: .7),
      blurRadius: 7,
      offset: const Offset(-3, -3),
    ),
  ];

  static BoxDecoration surfaceDecoration({
    Color? color,
    double radius = AppRadii.marketplaceCard,
    bool inset = false,
    Border? border,
  }) => BoxDecoration(
    color: color ?? AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border:
        border ??
        Border.all(
          color: AppColors.border.withValues(alpha: .65),
        ),
    boxShadow: inset ? insetShadows : raisedShadows,
  );

  static RoundedRectangleBorder get marketplaceShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(marketplaceRadius)),
    side: BorderSide(color: borderColor.withValues(alpha: .65)),
  );

  static RoundedRectangleBorder get merchantShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(merchantRadius)),
    side: BorderSide(color: borderColor.withValues(alpha: .65)),
  );
}
