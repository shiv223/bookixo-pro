import 'dart:convert';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/features/queue/data/booking_api_dto.dart';
import 'package:bookixo_pro/features/queue/data/booking_api_repository.dart';
import 'package:bookixo_pro/features/queue/data/booking_workspace_dto.dart';
import 'package:bookixo_pro/features/queue/domain/queue_item.dart';
import 'package:bookixo_pro/features/queue/domain/booking_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('booking API DTOs', () {
    test('normalizes Indian phone numbers and only supported genders', () {
      expect(BookingApiDto.normalizeIndianPhone('98765 43210'), '9876543210');
      expect(
        BookingApiDto.normalizeIndianPhone('+91 98765-43210'),
        '9876543210',
      );
      expect(
        BookingApiDto.customerLookup({
          'exists': true,
          'firstName': 'Asha',
          'lastName': 'Patel',
          'gender': 'female',
          'dob': '2000-04-03',
        })?.gender,
        AppStrings.genderFemale,
      );
      expect(
        () => BookingApiDto.normalizeIndianPhone('123'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => BookingApiDto.normalizeGender('Other'),
        throwsA(isA<ContractFailure>()),
      );
    });

    test('queue parsing omits phone/address data and maps shop-local time', () {
      final item = BookingApiDto.queue([
        {
          'id': 328,
          'queueNumber': 12,
          'appUserId': 11,
          'appUserName': 'Asha Patel',
          'appUserIdentifier': '+919876543210',
          'addressLine1': 'private address',
          'bookingTime': '2026-10-24T07:44:17',
          'status': 'IN_PROGRESS',
          'assigneeId': 21,
          'assigneeFirstName': 'Siba',
          'serviceId': null,
          'serviceName': null,
        },
      ], currentShopUserId: '21').single;

      expect(item.id, '328');
      expect(item.customer, 'Asha Patel');
      expect(item.assignedToCurrentUser, isTrue);
      expect(item.hasServices, isFalse);
      expect(item.bookingTimeUtc, DateTime.utc(2026, 10, 24, 2, 14, 17));
      expect(item.toString(), isNot(contains('private address')));
      expect(
        () => BookingApiDto.queue([
          {
            'id': 1,
            'queueNumber': 1,
            'appUserName': 'Customer',
            'bookingTime': 'bad-time',
            'status': 'PENDING',
          },
        ], currentShopUserId: null),
        throwsA(isA<ContractFailure>()),
      );
    });

    group('booking workspace API DTOs', () {
      group('conditional GST pricing', () {
        OwnerPricingResult parse(Map<String, Object?> gstFields) {
          return BookingWorkspaceDto.completionContext(
            pricing: {
              'servicePrice': 100,
              'perServiceDiscountAmount': 0,
              'discountAmount': 0,
              'finalAmount': 100,
              'appliedRules': <String>[],
              'hasActiveMembership': false,
              'membershipApplied': false,
              'serviceLines': <Object?>[],
              ...gstFields,
            },
            paymentConfig: BookingWorkspaceDto.paymentConfig({
              'paymentMethods': [
                {'code': 'CASH', 'name': 'Cash', 'enabled': true},
              ],
            }),
            revision: 1,
            request: OwnerCompletionRequest(
              bookingId: '2',
              draftRevision: 1,
              lines: const [],
            ),
            assigneeNamesByServiceId: const {},
          ).pricing!;
        }

        for (final fields in <String, Map<String, Object?>>{
          'missing': {},
          'null': {
            'gstAmount': null,
            'gstPercentage': null,
            'gstTaxMode': null,
          },
          'invalid': {
            'gstAmount': 'invalid',
            'gstPercentage': 'invalid',
            'gstTaxMode': false,
          },
          'populated': {
            'gstAmount': 18,
            'gstPercentage': 18,
            'gstTaxMode': 'INCLUSIVE',
          },
        }.entries) {
          test('ignores ${fields.key} GST fields when not applied', () {
            final pricing = parse({'gstApplied': false, ...fields.value});
            expect(pricing.gstApplied, isFalse);
            expect(pricing.gstAmount, 0);
            expect(pricing.gstPercent, 0);
            expect(pricing.gstIncluded, isFalse);
            expect(pricing.finalAmount, 100);
          });
        }

        test('parses GST fields when applied', () {
          final pricing = parse({
            'gstApplied': true,
            'gstAmount': '18',
            'gstPercentage': 18,
            'gstTaxMode': 'INCLUSIVE',
          });
          expect(pricing.gstApplied, isTrue);
          expect(pricing.gstAmount, 18);
          expect(pricing.gstPercent, 18);
          expect(pricing.gstIncluded, isTrue);
        });

        for (final field in ['gstAmount', 'gstPercentage']) {
          for (final value in [null, 'invalid']) {
            test('rejects $field=$value when GST is applied', () {
              expect(
                () => parse({
                  'gstApplied': true,
                  'gstAmount': 18,
                  'gstPercentage': 18,
                  'gstTaxMode': 'EXCLUSIVE',
                  field: value,
                }),
                throwsA(isA<ContractFailure>()),
              );
            });
          }
        }
      });

      test('maps draft, services, pricing, and enabled payment methods', () {
        final services = BookingWorkspaceDto.services({
          'shopId': 1,
          'services': [
            {'id': 9, 'name': 'Cut', 'price': 1500, 'isBookable': true},
            {'id': 10, 'name': 'Hidden', 'price': 500, 'isBookable': false},
          ],
        });
        expect(services.map((service) => service.id), ['9', '10']);
        expect(services.first.name, 'Cut');
        expect(services.first.isBookable, isTrue);
        expect(services.last.isBookable, isFalse);

        final draft = BookingWorkspaceDto.draft({
          'draftState': 'EDITABLE',
          'revision': 4,
          'schemaVersion': 1,
          'payload': {
            'serviceLines': [
              {
                'serviceId': 9,
                'quantity': 1,
                'subtotalOverride': null,
                'additionalDiscountPercent': 0,
                'assigneeId': null,
              },
            ],
            'selectedMembershipId': null,
            'customField': 'preserved',
          },
        });
        expect(draft.revision, 4);
        expect(draft.lines.single.assigneeId, isNull);
        expect(draft.payloadFields['customField'], 'preserved');

        final context = BookingWorkspaceDto.completionContext(
          pricing: {
            'servicePrice': 1500,
            'perServiceDiscountAmount': 0,
            'discountAmount': 100,
            'gstAmount': 252,
            'gstPercentage': 18,
            'gstTaxMode': 'EXCLUSIVE',
            'gstApplied': true,
            'finalAmount': 1652,
            'appliedRules': ['Offer'],
            'hasActiveMembership': false,
            'membershipApplied': false,
            'activeMembershipName': null,
            'serviceLines': [
              {
                'serviceId': 9,
                'serviceName': 'Cut',
                'quantity': 1,
                'lineSubtotal': 1500,
                'additionalDiscountPercent': 0,
                'additionalDiscountAmount': 0,
              },
            ],
          },
          paymentConfig: BookingWorkspaceDto.paymentConfig({
            'paymentMethods': [
              {'code': 'CASH', 'name': 'Cash', 'enabled': true},
              {
                'code': 'CARD',
                'name': 'Card',
                'enabled': true,
                'options': [
                  {'code': 'VISA', 'name': 'Visa', 'enabled': true},
                  {'code': 'OLD', 'name': 'Old option', 'enabled': false},
                ],
              },
              {'code': 'WALLET', 'name': 'Wallet', 'enabled': true},
              {'code': 'UPI', 'name': 'UPI', 'enabled': false},
            ],
          }),
          revision: 4,
          request: OwnerCompletionRequest(
            bookingId: '5',
            draftRevision: 4,
            lines: const [],
          ),
          assigneeNamesByServiceId: const {'9': 'Taylor'},
        );

        expect(context.pricing?.finalAmount, 1652);
        expect(context.pricing?.lines.single.assigneeName, 'Taylor');
        expect(context.paymentConfig.enabledModes, [
          BookingPaymentMode.cash,
          BookingPaymentMode.card,
        ]);
        expect(context.paymentConfig.cardOptions.single.code, 'VISA');
        expect(context.paymentConfig.currencySymbol, '₹');
      });

      test('pricing treats null additional discounts as zero', () {
        final context = BookingWorkspaceDto.completionContext(
          pricing: {
            'servicePrice': 650.0,
            'perServiceDiscountAmount': 0.0,
            'discountAmount': 50.0,
            'gstAmount': 108.0,
            'gstPercentage': 18.0,
            'gstTaxMode': 'EXCLUSIVE',
            'gstApplied': true,
            'finalAmount': 708.0,
            'appliedRules': ['Offer applied'],
            'hasActiveMembership': false,
            'membershipApplied': false,
            'activeMembershipName': null,
            'serviceLines': [
              {
                'serviceId': 13,
                'serviceName': 'Silver Facial',
                'quantity': 1,
                'lineSubtotal': 650.0,
                'additionalDiscountPercent': null,
                'additionalDiscountAmount': null,
              },
            ],
          },
          paymentConfig: BookingWorkspaceDto.paymentConfig({
            'paymentMethods': [
              {'code': 'CASH', 'name': 'Cash', 'enabled': true},
            ],
          }),
          revision: 1,
          request: OwnerCompletionRequest(
            bookingId: '2',
            draftRevision: 1,
            lines: const [],
          ),
          assigneeNamesByServiceId: const {},
        );

        final line = context.pricing!.lines.single;
        expect(line.additionalDiscountPercent, 0);
        expect(line.additionalDiscountAmount, 0);
        expect(context.pricing!.finalAmount, 708);
      });
    });

    test(
      'live workspace saves preserve other lines and non-line payload values',
      () async {
        var draftReads = 0;
        final adapter = StubAdapter((request) {
          if (request.path.endsWith('completion-draft') &&
              request.method == 'GET') {
            draftReads++;
            if (draftReads == 1) {
              return (status: 404, body: {'message': 'No draft'});
            }
            return (
              status: 200,
              body: _draft(
                revision: 2,
                lines: [
                  _line(serviceId: 9, assigneeId: 22),
                  _line(serviceId: 10, assigneeId: 21),
                ],
                fields: {
                  'paymentMode': 'CASH',
                  'paymentOption': null,
                  'selectedMembershipId': 31,
                  'customFlag': 'retain-me',
                },
              ),
            );
          }
          if (request.path.endsWith('completion-draft') &&
              request.method == 'PUT') {
            final body = _requestMap(request.data);
            final payload = body['payload'] as Map<String, Object?>;
            final savedLines = payload['serviceLines'] as List<Object?>;
            expect(body['expectedRevision'], 2);
            expect(payload['paymentMode'], 'CASH');
            expect(payload['selectedMembershipId'], 31);
            expect(payload['customFlag'], 'retain-me');
            expect(savedLines, hasLength(2));
            expect(
              (savedLines.first as Map<String, Object?>)['assigneeId'],
              22,
            );
            expect(payload.containsKey('editedserviceprice'), isFalse);
            expect(payload.containsKey('totalAmount'), isFalse);
            return (
              status: 200,
              body: _draft(
                revision: 3,
                lines: [
                  _line(serviceId: 9, assigneeId: 22),
                  _line(serviceId: 10, assigneeId: 21),
                ],
                fields: {
                  'paymentMode': 'CASH',
                  'selectedMembershipId': 31,
                  'customFlag': 'retain-me',
                },
              ),
            );
          }
          if (request.path.endsWith('start-users')) {
            return (
              status: 200,
              body: [
                {
                  'shopUserId': 21,
                  'userId': 7,
                  'email': 'staff@example.test',
                  'name': 'Taylor Staff',
                },
                {
                  'shopUserId': 22,
                  'userId': 8,
                  'email': 'other@example.test',
                  'name': 'Alex Staff',
                },
              ],
            );
          }
          if (request.path.contains('/services/')) {
            return (
              status: 200,
              body: {
                'shopId': 1,
                'services': [
                  {'id': 9, 'name': 'Cut', 'price': 300, 'isBookable': true},
                  {'id': 10, 'name': 'Color', 'price': 500, 'isBookable': true},
                ],
              },
            );
          }
          return (status: 404, body: {'message': 'unexpected request'});
        });
        final repository = BookingApiRepository(
          client: stubClient(adapter),
          shopId: 1,
          userEmail: 'staff@example.test',
          canCreateWalkIn: true,
        );

        expect(await repository.loadDraft('45'), isNull);
        final saved = await repository.saveOwnLines(
          bookingId: '45',
          actorId: '21',
          expectedRevision: 2,
          ownLines: const [
            BookingDraftLine(
              serviceId: '10',
              serviceName: 'Color',
              quantity: 1,
              additionalDiscountPercent: 5,
              assigneeId: '21',
              assigneeName: 'Taylor Staff',
            ),
          ],
        );

        expect(saved.revision, 3);
        expect(saved.lines.map((line) => line.assigneeId), ['22', '21']);
        expect(
          adapter.requests
              .where((request) => request.path.endsWith('completion-draft'))
              .every(
                (request) => !request.queryParameters.containsKey('shopId'),
              ),
          isTrue,
        );
        final employeeSave = adapter.requests.firstWhere(
          (request) => request.method == 'PUT',
        );
        final savedPayload =
            _requestMap(employeeSave.data)['payload'] as Map<String, Object?>;
        expect(savedPayload.containsKey('manualTransactionId'), isFalse);
      },
    );

    test('details and actor use server shop-user identifiers', () async {
      final adapter = StubAdapter((request) {
        if (request.path.endsWith('start-users')) {
          return (
            status: 200,
            body: [
              {
                'shopUserId': 21,
                'userId': 5,
                'email': 'owner@example.test',
                'name': 'Taylor Owner',
              },
            ],
          );
        }
        if (request.path.endsWith('bookings/queue')) {
          return (
            status: 200,
            body: [
              {
                'id': 45,
                'queueNumber': 1,
                'appUserName': 'Jamie Customer',
                'bookingTime': '2026-10-24T07:44:17',
                'status': 'IN_PROGRESS',
                'assigneeId': 21,
                'assigneeFirstName': 'Taylor',
                'serviceId': 9,
                'serviceName': 'Cut',
              },
            ],
          );
        }
        if (request.path.endsWith('/45/details')) {
          return (
            status: 200,
            body: {
              'bookingId': 45,
              'appUserId': 17,
              'assigneeId': 21,
              'serviceId': 9,
              'serviceIds': [9, 10],
              'servicePrice': 300,
            },
          );
        }
        return (status: 404, body: {'message': 'unexpected request'});
      });
      final repository = BookingApiRepository(
        client: stubClient(adapter),
        shopId: 1,
        userEmail: 'OWNER@example.test',
        canCreateWalkIn: true,
      );

      await repository.load(QueueTabSelector.inProgress);
      final actor = await repository.resolveActor('5');
      final details = await repository.loadDetails('45');

      expect(actor.id, '21');
      expect(actor.name, 'Taylor Owner');
      expect(details.customerName, 'Jamie Customer');
      expect(details.assigneeId, '21');
      expect(details.assigneeName, 'Taylor');
      expect(details.serviceIds, ['9', '10']);
    });

    test(
      'owner pricing uses the server and reuses payment configuration',
      () async {
        var pricingCalls = 0;
        var paymentConfigCalls = 0;
        final adapter = StubAdapter((request) {
          if (request.path.endsWith('pricing/calculate')) {
            pricingCalls++;
            final body = _requestMap(request.data);
            expect(request.queryParameters['shopId'], 1);
            expect(body['serviceId'], 9);
            expect(body['selectedMembershipId'], isNull);
            expect(body['applyGst'], true);
            expect(body['services'], [
              {'serviceId': 9, 'quantity': 2, 'additionalDiscountPercent': 5.0},
            ]);
            return (
              status: 200,
              body: {
                'servicePrice': 300,
                'perServiceDiscountAmount': 15,
                'discountAmount': 0,
                'gstAmount': 0,
                'gstPercentage': 0,
                'gstTaxMode': 'EXCLUSIVE',
                'gstApplied': false,
                'finalAmount': 285,
                'appliedRules': <String>[],
                'hasActiveMembership': false,
                'membershipApplied': false,
                'activeMembershipName': null,
                'serviceLines': [
                  {
                    'serviceId': 9,
                    'serviceName': 'Cut',
                    'quantity': 2,
                    'lineSubtotal': 300,
                    'additionalDiscountPercent': 5,
                    'additionalDiscountAmount': 15,
                  },
                ],
              },
            );
          }
          if (request.path.endsWith('shop-payment-config')) {
            paymentConfigCalls++;
            return (
              status: 200,
              body: {
                'paymentMethods': [
                  {'code': 'CASH', 'name': 'Cash', 'enabled': true},
                  {
                    'code': 'CARD',
                    'name': 'Card',
                    'enabled': true,
                    'hasOptions': true,
                    'options': [
                      {'code': 'VISA', 'name': 'Visa', 'enabled': true},
                    ],
                  },
                ],
              },
            );
          }
          return (status: 404, body: {'message': 'unexpected request'});
        });
        final repository = BookingApiRepository(
          client: stubClient(adapter),
          shopId: 1,
          userEmail: 'owner@example.test',
          canCreateWalkIn: true,
        );
        const lines = [
          BookingDraftLine(
            serviceId: '9',
            serviceName: 'Cut',
            quantity: 2,
            additionalDiscountPercent: 5,
            assigneeId: '21',
            assigneeName: 'Taylor',
          ),
        ];

        final first = await repository.loadOwnerCompletionContext(
          bookingId: '45',
          draftRevision: 2,
          lines: lines,
        );
        final second = await repository.loadOwnerCompletionContext(
          bookingId: '45',
          draftRevision: 2,
          lines: lines,
        );

        expect(first.pricing?.finalAmount, 285);
        expect(second.paymentConfig.enabledModes, [
          BookingPaymentMode.cash,
          BookingPaymentMode.card,
        ]);
        expect(second.paymentConfig.currencySymbol, '₹');
        expect(pricingCalls, 2);
        expect(paymentConfigCalls, 1);
      },
    );

    test(
      'employee draft save surfaces revision conflict without mutation retry',
      () async {
        var draftReads = 0;
        var putAttempts = 0;
        final adapter = StubAdapter((request) {
          if (request.path.endsWith('completion-draft') &&
              request.method == 'GET') {
            draftReads++;
            return (
              status: 200,
              body: _draft(
                revision: draftReads == 1 ? 1 : 2,
                lines: [
                  _line(serviceId: 9, assigneeId: 21),
                  if (draftReads > 1) _line(serviceId: 10, assigneeId: 22),
                ],
                fields: {'custom': 'preserve'},
              ),
            );
          }
          if (request.path.endsWith('completion-draft') &&
              request.method == 'PUT') {
            putAttempts++;
            if (putAttempts == 1) {
              return (status: 409, body: {'message': 'stale'});
            }
            final body = _requestMap(request.data);
            final payload = body['payload'] as Map<String, Object?>;
            final lines = payload['serviceLines'] as List<Object?>;
            expect(body['expectedRevision'], 2);
            expect(lines, hasLength(2));
            expect(payload['custom'], 'preserve');
            return (
              status: 200,
              body: _draft(
                revision: 3,
                lines: [
                  _line(serviceId: 9, assigneeId: 21),
                  _line(serviceId: 10, assigneeId: 22),
                ],
                fields: {'custom': 'preserve'},
              ),
            );
          }
          if (request.path.endsWith('start-users')) {
            return (
              status: 200,
              body: [
                {
                  'shopUserId': 21,
                  'userId': 7,
                  'email': 'staff@example.test',
                  'name': 'Taylor Staff',
                },
                {
                  'shopUserId': 22,
                  'userId': 8,
                  'email': 'other@example.test',
                  'name': 'Alex Staff',
                },
              ],
            );
          }
          if (request.path.contains('/services/')) {
            return (
              status: 200,
              body: {
                'shopId': 1,
                'services': [
                  {'id': 9, 'name': 'Cut', 'isBookable': true},
                  {'id': 10, 'name': 'Color', 'isBookable': true},
                ],
              },
            );
          }
          return (status: 404, body: {'message': 'unexpected request'});
        });
        final repository = BookingApiRepository(
          client: stubClient(adapter),
          shopId: 1,
          userEmail: 'staff@example.test',
          canCreateWalkIn: true,
        );

        final save = repository.saveOwnLines(
          bookingId: '45',
          actorId: '21',
          expectedRevision: 1,
          ownLines: const [
            BookingDraftLine(
              serviceId: '9',
              serviceName: 'Cut',
              quantity: 2,
              additionalDiscountPercent: 0,
              assigneeId: '21',
            ),
          ],
        );

        await expectLater(save, throwsA(isA<ConflictFailure>()));
        expect(draftReads, 1);
        expect(putAttempts, 1);
      },
    );

    test(
      'owner draft payment, completion, and discard use confirmed contracts',
      () async {
        final adapter = StubAdapter((request) {
          if (request.path.endsWith('completion-draft') &&
              request.method == 'GET') {
            return (
              status: 200,
              body: _draft(
                revision: 5,
                lines: [_line(serviceId: 9, assigneeId: 21)],
                fields: {'applyGst': true, 'customField': 'keep'},
              ),
            );
          }
          if (request.path.endsWith('completion-draft') &&
              request.method == 'PUT') {
            final body = _requestMap(request.data);
            final payload = body['payload'] as Map<String, Object?>;
            expect(body['expectedRevision'], 5);
            expect(payload['paymentMode'], 'UPI');
            expect(payload['manualTransactionId'], 'txn-1');
            expect(payload['manualPaymentNote'], 'paid');
            expect(payload['customField'], 'keep');
            return (
              status: 200,
              body: _draft(
                revision: 6,
                lines: [_line(serviceId: 9, assigneeId: 21)],
                fields: {'draftState': 'EDITABLE'},
              ),
            );
          }
          if (request.path.endsWith('completion-draft/complete')) {
            expect(_requestMap(request.data)['expectedRevision'], 6);
            return (
              status: 200,
              body: {'draftState': 'COMPLETION_PENDING', 'revision': 7},
            );
          }
          if (request.method == 'DELETE' &&
              request.path.endsWith('completion-draft')) {
            expect(_requestMap(request.data)['expectedRevision'], 7);
            return (status: 204, body: null);
          }
          if (request.path.endsWith('start-users')) {
            return (
              status: 200,
              body: [
                {
                  'shopUserId': 21,
                  'userId': 7,
                  'email': 'staff@example.test',
                  'name': 'Taylor Staff',
                },
              ],
            );
          }
          if (request.path.contains('/services/')) {
            return (
              status: 200,
              body: {
                'shopId': 1,
                'services': [
                  {'id': 9, 'name': 'Cut', 'price': 300, 'isBookable': true},
                ],
              },
            );
          }
          return (status: 404, body: {'message': 'unexpected request'});
        });
        final repository = BookingApiRepository(
          client: stubClient(adapter),
          shopId: 1,
          userEmail: 'staff@example.test',
          canCreateWalkIn: true,
        );

        final saved = await repository.saveOwnerDraft(
          bookingId: '45',
          expectedRevision: 5,
          lines: const [
            BookingDraftLine(
              serviceId: '9',
              serviceName: 'Cut',
              quantity: 1,
              additionalDiscountPercent: 0,
              assigneeId: '21',
            ),
          ],
          payment: const BookingPaymentDraft(
            mode: BookingPaymentMode.upi,
            transactionId: ' txn-1 ',
            note: ' paid ',
          ),
        );
        expect(saved.revision, 6);
        final completion = await repository.complete(
          bookingId: '45',
          expectedRevision: saved.revision,
        );
        expect(completion.status, BookingDraftStatus.completionPending);
        expect(completion.revision, 7);
        await repository.discardDraft(bookingId: '45', expectedRevision: 7);
      },
    );

    test(
      'services-only owner saves always send a payment mode placeholder',
      () async {
        Map<String, Object?>? existingFields;
        final sentPayloads = <Map<String, Object?>>[];
        final adapter = StubAdapter((request) {
          if (request.path.endsWith('completion-draft') &&
              request.method == 'GET') {
            final fields = existingFields;
            if (fields == null) {
              return (
                status: 404,
                body: {
                  'message': 'No completion draft exists for this booking',
                },
              );
            }
            return (
              status: 200,
              body: _draft(
                revision: 2,
                lines: [_line(serviceId: 9, assigneeId: 21)],
                fields: fields,
              ),
            );
          }
          if (request.path.endsWith('completion-draft') &&
              request.method == 'PUT') {
            final body = _requestMap(request.data);
            sentPayloads.add(body['payload'] as Map<String, Object?>);
            return (
              status: 200,
              body: _draft(
                revision: 3,
                lines: [_line(serviceId: 9, assigneeId: 21)],
                fields: {'draftState': 'EDITABLE'},
              ),
            );
          }
          if (request.path.endsWith('start-users')) {
            return (
              status: 200,
              body: [
                {
                  'shopUserId': 21,
                  'userId': 7,
                  'email': 'staff@example.test',
                  'name': 'Taylor Staff',
                },
              ],
            );
          }
          if (request.path.contains('/services/')) {
            return (
              status: 200,
              body: {
                'shopId': 1,
                'services': [
                  {'id': 9, 'name': 'Cut', 'price': 300, 'isBookable': true},
                ],
              },
            );
          }
          return (status: 404, body: {'message': 'unexpected request'});
        });
        final repository = BookingApiRepository(
          client: stubClient(adapter),
          shopId: 1,
          userEmail: 'staff@example.test',
          canCreateWalkIn: true,
        );
        const lines = [
          BookingDraftLine(
            serviceId: '9',
            serviceName: 'Cut',
            quantity: 1,
            additionalDiscountPercent: 0,
            assigneeId: '21',
          ),
        ];

        await repository.saveOwnerDraft(
          bookingId: '329',
          expectedRevision: 0,
          lines: lines,
        );
        expect(sentPayloads.last['paymentMode'], 'CASH');

        existingFields = {
          'paymentMode': 'CARD',
          'paymentOption': 'VISA',
          'manualTransactionId': '',
          'manualPaymentNote': '',
        };
        await repository.saveOwnerDraft(
          bookingId: '329',
          expectedRevision: 2,
          lines: lines,
        );
        expect(sentPayloads.last['paymentMode'], 'CARD');
        expect(sentPayloads.last['paymentOption'], 'VISA');
      },
    );
  });

  test(
    'confirmed lookup, walk-in and start APIs use safe scoped contracts',
    () async {
      final adapter = StubAdapter((request) {
        if (request.method == 'GET' &&
            request.path.endsWith('lookup-app-user')) {
          return (
            status: 200,
            body: {
              'exists': true,
              'appUserId': 11,
              'phoneNumber': '+919876543210',
              'firstName': 'Asha',
              'lastName': 'Patel',
              'gender': 'Female',
              'dob': '2000-04-03',
            },
          );
        }

        if (request.method == 'POST' &&
            request.path.endsWith('bookings/walk-in')) {
          return (
            status: 200,
            body: {
              'bookingId': 328,
              'bookingReference': 'BK-328',
              'queueNumber': 12,
              'status': 'PENDING',
              'message': 'Created',
            },
          );
        }
        if (request.method == 'GET' &&
            request.path.endsWith('bookings/start-users')) {
          return (
            status: 200,
            body: [
              {
                'shopUserId': 21,
                'userId': 44,
                'email': 'staff@example.test',
                'name': 'Sibabrata Acharya',
              },
            ],
          );
        }
        if (request.method == 'PUT' &&
            request.path.endsWith('bookings/328/start')) {
          return (status: 200, body: null);
        }
        if (request.method == 'GET' &&
            request.path.endsWith('bookings/queue')) {
          return (
            status: 200,
            body: [
              {
                'id': 328,
                'queueNumber': 12,
                'appUserName': 'Asha Patel',
                'bookingTime': '2026-10-24T07:44:17',
                'status': 'IN_PROGRESS',
                'assigneeId': 21,
                'assigneeFirstName': 'Sibabrata',
                'serviceId': null,
                'serviceName': null,
              },
            ],
          );
        }
        return (status: 404, body: {'message': 'unexpected request'});
      });
      final repository = BookingApiRepository(
        client: stubClient(adapter),
        shopId: 1,
        userEmail: 'STAFF@example.test',
        canCreateWalkIn: true,
      );

      final lookup = await repository.lookupCustomer('98765 43210');
      expect(lookup?.firstName, 'Asha');
      final created = await repository.createWalkIn(
        const NewBookingRequest(
          phoneNumber: '9876543210',
          firstName: 'Asha',
          lastName: 'Patel',
        ),
      );
      expect(created.id, '328');
      final started = await repository.start(created.id);
      expect(started.status, QueueBookingStatus.inProgress);
      expect(started.assignedToCurrentUser, isTrue);

      final lookupRequest = adapter.requests.firstWhere(
        (request) => request.path.endsWith('lookup-app-user'),
      );
      expect(lookupRequest.queryParameters['phoneNumber'], '9876543210');
      expect(
        adapter.requests.any(
          (request) =>
              request.path.endsWith('bookings/start-users') &&
              request.queryParameters['shopId'] == 1,
        ),
        isTrue,
      );
      final createRequest = adapter.requests.firstWhere(
        (request) => request.method == 'POST',
      );
      final encodedBody = createRequest.data;
      final body = encodedBody is String
          ? jsonDecode(encodedBody) as Map<String, dynamic>
          : encodedBody as Map<String, Object?>;
      expect(body['shopId'], 1);
      expect(body['phoneNumber'], '9876543210');
      expect(body.containsKey('gender'), isFalse);
      expect(body['dateOfBirth'], isNull);
      final startRequest = adapter.requests.firstWhere(
        (request) => request.method == 'PUT',
      );
      expect(startRequest.queryParameters['shopId'], 1);
      expect(startRequest.queryParameters['assigneeId'], '21');
    },
  );

  test(
    'walk-in creation is blocked without the navigation feature key',
    () async {
      final adapter = StubAdapter((request) async => (status: 200, body: {}));
      final repository = BookingApiRepository(
        client: stubClient(adapter),
        shopId: 1,
        userEmail: 'staff@example.test',
        canCreateWalkIn: false,
      );

      await expectLater(
        repository.createWalkIn(
          const NewBookingRequest(
            phoneNumber: '9876543210',
            firstName: 'Asha',
            lastName: 'Patel',
          ),
        ),
        throwsA(isA<ForbiddenFailure>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );
}

Map<String, Object?> _draft({
  required int revision,
  required List<Map<String, Object?>> lines,
  Map<String, Object?> fields = const {},
}) => {
  'draftState': 'EDITABLE',
  'revision': revision,
  'schemaVersion': 1,
  'payload': {
    'serviceLines': lines,
    'additionalServiceNames': const <String>[],
    'applyGst': true,
    'selectedMembershipId': null,
    ...fields,
  },
};

Map<String, Object?> _line({required int serviceId, required int assigneeId}) =>
    {
      'serviceId': serviceId,
      'quantity': 1,
      'subtotalOverride': null,
      'additionalDiscountPercent': 0,
      'assigneeId': assigneeId,
    };

Map<String, Object?> _requestMap(Object? data) {
  if (data is String) return jsonDecode(data) as Map<String, Object?>;
  return Map<String, Object?>.from(data as Map);
}
