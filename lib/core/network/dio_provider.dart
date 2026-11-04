import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// No logging interceptor: request bodies and auth headers are sensitive.
Dio createDio(AppConfig config) => Dio(
  BaseOptions(
    baseUrl: config.baseUrl,
    connectTimeout: AppConfig.timeout,
    receiveTimeout: AppConfig.timeout,
    sendTimeout: AppConfig.timeout,
    followRedirects: false,
    headers: {'Accept': 'application/json'},
  ),
);
