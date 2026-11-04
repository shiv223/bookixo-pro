import '../../auth/domain/role_policy.dart';

/// Routes the booking workspace from server-issued role claims.
enum BookingViewerMode { employee, owner, unsupported }

abstract final class BookingRolePolicy {
  static BookingViewerMode modeFor(AppRole role) => switch (role) {
    AppRole.employee => BookingViewerMode.employee,
    AppRole.owner => BookingViewerMode.owner,
    AppRole.unknown => BookingViewerMode.unsupported,
  };
}

enum BookingDraftStatus {
  editable,
  completionPending,
  completionRecoveryRequired,
  completed,
}

enum BookingPaymentMode { cash, card, upi, bookixo }

/// Payment fields persisted as part of an owner draft before completion.
class BookingPaymentDraft {
  const BookingPaymentDraft({
    required this.mode,
    this.option,
    this.transactionId,
    this.note,
  });

  final BookingPaymentMode mode;
  final String? option;
  final String? transactionId;
  final String? note;
}

/// Service catalogue entry intentionally contains no price.
class BookingService {
  const BookingService({
    required this.id,
    required this.name,
    this.usual = false,
    this.parentId,
    this.isBookable = true,
  });

  final String id;
  final String name;
  final bool usual;
  final String? parentId;
  final bool isBookable;
}

/// A draft line is safe to share with employees: it contains no price fields.
class BookingDraftLine {
  const BookingDraftLine({
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.additionalDiscountPercent,
    this.assigneeId,
    this.assigneeName = '',
    this.payloadFields = const {},
  });

  final String serviceId;
  final String serviceName;
  final int quantity;
  final double additionalDiscountPercent;
  final String? assigneeId;
  final String assigneeName;
  final Map<String, Object?> payloadFields;

  BookingDraftLine copyWith({
    int? quantity,
    double? additionalDiscountPercent,
  }) => BookingDraftLine(
    serviceId: serviceId,
    serviceName: serviceName,
    quantity: quantity ?? this.quantity,
    additionalDiscountPercent:
        additionalDiscountPercent ?? this.additionalDiscountPercent,
    assigneeId: assigneeId,
    assigneeName: assigneeName,
    payloadFields: payloadFields,
  );
}

class BookingDetails {
  const BookingDetails({
    required this.id,
    required this.customerName,
    required this.status,
    required this.assigneeName,
    this.assigneeId,
    this.serviceIds = const [],
  });

  final String id;
  final String customerName;
  final String status;
  final String assigneeName;
  final String? assigneeId;
  final List<String> serviceIds;
}

class BookingDraft {
  BookingDraft({
    required this.revision,
    required this.status,
    required List<BookingDraftLine> lines,
    Map<String, Object?> payloadFields = const {},
  }) : lines = List.unmodifiable(lines),
       payloadFields = Map.unmodifiable(payloadFields);

  final int revision;
  final BookingDraftStatus status;
  final List<BookingDraftLine> lines;
  final Map<String, Object?> payloadFields;
}

class BookingPaymentOption {
  const BookingPaymentOption({required this.code, required this.label});

  final String code;
  final String label;
}

/// Payment methods enabled for the selected shop.
class BookingPaymentConfig {
  BookingPaymentConfig({
    required this.currencySymbol,
    required List<BookingPaymentMode> enabledModes,
    required List<BookingPaymentOption> cardOptions,
  }) : enabledModes = List.unmodifiable(enabledModes),
       cardOptions = List.unmodifiable(cardOptions);

  final String currencySymbol;
  final List<BookingPaymentMode> enabledModes;
  final List<BookingPaymentOption> cardOptions;
}

/// Structural family argument for debounced, server-calculated owner pricing.
class OwnerCompletionRequest {
  OwnerCompletionRequest({
    required this.bookingId,
    required this.draftRevision,
    required List<BookingDraftLine> lines,
  }) : lines = List.unmodifiable(lines),
       _lineKey = lines
           .map(
             (line) =>
                 '${line.serviceId}:${line.quantity}:${line.additionalDiscountPercent}',
           )
           .join('|');

  final String bookingId;
  final int draftRevision;
  final List<BookingDraftLine> lines;
  final String _lineKey;

  @override
  bool operator ==(Object other) =>
      other is OwnerCompletionRequest &&
      other.bookingId == bookingId &&
      other.draftRevision == draftRevision &&
      other._lineKey == _lineKey;

  @override
  int get hashCode => Object.hash(bookingId, draftRevision, _lineKey);
}

class BookingWorkspace {
  BookingWorkspace({
    required this.details,
    required this.draft,
    required List<BookingService> services,
    required this.employeeDiscountLimitPercent,
    this.actorId = '',
    this.actorName = '',
  }) : services = List.unmodifiable(services);

  final BookingDetails details;
  final BookingDraft draft;
  final List<BookingService> services;
  final double employeeDiscountLimitPercent;
  final String actorId;
  final String actorName;
}

class BookingActor {
  const BookingActor({required this.id, required this.name});

  final String id;
  final String name;
}

/// Owner-only, server-shaped pricing result. Never loaded for employees.
class OwnerPricingLine {
  const OwnerPricingLine({
    required this.serviceId,
    required this.serviceName,
    required this.quantity,
    required this.assigneeName,
    required this.subtotal,
    required this.additionalDiscountPercent,
    required this.additionalDiscountAmount,
  });

  final String serviceId;
  final String serviceName;
  final int quantity;
  final String assigneeName;
  final double subtotal;
  final double additionalDiscountPercent;
  final double additionalDiscountAmount;
}

class OwnerPricingResult {
  OwnerPricingResult({
    required List<OwnerPricingLine> lines,
    required this.subtotal,
    required this.employeeDiscount,
    required this.otherDiscounts,
    required this.gstAmount,
    required this.gstPercent,
    required this.gstIncluded,
    required this.gstApplied,
    required this.finalAmount,
    required List<String> appliedRules,
    required this.hasActiveMembership,
    required this.membershipApplied,
    this.membershipName,
  }) : lines = List.unmodifiable(lines),
       appliedRules = List.unmodifiable(appliedRules);

  final List<OwnerPricingLine> lines;
  final double subtotal;
  final double employeeDiscount;
  final double otherDiscounts;
  final double gstAmount;
  final double gstPercent;
  final bool gstIncluded;
  final bool gstApplied;
  final double finalAmount;
  final List<String> appliedRules;
  final bool hasActiveMembership;
  final bool membershipApplied;
  final String? membershipName;
}

/// Owner-only calculated pricing and enabled payment methods.
class OwnerCompletionContext {
  const OwnerCompletionContext({
    required this.pricing,
    required this.paymentConfig,
    required this.requestedDraftRevision,
    this.request,
  });

  final OwnerPricingResult? pricing;
  final BookingPaymentConfig paymentConfig;

  /// Local mock cache identity; this is not asserted to be a backend field.
  final int requestedDraftRevision;
  final OwnerCompletionRequest? request;
}

class BookingCompletionResult {
  const BookingCompletionResult({required this.status, required this.revision});

  final BookingDraftStatus status;
  final int revision;
}

/// Fixture switch used to exercise the recovery-required mock state.
enum MockCompletionBehavior { normal, requireRecoveryOnce }
