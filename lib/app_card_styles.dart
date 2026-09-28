import 'package:flutter/material.dart';

abstract final class AppCardStyles {
  static const borderColor = Color(0xFFE2E7EF);
  static const marketplaceRadius = 18.0;
  static const merchantRadius = 16.0;
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
