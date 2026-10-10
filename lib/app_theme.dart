import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_card_styles.dart';
import 'app_design_system.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    colorScheme: ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      error: AppColors.error,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.page,
    useMaterial3: true,
    textTheme: GoogleFonts.latoTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTypography.pageTitle,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AppCardStyles.elevation,
      shadowColor: AppColors.neumorphicShadow,
      shape: AppCardStyles.marketplaceShape,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.chipSurface,
      selectedColor: AppColors.softOrange,
      disabledColor: AppColors.disabledSurface,
      side: BorderSide(color: AppColors.border),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: TextStyle(
        color: AppColors.navy,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.softSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        padding: AppSpacing.buttonPadding,
        minimumSize: const Size(0, 46),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
        padding: AppSpacing.buttonPadding,
        minimumSize: const Size(0, 46),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(padding: AppSpacing.buttonPadding),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(padding: AppSpacing.buttonPadding),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(padding: AppSpacing.buttonPadding),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(AppSpacing.buttonPadding),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      shadowColor: Color(0x14000000),
      elevation: 2,
      height: 72,
      indicatorColor: AppColors.softOrange,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: Colors.transparent,
      indicatorColor: AppColors.orange,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: AppColors.navy,
      unselectedLabelColor: AppColors.muted,
      labelStyle: TextStyle(fontWeight: FontWeight.w800),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.orange,
      linearTrackColor: AppColors.softOrange,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.orange,
      inactiveTrackColor: AppColors.border,
      thumbColor: AppColors.orange,
      overlayColor: AppColors.softOrange,
      valueIndicatorColor: AppColors.orange,
      valueIndicatorTextStyle: TextStyle(color: AppColors.onAccent),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.orange,
      selectionColor: AppColors.softOrange,
      selectionHandleColor: AppColors.orange,
    ),
    dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
  );

  static ThemeData configured({
    required bool darkMode,
    required Color accentColor,
  }) {
    final base = darkMode ? ThemeData.dark(useMaterial3: true) : light;
    final brightness = darkMode ? Brightness.dark : Brightness.light;
    final surface = darkMode ? AppColors.darkSurface : Colors.white;
    final page = darkMode ? AppColors.darkPage : AppColors.lightPage;
    final accentForeground = AppColors.accessibleForeground(
      accentColor,
      darkMode ? AppColors.darkSurfaceHighest : Colors.white,
    );
    final onAccent = AppColors.contrastingForeground(accentColor);
    final onAccentForeground = AppColors.contrastingForeground(
      accentForeground,
    );
    final primaryColor = accentForeground;
    final onPrimary = darkMode
        ? onAccentForeground
        : AppColors.contrastingForeground(primaryColor);
    final sourceScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    );
    final scheme = sourceScheme.copyWith(
      primary: primaryColor,
      onPrimary: onPrimary,
      secondary: accentColor,
      onSecondary: onAccent,
      primaryContainer: darkMode
          ? primaryColor.withValues(alpha: .28)
          : primaryColor.withValues(alpha: .12),
      onPrimaryContainer: darkMode
          ? const Color(0xFFF2F4F8)
          : AppColors.lightInk,
      secondaryContainer: darkMode
          ? accentColor.withValues(alpha: .22)
          : accentColor.withValues(alpha: .12),
      onSecondaryContainer: darkMode
          ? const Color(0xFFF2F4F8)
          : AppColors.lightInk,
      surface: surface,
      onSurface: darkMode ? AppColors.darkInk : AppColors.lightInk,
      surfaceContainerLowest: darkMode ? const Color(0xFF15171D) : Colors.white,
      surfaceContainerLow: darkMode
          ? const Color(0xFF191B22)
          : const Color(0xFFFAFBFD),
      surfaceContainer: darkMode
          ? const Color(0xFF20222A)
          : const Color(0xFFF4F6F9),
      surfaceContainerHigh: darkMode
          ? const Color(0xFF282A32)
          : const Color(0xFFEEF1F5),
      surfaceContainerHighest: darkMode
          ? AppColors.darkSurfaceHighest
          : const Color(0xFFE8ECF2),
      onSurfaceVariant: darkMode ? AppColors.darkMuted : AppColors.lightMuted,
      outline: darkMode ? AppColors.darkBorder : AppColors.lightBorder,
      outlineVariant: darkMode
          ? const Color(0xFF41444E)
          : AppColors.lightBorderSubtle,
      error: darkMode ? AppColors.darkError : AppColors.error,
      onError: Colors.white,
    );
    final textTheme = GoogleFonts.latoTextTheme(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final inputBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.control)),
      borderSide: BorderSide(color: scheme.outline),
    );

    return base.copyWith(
      colorScheme: scheme,
      primaryColor: primaryColor,
      textTheme: textTheme,
      scaffoldBackgroundColor: page,
      canvasColor: surface,
      cardColor: surface,
      disabledColor: darkMode
          ? const Color(0xFF858B98)
          : const Color(0xFF9AA3B2),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: page,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppCardStyles.elevation,
        shadowColor: AppColors.neumorphicShadow,
        shape: AppCardStyles.marketplaceShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        tileColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.dialog),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadii.dialog),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: onAccent,
          elevation: 2,
          shadowColor: AppColors.neumorphicShadow,
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, 46),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: AppSpacing.buttonPadding,
          minimumSize: const Size(0, 46),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: AppSpacing.buttonPadding,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          foregroundColor: scheme.primary,
          elevation: 2,
          shadowColor: AppColors.neumorphicShadow,
          padding: AppSpacing.buttonPadding,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          padding: AppSpacing.buttonPadding,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.primary),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          borderSide: BorderSide(color: accentColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: accentColor,
        disabledColor: scheme.surfaceContainerHigh,
        checkmarkColor: onAccent,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: TextStyle(
          color: onAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(AppSpacing.buttonPadding),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentColor;
            }
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return onAccent;
            }
            return scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkMode ? accentForeground : accentColor;
          }
          return darkMode ? const Color(0xFFB8BFCC) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor.withValues(alpha: .36);
          }
          return scheme.surfaceContainerHigh;
        }),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(onAccent),
        side: BorderSide(color: scheme.outline),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          return scheme.onSurfaceVariant;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: surface,
        indicatorColor: accentColor.withValues(alpha: darkMode ? .28 : .14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: scheme.outlineVariant,
        indicatorColor: accentColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: onAccent,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primaryColor,
        headerForegroundColor: onPrimary,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurfaceVariant.withValues(alpha: .55);
          }
          if (states.contains(WidgetState.selected)) return onPrimary;
          return scheme.onSurface;
        }),
        todayForegroundColor: WidgetStatePropertyAll(accentForeground),
        todayBorder: BorderSide(color: accentForeground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: scheme.surfaceContainerHigh,
        dialHandColor: accentColor,
        hourMinuteColor: scheme.surfaceContainerHigh,
        hourMinuteTextColor: scheme.onSurface,
        dayPeriodColor: scheme.surfaceContainerHigh,
        dayPeriodTextColor: scheme.onSurface,
        entryModeIconColor: scheme.onSurfaceVariant,
        helpTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentForeground,
        linearTrackColor: accentColor.withValues(alpha: .18),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: scheme.surfaceContainerHigh,
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: .12),
        valueIndicatorColor: accentColor,
        valueIndicatorTextStyle: TextStyle(color: onAccent),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: .28),
        selectionHandleColor: accentColor,
      ),
    );
  }
}
