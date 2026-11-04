import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/queue_item.dart';
import 'queue_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../shop_context/presentation/salon_switch_guard.dart';

enum CustomerLookupStatus { idle, loading, found, newCustomer, failed }

/// Presentation state for lookups and booking mutations.
class BookingFlowState {
  const BookingFlowState({
    this.lookupStatus = CustomerLookupStatus.idle,
    this.customer,
    this.isCreating = false,
    this.startingBookingId,
    this.createdBooking,
    this.failedStartBookingId,
    this.errorMessage,
  });

  final CustomerLookupStatus lookupStatus;
  final CustomerLookup? customer;
  final bool isCreating;
  final String? startingBookingId;
  final QueueItem? createdBooking;
  final String? failedStartBookingId;
  final String? errorMessage;

  BookingFlowState copyWith({
    CustomerLookupStatus? lookupStatus,
    CustomerLookup? customer,
    bool clearCustomer = false,
    bool? isCreating,
    String? startingBookingId,
    bool clearStartingBookingId = false,
    QueueItem? createdBooking,
    bool clearCreatedBooking = false,
    String? failedStartBookingId,
    bool clearFailedStartBookingId = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => BookingFlowState(
    lookupStatus: lookupStatus ?? this.lookupStatus,
    customer: clearCustomer ? null : customer ?? this.customer,
    isCreating: isCreating ?? this.isCreating,
    startingBookingId: clearStartingBookingId
        ? null
        : startingBookingId ?? this.startingBookingId,
    createdBooking: clearCreatedBooking
        ? null
        : createdBooking ?? this.createdBooking,
    failedStartBookingId: clearFailedStartBookingId
        ? null
        : failedStartBookingId ?? this.failedStartBookingId,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
}

final bookingFlowControllerProvider =
    NotifierProvider<BookingFlowController, BookingFlowState>(
      BookingFlowController.new,
    );

/// Repository operations live in this notifier rather than the widgets.
class BookingFlowController extends Notifier<BookingFlowState> {
  int _lookupGeneration = 0;
  int _epoch = 0;
  int _scopeRevision = 0;

  @override
  BookingFlowState build() {
    _scopeRevision = ref.watch(scopeRevisionProvider);
    _lookupGeneration++;
    _epoch++;
    return const BookingFlowState();
  }

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      ref.read(scopeRevisionProvider) == _scopeRevision;

  Future<void> lookupCustomer(String phoneNumber) async {
    // Lookups run as the number is typed, so only the latest one may update state.
    final generation = ++_lookupGeneration;
    final epoch = _epoch;
    state = state.copyWith(
      lookupStatus: CustomerLookupStatus.loading,
      clearCustomer: true,
      clearErrorMessage: true,
    );
    try {
      final customer = await ref
          .read(queueRepositoryProvider)
          .lookupCustomer(phoneNumber);
      if (!_current(epoch) || generation != _lookupGeneration) return;
      state = state.copyWith(
        lookupStatus: customer == null
            ? CustomerLookupStatus.newCustomer
            : CustomerLookupStatus.found,
        customer: customer,
        clearCustomer: customer == null,
      );
    } on AppFailure {
      if (!_current(epoch) || generation != _lookupGeneration) return;
      state = state.copyWith(
        lookupStatus: CustomerLookupStatus.failed,
        clearCustomer: true,
      );
    }
  }

  /// Drops the lookup result once the phone number no longer matches it.
  void clearLookup() {
    _lookupGeneration++;
    state = state.copyWith(
      lookupStatus: CustomerLookupStatus.idle,
      clearCustomer: true,
    );
  }

  /// Clears walk-in state left over from a previous New booking visit.
  void startNewBooking() {
    if (state.isCreating || state.startingBookingId != null) return;
    _lookupGeneration++;
    state = const BookingFlowState();
  }

  void showValidationError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  Future<QueueItem?> createWalkIn(
    NewBookingRequest request, {
    required bool startImmediately,
  }) async {
    if (state.isCreating || state.startingBookingId != null) return null;
    final epoch = _epoch;
    final finish = ref.read(salonSwitchGuardProvider).beginRequest();
    state = state.copyWith(isCreating: true, clearErrorMessage: true);
    try {
      final created = await ref
          .read(queueRepositoryProvider)
          .createWalkIn(request);
      if (!_current(epoch)) return null;
      state = state.copyWith(createdBooking: created, isCreating: false);
      if (startImmediately) return await startCreatedBooking();
      state = state.copyWith(clearCreatedBooking: true);
      return created;
    } on AppFailure catch (failure) {
      if (!_current(epoch)) return null;
      state = state.copyWith(isCreating: false, errorMessage: failure.message);
      return null;
    } finally {
      finish();
    }
  }

  Future<QueueItem?> startCreatedBooking() async {
    final created = state.createdBooking;
    if (created == null) return null;
    return _start(created.id);
  }

  Future<bool> startQueueBooking(String bookingId) async =>
      await _start(bookingId) != null;

  /// On failure `createdBooking` is kept so the walk-in start can be retried.
  Future<QueueItem?> _start(String bookingId) async {
    if (state.startingBookingId != null) return null;
    final epoch = _epoch;
    final finish = ref.read(salonSwitchGuardProvider).beginRequest();
    state = state.copyWith(
      startingBookingId: bookingId,
      clearErrorMessage: true,
      clearFailedStartBookingId: true,
    );
    try {
      final started = await ref.read(queueRepositoryProvider).start(bookingId);
      if (!_current(epoch)) return null;
      state = state.copyWith(
        clearStartingBookingId: true,
        clearFailedStartBookingId: true,
        clearErrorMessage: true,
        clearCreatedBooking: true,
      );
      return started;
    } on AppFailure {
      if (!_current(epoch)) return null;
      state = state.copyWith(
        clearStartingBookingId: true,
        failedStartBookingId: bookingId,
        errorMessage: AppStrings.startFailed,
      );
      return null;
    } finally {
      finish();
    }
  }
}
