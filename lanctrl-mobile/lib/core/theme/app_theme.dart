import 'dart:ui';

import 'package:flutter/material.dart';

import '../../features/app/domain/app_models.dart';

class AppThemeDefinition {
  const AppThemeDefinition({
    required this.id,
    required this.name,
    required this.seed,
    required this.lightHero,
    required this.darkHero,
    required this.highlight,
  });

  final String id;
  final String name;
  final Color seed;
  final List<Color> lightHero;
  final List<Color> darkHero;
  final Color highlight;
}

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  const AppThemePalette({
    required this.heroGradient,
    required this.heroGlow,
    required this.glassFill,
    required this.glassStroke,
    required this.softFill,
    required this.strongFill,
  });

  final List<Color> heroGradient;
  final Color heroGlow;
  final Color glassFill;
  final Color glassStroke;
  final Color softFill;
  final Color strongFill;

  @override
  AppThemePalette copyWith({
    List<Color>? heroGradient,
    Color? heroGlow,
    Color? glassFill,
    Color? glassStroke,
    Color? softFill,
    Color? strongFill,
  }) {
    return AppThemePalette(
      heroGradient: heroGradient ?? this.heroGradient,
      heroGlow: heroGlow ?? this.heroGlow,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      softFill: softFill ?? this.softFill,
      strongFill: strongFill ?? this.strongFill,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) {
      return this;
    }

    return AppThemePalette(
      heroGradient: List<Color>.generate(
        heroGradient.length,
        (index) =>
            Color.lerp(heroGradient[index], other.heroGradient[index], t) ??
            heroGradient[index],
      ),
      heroGlow: Color.lerp(heroGlow, other.heroGlow, t) ?? heroGlow,
      glassFill: Color.lerp(glassFill, other.glassFill, t) ?? glassFill,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t) ?? glassStroke,
      softFill: Color.lerp(softFill, other.softFill, t) ?? softFill,
      strongFill: Color.lerp(strongFill, other.strongFill, t) ?? strongFill,
    );
  }
}

const defaultTheme = AppThemeDefinition(
  id: 'default',
  name: '紫曜',
  seed: Color(0xFF7C5CFF),
  lightHero: [Color(0xFFF4F0FF), Color(0xFFEAE4FF), Color(0xFFD7CCFF)],
  darkHero: [Color(0xFF201540), Color(0xFF15112A), Color(0xFF0C0A16)],
  highlight: Color(0xFF9B85FF),
);

const themeRegistry = <String, AppThemeDefinition>{'default': defaultTheme};

ThemeData buildAppTheme(AppThemeDefinition definition, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: definition.seed,
    brightness: brightness,
  );

  final textTheme = Typography.blackCupertino.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  final palette = AppThemePalette(
    heroGradient: isDark ? definition.darkHero : definition.lightHero,
    heroGlow: definition.highlight.withValues(alpha: isDark ? 0.34 : 0.20),
    glassFill: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.70),
    glassStroke: isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80),
    softFill: isDark ? const Color(0xFF14131C) : const Color(0xFFF8F7FC),
    strongFill: isDark
        ? const Color(0xFF0D0C12)
        : Colors.white.withValues(alpha: 0.88),
  );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF09080D)
        : const Color(0xFFF4F2F8),
    textTheme: textTheme,
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.strongFill,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.softFill,
      selectedColor: colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.18)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? const Color(0xFF14131C)
          : Colors.white.withValues(alpha: 0.96),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.strongFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.strongFill,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.12),
      thickness: 1,
    ),
  );
}

ThemeMode themeModeFromPreference(ThemePreferenceMode mode) {
  return switch (mode) {
    ThemePreferenceMode.light => ThemeMode.light,
    ThemePreferenceMode.dark => ThemeMode.dark,
    ThemePreferenceMode.system => ThemeMode.system,
  };
}

ThemePreferenceMode themePreferenceModeFromStorage(String raw) {
  return ThemePreferenceMode.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => ThemePreferenceMode.light,
  );
}

AppThemeDefinition themeFromStorage(String raw) {
  return themeRegistry[raw] ?? defaultTheme;
}

AppThemePalette paletteOf(BuildContext context) {
  return Theme.of(context).extension<AppThemePalette>()!;
}

ImageFilter glassBlur([double sigma = 20]) {
  return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
}
