import 'dart:math' as math;

import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test(
      'Material3 $brightness retains seeded scheme and readable controls',
      () {
        final theme = AppTheme.forBrightness(brightness);
        final scheme = theme.colorScheme;
        final seeded = ColorScheme.fromSeed(
          seedColor: AppTokens.primary,
          brightness: brightness,
        );
        expect(theme.useMaterial3, isTrue);
        expect(scheme.brightness, brightness);
        final dark = brightness == Brightness.dark;
        final card = dark ? const Color(0xFF1A2335) : const Color(0xFFFFFFFF);
        final text = dark ? const Color(0xFFEEF2FA) : const Color(0xFF14213D);
        final muted = dark ? const Color(0xFF98A4BB) : const Color(0xFF6B778C);
        final border = dark ? const Color(0xFF2A3550) : const Color(0xFFE4E8F0);
        expect(scheme.primary, const Color(0xFF1A73E8));
        expect(scheme.onPrimary, const Color(0xFFFFFFFF));
        expect(scheme.secondary, const Color(0xFFF59309));
        expect(scheme.surface, card);
        expect(scheme.surfaceContainerLow, card);
        expect(scheme.onSurface, text);
        expect(scheme.onSurfaceVariant, muted);
        expect(scheme.outline, border);
        expect(scheme.outlineVariant, border);
        expect(
          theme.scaffoldBackgroundColor,
          dark ? const Color(0xFF0F1624) : const Color(0xFFF4F6FB),
        );
        expect(theme.dividerColor, border);
        expect(theme.textTheme.bodyLarge?.color, text);
        expect(theme.textTheme.headlineMedium?.color, text);
        expect(theme.inputDecorationTheme.fillColor, card);
        expect(theme.inputDecorationTheme.labelStyle?.color, muted);
        expect(theme.inputDecorationTheme.hintStyle?.color, muted);
        expect(
          theme.inputDecorationTheme.enabledBorder?.borderSide.color,
          border,
        );
        expect(
          theme.inputDecorationTheme.focusedBorder?.borderSide.color,
          const Color(0xFF1A73E8),
        );
        expect(theme.cardTheme.color, card);
        expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
        expect(
          (theme.cardTheme.shape as RoundedRectangleBorder).side.color,
          border,
        );
        expect(scheme.primaryContainer, seeded.primaryContainer);
        expect(scheme.tertiary, seeded.tertiary);
        expect(scheme.error, seeded.error);
        expect(scheme.surfaceContainerHighest, seeded.surfaceContainerHighest);
        expect(
          contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.error, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve({}),
          const Size(AppTokens.target, AppTokens.target),
        );
      },
    );
  }

  test('success and dark-blue tokens match CSS', () {
    expect(AppTokens.success, const Color(0xFF12A150));
    expect(AppTokens.darkBlue, const Color(0xFF1560C4));
  });

  for (final size in [
    const Size(390, 780),
    const Size(780, 390),
    const Size(320, 328),
    const Size(600, 600),
  ]) {
    test(
      'CSS 170-degree gradient has exact stops and projections at $size',
      () {
        final gradient = AppTokens.loginGradient(size);
        expect(gradient.colors, const [
          Color(0xFF4A8DF0),
          Color(0xFF1A73E8),
          Color(0xFF1560C4),
        ]);
        expect(gradient.stops, [0.0, 0.45, 1.0]);
        final rect = Offset.zero & size;
        final begin = gradient.begin
            .resolve(TextDirection.ltr)
            .withinRect(rect);
        final end = gradient.end.resolve(TextDirection.ltr).withinRect(rect);
        final vector = end - begin;
        expect(vector.dx, greaterThan(0));
        expect(vector.dy, greaterThan(0));
        expect(
          math.atan2(vector.dx, -vector.dy) * 180 / math.pi,
          closeTo(170, 1e-10),
        );
        final expectedLength =
            size.width * math.sin(10 * math.pi / 180) +
            size.height * math.cos(10 * math.pi / 180);
        expect(vector.distance, closeTo(expectedLength, 1e-10));
        expect((begin + end) / 2, rect.center);
        double projection(Offset point) {
          final delta = point - begin;
          return (delta.dx * vector.dx + delta.dy * vector.dy) /
              vector.distanceSquared;
        }

        expect(projection(rect.topLeft), closeTo(0, 1e-10));
        expect(projection(rect.bottomRight), closeTo(1, 1e-10));
        expect(projection(rect.topRight), inInclusiveRange(0, 1));
        expect(projection(rect.bottomLeft), inInclusiveRange(0, 1));
        expect(
          gradient.begin.resolve(TextDirection.rtl),
          gradient.begin.resolve(TextDirection.ltr),
        );
      },
    );
  }

  test(
    'white login form has coherent light text, labels and error contrast',
    () {
      final theme = AppTheme.loginForm;
      final scheme = theme.colorScheme;
      final inputFill = theme.inputDecorationTheme.fillColor ?? scheme.surface;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.surface, AppTokens.white);
      expect(theme.cardTheme.color, AppTokens.white);
      expect(
        contrast(scheme.onSurface, AppTokens.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(scheme.onSurface, inputFill), greaterThanOrEqualTo(4.5));
      expect(
        contrast(scheme.onSurfaceVariant, inputFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(scheme.error, inputFill), greaterThanOrEqualTo(4.5));
      expect(
        contrast(scheme.error, AppTokens.white),
        greaterThanOrEqualTo(4.5),
      );
      // Brand copy is large/bold and meets the large-text threshold at the
      // brightest gradient endpoint, not just at the darker bottom.
      expect(
        contrast(AppTokens.white, AppTokens.brightBlue),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrast(
          Color.alphaBlend(
            AppTokens.white.withValues(alpha: AppTokens.subtitleOpacity),
            AppTokens.brightBlue,
          ),
          AppTokens.brightBlue,
        ),
        greaterThanOrEqualTo(3),
      );
    },
  );
}
