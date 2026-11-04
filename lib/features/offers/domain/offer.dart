/// Promotional value, never a service price. Unconfirmed validity stays absent.
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.discountType,
    required this.discountValue,
    required this.isActive,
    this.startDate,
    this.endDate,
  });
  final int id;
  final String title;
  final String discountType;
  final num discountValue;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  bool get validDates {
    final start = startDate;
    final end = endDate;
    return start != null && end != null && !start.isAfter(end);
  }

  bool get knownDiscount =>
      (discountType == 'FLAT' || discountType == 'PERCENT') &&
      discountValue.isFinite &&
      discountValue >= 0;
  OfferStatus status(DateTime now) {
    if (!isActive) return OfferStatus.off;
    if (!validDates) return OfferStatus.unavailable;
    final today = DateTime(now.year, now.month, now.day);
    final start = startDate;
    final end = endDate;
    if (end != null && end.isBefore(today)) return OfferStatus.expired;
    if (start != null && start.isAfter(today)) return OfferStatus.upcoming;
    return OfferStatus.active;
  }
}

enum OfferStatus { active, off, expired, upcoming, unavailable }

enum OfferFilter { all, active, inactive }

/// Distinct records remain distinct even when their names match.
class OfferTarget {
  OfferTarget({
    required this.id,
    required this.offerId,
    required this.targetType,
    required this.serviceMatchMode,
    required this.isCombo,
    required List<int> targetIds,
    required List<String> targetNames,
    required this.hasAnotherOfferForSameService,
  }) : targetIds = List.unmodifiable(targetIds),
       targetNames = List.unmodifiable(targetNames);
  final int id;
  final int offerId;
  final String targetType;
  final String? serviceMatchMode;
  final bool isCombo;
  final List<int> targetIds;
  final List<String> targetNames;
  final bool hasAnotherOfferForSameService;
  bool get eligible =>
      targetType == 'SHOP' ||
      (targetType == 'SERVICE' && targetNames.isNotEmpty);
}

/// Source metadata is retained independently of the merged display schedule.
class ScheduleRule {
  ScheduleRule({
    required this.id,
    required this.offerId,
    required this.scheduleType,
    required this.isActive,
    this.dayOfWeek,
    this.dayOfMonth,
    this.specificDate,
    this.startTime,
    this.endTime,
    Map<String, Object?> source = const {},
  }) : source = Map.unmodifiable(source);
  final int id;
  final int offerId;
  final String scheduleType;
  final bool isActive;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final DateTime? specificDate;
  final String? startTime;
  final String? endTime;
  final Map<String, Object?> source;
}
