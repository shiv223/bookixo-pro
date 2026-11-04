import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/offers/data/offers_dto.dart';
import 'package:bookixo_pro/features/offers/domain/offer.dart';
import 'package:bookixo_pro/features/offers/domain/offer_schedule.dart';
import 'package:bookixo_pro/features/offers/presentation/offer_labels.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_test.dart';

void main() {
  final today = DateTime(2026, 10, 8);
  test('local date statuses inclusive bounds and Off precedence', () {
    Offer offer(Map<String, Object?> patch) =>
        OffersDto.offer({...offerJson(), ...patch});
    expect(
      offer({'startDate': '2026-10-08', 'endDate': '2026-10-08'}).status(today),
      OfferStatus.active,
    );
    expect(offer({'endDate': '2026-10-07'}).status(today), OfferStatus.expired);
    expect(
      offer({'startDate': '2026-10-09'}).status(today),
      OfferStatus.upcoming,
    );
    expect(
      offer({'isActive': false, 'endDate': '2026-10-07'}).status(today),
      OfferStatus.off,
    );
    expect(offer({'startDate': null}).status(today), OfferStatus.unavailable);
    expect(
      offer({'startDate': '2027-03-01'}).status(today),
      OfferStatus.unavailable,
    );
  });
  test('list aggregates raw rules per offer, independent of parent/date eligibility', () {
    final view = OffersView(
      offers: ResourceState(
        items: [
          OffersDto.offer({...offerJson(id: 2), 'title': 'Zulu'}),
          OffersDto.offer({...offerJson(id: 3), 'title': 'Alpha'}),
          OffersDto.offer({
            ...offerJson(id: 4),
            'title': 'Beta',
            'isActive': false,
          }),
          OffersDto.offer({
            ...offerJson(id: 5),
            'title': 'Dates',
            'startDate': null,
          }),
          OffersDto.offer({...offerJson(id: 6), 'endDate': '2026-10-07'}),
        ],
        last: true,
      ),
      rules: ResourceState(
        items: [
          OffersDto.rule({...ruleJson(id: 1), 'offerId': 2, 'isActive': true}),
          OffersDto.rule({...ruleJson(id: 2), 'offerId': 2, 'isActive': true}),
          OffersDto.rule({...ruleJson(id: 3), 'offerId': 3}),
          OffersDto.rule({...ruleJson(id: 4), 'offerId': 4, 'isActive': true}),
          OffersDto.rule({...ruleJson(id: 5), 'offerId': 4}),
          // Unknown schedules still contribute raw activity, but block export.
          OffersDto.rule({
            ...ruleJson(id: 6),
            'offerId': 6,
            'scheduleType': 'UNKNOWN',
            'isActive': true,
          }),
        ],
        last: true,
      ),
    );
    expect(view.visible(OfferFilter.active).map((o) => o.id), [4, 6, 2]);
    expect(view.visible(OfferFilter.inactive).map((o) => o.id), [3]);
    expect(view.visible(OfferFilter.all), hasLength(5));
    expect(view.listStatus(5), OfferListStatus.noRules);
    expect(view.canExport(4, today), false);
    expect(view.schedule(6).hasDiagnostics, true);
    expect(view.canExport(6, today), false);
  });
  test('all active parents with all false rules count zero active cards', () {
    final view = OffersView(
      offers: ResourceState(
        items: [
          for (var id = 1; id <= 4; id++) OffersDto.offer(offerJson(id: id)),
        ],
        last: true,
      ),
      rules: ResourceState(
        items: [
          for (var id = 1; id <= 4; id++)
            OffersDto.rule({...ruleJson(id: id), 'offerId': id}),
        ],
        last: true,
      ),
    );
    expect(view.visible(OfferFilter.active), isEmpty);
    expect(view.visible(OfferFilter.inactive), hasLength(4));
  });
  test('pending/failed/capped rules never yield definitive card activity', () {
    for (final rules in [
      ResourceState<ScheduleRule>(
        items: [
          OffersDto.rule({...ruleJson(), 'isActive': true}),
        ],
        loading: true,
      ),
      ResourceState<ScheduleRule>(
        items: [OffersDto.rule(ruleJson())],
        failure: const NetworkFailure(),
      ),
      ResourceState<ScheduleRule>(
        items: [OffersDto.rule(ruleJson())],
        capped: true,
      ),
    ]) {
      final view = OffersView(
        offers: ResourceState(
          items: [OffersDto.offer(offerJson())],
          last: true,
        ),
        rules: rules,
      );
      expect(view.listStatus(1), OfferListStatus.unavailable);
      expect(view.visible(OfferFilter.all), hasLength(1));
      expect(view.visible(OfferFilter.active), isEmpty);
      expect(view.visible(OfferFilter.inactive), isEmpty);
    }
  });
  test(
    'no rules is All-only and inactive rules do not replace export eligibility',
    () {
      final noRules = OffersView(
        offers: ResourceState(
          items: [OffersDto.offer(offerJson())],
          last: true,
        ),
        targets: ResourceState(
          items: [OffersDto.target(targetJson())],
          last: true,
        ),
        rules: ResourceState(last: true),
      );
      expect(noRules.listStatus(1), OfferListStatus.noRules);
      expect(noRules.visible(OfferFilter.active), isEmpty);
      expect(noRules.visible(OfferFilter.inactive), isEmpty);
      expect(noRules.canExport(1, today), true);
      final off = OffersView(
        offers: noRules.offers,
        targets: noRules.targets,
        rules: ResourceState(items: [OffersDto.rule(ruleJson())], last: true),
      );
      expect(off.listStatus(1), OfferListStatus.inactive);
      expect(off.canExport(1, today), true);
    },
  );
  test('discount formatting is promotional, drops zeros, no inferred currency/free', () {
    expect(OfferLabels.value(OffersDto.offer(offerJson())), '50');
    expect(
      OfferLabels.value(
        OffersDto.offer({
          ...offerJson(),
          'discountType': 'PERCENT',
          'discountValue': 12.5,
        }),
      ),
      '12.5%',
    );
    expect(OfferLabels.discount(OffersDto.offer(offerJson())), 'FLAT OFF');
    expect(
      OfferLabels.value(
        OffersDto.offer({...offerJson(), 'discountType': 'FREE'}),
      ),
      'Discount unavailable',
    );
  });
  test('target Combo ALL ANY and unknown neutral wording', () {
    for (final entry in [
      ('ALL', 'On Hair Cut and Hair Spa'),
      ('ANY', 'On Hair Cut or Hair Spa'),
      ('OTHER', 'On Hair Cut, Hair Spa'),
    ]) {
      final target = OffersDto.target({
        ...targetJson(),
        'targetType': 'SERVICE',
        'targetNames': ['Hair Cut', 'Hair Spa'],
        'serviceMatchMode': entry.$1,
      });
      expect(OfferLabels.target(target), entry.$2);
    }
    expect(
      OfferLabels.target(
        OffersDto.target({
          ...targetJson(),
          'targetType': 'SERVICE',
          'targetNames': ['Hair Cut', 'Hair Spa'],
          'isCombo': true,
        }),
      ),
      'Combo: Hair Cut + Hair Spa',
    );
  });
  test(
    'Sunday-first merging retains raw/isActive; duplicate semantics collapse',
    () {
      final rules = [
        for (var day = 1; day <= 7; day++)
          OffersDto.rule({...ruleJson(id: day), 'dayOfWeek': day}),
        OffersDto.rule(ruleJson(id: 20)),
        OffersDto.rule(ruleJson()),
      ];
      final summary = OfferSchedules.merge(rules);
      expect(summary.schedules, hasLength(1));
      expect(summary.schedules.single.days.toList(), [1, 2, 3, 4, 5, 6, 7]);
      expect(summary.schedules.single.sources, hasLength(9));
      expect(summary.schedules.single.sources.first.isActive, false);
      expect(OfferLabels.schedule(summary.schedules.single), 'Every day');
      expect(OfferLabels.days({2, 3, 4, 5, 6}), 'Weekdays');
      expect(OfferLabels.days({1, 7}), 'Weekends');
    },
  );
  test('modular windows: all-day, 59 invalid, 60 valid, equal invalid and overnight', () {
    for (final pair in [('00:00:00', '23:59:59'), ('08:00:00', '07:59:59')]) {
      expect(
        OfferSchedules.window(
          OffersDto.rule({
            ...ruleJson(),
            'startTime': pair.$1,
            'endTime': pair.$2,
          }),
        )?.allDay,
        true,
      );
    }
    for (final pair in [
      ('10:00:00', '10:00:59'),
      ('10:00:00', '10:00:00'),
      ('24:00:00', '11:00:00'),
    ]) {
      expect(
        OfferSchedules.window(
          OffersDto.rule({
            ...ruleJson(),
            'startTime': pair.$1,
            'endTime': pair.$2,
          }),
        ),
        isNull,
      );
    }
    expect(
      OfferSchedules.window(
        OffersDto.rule({
          ...ruleJson(),
          'startTime': '23:59:30',
          'endTime': '00:00:30',
        }),
      )?.allDay,
      false,
    );
  });
  test(
    'different windows separate; malformed and unknown explicitly diagnosed',
    () {
      final summary = OfferSchedules.merge([
        OffersDto.rule(ruleJson()),
        OffersDto.rule({...ruleJson(id: 2), 'dayOfWeek': 2}),
        OffersDto.rule({
          ...ruleJson(id: 3),
          'startTime': '10:00:00',
          'endTime': '12:00:00',
        }),
        OffersDto.rule({...ruleJson(id: 4), 'scheduleType': 'OTHER'}),
        OffersDto.rule({...ruleJson(id: 5), 'dayOfWeek': 8}),
        OffersDto.rule({
          ...ruleJson(id: 6),
          'scheduleType': 'DATE',
          'specificDate': '2026-02-30',
        }),
      ]);
      expect(summary.schedules, hasLength(2));
      expect(summary.hasDiagnostics, true);
      expect(
        OfferLabels.schedule(summary.schedules.last),
        'Sun · 10:00 to 12:00',
      );
    },
  );
  test('ALWAYS never displays Always; monthly/date and validity fallback', () {
    final summary = OfferSchedules.merge([
      OffersDto.rule({...ruleJson(), 'scheduleType': 'ALWAYS'}),
      OffersDto.rule({
        ...ruleJson(id: 2),
        'scheduleType': 'MONTHLY',
        'dayOfMonth': 15,
      }),
      OffersDto.rule({
        ...ruleJson(id: 3),
        'scheduleType': 'DATE',
        'specificDate': '2026-10-08',
      }),
    ]);
    expect(summary.schedules.map(OfferLabels.schedule), [
      'Every day',
      'Day 15 of each month',
      'October 8, 2026',
    ]);
    final offer = OffersDto.offer(offerJson());
    expect(
      OfferLabels.fullSchedule(offer, ScheduleSummary([], false)),
      OfferLabels.validity(offer),
    );
  });
}
