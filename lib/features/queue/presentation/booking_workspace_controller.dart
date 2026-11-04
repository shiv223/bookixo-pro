import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/booking_api_repository.dart';
import '../data/mock_booking_repository.dart';
import '../domain/booking_repository.dart';
import '../domain/booking_workspace.dart';
import 'queue_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final queueRepository = ref.watch(queueRepositoryProvider);
  if (queueRepository is BookingApiRepository) return queueRepository;
  return MockBookingRepository();
});

final bookingWorkspaceIsMockProvider = Provider<bool>(
  (ref) => ref.watch(bookingRepositoryProvider) is MockBookingRepository,
);

final bookingWorkspaceProvider = FutureProvider.autoDispose
    .family<BookingWorkspace, (String, String)>((ref, scope) async {
      ref.watch(scopeRevisionProvider);
      final repository = ref.watch(bookingRepositoryProvider);
      final actor = await repository.resolveActor(scope.$2);
      final results = await Future.wait<Object?>([
        repository.loadDetails(scope.$1),
        repository.loadDraft(scope.$1),
        repository.loadServices(),
        repository.loadEmployeeDiscountLimit(),
      ]);
      final details = results[0] as BookingDetails;
      final draft = results[1] as BookingDraft?;
      final services = results[2] as List<BookingService>;
      final discountLimit = results[3] as double;
      final serviceNames = {
        for (final service in services) service.id: service.name,
      };
      final initialLines =
          draft?.lines ??
          [
            for (final serviceId in details.serviceIds)
              BookingDraftLine(
                serviceId: serviceId,
                serviceName: serviceNames[serviceId] ?? serviceId,
                quantity: 1,
                additionalDiscountPercent: 0,
                assigneeId: details.assigneeId,
                assigneeName: details.assigneeName,
              ),
          ];
      return BookingWorkspace(
        details: details,
        draft:
            draft ??
            BookingDraft(
              revision: 0,
              status: BookingDraftStatus.editable,
              lines: initialLines,
            ),
        services: services,
        employeeDiscountLimitPercent: discountLimit,
        actorId: actor.id,
        actorName: actor.name,
      );
    }, retry: (_, _) => null);

/// Owner-only data; employee screens never request pricing or payment config.
final ownerCompletionContextProvider = FutureProvider.autoDispose
    .family<OwnerCompletionContext, OwnerCompletionRequest>((
      ref,
      request,
    ) async {
      ref.watch(scopeRevisionProvider);
      final repository = ref.watch(bookingRepositoryProvider);
      final ready = Completer<void>();
      var disposed = false;
      final timer = Timer(const Duration(milliseconds: 350), ready.complete);
      ref.onDispose(() {
        disposed = true;
        timer.cancel();
        if (!ready.isCompleted) ready.complete();
      });
      await ready.future;
      if (disposed) throw const _PricingRequestCancelled();
      return repository.loadOwnerCompletionContext(
        bookingId: request.bookingId,
        draftRevision: request.draftRevision,
        lines: request.lines,
      );
    }, retry: (_, _) => null);

final class _PricingRequestCancelled implements Exception {
  const _PricingRequestCancelled();
}
