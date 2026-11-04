import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/queue_item.dart';

/// In-memory demo adapter. It deliberately contains no endpoint assumptions.
class MockQueueRepository implements QueueRepository {
  MockQueueRepository()
    : _items = [
        const QueueItem(
          'sample-pending',
          AppStrings.sampleCustomer,
          AppStrings.sampleWait,
          queueNumber: 12,
        ),
        const QueueItem(
          'sample-in-progress',
          AppStrings.sampleCustomerInProgress,
          AppStrings.sampleService,
          queueNumber: 11,
          status: QueueBookingStatus.inProgress,
          assigneeFirstName: AppStrings.sampleStaff,
          assignedToCurrentUser: true,
          hasServices: true,
        ),
      ];

  final List<QueueItem> _items;
  var _nextQueueNumber = 13;
  var _nextBookingId = 1;

  @override
  bool get canCreateWalkIn => true;

  @override
  Future<List<QueueItem>> load(String tab) async {
    final status = switch (tab) {
      QueueTabSelector.pending => QueueBookingStatus.pending,
      QueueTabSelector.inProgress => QueueBookingStatus.inProgress,
      _ => null,
    };
    if (status == null) return [];
    return List.unmodifiable(_items.where((item) => item.status == status));
  }

  @override
  Future<CustomerLookup?> lookupCustomer(String phoneNumber) async {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.endsWith('0001')) {
      return const CustomerLookup(
        firstName: AppStrings.sampleCustomer,
        lastName: AppStrings.sampleLastName,
        gender: 'Female',
      );
    }
    return null;
  }

  @override
  Future<QueueItem> createWalkIn(NewBookingRequest request) async {
    final item = QueueItem(
      'walk-in-${_nextBookingId++}',
      '${request.firstName.trim()} ${request.lastName.trim()}'.trim(),
      AppStrings.sampleWait,
      queueNumber: _nextQueueNumber++,
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<QueueItem> start(String bookingId) async {
    final index = _items.indexWhere((item) => item.id == bookingId);
    if (index < 0 || _items[index].status != QueueBookingStatus.pending) {
      throw const ConflictFailure();
    }
    final current = _items[index];
    final updated = QueueItem(
      current.id,
      current.customer,
      current.service,
      queueNumber: current.queueNumber,
      status: QueueBookingStatus.inProgress,
      assigneeFirstName: AppStrings.sampleStaff,
      assignedToCurrentUser: true,
    );
    _items[index] = updated;
    return updated;
  }
}
