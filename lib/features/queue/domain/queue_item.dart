/// Price-free booking summary shared by the Pending and In progress queues.
class QueueItem {
  const QueueItem(
    this.id,
    this.customer,
    this.service, {
    this.queueNumber = 1,
    this.status = QueueBookingStatus.pending,
    this.assigneeFirstName,
    this.assignedToCurrentUser = false,
    this.hasServices = false,
    this.awaitingPayment = false,
    this.bookingTimeUtc,
  });

  final String id;
  final String customer;
  final String service;
  final int queueNumber;
  final QueueBookingStatus status;
  final String? assigneeFirstName;
  final bool assignedToCurrentUser;
  final bool hasServices;
  final bool awaitingPayment;
  final DateTime? bookingTimeUtc;
}

enum QueueBookingStatus { pending, inProgress }

abstract final class QueueTabSelector {
  static const pending = 'pending';
  static const inProgress = 'in-progress';
}

/// Returns the 10-digit Indian number, or null while the input is incomplete
/// or invalid. A typed or pasted `+91` is dropped because the backend adds it.
String? completeIndianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return digits;
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }
  return null;
}

/// Customer details required by the walk-in form; contains no pricing data.
class CustomerLookup {
  const CustomerLookup({
    required this.firstName,
    this.lastName = '',
    this.gender,
    this.dateOfBirth,
  });

  final String firstName;
  final String lastName;
  final String? gender;
  final DateTime? dateOfBirth;
}

/// Input to the confirmed walk-in API contract.
class NewBookingRequest {
  const NewBookingRequest({
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    this.gender,
    this.dateOfBirth,
  });

  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String? gender;
  final DateTime? dateOfBirth;
}

/// Repository boundary for queue and walk-in operations.
abstract interface class QueueRepository {
  bool get canCreateWalkIn;

  Future<List<QueueItem>> load(String tab);

  Future<CustomerLookup?> lookupCustomer(String phoneNumber);

  Future<QueueItem> createWalkIn(NewBookingRequest request);

  Future<QueueItem> start(String bookingId);
}
