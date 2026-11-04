import '../../../core/errors/app_failure.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';

/// Validates transport structure; does not infer dates, modes or discount types.
abstract final class OffersDto {
  static Map<String, Object?> object(Object? value) {
    if (value is! Map<String, Object?>) throw const ContractFailure();
    return value;
  }

  static int integer(Object? value, {int minimum = 0}) {
    if (value is! int || value < minimum) throw const ContractFailure();
    return value;
  }

  static String text(Object? value) {
    if (value is! String || value.trim().isEmpty) throw const ContractFailure();
    return value.trim();
  }

  static bool boolean(Object? value) {
    if (value is! bool) throw const ContractFailure();
    return value;
  }

  static DateTime? date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static Offer offer(Object? body) {
    final json = object(body);
    final value = json['discountValue'];
    if (value is! num || !value.isFinite || value < 0) {
      throw const ContractFailure();
    }
    return Offer(
      id: integer(json['id'], minimum: 1),
      title: text(json['title']),
      discountType: text(json['discountType']),
      discountValue: value,
      isActive: boolean(json['isActive']),
      startDate: date(json['startDate']),
      endDate: date(json['endDate']),
    );
  }

  static OfferTarget target(Object? body) {
    final json = object(body);
    final ids = json['targetIds'];
    final names = json['targetNames'];
    if (ids is! List ||
        names is! List ||
        names.any((name) => name is! String)) {
      throw const ContractFailure();
    }
    final mode = json['serviceMatchMode'];
    if (mode != null && mode is! String) throw const ContractFailure();
    return OfferTarget(
      id: integer(json['id'], minimum: 1),
      offerId: integer(json['offerId'], minimum: 1),
      targetType: text(json['targetType']),
      serviceMatchMode: mode as String?,
      isCombo: boolean(json['isCombo']),
      targetIds: ids.map((id) => integer(id, minimum: 1)).toList(),
      targetNames: names
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList(),
      hasAnotherOfferForSameService: boolean(
        json['hasAnotherOfferForSameService'],
      ),
    );
  }

  static ScheduleRule rule(Object? body) {
    final json = object(body);
    int? optionalInt(String key) =>
        json[key] == null ? null : integer(json[key]);
    String? optionalText(String key) {
      final value = json[key];
      if (value != null && value is! String) throw const ContractFailure();
      return value as String?;
    }

    return ScheduleRule(
      id: integer(json['id'], minimum: 1),
      offerId: integer(json['offerId'], minimum: 1),
      scheduleType: text(json['scheduleType']),
      isActive: boolean(json['isActive']),
      dayOfWeek: optionalInt('dayOfWeek'),
      dayOfMonth: optionalInt('dayOfMonth'),
      specificDate: date(json['specificDate']),
      startTime: optionalText('startTime'),
      endTime: optionalText('endTime'),
      source: {
        for (final key in [
          'id',
          'offerId',
          'scheduleType',
          'isActive',
          'dayOfWeek',
          'dayOfMonth',
          'specificDate',
          'startTime',
          'endTime',
        ])
          key: json[key],
      },
    );
  }

  static ResourcePage<T> page<T>(
    Object? body,
    int expected,
    T Function(Object?) parse,
  ) {
    final json = object(body);
    final content = json['content'];
    if (content is! List ||
        integer(json['number']) != expected ||
        integer(json['size'], minimum: 1) != 100) {
      throw const ContractFailure();
    }
    return ResourcePage(
      content.map(parse).toList(),
      expected,
      100,
      integer(json['totalElements']),
      integer(json['totalPages']),
      boolean(json['last']),
    );
  }
}
