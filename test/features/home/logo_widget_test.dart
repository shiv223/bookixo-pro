import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/home/domain/shop_logo.dart';
import 'package:bookixo_pro/features/home/presentation/home_logo.dart';
import 'package:bookixo_pro/features/home/presentation/home_screen.dart';
import 'package:bookixo_pro/features/home/presentation/shop_logo_controller.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'logo_controller_test.dart';

// Generated 2x2 JPEG pixels, no external artwork or real URL/signature.
const jpeg =
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD8q3dpGLMSzE5JJySaKKK68X/vFT/E/wAyY7I//9k=';
const png =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAQSURBVBhXY2Bg+P+fARkAABz1Af843v6+AAAAAElFTkSuQmCC';

class ImageHeaders extends Fake implements HttpHeaders {
  final Map<String, Object> values = {};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name] = value;
}

class ImageResponse extends Fake implements HttpClientResponse {
  ImageResponse(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

class ImageRequest extends Fake implements HttpClientRequest {
  ImageRequest(this.bytes);
  final Uint8List bytes;
  @override
  final ImageHeaders headers = ImageHeaders();
  @override
  Future<HttpClientResponse> close() async => ImageResponse(bytes);
}

class ImageClient extends Fake implements HttpClient {
  ImageClient(this.bytes);
  final Uint8List bytes;
  final List<ImageRequest> requests = [];
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    expect(url.scheme, 'https');
    expect(url.host, 'images.example.test');
    final request = ImageRequest(bytes);
    requests.add(request);
    return request;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLogoRepository repository;
  late LogoLogger logger;
  late ProviderContainer container;
  setUp(() {
    repository = FakeLogoRepository();
    logger = LogoLogger();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        menuScopeProvider.overrideWithValue(const MenuScope('5', null, 15)),
        clockProvider.overrideWithValue(FakeClock()),
        shopLogoRepositoryProvider.overrideWithValue(repository),
        appLoggerProvider.overrideWithValue(logger),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    debugNetworkImageHttpClientProvider = null;
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() => container.read(authControllerProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HomeProfile(
                  shopLabel: 'Synthetic salon',
                  selectedSalonName: 'Synthetic salon',
                ),
                HomeLogoNotice(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'API loading then 204 retains default and original rounded geometry',
    (tester) async {
      repository.gate = Completer();
      await pump(tester);
      expect(find.byType(DefaultHomeLogo), findsOneWidget);
      expect(tester.getSize(find.byType(HomeLogo)), const Size(42, 42));
      final crop = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(crop.borderRadius, BorderRadius.circular(AppTokens.controlRadius));
      repository.gate?.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(DefaultHomeLogo), findsOneWidget);
      expect(find.text(AppStrings.logoUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('API failure leaves default and a nonblocking Retry', (
    tester,
  ) async {
    repository.failure = const ForbiddenFailure();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DefaultHomeLogo), findsOneWidget);
    expect(find.text(AppStrings.logoUnavailable), findsOneWidget);
    expect(
      container.read(shopLogoControllerProvider).error,
      isA<ForbiddenFailure>(),
    );
    repository.failure = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(repository.calls, hasLength(2));
    expect(find.text(AppStrings.logoUnavailable), findsNothing);
  });
  for (final entry in {'jpeg': jpeg, 'png': png}.entries) {
    testWidgets(
      '${entry.key} bytes actually decode; external fetch carries NO auth headers',
      (tester) async {
        final client = ImageClient(base64Decode(entry.value));
        debugNetworkImageHttpClientProvider = () => client;
        try {
          repository.result = ShopLogo(
            Uri.parse(
              'https://images.example.test/${entry.key}?synthetic=fixture',
            ),
          );
          await pump(tester);
          await tester.runAsync(() async {
            // Wait for the decoder, not a live network or wall-clock lifetime.
            await container.read(shopLogoControllerProvider.future);
          });
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () async => Future<void>.delayed(Duration.zero),
            );
            await tester.pump();
            final decoded = tester
                .widgetList<RawImage>(find.byType(RawImage))
                .where(
                  (image) => image.image != null && image.fit == BoxFit.cover,
                );
            if (decoded.isNotEmpty &&
                find.byType(DefaultHomeLogo).evaluate().isEmpty) {
              break;
            }
          }
          expect(client.requests, hasLength(1));
          expect(client.requests.single.headers.values, isEmpty);
          final image = tester.widget<Image>(
            find
                .descendant(
                  of: find.byType(RemoteHomeLogo),
                  matching: find.byType(Image),
                )
                .first,
          );
          expect(image.fit, BoxFit.cover);
          expect(image.semanticLabel, AppStrings.shopLogo);
          expect(find.byType(DefaultHomeLogo), findsNothing);
          expect(logger.events, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          debugNetworkImageHttpClientProvider = null;
        }
      },
    );
  }
  testWidgets(
    'decode failure is logged only as fixed context with fallback and Retry',
    (tester) async {
      final client = ImageClient(Uint8List.fromList([1, 2, 3, 4]));
      debugNetworkImageHttpClientProvider = () => client;
      try {
        repository.result = ShopLogo(
          Uri.parse('https://images.example.test/bad?synthetic=do-not-log'),
        );
        await pump(tester);
        for (var i = 0; i < 20 && logger.events.isEmpty; i++) {
          await tester.runAsync(
            () async => Future<void>.delayed(Duration.zero),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byType(DefaultHomeLogo), findsOneWidget);
        expect(find.text(AppStrings.logoUnavailable), findsOneWidget);
        expect(logger.events, ['image']);
        expect(repository.calls, hasLength(1));
        expect(tester.takeException(), isNull);
        expect(
          container.read(shopLogoControllerProvider).error.toString(),
          'LogoImageFailure',
        );
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
}
