import 'package:flutter/foundation.dart';

/// Explicit deployment configuration; development transport is debug-only.
class AppConfig {
  const AppConfig._(this.baseUrl, this.demo, this.socketBaseUrl);

  factory AppConfig.parse(
    String input, {
    required bool debug,
    bool demo = false,
    String? socketBaseUrl,
  }) {
    final apiUri = _parseEndpoint(input, debug: debug, demo: demo);
    final socketInput = socketBaseUrl?.trim();
    final socketUri = switch (socketInput) {
      null || '' => null,
      final input => _parseEndpoint(input, debug: debug, demo: demo),
    };
    if (socketUri != null &&
        socketUri.path.isNotEmpty &&
        socketUri.path != '/') {
      throw const FormatException('Invalid deployment configuration');
    }
    if (!debug && demo) {
      throw const FormatException('Invalid deployment configuration');
    }
    final apiPath = apiUri.path.replaceAll(RegExp(r'/+$'), '');
    final normalizedSocket = socketUri?.replace(path: '').toString();
    return AppConfig._(
      apiUri.replace(path: '$apiPath/').toString(),
      demo,
      normalizedSocket,
    );
  }

  factory AppConfig.environment() => AppConfig.parse(
    const String.fromEnvironment('API_BASE_URL'),
    debug: kDebugMode,
    demo: const bool.fromEnvironment('DEMO_MODE'),
    socketBaseUrl: const String.fromEnvironment('SOCKET_BASE_URL'),
  );

  final String baseUrl;
  final bool demo;
  final String? socketBaseUrl;
  static const timeout = Duration(seconds: 15);

  static Uri _parseEndpoint(
    String input, {
    required bool debug,
    required bool demo,
  }) {
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme) ||
        (!debug && (uri.scheme != 'https' || demo))) {
      throw const FormatException('Invalid deployment configuration');
    }
    return uri;
  }
}
