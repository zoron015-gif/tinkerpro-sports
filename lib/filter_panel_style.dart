import 'dart:math' as math;

import 'package:flutter/material.dart';

const filterPanelTransitionDuration = Duration(milliseconds: 300);
const filterPanelMaxWidth = 440.0;
const filterPanelWidthFactor = .9;
const filterPanelSectionSpacing = 16.0;

const filterPanelHeaderPadding = EdgeInsets.fromLTRB(20, 14, 12, 8);
const filterPanelContentPadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
const filterPanelFooterPadding = EdgeInsets.fromLTRB(20, 8, 20, 14);
const filterPanelTitleStyle = TextStyle(
  color: Color(0xFF101B33),
  fontSize: 20,
  fontWeight: FontWeight.w900,
);
const filterPanelSectionLabelStyle = TextStyle(
  color: Color(0xFF68748A),
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 1,
);
const filterPanelButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(48, 48)),
  fixedSize: WidgetStatePropertyAll(Size(48, 48)),
  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
  shape: WidgetStatePropertyAll(CircleBorder()),
  backgroundColor: WidgetStatePropertyAll(Color(0xFFF7F9FC)),
  foregroundColor: WidgetStatePropertyAll(Color(0xFF101B33)),
);
const filterPanelApplyButtonStyle = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(Color(0xFF101B33)),
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
      label: Text('$activeCount'),
      child: const Icon(Icons.tune_rounded),
    ),
  );
}
