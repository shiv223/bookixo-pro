import 'dart:async';
import 'dart:io';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/widgets/app_inner_header.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/domain/role_policy.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/queue/data/mock_booking_repository.dart';
import 'package:bookixo_pro/features/queue/domain/booking_workspace.dart';
import 'package:bookixo_pro/features/queue/presentation/booking_details_screen.dart';
import 'package:bookixo_pro/features/queue/presentation/booking_workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class HeaderTestBookingRepository extends MockBookingRepository {
  Completer<BookingDetails>? detailsGate;

  @override
  Future<BookingDetails> loadDetails(String bookingId) =>
      detailsGate?.future ?? super.loadDetails(bookingId);
}

class GroupedServiceTestRepository extends MockBookingRepository {
  @override
  Future<List<BookingService>> loadServices() async => const [
    BookingService(id: 'hair', name: 'Hair'),
    BookingService(
      id: 'service-style',
      name: 'Blow dry',
      parentId: 'hair',
      usual: true,
    ),
    BookingService(id: 'service-cut', name: 'Hair cut', parentId: 'hair'),
    BookingService(id: 'colour', name: 'Colour', parentId: 'hair'),
    BookingService(id: 'skin', name: 'Skin', isBookable: false),
    BookingService(id: 'facial', name: 'Facial', parentId: 'skin'),
    BookingService(id: 'root', name: 'Massage'),
    BookingService(id: 'orphan', name: 'Orphan', parentId: 'absent'),
  ];
}

class BookingTestAuth extends AuthController {
  static AuthIdentity identity = _identity(['shop_employee']);

  @override
  Future<AuthView> build() async => AuthView(identity, 1, ownership: 1);
}

AuthIdentity _identity(List<String> groups) => AuthIdentity(
  userId: 'employee-current',
  email: 'fixture@example.test',
  groups: groups,
);

void main() {
  testWidgets('Booking Details keeps canonical header through loading, Retry and success; '
      'back pops or falls back to Queue', (tester) async {
    BookingTestAuth.identity = _identity(['shop_employee']);
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gate = Completer<BookingDetails>();
    final repository = HeaderTestBookingRepository()..detailsGate = gate;
    final router = GoRouter(
      initialLocation: '/booking',
      routes: [
        GoRoute(
          path: '/queue',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/booking'),
              child: const Text(AppStrings.operations),
            ),
          ),
        ),
        GoRoute(
          path: '/booking',
          builder: (_, _) =>
              const BookingDetailsScreen(bookingId: 'sample-in-progress'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(BookingTestAuth.new),
          bookingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          theme: AppTheme.forBrightness(Brightness.dark),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AppInnerHeader), findsOneWidget);
    expect(find.text(AppStrings.bookingDetails), findsOneWidget);
    expect(find.byTooltip(AppStrings.back), findsOneWidget);

    gate.completeError(const NetworkFailure());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.network), findsOneWidget);
    expect(find.byType(AppInnerHeader), findsOneWidget);
    repository.detailsGate = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.network), findsNothing);
    expect(find.byType(AppInnerHeader), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.text(AppStrings.paymentMode), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/queue');
    await tester.tap(find.text(AppStrings.operations));
    await tester.pumpAndSettle();
    expect(find.byType(AppInnerHeader), findsOneWidget);
    expect(router.canPop(), isTrue);
    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.operations), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  group('booking role policy', () {
    test('only server-derived employee and owner claims select workflows', () {
      expect(
        BookingRolePolicy.modeFor(AppRole.employee),
        BookingViewerMode.employee,
      );
      expect(BookingRolePolicy.modeFor(AppRole.owner), BookingViewerMode.owner);
      expect(
        BookingRolePolicy.modeFor(AppRole.unknown),
        BookingViewerMode.unsupported,
      );
    });
  });

  group('mock booking repository', () {
    test(
      'own-line save keeps other staff lines and rejects duplicates',
      () async {
        final repository = MockBookingRepository();
        final draft = await repository.loadDraft('sample-in-progress');
        expect(draft?.lines.single.assigneeName, 'Rahul');

        final service = (await repository.loadServices()).singleWhere(
          (item) => item.id == 'service-style',
        );
        final line = BookingDraftLine(
          serviceId: service.id,
          serviceName: service.name,
          quantity: 2,
          additionalDiscountPercent: 10,
          assigneeId: 'employee-current',
          assigneeName: 'Taylor',
        );
        final saved = await repository.saveOwnLines(
          bookingId: 'sample-in-progress',
          actorId: 'employee-current',
          expectedRevision: draft!.revision,
          ownLines: [line],
        );

        expect(saved.revision, draft.revision + 1);
        expect(saved.lines.map((item) => item.assigneeId), [
          'mock-staff-rahul',
          'employee-current',
        ]);
        await expectLater(
          repository.saveOwnLines(
            bookingId: 'sample-in-progress',
            actorId: 'employee-current',
            expectedRevision: saved.revision,
            ownLines: [line, line.copyWith(quantity: 1)],
          ),
          throwsA(isA<ConflictFailure>()),
        );
      },
    );

    test(
      'own-line revision conflict requires explicit save without retry',
      () async {
        final repository = MockBookingRepository(
          ownLineRevisionConflictsToInject: 1,
          concurrentLineOnInjectedConflict: const BookingDraftLine(
            serviceId: 'service-facial',
            serviceName: 'Facial',
            quantity: 1,
            additionalDiscountPercent: 0,
            assigneeId: 'employee-other',
            assigneeName: 'Morgan',
          ),
        );
        final initial = await repository.loadDraft('sample-in-progress');
        final save = repository.saveOwnLines(
          bookingId: 'sample-in-progress',
          actorId: 'employee-current',
          expectedRevision: initial!.revision,
          ownLines: const [
            BookingDraftLine(
              serviceId: 'service-style',
              serviceName: 'Blow dry',
              quantity: 1,
              additionalDiscountPercent: 0,
              assigneeId: 'employee-current',
              assigneeName: 'Taylor',
            ),
          ],
        );

        await expectLater(save, throwsA(isA<ConflictFailure>()));
        expect(repository.ownLineSaveAttempts, 1);
        expect(repository.draftReadCount, 1);
        final saved = await repository.loadDraft('sample-in-progress');
        expect(saved?.revision, initial.revision + 1);
        expect(saved?.lines.map((line) => line.assigneeId), [
          'mock-staff-rahul',
          'employee-other',
        ]);
        expect(saved?.lines.map((line) => line.serviceId), [
          'service-cut',
          'service-facial',
        ]);
      },
    );

    test(
      'multiple potential revision conflicts still send only one mutation',
      () async {
        final repository = MockBookingRepository(
          ownLineRevisionConflictsToInject: 2,
        );
        final initial = await repository.loadDraft('sample-in-progress');
        await expectLater(
          repository.saveOwnLines(
            bookingId: 'sample-in-progress',
            actorId: 'employee-current',
            expectedRevision: initial!.revision,
            ownLines: const [],
          ),
          throwsA(
            isA<ConflictFailure>().having(
              (failure) => failure.isRevisionConflict,
              'isRevisionConflict',
              isTrue,
            ),
          ),
        );
        expect(repository.ownLineSaveAttempts, 1);
        expect(repository.draftReadCount, 1);
      },
    );

    test('non-revision own-line conflicts are not retried', () async {
      final repository = MockBookingRepository();
      await expectLater(
        repository.saveOwnLines(
          bookingId: 'sample-in-progress',
          actorId: 'employee-current',
          expectedRevision: 1,
          ownLines: const [
            BookingDraftLine(
              serviceId: 'service-cut',
              serviceName: 'Hair cut',
              quantity: 1,
              additionalDiscountPercent: 0,
              assigneeId: 'employee-current',
              assigneeName: 'Taylor',
            ),
          ],
        ),
        throwsA(isA<ConflictFailure>()),
      );
      expect(repository.ownLineSaveAttempts, 1);
      expect(repository.draftReadCount, 0);
    });

    test('stale revision and foreign line edits are typed failures', () async {
      final repository = MockBookingRepository();
      await expectLater(
        repository.saveOwnLines(
          bookingId: 'sample-in-progress',
          actorId: 'employee-current',
          expectedRevision: 1,
          ownLines: const [
            BookingDraftLine(
              serviceId: 'service-cut',
              serviceName: 'Hair cut',
              quantity: 1,
              additionalDiscountPercent: 0,
              assigneeId: 'mock-staff-rahul',
              assigneeName: 'Rahul',
            ),
          ],
        ),
        throwsA(isA<ForbiddenFailure>()),
      );
      expect(repository.ownLineSaveAttempts, 1);
    });

    test(
      'owner completion saves payment fields then uses the saved revision',
      () async {
        final repository = MockBookingRepository();
        await expectLater(
          repository.saveOwnerDraft(
            bookingId: 'card-booking',
            expectedRevision: 0,
            lines: const [],
            payment: const BookingPaymentDraft(mode: BookingPaymentMode.card),
          ),
          throwsA(isA<ValidationFailure>()),
        );
        final paymentDraft = await repository.saveOwnerDraft(
          bookingId: 'bookixo-booking',
          expectedRevision: 0,
          lines: const [],
          payment: const BookingPaymentDraft(mode: BookingPaymentMode.bookixo),
        );
        final pending = await repository.complete(
          bookingId: 'bookixo-booking',
          expectedRevision: paymentDraft.revision,
        );
        expect(pending.status, BookingDraftStatus.completionPending);
        expect(repository.lastCompleteExpectedRevision, paymentDraft.revision);
        expect(repository.operationLog, ['owner-draft-save:1', 'complete:1']);
        expect(repository.lastSavedPayment?.mode, BookingPaymentMode.bookixo);

        final cashDraft = await repository.saveOwnerDraft(
          bookingId: 'cash-booking',
          expectedRevision: 0,
          lines: const [],
          payment: const BookingPaymentDraft(mode: BookingPaymentMode.cash),
        );
        final completed = await repository.complete(
          bookingId: 'cash-booking',
          expectedRevision: cashDraft.revision,
        );
        expect(completed.status, BookingDraftStatus.completed);

        final recoveryRepository = MockBookingRepository(
          completionBehavior: MockCompletionBehavior.requireRecoveryOnce,
        );
        final recoveryDraft = await recoveryRepository.saveOwnerDraft(
          bookingId: 'recovery-booking',
          expectedRevision: 0,
          lines: const [],
          payment: const BookingPaymentDraft(mode: BookingPaymentMode.cash),
        );
        final recovery = await recoveryRepository.complete(
          bookingId: 'recovery-booking',
          expectedRevision: recoveryDraft.revision,
        );
        expect(recovery.status, BookingDraftStatus.completionRecoveryRequired);
        final retried = await recoveryRepository.retryCompletion(
          'recovery-booking',
        );
        expect(retried.status, BookingDraftStatus.completed);
      },
    );

    test('completion failure leaves saved payment draft available', () async {
      final repository = MockBookingRepository(
        completionFailure: const NetworkFailure(),
      );
      final saved = await repository.saveOwnerDraft(
        bookingId: 'failed-completion',
        expectedRevision: 0,
        lines: const [],
        payment: const BookingPaymentDraft(
          mode: BookingPaymentMode.upi,
          transactionId: 'fixture-transaction',
          note: 'fixture note',
        ),
      );

      await expectLater(
        repository.complete(
          bookingId: 'failed-completion',
          expectedRevision: saved.revision,
        ),
        throwsA(isA<NetworkFailure>()),
      );
      final latest = await repository.loadDraft('failed-completion');
      expect(latest?.revision, saved.revision);
      expect(latest?.status, BookingDraftStatus.editable);
      expect(repository.lastSavedPayment?.transactionId, 'fixture-transaction');
      expect(repository.operationLog, ['owner-draft-save:1', 'complete:1']);
    });

    test(
      'employee domain line has no price members and mock is offline only',
      () {
        final workspaceSource = File(
          'lib/features/queue/domain/booking_workspace.dart',
        ).readAsStringSync();
        final draftLineSource = workspaceSource
            .split('class BookingDraftLine')
            .last
            .split('class BookingDetails')
            .first;
        expect(
          draftLineSource,
          isNot(matches(RegExp(r'\b(price|subtotal|amount|currency)\b'))),
        );
        final adapterSource = File(
          'lib/features/queue/data/mock_booking_repository.dart',
        ).readAsStringSync();
        expect(adapterSource, isNot(contains('dio')));
        expect(adapterSource, isNot(contains('/api/')));
      },
    );
  });

  group('booking details role visibility', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      MockBookingRepository repository,
      List<String> groups,
    ) async {
      BookingTestAuth.identity = _identity(groups);
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(BookingTestAuth.new),
            bookingRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.forBrightness(Brightness.light),
            home: const BookingDetailsScreen(bookingId: 'sample-in-progress'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'picker groups badges, searches parents/children and preserves selection',
      (tester) async {
        await pumpScreen(tester, GroupedServiceTestRepository(), [
          'shop_employee',
        ]);
        Finder chip(String text) => find.widgetWithText(ChoiceChip, text);
        final search = find.widgetWithText(TextField, AppStrings.serviceSearch);

        expect(find.text(AppStrings.yourUsualServices), findsOneWidget);
        expect(find.text('Hair'), findsNWidgets(3)); // Two headings + option.
        expect(chip('Hair'), findsOneWidget);
        expect(chip('Skin'), findsNothing);
        expect(find.text('Skin'), findsOneWidget);
        expect(chip('Massage'), findsOneWidget);
        expect(chip('Orphan'), findsOneWidget);
        final blocked = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Hair cut · Already added by Rahul'),
        );
        expect(blocked.onSelected, isNull);

        await tester.enterText(search, ' HAIR ');
        await tester.pumpAndSettle();
        expect(chip('Blow dry'), findsOneWidget);
        expect(chip('Colour'), findsOneWidget);
        expect(chip('Massage'), findsNothing);
        expect(find.text('Skin'), findsNothing);

        await tester.enterText(search, 'colour');
        await tester.pumpAndSettle();
        expect(find.text('Hair'), findsOneWidget); // Heading survives.
        expect(chip('Hair'), findsNothing);
        expect(chip('Blow dry'), findsNothing);
        expect(find.text(AppStrings.yourUsualServices), findsNothing);
        await tester.tap(chip('Colour'));
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip('Colour')).selected, isTrue);
        expect(tester.widget<ChoiceChip>(chip('Colour')).onSelected, isNull);

        await tester.enterText(search, 'no match');
        await tester.pumpAndSettle();
        expect(find.text(AppStrings.noMatchingServices), findsOneWidget);
        // Search filters the catalogue, not the selected draft.
        expect(find.textContaining('Colour ·'), findsOneWidget);
        await tester.enterText(search, '');
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip('Colour')).selected, isTrue);
        expect(find.textContaining('₹'), findsNothing);
        expect(find.text(AppStrings.paymentMode), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'employee can edit own services, but sees no price or payment UI',
      (tester) async {
        final repository = MockBookingRepository();
        await pumpScreen(tester, repository, ['shop_employee']);

        expect(find.byType(AppInnerHeader), findsOneWidget);
        expect(find.text(AppStrings.bookingDetails), findsOneWidget);
        expect(find.text(AppStrings.alreadyAddedBy), findsNothing);
        expect(find.textContaining('Already added by Rahul'), findsOneWidget);
        expect(find.text(AppStrings.paymentMode), findsNothing);
        expect(find.text(AppStrings.finalAmount), findsNothing);
        expect(find.textContaining('₹'), findsNothing);

        await tester.tap(find.text('Blow dry'));
        await tester.pumpAndSettle();
        expect(find.text('Blow dry'), findsWidgets);
        await tester.tap(find.text(AppStrings.saveServiceCount(1)));
        await tester.pumpAndSettle();

        final saved = await repository.loadDraft('sample-in-progress');
        expect(saved?.lines.map((line) => line.assigneeId), [
          'mock-staff-rahul',
          'employee-current',
        ]);
      },
    );

    testWidgets('employee gets final conflict feedback and keeps draft input', (
      tester,
    ) async {
      final repository = MockBookingRepository(
        ownLineRevisionConflictsToInject: 2,
      );
      await pumpScreen(tester, repository, ['shop_employee']);

      await tester.tap(find.text('Blow dry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.saveServiceCount(1)));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.bookingChanged), findsOneWidget);
      expect(repository.ownLineSaveAttempts, 1);
      expect((await repository.loadDraft('sample-in-progress'))?.revision, 2);
      expect(find.text('Blow dry'), findsWidgets);
    });

    testWidgets('owner sees the mock server pricing and completion controls', (
      tester,
    ) async {
      await pumpScreen(tester, MockBookingRepository(), ['shop_owner']);
      expect(find.byType(AppInnerHeader), findsOneWidget);
      expect(find.text(AppStrings.finalAmount), findsOneWidget);
      expect(find.text(AppStrings.completePayment), findsOneWidget);
      expect(find.textContaining('₹2360.00'), findsOneWidget);
      expect(find.text(AppStrings.employeeDiscount), findsNothing);
    });

    testWidgets('owner Bookixo completion enters the awaiting-payment state', (
      tester,
    ) async {
      await pumpScreen(tester, MockBookingRepository(), ['shop_admin']);
      await tester.tap(find.text(AppStrings.bookixo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.completePayment));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.completionAwaitingPayment), findsNWidgets(2));
    });

    testWidgets(
      'completion failure preserves payment input and refreshes draft',
      (tester) async {
        final repository = MockBookingRepository(
          completionFailure: const NetworkFailure(),
          failCompletionOnce: true,
        );
        await pumpScreen(tester, repository, ['shop_owner']);
        await tester.tap(find.text(AppStrings.upi));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == AppStrings.paymentTransactionId,
          ),
          'preserve-this-id',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == AppStrings.paymentNote,
          ),
          'preserve this note',
        );
        await tester.tap(find.text(AppStrings.completePayment));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.network), findsOneWidget);
        expect(find.text('preserve-this-id'), findsOneWidget);
        expect(find.text('preserve this note'), findsOneWidget);
        expect(repository.lastSavedPayment?.transactionId, 'preserve-this-id');
        expect(repository.lastSavedPayment?.note, 'preserve this note');
        expect(repository.lastCompleteExpectedRevision, 2);
      },
    );

    testWidgets('owner can recover a mock completion and see confirmation', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        MockBookingRepository(
          completionBehavior: MockCompletionBehavior.requireRecoveryOnce,
        ),
        ['OWNER'],
      );
      await tester.tap(find.text(AppStrings.cash));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.completePayment));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.retryCompletion), findsOneWidget);
      await tester.tap(find.text(AppStrings.retryCompletion));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.bookingCompleted), findsNWidgets(2));
    });
  });
}
