import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/localization/app_strings.dart';
import 'core/logging/app_logger.dart';
import 'features/auth/presentation/auth_dependencies.dart';

void main() {
  const logger = AppLogger();
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (_) => logger.boundaryFailure();
    PlatformDispatcher.instance.onError = (_, _) {
      logger.boundaryFailure();
      return true;
    };
    if (kReleaseMode) {
      ErrorWidget.builder = (_) =>
          const Material(child: Center(child: Text(AppStrings.unknown)));
    }
    try {
      final config = AppConfig.environment();
      runApp(
        ProviderScope(
          overrides: [configProvider.overrideWithValue(config)],
          child: const BookixoApp(),
        ),
      );
    } on FormatException {
      runApp(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text(AppStrings.config))),
        ),
      );
    }
  }, (_, _) => logger.boundaryFailure());
}
