import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// NDS (DGA theme) color primitives, as used by the redesign canvas.
class NdsColors {
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF161616);

  static const primary25 = Color(0xFFF7FDF9);
  static const primary50 = Color(0xFFF3FCF6);
  static const primary100 = Color(0xFFDFF6E7);
  static const primary200 = Color(0xFFB8EACB);
  static const primary400 = Color(0xFF54C08A);
  static const primary500 = Color(0xFF25935F);
  static const primary600 = Color(0xFF1B8354);
  static const primary700 = Color(0xFF166A45);
  static const primary800 = Color(0xFF14573A);
  static const primary900 = Color(0xFF104631);
  static const primary950 = Color(0xFF092A1E);

  static const neutral25 = Color(0xFFFCFCFD);
  static const neutral50 = Color(0xFFF9FAFB);
  static const neutral100 = Color(0xFFF3F4F6);
  static const neutral200 = Color(0xFFE5E7EB);
  static const neutral300 = Color(0xFFD2D6DB);
  static const neutral400 = Color(0xFF9DA4AE);
  static const neutral500 = Color(0xFF6C727E);
  static const neutral600 = Color(0xFF4D5761);
  static const neutral700 = Color(0xFF384250);
  static const neutral800 = Color(0xFF1F2A37);
  static const neutral950 = Color(0xFF0C111B);

  static const green50 = Color(0xFFECFDF3);
  static const green200 = Color(0xFFABEFC6);
  static const green600 = Color(0xFF069454);
  static const green700 = Color(0xFF067647);
  static const green800 = Color(0xFF085D3A);

  static const blue50 = Color(0xFFEFF8FF);
  static const blue100 = Color(0xFFD1E9FF);
  static const blue200 = Color(0xFFB2DDFF);
  static const blue600 = Color(0xFF156FEE);
  static const blue700 = Color(0xFF175CD3);
  static const blue800 = Color(0xFF1849A9);

  static const yellow50 = Color(0xFFFFFAEB);
  static const yellow200 = Color(0xFFFEDF89);
  static const yellow600 = Color(0xFFDC6803);
  static const yellow700 = Color(0xFFB54707);
  static const yellow800 = Color(0xFF93370C);

  static const red50 = Color(0xFFFEF3F2);
  static const red200 = Color(0xFFFECDCA);
  static const red600 = Color(0xFFD92C20);
  static const red700 = Color(0xFFB42318);
  static const red800 = Color(0xFF912018);
}

/// Semantic NDS tokens. Screens use these rather than raw primitives.
class Nds {
  static const fontFamily = 'IBMPlexSansArabic';

  static const backgroundBody = NdsColors.neutral50;
  static const backgroundDefault = NdsColors.white;
  static const backgroundCard = NdsColors.white;
  static const backgroundPrimary = NdsColors.primary600;
  static const backgroundPrimaryStrong = NdsColors.primary900;
  static const backgroundPrimaryLight = NdsColors.primary50;
  static const backgroundPrimaryFaint = NdsColors.primary25;
  static const backgroundNeutralLight = NdsColors.neutral100;
  static const backgroundOverlay = Color(0x7F161616);

  static const textDefault = NdsColors.black;
  static const textDisplay = NdsColors.neutral800;
  static const textParagraph = NdsColors.neutral700;
  static const textSecondary = NdsColors.neutral500;
  static const textPrimary = NdsColors.primary600;
  static const textPrimaryStrong = NdsColors.primary700;
  static const textOnColor = NdsColors.white;
  static const textOnColorSecondary = Color(0xCCFFFFFF);
  static const textSuccess = NdsColors.green700;
  static const textInfo = NdsColors.blue700;
  static const textWarning = NdsColors.yellow700;
  static const textError = NdsColors.red700;

  static const borderNeutral = NdsColors.neutral200;
  static const borderPrimary = NdsColors.primary600;
  static const borderPrimaryLight = NdsColors.primary200;
  static const borderOnColor = Color(0x66FFFFFF);
  static const borderField = NdsColors.neutral400;
  static const divider = Color(0x19161616);

  static const iconNeutral = NdsColors.neutral700;
  static const iconSeparator = NdsColors.neutral400;
}

/// NDS spacing scale (px).
class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double x2l = 20;
  static const double x3l = 24;
  static const double x4l = 32;
  static const double x5l = 40;
  static const double x6l = 48;
}

/// NDS corner radii (px).
class Radii {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
  static const double full = 999;
}

/// NDS type scale: font size with its line height.
class NdsText {
  static TextStyle _style(double size, double lineHeight) => TextStyle(
    fontFamily: Nds.fontFamily,
    fontSize: size,
    height: lineHeight / size,
  );

  static final displayXs = _style(24, 32).copyWith(fontWeight: FontWeight.w600);
  static final textXl = _style(20, 30);
  static final textLg = _style(18, 28);
  static final textMd = _style(16, 24);
  static final textSm = _style(14, 20);
  static final textXs = _style(12, 18);
}

/// Lets a mouse drag lists as a finger does, so pull-to-refresh also works in
/// a desktop browser.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };

  /// macOS elastic scrolling absorbs most of a pull, so a mouse drag would
  /// rarely reach the refresh point. Phones keep their native scrolling.
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      getPlatform(context) == TargetPlatform.macOS
      ? const ClampingScrollPhysics()
      : super.getScrollPhysics(context);
}

ThemeData buildTheme() {
  const colorScheme = ColorScheme.light(
    primary: Nds.backgroundPrimary,
    onPrimary: Nds.textOnColor,
    primaryContainer: Nds.backgroundPrimaryLight,
    onPrimaryContainer: NdsColors.primary800,
    secondary: Nds.backgroundPrimaryStrong,
    onSecondary: Nds.textOnColor,
    surface: Nds.backgroundCard,
    onSurface: Nds.textDefault,
    onSurfaceVariant: Nds.textSecondary,
    surfaceContainerLowest: Nds.backgroundDefault,
    surfaceContainerLow: Nds.backgroundBody,
    surfaceContainer: Nds.backgroundNeutralLight,
    outline: Nds.borderField,
    outlineVariant: Nds.borderNeutral,
    error: NdsColors.red600,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: Nds.fontFamily,
    scaffoldBackgroundColor: Nds.backgroundBody,
    dividerColor: Nds.divider,
  );

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(Radii.sm)),
  );
  final buttonLabel = NdsText.textMd.copyWith(fontWeight: FontWeight.w500);
  final primaryButton = ElevatedButton.styleFrom(
    backgroundColor: Nds.backgroundPrimary,
    foregroundColor: Nds.textOnColor,
    disabledBackgroundColor: Nds.backgroundNeutralLight,
    disabledForegroundColor: Nds.iconSeparator,
    elevation: 0,
    minimumSize: const Size.fromHeight(48),
    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
    shape: buttonShape,
    textStyle: buttonLabel,
  );
  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          headlineSmall: NdsText.displayXs,
          titleLarge: NdsText.textXl.copyWith(fontWeight: FontWeight.w600),
          titleMedium: NdsText.textMd.copyWith(fontWeight: FontWeight.w600),
          titleSmall: NdsText.textSm.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: NdsText.textMd,
          bodyMedium: NdsText.textSm,
          bodySmall: NdsText.textXs.copyWith(color: Nds.textSecondary),
          labelLarge: buttonLabel,
          labelMedium: NdsText.textSm.copyWith(fontWeight: FontWeight.w500),
          labelSmall: NdsText.textXs.copyWith(fontWeight: FontWeight.w500),
        )
        .apply(bodyColor: Nds.textDefault, displayColor: Nds.textDisplay),
    appBarTheme: AppBarTheme(
      backgroundColor: Nds.backgroundDefault,
      foregroundColor: Nds.textDisplay,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 72,
      titleTextStyle: NdsText.textLg.copyWith(
        fontWeight: FontWeight.w600,
        color: Nds.textDisplay,
      ),
      shape: const Border(bottom: BorderSide(color: Nds.borderNeutral)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
    filledButtonTheme: FilledButtonThemeData(style: primaryButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Nds.textDisplay,
        backgroundColor: Nds.backgroundDefault,
        disabledForegroundColor: Nds.iconSeparator,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        side: const BorderSide(color: NdsColors.neutral300),
        shape: buttonShape,
        textStyle: buttonLabel,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Nds.textPrimary,
        shape: buttonShape,
        textStyle: NdsText.textSm.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Nds.backgroundCard,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md + 2,
      ),
      hintStyle: NdsText.textMd.copyWith(color: Nds.textSecondary),
      labelStyle: NdsText.textSm.copyWith(color: Nds.textParagraph),
      prefixIconColor: Nds.iconNeutral,
      suffixIconColor: Nds.iconNeutral,
      border: fieldBorder(Nds.borderField),
      enabledBorder: fieldBorder(Nds.borderField),
      focusedBorder: fieldBorder(Nds.borderPrimary, 2),
      errorBorder: fieldBorder(Nds.textError),
      focusedErrorBorder: fieldBorder(Nds.textError, 2),
      errorStyle: NdsText.textXs.copyWith(color: Nds.textError),
    ),
    cardTheme: const CardThemeData(
      color: Nds.backgroundCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
        side: BorderSide(color: Nds.borderNeutral),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: Nds.iconNeutral,
      titleTextStyle: NdsText.textMd.copyWith(
        fontWeight: FontWeight.w600,
        color: Nds.textDisplay,
      ),
      subtitleTextStyle: NdsText.textSm.copyWith(color: Nds.textSecondary),
    ),
    dividerTheme: const DividerThemeData(
      color: Nds.divider,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Nds.backgroundDefault,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => NdsText.textXs.copyWith(
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? Nds.textPrimary
              : Nds.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? Nds.textPrimary
              : Nds.textSecondary,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NdsColors.neutral50,
      side: const BorderSide(color: Nds.borderNeutral),
      labelStyle: NdsText.textSm.copyWith(
        fontWeight: FontWeight.w500,
        color: NdsColors.neutral800,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.sm)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: NdsColors.neutral800,
      contentTextStyle: NdsText.textSm.copyWith(color: Nds.textOnColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.md)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Nds.backgroundDefault,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Nds.backgroundPrimary,
      linearTrackColor: Nds.backgroundNeutralLight,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: Nds.iconNeutral,
      collapsedIconColor: Nds.iconNeutral,
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}
