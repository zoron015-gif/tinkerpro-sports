import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_design_system.dart';
import 'app_preferences.dart';

const filterPanelTransitionDuration = Duration(milliseconds: 300);
const filterPanelMaxWidth = 440.0;
const filterPanelWidthFactor = .9;
const filterPanelSectionSpacing = 16.0;

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
  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
  shape: WidgetStatePropertyAll(CircleBorder()),
  backgroundColor: WidgetStatePropertyAll(AppColors.page),
  foregroundColor: WidgetStatePropertyAll(AppColors.ink),
);
final filterPanelApplyButtonStyle = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(AppColors.ink),
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(50)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
  ),
);

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
