import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';
import 'core/business_type.dart';

double venueFilterPrice(Map<String, dynamic> post) =>
    double.tryParse(
      '${post['pricePerHour'] ?? post['price_per_hour'] ?? post['eventFee'] ?? post['event_fee'] ?? 0}',
    ) ??
    0;

double venueFilterPriceMaximum(Iterable<Map<String, dynamic>> posts) {
  var maximum = 700.0;
  for (final post in posts) {
    final price = venueFilterPrice(post);
    if (price > maximum) maximum = price;
  }
  return (maximum / 100).ceil() * 100.0;
}

List<String> venueFilterCategories(Map<String, dynamic> post) {
  final eventTypes = post['eventTypes'];
  if (BusinessTypeParser.parse(post['businessType']) == BusinessType.event &&
      eventTypes is List) {
    final categories = eventTypes
        .map((value) => '$value'.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (categories.isNotEmpty) return categories;
  }

  final category = '${post['category'] ?? ''}'.trim();
  return category.isEmpty ? const [] : [category];
}

const filterPanelTransitionDuration = Duration(milliseconds: 300);
const filterPanelMaxWidth = 440.0;
const filterPanelWidthFactor = .9;
const filterPanelSectionSpacing = 6.0;

const filterPanelHeaderPadding = EdgeInsets.fromLTRB(
  AppSpacing.panelInset,
  14,
  AppSpacing.medium,
  AppSpacing.small,
);
const filterPanelContentPadding = EdgeInsets.fromLTRB(
  AppSpacing.panelInset,
  AppSpacing.large,
  AppSpacing.panelInset,
  AppSpacing.xLarge,
);
const filterPanelFooterPadding = EdgeInsets.fromLTRB(
  AppSpacing.panelInset,
  AppSpacing.small,
  AppSpacing.panelInset,
  14,
);
TextStyle get filterPanelTitleStyle => AppTypography.filterTitle;
TextStyle get filterPanelSectionLabelStyle => TextStyle(
  color: AppColors.muted,
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 1,
);
final filterPanelButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(48, 48)),
  fixedSize: WidgetStatePropertyAll(Size(48, 48)),
  padding: WidgetStatePropertyAll(AppSpacing.buttonPadding),
  shape: WidgetStatePropertyAll(CircleBorder()),
  backgroundColor: WidgetStatePropertyAll(AppColors.page),
  foregroundColor: WidgetStatePropertyAll(AppColors.ink),
);
ButtonStyle filterPanelApplyButtonStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(colors.secondary),
    foregroundColor: WidgetStatePropertyAll(colors.onSecondary),
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
  );
}

double filterPanelWidth(BuildContext context) => math.min(
  MediaQuery.sizeOf(context).width * filterPanelWidthFactor,
  filterPanelMaxWidth,
);

class FilterPanelButton extends StatelessWidget {
  const FilterPanelButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: activeCount == 0
        ? 'Filter venues'
        : 'Filter venues ($activeCount active)',
    onPressed: onPressed,
    style: filterPanelButtonStyle,
    icon: Badge(
      isLabelVisible: activeCount > 0,
      label: AppText('$activeCount', localize: true),
      child: const Icon(Icons.tune_rounded),
    ),
  );
}
