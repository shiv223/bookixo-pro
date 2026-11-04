import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/booking_repository.dart';
import '../domain/queue_item.dart';
import '../domain/booking_workspace.dart';
import 'booking_api_dto.dart';
import 'booking_workspace_dto.dart';

const bookingCreateFeatureKey = 'SHOP_BOOKINGS_CREATE';

/// Authenticated queue, walk-in and booking-workspace APIs.
class BookingApiRepository implements QueueRepository, BookingRepository {
  BookingApiRepository({
    required this.client,
    required this.shopId,
    required this.userEmail,
    required this.canCreateWalkIn,
    this.isCurrent,
  });

  final Dio client;
  final int? shopId;
  final String? userEmail;
  final bool Function()? isCurrent;
  @override
  final bool canCreateWalkIn;
  Future<List<BookingStaffMember>>? _staffRequest;
  Future<List<BookingService>>? _servicesRequest;
  Future<BookingPaymentConfig>? _paymentConfigRequest;
  final Map<String, QueueItem> _knownBookings = {};

  @override
  Future<List<QueueItem>> load(String tab) async {
    final status = switch (tab) {
      QueueTabSelector.pending => 'PENDING',
      QueueTabSelector.inProgress => 'IN_PROGRESS',
      _ => null,
    };
    if (status == null) return const [];
    final shop = _requireShop();
    final staffFuture = status == 'IN_PROGRESS'
        ? _loadStaff()
        : Future<List<BookingStaffMember>>.value(const []);
    final results = await Future.wait<Object?>([
      _get(
        'api/public/bookings/queue',
        queryParameters: {'shopId': shop, 'status': status},
      ),
      staffFuture,
    ]);
    final currentShopUserId = status == 'IN_PROGRESS'
        ? _currentStaffId(results[1] as List<BookingStaffMember>)
        : null;
    final items = BookingApiDto.queue(
      results[0],
      currentShopUserId: currentShopUserId,
    );
    for (final item in items) {
      _knownBookings[item.id] = item;
    }
    return items;
  }

  @override
  Future<CustomerLookup?> lookupCustomer(String phoneNumber) async {
    final normalized = BookingApiDto.normalizeIndianPhone(phoneNumber);
    final response = await _get(
      'api/public/bookings/lookup-app-user',
      queryParameters: {'phoneNumber': normalized},
    );
    return BookingApiDto.customerLookup(response);
  }

  @override
  Future<QueueItem> createWalkIn(NewBookingRequest request) async {
    if (!canCreateWalkIn) throw const ForbiddenFailure();
    final shop = _requireShop();
    final phoneNumber = BookingApiDto.normalizeIndianPhone(request.phoneNumber);
    final requestedGender = request.gender;
    final gender = requestedGender == null
        ? null
        : BookingApiDto.normalizeGender(requestedGender);
    final body = <String, Object?>{
      'shopId': shop,
      'phoneNumber': phoneNumber,
      'firstName': request.firstName.trim(),
      'lastName': request.lastName.trim(),
      'gender': gender,
      'dateOfBirth': _formatDate(request.dateOfBirth),
    };
    if (body['gender'] == null) body.remove('gender');
    final response = await _guard(() async {
      final result = await client.post<Object?>(
        'api/public/bookings/walk-in',
        data: body,
      );
      return result.data;
    });
    final json = _map(response);
    final bookingId = BookingApiDto.identifier(json['bookingId']);
    final queueNumber = BookingApiDto.integer(json['queueNumber']);
    final status = _status(json['status']);
    final name = '${request.firstName.trim()} ${request.lastName.trim()}'
        .trim();
    final item = QueueItem(
      bookingId,
      name,
      '',
      queueNumber: queueNumber,
      status: status,
    );
    _knownBookings[bookingId] = item;
    return item;
  }

  @override
  Future<QueueItem> start(String bookingId) async {
    final shop = _requireShop();
    final users = await _loadStaff();
    final assigneeId = _currentStaffId(users);
    final previous =
        _knownBookings[bookingId] ??
        (await load(QueueTabSelector.pending))
            .where((item) => item.id == bookingId)
            .firstOrNull;
    await _guard(() async {
      await client.put<Object?>(
        'api/public/bookings/$bookingId/start',
        queryParameters: {'shopId': shop, 'assigneeId': assigneeId},
      );
      return null;
    });

    final started = (await load(QueueTabSelector.inProgress))
        .where((item) => item.id == bookingId)
        .firstOrNull;
    if (started != null) return started;
    if (previous == null) throw const ContractFailure();
    final staff = users.singleWhere((item) => item.shopUserId == assigneeId);
    final fallback = QueueItem(
      previous.id,
      previous.customer,
      previous.service,
      queueNumber: previous.queueNumber,
      status: QueueBookingStatus.inProgress,
      assigneeFirstName: staff.name.split(' ').first,
      assignedToCurrentUser: true,
      hasServices: previous.hasServices,
      bookingTimeUtc: previous.bookingTimeUtc,
    );
    _knownBookings[bookingId] = fallback;
    return fallback;
  }

  @override
  Future<BookingDetails> loadDetails(String bookingId) async {
    final shop = _requireShop();
    final known = _knownBookings[bookingId];
    final response = await _get(
      'api/public/bookings/$bookingId/details',
      queryParameters: {'shopId': shop},
    );
    final json = _map(response);
    final assigneeId = json['assigneeId'] == null
        ? known?.assignedToCurrentUser == true
              ? (await resolveActor('')).id
              : null
        : BookingApiDto.identifier(json['assigneeId']);
    final staff = await _loadStaff();
    final assigneeName =
        known?.assigneeFirstName ??
        staff
            .where((member) => member.shopUserId == assigneeId)
            .map((member) => member.name)
            .firstOrNull ??
        '';
    final details = BookingWorkspaceDto.details(
      response,
      bookingId: bookingId,
      customerName: known?.customer ?? AppStrings.bookingCustomerFallback,
      status: known?.status == QueueBookingStatus.pending
          ? 'PENDING'
          : 'IN_PROGRESS',
      assigneeName: assigneeName,
      fallbackAssigneeId: assigneeId,
    );
    return details;
  }

  @override
  Future<BookingActor> resolveActor(String _) async {
    final staff = await _loadStaff();
    final current = _currentStaff(staff);
    return BookingActor(id: current.shopUserId, name: current.name);
  }

  @override
  Future<BookingDraft?> loadDraft(String bookingId) async {
    Object? response;
    try {
      final result = await client.get<Object?>(
        'api/bookings/$bookingId/completion-draft',
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      response = result.data;
    } on DioException catch (error, stack) {
      if (error.response?.statusCode == 404) return null;
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
    return _resolveDraftNames(BookingWorkspaceDto.draft(response));
  }

  @override
  Future<List<BookingService>> loadServices() {
    final pending = _servicesRequest;
    if (pending != null) return pending;
    final shop = _requireShop();
    final request = _get(
      'api/public/shops/shop/services/$shop',
      queryParameters: const {},
    ).then((value) => BookingWorkspaceDto.services(value));
    _servicesRequest = request;
    request.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_servicesRequest, request)) _servicesRequest = null;
      },
    );
    return request;
  }

  @override
  Future<double> loadEmployeeDiscountLimit() async => 100;

  @override
  Future<OwnerCompletionContext> loadOwnerCompletionContext({
    required String bookingId,
    required int draftRevision,
    required List<BookingDraftLine> lines,
  }) async {
    final shop = _requireShop();
    final request = OwnerCompletionRequest(
      bookingId: bookingId,
      draftRevision: draftRevision,
      lines: lines,
    );
    final paymentFuture = _loadPaymentConfig();
    final pricingFuture = lines.isEmpty
        ? Future<Object?>.value(null)
        : _post(
            'api/public/bookings/$bookingId/pricing/calculate',
            queryParameters: {'shopId': shop},
            body: {
              'serviceId': _serializedId(lines.first.serviceId, null),
              'services': [
                for (final line in lines)
                  {
                    'serviceId': _serializedId(line.serviceId, null),
                    'quantity': line.quantity,
                    'additionalDiscountPercent': line.additionalDiscountPercent,
                  },
              ],
              'selectedMembershipId': null,
              'applyGst': true,
            },
          );
    try {
      final results = await Future.wait<Object?>([
        pricingFuture,
        paymentFuture,
      ]);
      return BookingWorkspaceDto.completionContext(
        pricing: results[0],
        paymentConfig: results[1] as BookingPaymentConfig,
        revision: draftRevision,
        request: request,
        assigneeNamesByServiceId: {
          for (final line in lines) line.serviceId: line.assigneeName,
        },
      );
    } on AppFailure catch (_, stack) {
      const AppLogger().bookingPricingFailure(stack);
      rethrow;
    }
  }

  Future<BookingPaymentConfig> _loadPaymentConfig() {
    final pending = _paymentConfigRequest;
    if (pending != null) return pending;
    final request = _get(
      'api/shop-payment-config',
      queryParameters: {'shopId': _requireShop()},
    ).then(BookingWorkspaceDto.paymentConfig);
    _paymentConfigRequest = request;
    request.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_paymentConfigRequest, request)) {
          _paymentConfigRequest = null;
        }
      },
    );
    return request;
  }

  @override
  Future<BookingDraft> saveOwnLines({
    required String bookingId,
    required String actorId,
    required int expectedRevision,
    required List<BookingDraftLine> ownLines,
  }) async {
    final current = await loadDraft(bookingId) ?? _emptyDraft();
    return _saveOwnLinesAttempt(
      bookingId: bookingId,
      actorId: actorId,
      expectedRevision: expectedRevision,
      ownLines: ownLines,
      current: current,
    );
  }

  Future<BookingDraft> _saveOwnLinesAttempt({
    required String bookingId,
    required String actorId,
    required int expectedRevision,
    required List<BookingDraftLine> ownLines,
    required BookingDraft current,
  }) async {
    if (ownLines.any((line) => line.assigneeId != actorId)) {
      throw const ForbiddenFailure();
    }
    final otherLines = current.lines
        .where((line) => line.assigneeId != actorId)
        .toList(growable: false);
    final otherServiceIds = otherLines.map((line) => line.serviceId).toSet();
    final ownServiceIds = ownLines.map((line) => line.serviceId).toSet();
    if (ownServiceIds.length != ownLines.length ||
        ownLines.any((line) => otherServiceIds.contains(line.serviceId))) {
      throw const ConflictFailure();
    }
    return _saveDraft(
      bookingId: bookingId,
      expectedRevision: expectedRevision,
      lines: [...otherLines, ...ownLines],
      previous: current,
    );
  }

  @override
  Future<BookingDraft> saveOwnerDraft({
    required String bookingId,
    required int expectedRevision,
    required List<BookingDraftLine> lines,
    BookingPaymentDraft? payment,
  }) async {
    final current = await loadDraft(bookingId) ?? _emptyDraft();
    return _saveDraft(
      bookingId: bookingId,
      expectedRevision: expectedRevision,
      lines: lines,
      previous: current,
      payment: payment,
    );
  }

  Future<BookingDraft> _saveDraft({
    required String bookingId,
    required int expectedRevision,
    required List<BookingDraftLine> lines,
    required BookingDraft previous,
    BookingPaymentDraft? payment,
  }) async {
    final payload = _cloneMap(previous.payloadFields);
    payload['serviceLines'] = [
      for (final line in lines)
        {
          ..._cloneMap(line.payloadFields),
          'serviceId': _serializedId(
            line.serviceId,
            line.payloadFields['serviceId'],
          ),
          'quantity': line.quantity,
          'subtotalOverride': null,
          'additionalDiscountPercent': line.additionalDiscountPercent,
          'assigneeId': _serializedAssigneeId(line),
        },
    ];
    payload['additionalServiceNames'] = [
      for (final line in lines.skip(1)) line.serviceName,
    ];
    payload.putIfAbsent('selectedMembershipId', () => null);
    payload.putIfAbsent('applyGst', () => true);
    payload.putIfAbsent('manualFinalAmount', () => null);
    payload.putIfAbsent('selectedWalletId', () => null);
    payload.putIfAbsent('useWalletCredit', () => false);
    payload.putIfAbsent('walletAmount', () => null);
    payload.putIfAbsent('walletPackageQuantity', () => 1);
    payload.putIfAbsent('walletPackageAllocations', () => <Object?>[]);
    payload.putIfAbsent('selectedWalletPlanId', () => null);
    payload['printBill'] = false;
    if (payment != null) {
      payload['paymentMode'] = _paymentModeCode(payment.mode);
      payload['paymentOption'] = payment.option;
      payload['manualTransactionId'] = payment.transactionId?.trim() ?? '';
      payload['manualPaymentNote'] = payment.note?.trim() ?? '';
    } else if (payload['paymentMode'] == null) {
      // The backend rejects drafts without a payment mode, even when only
      // services change. Keep any saved choice, otherwise send the documented
      // placeholder; the owner picks the real mode when completing.
      payload['paymentMode'] = 'CASH';
    }
    final response = await _put(
      'api/bookings/$bookingId/completion-draft',
      queryParameters: const {},
      revisionConflict: true,
      body: {
        'expectedRevision': expectedRevision,
        'schemaVersion': 1,
        'payload': payload,
      },
    );
    return _resolveDraftNames(BookingWorkspaceDto.draft(response));
  }

  @override
  Future<BookingCompletionResult> complete({
    required String bookingId,
    required int expectedRevision,
  }) async {
    final response = await _post(
      'api/bookings/$bookingId/completion-draft/complete',
      queryParameters: const {},
      body: {'expectedRevision': expectedRevision},
    );
    return BookingWorkspaceDto.completion(response);
  }

  @override
  Future<BookingCompletionResult> retryCompletion(String bookingId) async {
    final draft = await loadDraft(bookingId);
    if (draft == null ||
        draft.status != BookingDraftStatus.completionRecoveryRequired) {
      throw const ConflictFailure();
    }
    return complete(bookingId: bookingId, expectedRevision: draft.revision);
  }

  @override
  Future<void> discardDraft({
    required String bookingId,
    required int expectedRevision,
  }) async {
    await _delete(
      'api/bookings/$bookingId/completion-draft',
      body: {'expectedRevision': expectedRevision},
    );
  }

  Future<BookingDraft> _resolveDraftNames(BookingDraft draft) async {
    final servicesFuture = loadServices();
    final staffFuture = _loadStaff();
    final results = await Future.wait<Object?>([servicesFuture, staffFuture]);
    final services = results[0] as List<BookingService>;
    final staff = results[1] as List<BookingStaffMember>;
    final serviceNames = {for (final item in services) item.id: item.name};
    final staffNames = {for (final item in staff) item.shopUserId: item.name};
    return BookingDraft(
      revision: draft.revision,
      status: draft.status,
      payloadFields: draft.payloadFields,
      lines: [
        for (final line in draft.lines)
          BookingDraftLine(
            serviceId: line.serviceId,
            serviceName: serviceNames[line.serviceId] ?? line.serviceName,
            quantity: line.quantity,
            additionalDiscountPercent: line.additionalDiscountPercent,
            assigneeId: line.assigneeId,
            assigneeName: line.assigneeId == null
                ? line.assigneeName
                : staffNames[line.assigneeId] ?? line.assigneeName,
            payloadFields: line.payloadFields,
          ),
      ],
    );
  }

  BookingDraft _emptyDraft() => BookingDraft(
    revision: 0,
    status: BookingDraftStatus.editable,
    lines: const [],
  );

  Map<String, Object?> _cloneMap(Map<String, Object?> source) => {
    for (final entry in source.entries) entry.key: _cloneValue(entry.value),
  };

  Object? _cloneValue(Object? value) => switch (value) {
    Map() => _cloneMap(_map(value)),
    List() => [for (final item in value) _cloneValue(item)],
    _ => value,
  };

  String _paymentModeCode(BookingPaymentMode mode) => switch (mode) {
    BookingPaymentMode.cash => 'CASH',
    BookingPaymentMode.card => 'CARD',
    BookingPaymentMode.upi => 'UPI',
    BookingPaymentMode.bookixo => 'BOOKIXO',
  };

  Object _serializedId(String value, Object? original) {
    if (original != null && BookingApiDto.identifier(original) == value) {
      final cloned = _cloneValue(original);
      if (cloned != null) return cloned;
    }
    return int.tryParse(value) ?? value;
  }

  Object? _serializedAssigneeId(BookingDraftLine line) {
    final id = line.assigneeId;
    return id == null
        ? null
        : _serializedId(id, line.payloadFields['assigneeId']);
  }

  Future<List<BookingStaffMember>> _loadStaff() {
    final pending = _staffRequest;
    if (pending != null) return pending;
    final shop = _requireShop();
    final request =
        _get(
          'api/public/bookings/start-users',
          queryParameters: {'shopId': shop},
        ).then((value) {
          if (value is! List) throw const ContractFailure();
          return List<BookingStaffMember>.unmodifiable(
            value.map<BookingStaffMember>(BookingApiDto.staffMember),
          );
        });
    _staffRequest = request;
    request.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_staffRequest, request)) _staffRequest = null;
      },
    );
    return request;
  }

  String _currentStaffId(List<BookingStaffMember> users) {
    return _currentStaff(users).shopUserId;
  }

  BookingStaffMember _currentStaff(List<BookingStaffMember> users) {
    final email = userEmail?.trim().toLowerCase();
    if (email == null || email.isEmpty) throw const ContractFailure();
    final matches = users
        .where((user) => user.email.toLowerCase() == email)
        .toList(growable: false);
    if (matches.length != 1) throw const ContractFailure();
    return matches.single;
  }

  int _requireShop() {
    final value = shopId;
    if (value == null || value <= 0) throw const ContractFailure();
    return value;
  }

  Future<Object?> _get(
    String path, {
    required Map<String, Object?> queryParameters,
  }) => _guard(() async {
    final response = await client.get<Object?>(
      path,
      queryParameters: queryParameters,
      options: Options(extra: {AuthInterceptor.safeRead: true}),
    );
    return response.data;
  });

  Future<Object?> _post(
    String path, {
    required Map<String, Object?> queryParameters,
    required Map<String, Object?> body,
  }) => _guard(() async {
    final response = await client.post<Object?>(
      path,
      queryParameters: queryParameters,
      data: body,
    );
    if (path.endsWith('/pricing/calculate')) {
      const AppLogger().bookingPricingResponse(
        response.data,
        statusCode: response.statusCode,
      );
    }
    return response.data;
  });

  Future<Object?> _put(
    String path, {
    required Map<String, Object?> queryParameters,
    required Map<String, Object?> body,
    bool revisionConflict = false,
  }) => _guard(() async {
    try {
      final response = await client.put<Object?>(
        path,
        queryParameters: queryParameters,
        data: body,
      );
      return response.data;
    } on DioException catch (error) {
      if (revisionConflict && error.response?.statusCode == 409) {
        throw const ConflictFailure(isRevisionConflict: true);
      }
      rethrow;
    }
  });

  Future<void> _delete(String path, {required Map<String, Object?> body}) =>
      _guard(() async {
        await client.delete<Object?>(path, data: body);
      });

  Future<T> _guard<T>(Future<T> Function() operation) async {
    if (isCurrent?.call() == false) throw const UnauthorizedFailure();
    try {
      final result = await operation();
      if (isCurrent?.call() == false) throw const UnauthorizedFailure();
      return result;
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on FormatException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on TypeError catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }

  Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const ContractFailure();
    for (final key in value.keys) {
      if (key is! String) throw const ContractFailure();
    }
    return Map<String, Object?>.from(value);
  }

  QueueBookingStatus _status(Object? value) {
    if (value is! String) throw const ContractFailure();
    return switch (value.toUpperCase()) {
      'PENDING' => QueueBookingStatus.pending,
      'IN_PROGRESS' => QueueBookingStatus.inProgress,
      _ => throw const ContractFailure(),
    };
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
