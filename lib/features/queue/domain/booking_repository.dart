import 'booking_workspace.dart';

/// Domain boundary for booking details, drafts, pricing and completion.
abstract interface class BookingRepository {
  Future<BookingDetails> loadDetails(String bookingId);

  Future<BookingActor> resolveActor(String fallbackActorId);

  Future<BookingDraft?> loadDraft(String bookingId);

  Future<List<BookingService>> loadServices();

  Future<double> loadEmployeeDiscountLimit();

  Future<OwnerCompletionContext> loadOwnerCompletionContext({
    required String bookingId,
    required int draftRevision,
    required List<BookingDraftLine> lines,
  });

  /// Reconciles a revision conflict by rereading and retrying once only.
  Future<BookingDraft> saveOwnLines({
    required String bookingId,
    required String actorId,
    required int expectedRevision,
    required List<BookingDraftLine> ownLines,
  });

  /// Saves an owner draft, including payment fields when completing.
  Future<BookingDraft> saveOwnerDraft({
    required String bookingId,
    required int expectedRevision,
    required List<BookingDraftLine> lines,
    BookingPaymentDraft? payment,
  });

  Future<BookingCompletionResult> complete({
    required String bookingId,
    required int expectedRevision,
  });

  Future<BookingCompletionResult> retryCompletion(String bookingId);

  Future<void> discardDraft({
    required String bookingId,
    required int expectedRevision,
  });
}
