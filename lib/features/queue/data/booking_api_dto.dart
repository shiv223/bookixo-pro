import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/queue_item.dart';

abstract final class BookingApiDto {
  static List<QueueItem> queue(
    Object? value, {
    required String? currentShopUserId,
  }) {
    if (value is! List) throw const ContractFailure();
    return List.unmodifiable([
      for (final entry in value)
        _queueItem(entry, currentShopUserId: currentShopUserId),
    ]);
  }

  static QueueItem queueItem(Object? value) =>
      _queueItem(value, currentShopUserId: null);

  static CustomerLookup? customerLookup(Object? value) {
    final json = _map(value);
    final exists = json['exists'];
    if (exists is! bool) throw const ContractFailure();
    if (!exists) return null;
    final firstName = json['firstName'];
    if (firstName is! String || firstName.trim().isEmpty) {
      throw const ContractFailure();
    }
    final lastName = json['lastName'];
    final gender = json['gender'];
    final dob = json['dob'];
    return CustomerLookup(
      firstName: firstName,
      lastName: lastName is String ? lastName : '',
      gender: gender is String ? normalizeGender(gender) : null,
      dateOfBirth: dob is String && dob.isNotEmpty ? _date(dob) : null,
    );
  }

  static BookingStaffMember staffMember(Object? value) {
    final json = _map(value);
    final id = _identifier(json['shopUserId']);
    final email = json['email'];
    final name = json['name'];
    if (id == null ||
        email is! String ||
        email.trim().isEmpty ||
        (name != null && name is! String)) {
      throw const ContractFailure();
    }
    return BookingStaffMember(
      shopUserId: id,
      email: email.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : email,
    );
  }

  static String identifier(Object? value) {
    final id = _identifier(value);
    if (id == null) throw const ContractFailure();
    return id;
  }

  static int integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const ContractFailure();
  }

  static String normalizeGender(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'male' => AppStrings.genderMale,
      'female' => AppStrings.genderFemale,
      _ => throw const ContractFailure(),
    };
  }

  static String normalizeIndianPhone(String value) {
    return completeIndianPhone(value) ??
        (throw const ValidationFailure({'phoneNumber': 'invalid'}));
  }

  static DateTime shopLocalTimeAsUtc(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || value.contains(RegExp(r'(Z|[+-]\d{2}:?\d{2})$'))) {
      throw const ContractFailure();
    }
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).subtract(const Duration(hours: 5, minutes: 30));
  }

  static QueueItem _queueItem(
    Object? value, {
    required String? currentShopUserId,
  }) {
    final json = _map(value);
    final id = identifier(json['id']);
    final queueNumber = integer(json['queueNumber']);
    final statusText = json['status'];
    if (statusText is! String) throw const ContractFailure();
    final status = switch (statusText.toUpperCase()) {
      'PENDING' => QueueBookingStatus.pending,
      'IN_PROGRESS' => QueueBookingStatus.inProgress,
      _ => throw const ContractFailure(),
    };
    final customer = _customerName(json);
    final assigneeId = json['assigneeId'] == null
        ? null
        : identifier(json['assigneeId']);
    final assigneeFirstName = json['assigneeFirstName'];
    final serviceName = json['serviceName'];
    final bookingTime = json['bookingTime'];
    if ((assigneeFirstName != null && assigneeFirstName is! String) ||
        (serviceName != null && serviceName is! String) ||
        bookingTime is! String) {
      throw const ContractFailure();
    }
    final bookingTimeUtc = shopLocalTimeAsUtc(bookingTime);
    final hasServices = serviceName is String && serviceName.trim().isNotEmpty;
    return QueueItem(
      id,
      customer,
      hasServices ? serviceName : '',
      queueNumber: queueNumber,
      status: status,
      assigneeFirstName: assigneeFirstName is String ? assigneeFirstName : null,
      assignedToCurrentUser:
          currentShopUserId != null && currentShopUserId == assigneeId,
      hasServices: hasServices,
      bookingTimeUtc: bookingTimeUtc,
    );
  }

  static String _customerName(Map<String, Object?> json) {
    final name = json['appUserName'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    final first = json['appUserFirstName'];
    final last = json['appUserLastName'];
    final combined = [
      if (first is String && first.trim().isNotEmpty) first.trim(),
      if (last is String && last.trim().isNotEmpty) last.trim(),
    ].join(' ');
    if (combined.isEmpty) throw const ContractFailure();
    return combined;
  }

  static DateTime _date(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const ContractFailure();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String? _identifier(Object? value) {
    if (value is int) return value.toString();
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const ContractFailure();
    for (final key in value.keys) {
      if (key is! String) throw const ContractFailure();
    }
    return Map<String, Object?>.from(value);
  }
}

class BookingStaffMember {
  const BookingStaffMember({
    required this.shopUserId,
    required this.email,
    required this.name,
  });

  final String shopUserId;
  final String email;
  final String name;
}
