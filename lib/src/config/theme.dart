import 'package:flutter/material.dart';

class MagoColors {
  MagoColors._();

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral900 = Color(0xFF171717);
  static const Color neutral950 = Color(0xFF0A0A0A);

  static const Color brand = Color(0xFF6366F1);
  static const Color brandLight = Color(0xFF818CF8);
  static const Color brandDark = Color(0xFF4F46E5);

  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF4ADE80);
  static const Color successDark = Color(0xFF16A34A);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF60A5FA);
  static const Color infoDark = Color(0xFF2563EB);

  static const List<Color> canvasColors = [
    Color(0xFF1F2937),
    Color(0xFF000000),
    Color(0xFFEF4444),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
  ];

  static const List<Color> canvasColorsLight = [
    Color(0xFF1F2937),
    Color(0xFF000000),
    Color(0xFFDC2626),
    Color(0xFF16A34A),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDB2777),
  ];
}

class MagoThemeData {
  final Color drawerBackground;
  final Color cardBackground;
  final Color inputBackground;
  final Color popoverBackground;
  final Color canvasBackground;
  final Color dialogBackground;
  final Color dividerColor;
  final Color disabledColor;
  final Color hintTextColor;

  final Color textPrimary;

  final Color textSecondary;

  final Color textTertiary;

  final Color borderSubtle;

  final Color iconDefault;

  final Color iconMuted;

  final double defaultBorderRadius;
  final double defaultElevation;

  const MagoThemeData({
    required this.drawerBackground,
    required this.cardBackground,
    required this.inputBackground,
    required this.popoverBackground,
    required this.canvasBackground,
    required this.dialogBackground,
    required this.dividerColor,
    required this.disabledColor,
    required this.hintTextColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.iconDefault,
    required this.iconMuted,
    this.defaultBorderRadius = 12.0,
    this.defaultElevation = 4.0,
  });

  static MagoThemeData light(ColorScheme cs) => MagoThemeData(
        drawerBackground: cs.surfaceContainerHighest,
        cardBackground: cs.surfaceContainerLow,
        inputBackground: cs.surfaceContainerHighest,
        popoverBackground: cs.surfaceContainer,
        canvasBackground: cs.surface,
        dialogBackground: cs.surfaceContainerHigh,
        dividerColor: cs.outlineVariant,
        disabledColor: cs.onSurface.withAlpha(97),
        hintTextColor: cs.onSurface.withAlpha(128),
        textPrimary: MagoColors.neutral900,
        textSecondary: MagoColors.neutral600,
        textTertiary: MagoColors.neutral400,
        borderSubtle: MagoColors.neutral200,
        iconDefault: MagoColors.neutral700,
        iconMuted: MagoColors.neutral400,
      );

  static MagoThemeData dark(ColorScheme cs) => MagoThemeData(
        drawerBackground: cs.surfaceContainerHighest,
        cardBackground: cs.surfaceContainerLow,
        inputBackground: cs.surfaceContainerHighest,
        popoverBackground: cs.surfaceContainer,
        canvasBackground: cs.surface,
        dialogBackground: cs.surfaceContainerHigh,
        dividerColor: cs.outlineVariant,
        disabledColor: cs.onSurface.withAlpha(97),
        hintTextColor: cs.onSurface.withAlpha(128),
        textPrimary: MagoColors.neutral100,
        textSecondary: MagoColors.neutral400,
        textTertiary: MagoColors.neutral600,
        borderSubtle: MagoColors.neutral800,
        iconDefault: MagoColors.neutral300,
        iconMuted: MagoColors.neutral600,
      );
}

class MagoTheme extends InheritedWidget {
  final MagoThemeData data;

  const MagoTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static MagoThemeData of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MagoTheme>();
    if (widget != null) return widget.data;

    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? MagoThemeData.dark(theme.colorScheme)
        : MagoThemeData.light(theme.colorScheme);
  }

  static MagoThemeData? maybeOf(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<MagoTheme>();
    return widget?.data;
  }

  @override
  bool updateShouldNotify(MagoTheme oldWidget) => data != oldWidget.data;
}

class MagoTextStyles {
  MagoTextStyles._();

  static const String fontFamily = 'Inter';

  static TextTheme get textTheme => const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          height: 1.27,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          height: 1.50,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.33,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          height: 1.45,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          height: 1.50,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.43,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          height: 1.33,
        ),
      );
}

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: MagoColors.brand,
    onPrimary: Colors.white,
    primaryContainer: MagoColors.brandLight.withAlpha(51),
    onPrimaryContainer: MagoColors.brandDark,
    secondary: const Color(0xFF625B71),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE8DEF8),
    onSecondaryContainer: const Color(0xFF1D192B),
    tertiary: const Color(0xFF7D5260),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFFD8E4),
    onTertiaryContainer: const Color(0xFF31111D),
    error: MagoColors.error,
    onError: Colors.white,
    errorContainer: MagoColors.errorLight.withAlpha(51),
    onErrorContainer: MagoColors.errorDark,
    surface: const Color(0xFFFFFBFE),
    onSurface: const Color(0xFF1C1B1F),
    surfaceContainerHighest: const Color(0xFFE7E0EC),
    surfaceContainerHigh: const Color(0xFFECE6F0),
    surfaceContainer: const Color(0xFFF3EDF7),
    surfaceContainerLow: const Color(0xFFF7F2FA),
    surfaceContainerLowest: Colors.white,
    outline: const Color(0xFF79747E),
    outlineVariant: const Color(0xFFCAC4D0),
    inverseSurface: const Color(0xFF313033),
    onInverseSurface: const Color(0xFFF4EFF4),
    inversePrimary: MagoColors.brandLight,
    shadow: Colors.black,
    scrim: Colors.black,
  ),
  textTheme: MagoTextStyles.textTheme,
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 1,
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dividerTheme: const DividerThemeData(
    thickness: 1,
    space: 1,
  ),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: MagoColors.brandLight,
    onPrimary: const Color(0xFF1F1F3D),
    primaryContainer: MagoColors.brand.withAlpha(77),
    onPrimaryContainer: MagoColors.brandLight,
    secondary: const Color(0xFFCCC2DC),
    onSecondary: const Color(0xFF332D41),
    secondaryContainer: const Color(0xFF4A4458),
    onSecondaryContainer: const Color(0xFFE8DEF8),
    tertiary: const Color(0xFFEFB8C8),
    onTertiary: const Color(0xFF492532),
    tertiaryContainer: const Color(0xFF633B48),
    onTertiaryContainer: const Color(0xFFFFD8E4),
    error: MagoColors.errorLight,
    onError: const Color(0xFF601410),
    errorContainer: MagoColors.error.withAlpha(77),
    onErrorContainer: MagoColors.errorLight,
    surface: const Color(0xFF1C1B1F),
    onSurface: const Color(0xFFE6E1E5),
    surfaceContainerHighest: const Color(0xFF49454F),
    surfaceContainerHigh: const Color(0xFF3B383E),
    surfaceContainer: const Color(0xFF2B2930),
    surfaceContainerLow: const Color(0xFF211F26),
    surfaceContainerLowest: const Color(0xFF0F0D13),
    outline: const Color(0xFF938F99),
    outlineVariant: const Color(0xFF49454F),
    inverseSurface: const Color(0xFFE6E1E5),
    onInverseSurface: const Color(0xFF313033),
    inversePrimary: MagoColors.brand,
    shadow: Colors.black,
    scrim: Colors.black,
  ),
  textTheme: MagoTextStyles.textTheme,
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 1,
  ),
  cardTheme: CardThemeData(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dividerTheme: const DividerThemeData(
    thickness: 1,
    space: 1,
  ),
);
