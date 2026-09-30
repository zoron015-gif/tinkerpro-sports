import 'package:flutter/material.dart';

import 'app_design_system.dart';

abstract final class AppCardStyles {
  static const borderColor = AppColors.border;
  static const marketplaceRadius = AppRadii.marketplaceCard;
  static const merchantRadius = AppRadii.merchantCard;
  static const marketplaceImageAspectRatio = 16 / 10;
  static const merchantImageHeight = 150.0;
  static const elevation = 1.0;

  static const marketplaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(marketplaceRadius)),
    side: BorderSide(color: borderColor),
  );

  static const merchantShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(merchantRadius)),
    side: BorderSide(color: borderColor),
  );
}
