import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/booking_repository.dart';
import '../domain/booking_workspace.dart';

/// Local-only fixture adapter; it contains no HTTP client, URLs or endpoint
/// strings. The unresolved draft-save authorization contract must never be
/// wired to a production client by this feature.
class MockBookingRepository implements BookingRepository {
  MockBookingRepository({
    this.completionBehavior = MockCompletionBehavior.normal,
    this.ownLineRevisionConflictsToInject = 0,
    this.concurrentLineOnInjectedConflict,
    this.completionFailure,
    this.failCompletionOnce = false,
  }) {
    _drafts['sample-in-progress'] = BookingDraft(
      revision: 1,
      status: BookingDraftStatus.editable,
      lines: const [
        BookingDraftLine(
          serviceId: 'service-cut',
          serviceName: 'Hair cut',
          quantity: 1,
          additionalDiscountPercent: 0,
          assigneeId: 'mock-staff-rahul',
          assigneeName: 'Rahul',
        ),
      ],
    );
  }

  final MockCompletionBehavior completionBehavior;
  int ownLineRevisionConflictsToInject;
  final BookingDraftLine? concurrentLineOnInjectedConflict;
  AppFailure? completionFailure;
  final bool failCompletionOnce;
  final Map<String, BookingDraft> _drafts = {};
  final Map<String, BookingPaymentMode> _completionModes = {};
  var _recoveryUsed = false;
  var _completionFailureUsed = false;
  int ownLineSaveAttempts = 0;
  int draftReadCount = 0;
  int completeCallCount = 0;
  int? lastCompleteExpectedRevision;
  BookingPaymentDraft? lastSavedPayment;
  final List<String> operationLog = [];

  static final _services = List<BookingService>.unmodifiable([
    const BookingService(id: 'service-cut', name: 'Hair cut', usual: true),
    const BookingService(id: 'service-style', name: 'Blow dry', usual: true),
    const BookingService(id: 'service-color', name: 'Hair colour'),
    const BookingService(id: 'service-facial', name: 'Facial'),
  ]);

  @override
  Future<BookingDetails> loadDetails(String bookingId) async {
    if (bookingId.isEmpty) throw const NotFoundFailure();
    return BookingDetails(
      id: bookingId,
      customerName: bookingId == 'sample-in-progress'
          ? AppStrings.sampleCustomerInProgress
          : AppStrings.sampleCustomer,
      status: bookingId == 'sample-in-progress' ? 'IN_PROGRESS' : 'PENDING',
      assigneeName: 'Taylor',
    );
  }

  @override
  Future<BookingActor> resolveActor(String fallbackActorId) async =>
      BookingActor(id: fallbackActorId, name: AppStrings.sampleStaff);

  @override
  Future<BookingDraft?> loadDraft(String bookingId) async {
    draftReadCount++;
    return _drafts[bookingId];
  }

  @override
  Future<List<BookingService>> loadServices() async => _services;

  @override
  Future<double> loadEmployeeDiscountLimit() async => 20;

  @override
  Future<OwnerCompletionContext> loadOwnerCompletionContext({
    required String bookingId,
    required int draftRevision,
    required List<BookingDraftLine> lines,
  }) async => OwnerCompletionContext(
    request: OwnerCompletionRequest(
      bookingId: bookingId,
      draftRevision: draftRevision,
      lines: lines,
    ),
    requestedDraftRevision: draftRevision,
    paymentConfig: BookingPaymentConfig(
      currencySymbol: '₹',
      enabledModes: BookingPaymentMode.values,
      cardOptions: const [
        BookingPaymentOption(code: 'VISA', label: 'Visa'),
        BookingPaymentOption(code: 'MASTERCARD', label: 'Mastercard'),
      ],
    ),
    pricing: OwnerPricingResult(
      lines: const [
        OwnerPricingLine(
          serviceId: 'service-cut',
          serviceName: 'Hair cut',
          quantity: 1,
          assigneeName: 'Rahul',
          subtotal: 1200,
          additionalDiscountPercent: 0,
          additionalDiscountAmount: 0,
        ),
        OwnerPricingLine(
          serviceId: 'service-facial',
          serviceName: 'Facial',
          quantity: 1,
          assigneeName: 'Taylor',
          subtotal: 800,
          additionalDiscountPercent: 0,
          additionalDiscountAmount: 0,
        ),
      ],
      subtotal: 2000,
      employeeDiscount: 0,
      otherDiscounts: 0,
      gstAmount: 360,
      gstPercent: 18,
      gstIncluded: false,
      gstApplied: true,
      finalAmount: 2360,
      appliedRules: const ['Mock GST rule'],
      hasActiveMembership: false,
      membershipApplied: false,
    ),
  );

  @override
  Future<BookingDraft> saveOwnLines({
    required String bookingId,
    required String actorId,
    required int expectedRevision,
    required List<BookingDraftLine> ownLines,
  }) async {
    return _saveOwnLinesAttempt(
      bookingId: bookingId,
      actorId: actorId,
      expectedRevision: expectedRevision,
      ownLines: ownLines,
    );
  }

  Future<BookingDraft> _saveOwnLinesAttempt({
    required String bookingId,
    required String actorId,
    required int expectedRevision,
    required List<BookingDraftLine> ownLines,
  }) async {
    ownLineSaveAttempts++;
    if (ownLineRevisionConflictsToInject > 0) {
      ownLineRevisionConflictsToInject--;
      final concurrent = _currentDraft(bookingId);
      _drafts[bookingId] = BookingDraft(
        revision: concurrent.revision + 1,
        status: concurrent.status,
        lines: [...concurrent.lines, ?concurrentLineOnInjectedConflict],
      );
    }
    final current = _currentDraft(bookingId);
    if (current.revision != expectedRevision) {
      throw const ConflictFailure(isRevisionConflict: true);
    }
    if (ownLines.any((line) => line.assigneeId != actorId)) {
      throw const ForbiddenFailure();
    }
    final otherLines = current.lines
        .where((line) => line.assigneeId != actorId)
        .toList();
    final otherServiceIds = otherLines.map((line) => line.serviceId).toSet();
    final ownServiceIds = ownLines.map((line) => line.serviceId).toSet();
    if (ownLines.any((line) => otherServiceIds.contains(line.serviceId)) ||
        ownServiceIds.length != ownLines.length) {
      throw const ConflictFailure();
    }
    final saved = BookingDraft(
      revision: current.revision + 1,
      status: current.status,
      lines: [...otherLines, ...ownLines],
    );
    _drafts[bookingId] = saved;
    operationLog.add('own-lines-save:${saved.revision}');
    return saved;
  }

  @override
  Future<BookingDraft> saveOwnerDraft({
    required String bookingId,
    required int expectedRevision,
    required List<BookingDraftLine> lines,
    BookingPaymentDraft? payment,
  }) async {
    final current = _currentDraft(bookingId);
    if (current.revision != expectedRevision) {
      throw const ConflictFailure(isRevisionConflict: true);
    }
    final paymentOption = payment?.option;
    if (payment?.mode == BookingPaymentMode.card &&
        (paymentOption == null || paymentOption.isEmpty)) {
      throw const ValidationFailure({'paymentOption': 'required'});
    }
    final saved = BookingDraft(
      revision: current.revision + 1,
      status: current.status,
      lines: lines,
    );
    _drafts[bookingId] = saved;
    if (payment != null) {
      _completionModes[bookingId] = payment.mode;
      lastSavedPayment = payment;
    }
    operationLog.add('owner-draft-save:${saved.revision}');
    return saved;
  }

  @override
  Future<BookingCompletionResult> complete({
    required String bookingId,
    required int expectedRevision,
  }) async {
    completeCallCount++;
    lastCompleteExpectedRevision = expectedRevision;
    final current = _currentDraft(bookingId);
    if (current.revision != expectedRevision) {
      throw const ConflictFailure(isRevisionConflict: true);
    }
    operationLog.add('complete:$expectedRevision');
    final injectedFailure = completionFailure;
    if (injectedFailure != null &&
        (!failCompletionOnce || !_completionFailureUsed)) {
      _completionFailureUsed = true;
      throw injectedFailure;
    }
    if (completionBehavior == MockCompletionBehavior.requireRecoveryOnce &&
        !_recoveryUsed) {
      _recoveryUsed = true;
      final recovery = BookingDraft(
        revision: current.revision + 1,
        status: BookingDraftStatus.completionRecoveryRequired,
        lines: current.lines,
      );
      _drafts[bookingId] = recovery;
      return BookingCompletionResult(
        status: recovery.status,
        revision: recovery.revision,
      );
    }
    return _setCompletionStatus(bookingId, current);
  }

  @override
  Future<BookingCompletionResult> retryCompletion(String bookingId) async {
    final current = _currentDraft(bookingId);
    if (current.status != BookingDraftStatus.completionRecoveryRequired) {
      throw const ConflictFailure();
    }

    return _setCompletionStatus(bookingId, current);
  }

  @override
  Future<void> discardDraft({
    required String bookingId,
    required int expectedRevision,
  }) async {
    final current = _currentDraft(bookingId);
    if (current.revision != expectedRevision) {
      throw const ConflictFailure(isRevisionConflict: true);
    }
    _drafts.remove(bookingId);
  }

  BookingDraft _currentDraft(String bookingId) =>
      _drafts[bookingId] ??
      BookingDraft(revision: 0, status: BookingDraftStatus.editable, lines: []);

  BookingCompletionResult _setCompletionStatus(
    String bookingId,
    BookingDraft current,
  ) {
    final status = _completionModes[bookingId] == BookingPaymentMode.bookixo
        ? BookingDraftStatus.completionPending
        : BookingDraftStatus.completed;
    final updated = BookingDraft(
      revision: current.revision + 1,
      status: status,
      lines: current.lines,
    );
    _drafts[bookingId] = updated;
    return BookingCompletionResult(
      status: updated.status,
      revision: updated.revision,
    );
  }
}
