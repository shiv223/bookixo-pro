import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('config requires absolute URL and normalizes slash', () {
    expect(
      AppConfig.parse('http://localhost:8080', debug: true).baseUrl,
      'http://localhost:8080/',
    );
    for (final url in [
      '',
      '/relative',
      'ftp://example.org',
      'https://u:p@host',
    ]) {
      expect(() => AppConfig.parse(url, debug: true), throwsFormatException);
    }
  });
  test('release only accepts HTTPS and never demo', () {
    expect(
      () => AppConfig.parse('http://localhost:8080/', debug: false),
      throwsFormatException,
    );
    expect(
      AppConfig.parse('https://example.org', debug: false).baseUrl,
      'https://example.org/',
    );
    expect(
      () => AppConfig.parse('https://example.org', debug: false, demo: true),
      throwsFormatException,
    );
  });
  test(
    'socket URL is explicit, optional, and follows API transport policy',
    () {
      expect(
        AppConfig.parse('http://localhost:8080', debug: true).socketBaseUrl,
        isNull,
      );
      expect(
        AppConfig.parse(
          'http://localhost:8080',
          debug: true,
          socketBaseUrl: 'http://localhost:8090/',
        ).socketBaseUrl,
        'http://localhost:8090',
      );
      expect(
        AppConfig.parse(
          'https://api.example.test',
          debug: false,
          socketBaseUrl: 'https://socket.example.test/',
        ).socketBaseUrl,
        'https://socket.example.test',
      );
      for (final url in [
        'http://socket.example.test',
        'https://user:password@socket.example.test',
        'https://socket.example.test?token=sample',
        'https://socket.example.test/gateway',
      ]) {
        expect(
          () => AppConfig.parse(
            'https://api.example.test',
            debug: false,
            socketBaseUrl: url,
          ),
          throwsFormatException,
        );
      }
    },
  );
}
