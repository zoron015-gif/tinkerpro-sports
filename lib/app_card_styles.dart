import 'package:flutter/material.dart';

import 'app_design_system.dart';

abstract final class AppCardStyles {
  static Color get borderColor => AppColors.border;
  static const marketplaceRadius = AppRadii.marketplaceCard;
  static const merchantRadius = AppRadii.merchantCard;
  static const marketplaceImageAspectRatio = 16 / 10;
  static const merchantImageHeight = 150.0;
  static const elevation = 0.0;

  static List<BoxShadow> get raisedShadows => const [];

  static List<BoxShadow> get insetShadows => const [];

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
        Border.all(color: AppColors.border),
  );

  static RoundedRectangleBorder get marketplaceShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(marketplaceRadius)),
    side: BorderSide(color: borderColor),
  );

  static RoundedRectangleBorder get merchantShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(merchantRadius)),
    side: BorderSide(color: borderColor),
  );
}
