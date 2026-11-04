import '../../../core/errors/app_failure.dart';
import '../domain/booking_workspace.dart';
import 'booking_api_dto.dart';

const _bookingCurrencySymbol = '₹';

abstract final class BookingWorkspaceDto {
  static BookingDetails details(
    Object? value, {
    required String bookingId,
    required String customerName,
    required String status,
    required String assigneeName,
    String? fallbackAssigneeId,
  }) {
    final json = _map(value);
    final returnedId = json['bookingId'];
    if (returnedId != null &&
        BookingApiDto.identifier(returnedId) != bookingId) {
      throw const ContractFailure();
    }
    final assigneeId = json['assigneeId'] == null
        ? fallbackAssigneeId
        : BookingApiDto.identifier(json['assigneeId']);
    final serviceIds = _stringIds(json['serviceIds'], json['serviceId']);
    return BookingDetails(
      id: bookingId,
      customerName: _optionalText(json['appUserName']) ?? customerName,
      status: _optionalText(json['status']) ?? status,
      assigneeName: _optionalText(json['assigneeFirstName']) ?? assigneeName,
      assigneeId: assigneeId,
      serviceIds: serviceIds,
    );
  }

  static List<BookingService> services(Object? value) {
    final json = _map(value);
    final items = json['services'];
    if (items is! List) throw const ContractFailure();
    return List.unmodifiable([for (final item in items) _service(item)]);
  }

  static BookingDraft draft(Object? value) {
    final json = _map(value);
    final revision = BookingApiDto.integer(json['revision']);
    final status = _draftStatus(json['draftState']);
    final payload = _map(json['payload']);
    final rawLines = payload['serviceLines'];
    if (rawLines is! List) throw const ContractFailure();
    final lines = [for (final raw in rawLines) _draftLine(raw)];
    return BookingDraft(
      revision: revision,
      status: status,
      lines: lines,
      payloadFields: payload,
    );
  }

  static BookingDraftStatus draftStatus(Object? value) => _draftStatus(value);

  static OwnerCompletionContext completionContext({
    required Object? pricing,
    required BookingPaymentConfig paymentConfig,
    required int revision,
    required OwnerCompletionRequest request,
    required Map<String, String> assigneeNamesByServiceId,
  }) => OwnerCompletionContext(
    requestedDraftRevision: revision,
    request: request,
    paymentConfig: paymentConfig,
    pricing: pricing == null
        ? null
        : _pricing(pricing, assigneeNamesByServiceId),
  );

  static BookingPaymentConfig paymentConfig(Object? value) =>
      _paymentConfig(value);

  static BookingCompletionResult completion(Object? value) {
    final json = _map(value);
    return BookingCompletionResult(
      status: _draftStatus(json['draftState']),
      revision: BookingApiDto.integer(json['revision']),
    );
  }

  static BookingDraftLine _draftLine(Object? value) {
    final json = _map(value);
    final serviceId = BookingApiDto.identifier(json['serviceId']);
    final quantity = BookingApiDto.integer(json['quantity']);
    final discount = _number(json['additionalDiscountPercent']);
    final assigneeId = json['assigneeId'] == null
        ? null
        : BookingApiDto.identifier(json['assigneeId']);
    if (quantity < 1 || discount < 0 || discount > 100) {
      throw const ContractFailure();
    }
    return BookingDraftLine(
      serviceId: serviceId,
      serviceName: serviceId,
      quantity: quantity,
      additionalDiscountPercent: discount,
      assigneeId: assigneeId,
      assigneeName: '',
      payloadFields: json,
    );
  }

  static OwnerPricingResult _pricing(
    Object? value,
    Map<String, String> assigneeNamesByServiceId,
  ) {
    final json = _map(value);
    final lines = json['serviceLines'];
    final rules = json['appliedRules'];
    if (lines is! List ||
        rules is! List ||
        rules.any((item) => item is! String)) {
      throw const ContractFailure();
    }
    final activeMembership = json['hasActiveMembership'];
    final membershipApplied = json['membershipApplied'];
    final gstApplied = json['gstApplied'];
    if (activeMembership is! bool ||
        membershipApplied is! bool ||
        gstApplied is! bool) {
      throw const ContractFailure();
    }
    final taxMode = gstApplied ? json['gstTaxMode'] : null;
    final membershipName = json['activeMembershipName'];
    if ((taxMode != null && taxMode is! String) ||
        (membershipName != null && membershipName is! String)) {
      throw const ContractFailure();
    }
    return OwnerPricingResult(
      lines: [
        for (final item in lines) _pricingLine(item, assigneeNamesByServiceId),
      ],
      subtotal: _number(json['servicePrice']),
      employeeDiscount: _number(json['perServiceDiscountAmount']),
      otherDiscounts: _number(json['discountAmount']),
      gstAmount: gstApplied ? _number(json['gstAmount']) : 0,
      gstPercent: gstApplied ? _number(json['gstPercentage']) : 0,
      gstIncluded: gstApplied && taxMode == 'INCLUSIVE',
      gstApplied: gstApplied,
      finalAmount: _number(json['finalAmount']),
      appliedRules: rules.cast<String>(),
      hasActiveMembership: activeMembership,
      membershipApplied: membershipApplied,
      membershipName: membershipName is String ? membershipName : null,
    );
  }

  static OwnerPricingLine _pricingLine(
    Object? value,
    Map<String, String> assigneeNamesByServiceId,
  ) {
    final json = _map(value);
    final serviceName = json['serviceName'];
    if (serviceName is! String || serviceName.trim().isEmpty) {
      throw const ContractFailure();
    }
    return OwnerPricingLine(
      serviceId: BookingApiDto.identifier(json['serviceId']),
      serviceName: serviceName,
      quantity: BookingApiDto.integer(json['quantity']),
      assigneeName:
          assigneeNamesByServiceId[BookingApiDto.identifier(
            json['serviceId'],
          )] ??
          '',
      subtotal: _number(json['lineSubtotal']),
      // The backend sends null when no additional discount was applied.
      additionalDiscountPercent: _numberOrZero(
        json['additionalDiscountPercent'],
      ),
      additionalDiscountAmount: _numberOrZero(json['additionalDiscountAmount']),
    );
  }

  static BookingPaymentConfig _paymentConfig(Object? value) {
    final json = _map(value);
    final methods = json['paymentMethods'];
    if (methods is! List) throw const ContractFailure();
    final enabledModes = <BookingPaymentMode>[];
    final options = <BookingPaymentOption>[];
    for (final item in methods) {
      final method = _map(item);
      final code = method['code'];
      final name = method['name'];
      final enabled = method['enabled'];
      if (code is! String || name is! String || enabled is! bool) {
        throw const ContractFailure();
      }
      if (!enabled || code == 'WALLET') continue;
      final mode = switch (code) {
        'CASH' => BookingPaymentMode.cash,
        'CARD' => BookingPaymentMode.card,
        'UPI' => BookingPaymentMode.upi,
        'BOOKIXO' => BookingPaymentMode.bookixo,
        _ => null,
      };
      if (mode == null) continue;
      if (mode != BookingPaymentMode.card) {
        enabledModes.add(mode);
        continue;
      }
      final rawOptions = method['options'];
      if (rawOptions is! List) throw const ContractFailure();
      final optionStartIndex = options.length;
      for (final option in rawOptions) {
        final optionJson = _map(option);
        final optionCode = optionJson['code'];
        final optionName = optionJson['name'];
        final optionEnabled = optionJson['enabled'];
        if (optionCode is! String ||
            optionName is! String ||
            optionEnabled is! bool) {
          throw const ContractFailure();
        }
        if (optionEnabled) {
          options.add(
            BookingPaymentOption(code: optionCode, label: optionName),
          );
        }
      }
      if (options.length > optionStartIndex) enabledModes.add(mode);
    }
    return BookingPaymentConfig(
      currencySymbol: _bookingCurrencySymbol,
      enabledModes: enabledModes,
      cardOptions: options,
    );
  }

  static BookingDraftStatus _draftStatus(Object? value) {
    if (value is! String) throw const ContractFailure();
    return switch (value) {
      'EDITABLE' => BookingDraftStatus.editable,
      'COMPLETION_PENDING' => BookingDraftStatus.completionPending,
      'COMPLETION_RECOVERY_REQUIRED' =>
        BookingDraftStatus.completionRecoveryRequired,
      'COMPLETED' => BookingDraftStatus.completed,
      _ => throw const ContractFailure(),
    };
  }

  static BookingService _service(Object? value) {
    final json = _map(value);
    final rawId = json['id'];
    final name = json['name'];
    final bookable = json['isBookable'];
    if (name is! String || name.trim().isEmpty) {
      throw const ContractFailure();
    }
    if (bookable != null && bookable is! bool) {
      throw const ContractFailure();
    }
    return BookingService(
      id: BookingApiDto.identifier(rawId),
      name: name.trim(),
      parentId: _parentId(json['parentId']),
      isBookable: bookable != false,
    );
  }

  // Invalid optional relationships are roots, not a failed catalogue load.
  static String? _parentId(Object? value) {
    if (value is num &&
        value.isFinite &&
        value > 0 &&
        value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    if (value is String) {
      final id = value.trim();
      if (id.isEmpty) return null;
      final number = num.tryParse(id);
      if (number != null) return _parentId(number);
      return id;
    }
    return null;
  }

  static List<String> _stringIds(Object? values, Object? single) {
    if (values != null && values is! List) throw const ContractFailure();
    final ids = <String>[
      if (values is List)
        for (final value in values) BookingApiDto.identifier(value),
    ];
    if (single != null) ids.add(BookingApiDto.identifier(single));
    return List.unmodifiable(ids.toSet());
  }

  static double _number(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    throw const ContractFailure();
  }

  static double _numberOrZero(Object? value) =>
      value == null ? 0 : _number(value);

  static String? _optionalText(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw const ContractFailure();
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const ContractFailure();
    for (final key in value.keys) {
      if (key is! String) throw const ContractFailure();
    }
    return Map<String, Object?>.from(value);
  }
}
