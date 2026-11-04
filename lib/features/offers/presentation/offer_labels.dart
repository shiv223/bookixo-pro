import '../../../core/localization/app_strings.dart';
import '../domain/offer.dart';
import '../domain/offer_schedule.dart';
import 'offers_controller.dart';

/// Centralized display projections; no widget implements business rules.
abstract final class OfferLabels {
  static String listStatus(OfferListStatus status) => switch (status) {
    OfferListStatus.active => AppStrings.active,
    OfferListStatus.inactive => AppStrings.inactive,
    OfferListStatus.noRules => AppStrings.noRules,
    OfferListStatus.unavailable => AppStrings.ruleStatusUnavailable,
  };
  static String number(num value) => value
      .toString()
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirstMapped(
        RegExp(r'(\.\d*?[1-9])0+$'),
        (match) => match[1] ?? '',
      );
  static String value(Offer offer) => !offer.knownDiscount
      ? AppStrings.discountUnavailable
      : '${number(offer.discountValue)}${offer.discountType == 'PERCENT' ? '%' : ''}';
  static String discount(Offer offer) => !offer.knownDiscount
      ? ''
      : offer.discountType == 'PERCENT'
      ? AppStrings.offLabel
      : AppStrings.flatOff;
  static String status(OfferStatus status) => switch (status) {
    OfferStatus.active => AppStrings.active,
    OfferStatus.off => AppStrings.off,
    OfferStatus.expired => AppStrings.expired,
    OfferStatus.upcoming => AppStrings.upcoming,
    OfferStatus.unavailable => AppStrings.validityUnavailable,
  };
  static String note(OfferStatus status) => switch (status) {
    OfferStatus.off => AppStrings.offNote,
    OfferStatus.expired => AppStrings.expiredNote,
    OfferStatus.upcoming => AppStrings.upcomingNote,
    OfferStatus.unavailable => AppStrings.validityNote,
    OfferStatus.active => AppStrings.exportUnavailable,
  };
  static String target(OfferTarget target) {
    if (target.targetType == 'SHOP') return AppStrings.allServices;
    if (target.isCombo) {
      return '${AppStrings.comboPrefix}${target.targetNames.join(AppStrings.comboJoin)}';
    }
    final join = switch (target.serviceMatchMode) {
      'ALL' => AppStrings.andJoin,
      'ANY' => AppStrings.orJoin,
      _ => AppStrings.neutralJoin,
    };
    return '${AppStrings.onPrefix}${target.targetNames.join(join)}';
  }

  static String validity(Offer offer) {
    final start = offer.startDate;
    final end = offer.endDate;
    return !offer.validDates || start == null || end == null
        ? AppStrings.validityUnavailable
        : AppStrings.validityRange(start, end);
  }

  static String days(Set<int> days) {
    if (days.length == 7) return AppStrings.everyDay;
    if (days.length == 5 && days.containsAll({2, 3, 4, 5, 6})) {
      return AppStrings.weekdaysLabel;
    }
    if (days.length == 2 && days.containsAll({1, 7})) {
      return AppStrings.weekendsLabel;
    }
    return days
        .map((day) => AppStrings.weekdayShort[day - 1])
        .join(AppStrings.neutralJoin);
  }

  static String time(int seconds) {
    final hour = seconds ~/ 3600;
    final minute = (seconds % 3600) ~/ 60;
    final second = seconds % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}'
        '${second == 0 ? '' : ':${second.toString().padLeft(2, '0')}'}';
  }

  static String schedule(MergedSchedule schedule) {
    final label = switch (schedule.type) {
      'WEEKLY' => days(schedule.days),
      'MONTHLY' => AppStrings.monthlyDay(schedule.dayOfMonth ?? 0),
      'DATE' =>
        schedule.specificDate == null
            ? AppStrings.scheduleUnavailable
            : AppStrings.offerDate(schedule.specificDate ?? DateTime(0)),
      _ => AppStrings.everyDay,
    };
    return schedule.window.allDay
        ? label
        : '$label · ${AppStrings.timeWindow(time(schedule.window.start), time(schedule.window.end))}';
  }

  static String fullSchedule(Offer offer, ScheduleSummary summary) =>
      [...summary.schedules.map(schedule), validity(offer)].join(' · ');
}
