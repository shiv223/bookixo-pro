import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Material themes shared by every feature.
abstract final class AppTheme {
  static ThemeData forBrightness(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final card = dark ? AppTokens.darkCard : AppTokens.white;
    final text = dark ? AppTokens.darkText : AppTokens.text;
    final muted = dark ? AppTokens.darkMuted : AppTokens.muted;
    final border = dark ? AppTokens.darkBorder : AppTokens.border;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppTokens.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppTokens.primary,
          onPrimary: AppTokens.white,
          secondary: AppTokens.accent,
          onSecondary: AppTokens.accentInk,
          surface: card,
          surfaceContainerLow: card,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: border,
          outlineVariant: border,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark
          ? AppTokens.darkBackground
          : AppTokens.background,
      dividerColor: border,
      textTheme: base.textTheme
          .apply(bodyColor: text, displayColor: text)
          .copyWith(
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontSize: AppTokens.titleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: AppTokens.titleTracking,
            ),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              fontSize: AppTokens.bodySize,
              height: AppTokens.textHeight,
            ),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              fontSize: AppTokens.labelSize,
              fontWeight: FontWeight.w600,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.all(AppTokens.gap),
        errorMaxLines: AppTokens.errorLines,
        border: _border(scheme.outline),
        enabledBorder: _border(scheme.outline),
        focusedBorder: _border(scheme.primary, AppTokens.focusOutlineWidth),
        errorBorder: _border(scheme.error),
        focusedErrorBorder: _border(scheme.error, AppTokens.focusOutlineWidth),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          side: BorderSide(color: border, width: AppTokens.outlineWidth),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppTokens.target, AppTokens.target),
          padding: const EdgeInsets.all(AppTokens.gap),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppTokens.target, AppTokens.target),
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppTokens.target, AppTokens.target),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppTokens.target, AppTokens.target),
          padding: const EdgeInsets.all(AppTokens.gap),
          shape: shape,
        ),
      ),
    );
  }

  /// A white login card deliberately uses light controls, even in dark mode.
  static ThemeData get loginForm {
    return forBrightness(Brightness.light);
  }

  static OutlineInputBorder _border(
    Color color, [
    double width = AppTokens.outlineWidth,
  ]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.controlRadius),
    borderSide: BorderSide(color: color, width: width),
  );
}
