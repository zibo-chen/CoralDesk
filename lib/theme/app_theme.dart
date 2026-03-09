import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand / accent colors — constant across light & dark modes
class AppColors {
  AppColors._();

  static const primary = Color(0xFF5B6ABF);
  static const primaryLight = Color(0xFF7C8ADB);
  static const primaryDark = Color(0xFF3D4A9E);
  static const success = Color(0xFF4CAF50);
  static const error = Color(0xFFE53935);
  static const warning = Color(0xFFFFA726);
}

/// Theme-dependent custom color palette, accessible via [CoralDeskColors.of].
@immutable
class CoralDeskColors extends ThemeExtension<CoralDeskColors> {
  const CoralDeskColors({
    required this.sidebarBg,
    required this.sidebarText,
    required this.sidebarActiveText,
    required this.sidebarActiveBg,
    required this.sidebarSection,
    required this.chatListBg,
    required this.chatListBorder,
    required this.mainBg,
    required this.cardBg,
    required this.inputBg,
    required this.inputBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.surfaceBg,
  });

  final Color sidebarBg;
  final Color sidebarText;
  final Color sidebarActiveText;
  final Color sidebarActiveBg;
  final Color sidebarSection;
  final Color chatListBg;
  final Color chatListBorder;
  final Color mainBg;
  final Color cardBg;
  final Color inputBg;
  final Color inputBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color surfaceBg;

  static const light = CoralDeskColors(
    sidebarBg: Color(0xFFF8F9FC),
    sidebarText: Color(0xFF4A4D5C),
    sidebarActiveText: Color(0xFF5B6ABF),
    sidebarActiveBg: Color(0xFFEEF0FA),
    sidebarSection: Color(0xFF9498A8),
    chatListBg: Color(0xFFFFFFFF),
    chatListBorder: Color(0xFFE8EAF0),
    mainBg: Color(0xFFF5F6FA),
    cardBg: Color(0xFFFFFFFF),
    inputBg: Color(0xFFF5F6FA),
    inputBorder: Color(0xFFE0E3EB),
    textPrimary: Color(0xFF1A1D2E),
    textSecondary: Color(0xFF6B7080),
    textHint: Color(0xFFA0A5B5),
    surfaceBg: Color(0xFFFFFFFF),
  );

  static const dark = CoralDeskColors(
    sidebarBg: Color(0xFF1C1C2E),
    sidebarText: Color(0xFFB0B4C4),
    sidebarActiveText: Color(0xFF8B9AE8),
    sidebarActiveBg: Color(0xFF2D2D4A),
    sidebarSection: Color(0xFF7A7E90),
    chatListBg: Color(0xFF222234),
    chatListBorder: Color(0xFF353548),
    mainBg: Color(0xFF1A1A2C),
    cardBg: Color(0xFF262638),
    inputBg: Color(0xFF2A2A3C),
    inputBorder: Color(0xFF3A3A4E),
    textPrimary: Color(0xFFE2E4EC),
    textSecondary: Color(0xFF9498A8),
    textHint: Color(0xFF707488),
    surfaceBg: Color(0xFF262638),
  );

  static CoralDeskColors of(BuildContext context) =>
      Theme.of(context).extension<CoralDeskColors>()!;

  @override
  CoralDeskColors copyWith({
    Color? sidebarBg,
    Color? sidebarText,
    Color? sidebarActiveText,
    Color? sidebarActiveBg,
    Color? sidebarSection,
    Color? chatListBg,
    Color? chatListBorder,
    Color? mainBg,
    Color? cardBg,
    Color? inputBg,
    Color? inputBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? surfaceBg,
  }) {
    return CoralDeskColors(
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarActiveText: sidebarActiveText ?? this.sidebarActiveText,
      sidebarActiveBg: sidebarActiveBg ?? this.sidebarActiveBg,
      sidebarSection: sidebarSection ?? this.sidebarSection,
      chatListBg: chatListBg ?? this.chatListBg,
      chatListBorder: chatListBorder ?? this.chatListBorder,
      mainBg: mainBg ?? this.mainBg,
      cardBg: cardBg ?? this.cardBg,
      inputBg: inputBg ?? this.inputBg,
      inputBorder: inputBorder ?? this.inputBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      surfaceBg: surfaceBg ?? this.surfaceBg,
    );
  }

  @override
  CoralDeskColors lerp(CoralDeskColors? other, double t) {
    if (other is! CoralDeskColors) return this;
    return CoralDeskColors(
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarActiveText: Color.lerp(
        sidebarActiveText,
        other.sidebarActiveText,
        t,
      )!,
      sidebarActiveBg: Color.lerp(sidebarActiveBg, other.sidebarActiveBg, t)!,
      sidebarSection: Color.lerp(sidebarSection, other.sidebarSection, t)!,
      chatListBg: Color.lerp(chatListBg, other.chatListBg, t)!,
      chatListBorder: Color.lerp(chatListBorder, other.chatListBorder, t)!,
      mainBg: Color.lerp(mainBg, other.mainBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  // ── Platform-aware font helpers ────────────────────────

  /// CJK / system font fallback chain per platform.
  static List<String> get fontFamilyFallback {
    if (kIsWeb) return const [];
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => const [
        'Microsoft YaHei UI',
        'Segoe UI',
        'sans-serif',
      ],
      TargetPlatform.linux => const [
        'Noto Sans CJK SC',
        'WenQuanYi Micro Hei',
        'sans-serif',
      ],
      _ => const [], // macOS / iOS have excellent built-in fallback
    };
  }

  /// Build [TextTheme] with Inter (via google_fonts) + platform CJK fallback.
  static TextTheme _buildTextTheme(TextTheme base) {
    var theme = GoogleFonts.interTextTheme(base);
    final fallback = fontFamilyFallback;
    if (fallback.isNotEmpty) {
      theme = _applyFontFallback(theme, fallback);
    }
    return theme;
  }

  /// Attach [fontFamilyFallback] to every style in [theme] so that CJK
  /// glyphs resolve to a high-quality system font instead of the engine's
  /// arbitrary fallback.
  static TextTheme _applyFontFallback(TextTheme theme, List<String> fallback) {
    TextStyle? fb(TextStyle? s) => s?.copyWith(fontFamilyFallback: fallback);
    return theme.copyWith(
      displayLarge: fb(theme.displayLarge),
      displayMedium: fb(theme.displayMedium),
      displaySmall: fb(theme.displaySmall),
      headlineLarge: fb(theme.headlineLarge),
      headlineMedium: fb(theme.headlineMedium),
      headlineSmall: fb(theme.headlineSmall),
      titleLarge: fb(theme.titleLarge),
      titleMedium: fb(theme.titleMedium),
      titleSmall: fb(theme.titleSmall),
      bodyLarge: fb(theme.bodyLarge),
      bodyMedium: fb(theme.bodyMedium),
      bodySmall: fb(theme.bodySmall),
      labelLarge: fb(theme.labelLarge),
      labelMedium: fb(theme.labelMedium),
      labelSmall: fb(theme.labelSmall),
    );
  }

  /// Slim, macOS-like scrollbar styling for all platforms.
  static ScrollbarThemeData _scrollbarTheme(CoralDeskColors c) {
    return ScrollbarThemeData(
      thickness: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.dragged))
          return 8.0;
        return 4.0;
      }),
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return c.textHint.withValues(alpha: 0.6);
        }
        if (states.contains(WidgetState.hovered)) {
          return c.textHint.withValues(alpha: 0.5);
        }
        return c.textHint.withValues(alpha: 0.3);
      }),
      crossAxisMargin: 2,
      mainAxisMargin: 4,
    );
  }

  /// Platform-appropriate monospace font family for code blocks.
  static String get monoFontFamily {
    if (kIsWeb) return 'monospace';
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Cascadia Mono',
      TargetPlatform.macOS => 'SF Mono',
      _ => 'monospace',
    };
  }

  static ThemeData get light {
    const c = CoralDeskColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: c.mainBg,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: _buildTextTheme(ThemeData.light().textTheme),
      visualDensity: VisualDensity.standard,
      extensions: const [c],
      scrollbarTheme: _scrollbarTheme(c),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surfaceBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.chatListBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: c.textHint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.chatListBorder, thickness: 1),
      // Work around Flutter 3.41 RawTooltipState bug: it uses
      // SingleTickerProviderStateMixin but creates two AnimationControllers
      // (entrance + exit).  Setting exitDuration to zero avoids the second.
      tooltipTheme: TooltipThemeData(
        exitDuration: Duration.zero,
        waitDuration: const Duration(milliseconds: 500),
        textStyle: TextStyle(fontSize: 12, color: c.textPrimary),
        decoration: BoxDecoration(
          color: c.surfaceBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.chatListBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  static ThemeData get dark {
    const c = CoralDeskColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: c.mainBg,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: _buildTextTheme(ThemeData.dark().textTheme),
      visualDensity: VisualDensity.standard,
      extensions: const [c],
      scrollbarTheme: _scrollbarTheme(c),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surfaceBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.chatListBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: c.textHint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.chatListBorder, thickness: 1),
      tooltipTheme: TooltipThemeData(
        exitDuration: Duration.zero,
        waitDuration: const Duration(milliseconds: 500),
        textStyle: TextStyle(fontSize: 12, color: c.textPrimary),
        decoration: BoxDecoration(
          color: c.surfaceBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.chatListBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
