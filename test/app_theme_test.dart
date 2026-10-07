import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app_design_system.dart';
import 'package:myapp/app_preferences.dart';
import 'package:myapp/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configured themes keep accent foregrounds readable', () {
    for (final accent in [const Color(0xFF192B50), AppColors.orange]) {
      final darkTheme = AppTheme.configured(
        darkMode: true,
        accentColor: accent,
      );
      final foreground = AppColors.contrastingForeground(accent);
      final darkAccentForeground = Color.lerp(accent, Colors.white, .55)!;

      expect(_contrastRatio(foreground, accent), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(darkAccentForeground, AppColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        darkTheme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        foreground,
      );
      expect(darkTheme.chipTheme.checkmarkColor, foreground);
      expect(darkTheme.chipTheme.secondaryLabelStyle!.color, foreground);
      expect(
        darkTheme.colorScheme.onPrimary,
        AppColors.contrastingForeground(darkTheme.colorScheme.primary),
      );
    }
  });

  test('every palette provides readable controls in light and dark themes', () {
    for (final darkMode in [false, true]) {
      for (final palette in AppPalette.values) {
        final theme = AppTheme.configured(
          darkMode: darkMode,
          accentColor: palette.color,
        );
        final scheme = theme.colorScheme;
        final filledForeground = theme.filledButtonTheme.style!.foregroundColor!
            .resolve({});
        final outlinedForeground = theme
            .outlinedButtonTheme
            .style!
            .foregroundColor!
            .resolve({});
        final textForeground = theme.textButtonTheme.style!.foregroundColor!
            .resolve({});
        final elevatedStyle = theme.elevatedButtonTheme.style!;
        final elevatedForeground = elevatedStyle.foregroundColor!.resolve({});
        final elevatedBackground = elevatedStyle.backgroundColor!.resolve({});

        expect(
          _contrastRatio(filledForeground!, palette.color),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(outlinedForeground!, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(textForeground!, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(elevatedForeground!, elevatedBackground!),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(
            theme.snackBarTheme.contentTextStyle!.color!,
            theme.snackBarTheme.backgroundColor ?? scheme.inverseSurface,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  test('semantic colors and spacing use the shared design tokens', () {
    expect(AppColors.navy, const Color(0xFF192B50));
    expect(AppColors.ink, const Color(0xFF101B33));
    expect(AppColors.orange, const Color(0xFFFF8200));
    expect(AppColors.page, const Color(0xFFF7F9FC));
    expect(AppSpacing.large, 16);
    expect(AppRadii.marketplaceCard, 18);
    expect(
      AppSpacing.buttonPadding,
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
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
    expect(
      theme.filledButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      theme.outlinedButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      theme.textButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      theme.elevatedButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      theme.iconButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      theme.segmentedButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.cardTheme.elevation, 2);

    final configuredTheme = AppTheme.configured(
      darkMode: true,
      accentColor: AppColors.orange,
    );
    expect(
      configuredTheme.filledButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      configuredTheme.outlinedButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      configuredTheme.textButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      configuredTheme.elevatedButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      configuredTheme.iconButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
    expect(
      configuredTheme.segmentedButtonTheme.style!.padding!.resolve({}),
      AppSpacing.buttonPadding,
    );
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + .05) / (darker + .05);
}
