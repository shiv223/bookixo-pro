import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'crash_reporter.dart';

/// Allowlisted event logging; no exception, request or credential serialization.
class AppLogger {
  const AppLogger([this.reporter = const NoOpCrashReporter()]);
  final CrashReporter reporter;

  /// Temporary debug diagnostics: fixed field names and types, never values.
  void bookingPricingResponse(Object? response, {int? statusCode}) {
    if (!kDebugMode) return;
    const fields = [
      'serviceLines',
      'appliedRules',
      'hasActiveMembership',
      'membershipApplied',
      'gstApplied',
      'gstTaxMode',
      'activeMembershipName',
      'servicePrice',
      'perServiceDiscountAmount',
      'discountAmount',
      'gstAmount',
      'gstPercentage',
      'finalAmount',
    ];
    final diagnostic = <String, Object?>{
      'statusCode': statusCode,
      'bodyType': _responseType(response),
      if (response is Map)
        for (final field in fields)
          field: response.containsKey(field)
              ? _responseType(response[field])
              : 'missing',
    };
    if (response case {'serviceLines': final List lines}) {
      const lineFields = [
        'serviceId',
        'serviceName',
        'quantity',
        'lineSubtotal',
        'additionalDiscountPercent',
        'additionalDiscountAmount',
      ];
      diagnostic['serviceLineTypes'] = [
        for (final line in lines)
          if (line is Map)
            {
              for (final field in lineFields)
                field: line.containsKey(field)
                    ? _responseType(line[field])
                    : 'missing',
            }
          else
            _responseType(line),
      ];
    }
    developer.log(
      'Booking pricing response (values redacted): ${jsonEncode(diagnostic)}',
      name: 'BookixoPro',
    );
  }

  void bookingPricingFailure(StackTrace stack) {
    if (!kDebugMode) return;
    developer.log(
      'Booking pricing/payment configuration failed',
      name: 'BookixoPro',
      stackTrace: stack,
    );
  }

  static String _responseType(Object? value) => switch (value) {
    null => 'null',
    String() => 'String (redacted)',
    bool() => 'bool',
    num() => 'number',
    List() => 'List(${value.length})',
    Map() => 'Map',
    _ => 'unsupported',
  };

  /// Never serialize image exceptions, stack strings, or presigned URLs.
  void logoFailure({required bool image}) {
    final context = image ? 'shop_logo_image' : 'shop_logo_api';
    developer.log(context, name: 'BookixoPro');
    reporter.record(context);
  }

  /// Fixed allowlisted contexts only; never serializes requests or identities.
  void menuFailure(StackTrace stack) => developer.log(
    'Menu refresh failed',
    name: 'BookixoPro',
    stackTrace: stack,
  );
  void upsellTile() =>
      developer.log('Web feature tile tapped', name: 'BookixoPro');
  void offersFailure(StackTrace stack) => developer.log(
    'Offers resource failed',
    name: 'BookixoPro',
    stackTrace: stack,
  );
  void dashboardFailure(StackTrace stack) => developer.log(
    'Dashboard resource failed',
    name: 'BookixoPro',
    stackTrace: stack,
  );
  void queueRealtimeFailure(StackTrace stack) => developer.log(
    'Queue realtime transport failed',
    name: 'BookixoPro',
    stackTrace: stack,
  );
  void offerScheduleDiagnostic() => developer.log(
    'Offer schedule ignored: unsupported or invalid fields',
    name: 'BookixoPro',
  );
  void upsellButton() =>
      developer.log('Web feature CTA tapped', name: 'BookixoPro');
  void boundaryFailure() {
    developer.log('Application boundary failure', name: 'BookixoPro');
    reporter.record('application_boundary');
  }
}
