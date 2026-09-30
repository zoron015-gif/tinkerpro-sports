import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_theme.dart';

void main() {
  test('semantic colors and spacing use the shared design tokens', () {
    expect(AppColors.navy, const Color(0xFF192B50));
    expect(AppColors.ink, const Color(0xFF101B33));
    expect(AppColors.orange, const Color(0xFFFF8200));
    expect(AppColors.page, const Color(0xFFF7F9FC));
    expect(AppSpacing.large, 16);
    expect(AppRadii.marketplaceCard, 18);
  });

  test('light theme applies shared tokens to core controls', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.navy);
    expect(theme.colorScheme.secondary, AppColors.orange);
    expect(theme.scaffoldBackgroundColor, AppColors.page);
    expect(
      theme.inputDecorationTheme.focusedBorder!.borderSide.color,
      AppColors.navy,
    );
    expect(
      theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
      AppColors.orange,
    );
    expect(theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height, 46);
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.cardTheme.elevation, 2);
  });
}
