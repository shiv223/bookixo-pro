import 'dart:async';

import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/constants/app_assets.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/auth/presentation/login_branding.dart';
import 'package:bookixo_pro/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;
  setUp(() {
    auth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester, [
    Brightness brightness = Brightness.light,
  ]) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(brightness),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'owner@example.test');
    await tester.enterText(find.byType(TextField).at(1), ' secret ');
  }

  void expectLoginGradient(WidgetTester tester) {
    final backdrop = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).gradient is LinearGradient,
    );
    expect(backdrop, findsOneWidget);
    final decoration =
        tester.widget<DecoratedBox>(backdrop).decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors, const [
      Color(0xFF4A8DF0),
      Color(0xFF1A73E8),
      Color(0xFF1560C4),
    ]);
    expect(gradient.stops, [0.0, 0.45, 1.0]);
    expect(gradient, AppTokens.loginGradient(tester.getSize(backdrop)));
  }

  for (final brightness in Brightness.values) {
    testWidgets('branded assets and white light form under $brightness', (
      tester,
    ) async {
      await pump(tester, brightness);
      expectLoginGradient(tester);
      final logo = tester.widget<Image>(find.byType(Image));
      expect((logo.image as AssetImage).assetName, AppAssets.brandLogo);
      final tools = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(
        (tools.bytesLoader as SvgAssetLoader).assetName,
        AppAssets.loginTools,
      );
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text(AppStrings.loginSubtitle), findsOneWidget);
      expect(
        find.textContaining(
          RegExp('sign up|owner|employee|role', caseSensitive: false),
        ),
        findsNothing,
      );
      final formTheme = Theme.of(tester.element(find.byType(TextField).first));
      expect(formTheme.brightness, Brightness.light);
      expect(formTheme.colorScheme.surface, AppTokens.white);
      expect(formTheme.cardTheme.color, const Color(0xFFFFFFFF));
      expect(formTheme.inputDecorationTheme.fillColor, const Color(0xFFFFFFFF));
      expect(formTheme.colorScheme.onSurface, const Color(0xFF14213D));
      expect(formTheme.colorScheme.onSurfaceVariant, const Color(0xFF6B778C));
      expect(formTheme.colorScheme.outline, const Color(0xFFE4E8F0));
      expect(
        tester
            .widget<Material>(
              find.descendant(
                of: find.byType(FilledButton),
                matching: find.byType(Material),
              ),
            )
            .color,
        const Color(0xFF1A73E8),
      );
      expect(
        Theme.of(tester.element(find.byType(LoginScreen))).brightness,
        brightness,
      );
      expect(
        tester.getTopLeft(find.byType(Image)).dy,
        lessThan(tester.getTopLeft(find.byType(Card)).dy),
      );
      final cardWidth = tester.getSize(find.byType(Card)).width;
      expect(
        tester.getSize(find.byType(FilledButton)).width,
        cardWidth - AppTokens.padding * 2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gradient responds to portrait and landscape without mirroring', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [const Size(390, 780), const Size(780, 390)]) {
      tester.view.physicalSize = size;
      await pump(tester);
      expectLoginGradient(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('password toggle is local, labelled, >=48 and preserves input', (
    tester,
  ) async {
    await pump(tester);
    await fill(tester);
    final toggle = find.byType(IconButton);
    final size = tester.getSize(toggle);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip(AppStrings.showPassword));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    expect(find.byTooltip(AppStrings.hidePassword), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      ' secret ',
    );
    await tester.tap(find.byTooltip(AppStrings.hidePassword));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    expect(auth.signs, 0);
  });

  testWidgets(
    'loading disables controls and repeats; inline failure keeps fields',
    (tester) async {
      await pump(tester);
      await fill(tester);
      auth.signInGate = Completer<SignInOutcome>();
      await tester.tap(find.text(AppStrings.login));
      await tester.pump();
      expect(find.text(AppStrings.signingIn), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(auth.signs, 1);
      auth.signInGate?.completeError(const NetworkFailure(), StackTrace.empty);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.network), findsOneWidget);
      expect(find.text(AppStrings.retry), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        ' secret ',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('validation and unauthorized errors stay friendly and inline', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(AppStrings.login));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.identifierRequired), findsOneWidget);
    expect(find.text(AppStrings.passwordRequired), findsOneWidget);
    expect(auth.signs, 0);
    await fill(tester);
    auth.signInFailure = const UnauthorizedFailure();
    await tester.tap(find.text(AppStrings.login));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.invalidCredentials), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    for (final keyboard in [false, true]) {
      testWidgets(
        '320x568, 2.5x text, $brightness, keyboard=$keyboard can scroll and submit',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 568);
          tester.platformDispatcher.textScaleFactorTestValue = 2.5;
          if (keyboard) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 240);
          }
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await pump(tester, brightness);
          expectLoginGradient(tester);
          expect(
            find.byType(LoginToolsIllustration),
            keyboard ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await fill(tester);
          final button = find.byType(FilledButton);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(keyboard ? 328 : 568));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          final toggle = tester.getSize(find.byType(IconButton));
          expect(toggle.width, greaterThanOrEqualTo(48));
          expect(toggle.height, greaterThanOrEqualTo(48));
          auth.signInFailure = const NetworkFailure();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(auth.signs, 1);
          await tester.ensureVisible(find.text(AppStrings.network));
          await tester.pumpAndSettle();
          expect(find.text(AppStrings.network), findsOneWidget);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(button).bottom,
            lessThanOrEqualTo(keyboard ? 328 : 568),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
