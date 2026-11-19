import 'package:material_ui/material_ui.dart';

/// Raw brand colours. Widgets should read the [JPlayerPalette] theme extension
/// instead of referencing these constants directly, so light, dark and AMOLED
/// variants stay consistent.
class AppColors {
  const AppColors._();

  static const Color darkBackground = Color(0xFF0A1420);
  static const Color darkSurface = Color(0xFF101E2E);
  static const Color darkCard = Color(0xFF15283C);
  static const Color primaryAccent = Color(0xFF38BDF8);
  static const Color secondaryAccent = Color(0xFFBAE6FD);
  static const Color primaryText = Color(0xFFF4FAFF);
  static const Color secondaryText = Color(0xFFA9C0D6);
  static const Color lightBackground = Color(0xFFF3FAFF);
  static const Color amoledBlack = Color(0xFF000000);

  static const List<Color> accentGradient = [
    Color(0xFF7DD3FC),
    Color(0xFF0284C7),
  ];
}

/// Colours that are specific to JPlayer's surfaces and are not part of
/// Material's ColorScheme. Provided through ThemeExtension so every widget can
/// resolve colours from the active theme.
@immutable
class JPlayerPalette extends ThemeExtension<JPlayerPalette> {
  const JPlayerPalette({
    required this.background,
    required this.surface,
    required this.card,
    required this.elevated,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.navigation,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color elevated;
  final Color accent;
  final Color accentSoft;

  /// Foreground used on top of [accent] and accent gradients.
  final Color onAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color navigation;
  final bool isDark;

  static const JPlayerPalette dark = JPlayerPalette(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    elevated: Color(0xFF1B3148),
    accent: Color(0xFF7DD3FC),
    accentSoft: Color(0xFFBAE6FD),
    onAccent: Color(0xFF05283C),
    textPrimary: AppColors.primaryText,
    textSecondary: AppColors.secondaryText,
    divider: Color(0xFF213A52),
    navigation: Color(0xFF06111C),
    isDark: true,
  );

  static const JPlayerPalette amoled = JPlayerPalette(
    background: AppColors.amoledBlack,
    surface: Color(0xFF050B12),
    card: Color(0xFF0A1622),
    elevated: Color(0xFF102131),
    accent: Color(0xFF7DD3FC),
    accentSoft: Color(0xFFBAE6FD),
    onAccent: Color(0xFF05283C),
    textPrimary: AppColors.primaryText,
    textSecondary: Color(0xFF9CB4C9),
    divider: Color(0xFF17293C),
    navigation: AppColors.amoledBlack,
    isDark: true,
  );

  static const JPlayerPalette light = JPlayerPalette(
    background: AppColors.lightBackground,
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFE6F4FE),
    elevated: Color(0xFFFFFFFF),
    accent: Color(0xFF0369A1),
    accentSoft: Color(0xFF38BDF8),
    onAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0A1B2B),
    textSecondary: Color(0xFF4D667C),
    divider: Color(0xFFD4E6F4),
    navigation: Color(0xFFFFFFFF),
    isDark: false,
  );

  Color get accentMuted => accent.withValues(alpha: isDark ? 0.22 : 0.14);

  LinearGradient get accentGradient => LinearGradient(
    colors: isDark ? [accentSoft, accent] : [accent, const Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  JPlayerPalette copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? elevated,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? navigation,
    bool? isDark,
  }) {
    return JPlayerPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      elevated: elevated ?? this.elevated,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      navigation: navigation ?? this.navigation,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  JPlayerPalette lerp(ThemeExtension<JPlayerPalette>? other, double t) {
    if (other is! JPlayerPalette) return this;
    return JPlayerPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      navigation: Color.lerp(navigation, other.navigation, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension JPlayerThemeContext on BuildContext {
  JPlayerPalette get palette =>
      Theme.of(this).extension<JPlayerPalette>() ?? JPlayerPalette.dark;
}
