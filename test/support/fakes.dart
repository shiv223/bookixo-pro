import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/time/session_clock.dart';
import 'package:bookixo_pro/features/auth/data/refresh_transport.dart';
import 'package:bookixo_pro/features/auth/data/secure_session_store.dart';
import 'package:bookixo_pro/features/auth/data/sign_in_response_dto.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/domain/auth_repository.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context_repository.dart';
import 'package:dio/dio.dart';

final testNow = DateTime.utc(2026, 10, 6);
String fakeJwt(Map<String, Object?> payload) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.test';
Map<String, Object?> authResponse({
  DateTime? at,
  int lifetime = 3600,
  List<String> groups = const ['OWNER'],
  Object userId = 5,
  String email = 'owner@example.test',
  String refresh = 'test-refresh',
  String salt = 'a',
}) {
  final exp =
      (at ?? testNow).add(Duration(seconds: lifetime)).millisecondsSinceEpoch ~/
      1000;
  return {
    'accessToken': fakeJwt({'exp': exp, 'salt': salt}),
    'idToken': fakeJwt({'exp': exp, 'cognito:groups': groups, 'salt': salt}),
    'refreshToken': refresh,
    'expiresIn': lifetime,
    'tokenType': 'Bearer',
    'userId': userId,
    'email': email,
  };
}

AuthSession sampleSession({
  DateTime? at,
  int lifetime = 3600,
  List<String> groups = const ['OWNER'],
  String userId = '5',
  String salt = 'a',
}) => (SignInResponseDto.parse(
  authResponse(
    at: at,
    lifetime: lifetime,
    groups: groups,
    userId: userId,
    salt: salt,
  ),
).toOutcome(at ?? testNow) as Authenticated).session;

class FakeClock implements SessionClock {
  FakeClock([DateTime? at]) : time = at ?? testNow;
  DateTime time;
  final List<({DateTime at, void Function() call, List<bool> cancelled})>
  scheduled = [];
  @override
  DateTime now() => time;
  @override
  void Function() schedule(Duration delay, void Function() callback) {
    final cancelled = [false];
    scheduled.add((at: time.add(delay), call: callback, cancelled: cancelled));
    return () => cancelled[0] = true;
  }

  void advance(Duration duration) {
    time = time.add(duration);
    final due = scheduled.where((entry) => !entry.at.isAfter(time)).toList();
    scheduled.removeWhere((entry) => !entry.at.isAfter(time));
    for (final entry in due) {
      if (!entry.cancelled[0]) entry.call();
    }
  }
}

class MemoryBackend implements SecureBackend {
  String? value;
  AppFailure? readFailure;
  AppFailure? writeFailure;
  AppFailure? deleteFailure;
  Completer<void>? writeGate;
  Completer<void>? deleteGate;
  int writes = 0;
  int deletes = 0;
  @override
  Future<String?> read() async {
    if (readFailure case final AppFailure failure) throw failure;
    return value;
  }

  @override
  Future<void> write(String newValue) async {
    writes++;
    await writeGate?.future;
    if (writeFailure case final AppFailure failure) throw failure;
    value = newValue;
  }

  @override
  Future<void> delete() async {
    deletes++;
    await deleteGate?.future;
    if (deleteFailure case final AppFailure failure) throw failure;
    value = null;
  }
}

typedef Reply = FutureOr<({int status, Object? body})> Function(
  RequestOptions request,
);

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.reply);
  final Reply reply;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await reply(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio stubClient(StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test/'))
      ..httpClientAdapter = adapter;

class FakeRefresh implements RefreshTransport {
  FakeRefresh(this.result);
  SignInOutcome result;
  AppFailure? failure;
  Completer<SignInOutcome>? gate;
  int calls = 0;
  @override
  Future<SignInOutcome> refresh(AuthSession session) async {
    calls++;
    if (failure case final AppFailure error) throw error;
    return gate == null ? result : await gate?.future ?? result;
  }
}

class FakeAuthRepository implements AuthRepository {
  AuthSession? restored;
  AppFailure? restoreFailure;
  AppFailure? signInFailure;
  AppFailure? refreshFailure;
  AppFailure? logoutFailure;
  SignInOutcome? signInResult;
  SignInOutcome? refreshResult;
  Completer<SignInOutcome>? signInGate;
  Completer<SignInOutcome>? refreshGate;
  Completer<AuthSession?>? restoreGate;
  int signs = 0;
  int renewals = 0;
  final refreshStarted = Completer<void>();
  int logouts = 0;
  String? submittedIdentifier;
  String? submittedPassword;
  @override
  Future<AuthSession?> restore() async {
    if (restoreFailure case final AppFailure error) throw error;
    return restoreGate == null ? restored : await restoreGate?.future;
  }

  @override
  Future<SignInOutcome> signIn(String identifier, String password) async {
    signs++;
    submittedIdentifier = identifier;
    submittedPassword = password;
    if (signInFailure case final AppFailure error) throw error;
    return await signInGate?.future ??
        signInResult ??
        Authenticated(sampleSession());
  }

  @override
  Future<SignInOutcome> refresh(AuthSession session) async {
    renewals++;
    if (!refreshStarted.isCompleted) refreshStarted.complete();
    if (refreshFailure case final AppFailure error) throw error;
    return await refreshGate?.future ??
        refreshResult ??
        Authenticated(sampleSession(salt: 'renewed'));
  }

  @override
  Future<void> logout() async {
    logouts++;
    if (logoutFailure case final AppFailure error) throw error;
    restored = null;
  }
}

class FakeShopRepository implements ShopContextRepository {
  AppFailure? failure;
  ShopContext result = ShopContext(const [Shop(15, 'Test salon')], 15);
  Completer<ShopContext>? gate;
  int calls = 0;
  @override
  Future<ShopContext> load() async {
    calls++;
    if (failure case final AppFailure error) throw error;
    return await gate?.future ?? result;
  }
}

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
