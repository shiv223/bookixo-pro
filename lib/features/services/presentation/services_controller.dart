import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../menu/presentation/destination_scope_provider.dart';
import '../../queue/domain/service_catalogue.dart';
import '../../queue/presentation/booking_workspace_controller.dart';

/// Uses the existing price-free booking catalogue DTO and confirmed GET.
final servicesCatalogueProvider =
    FutureProvider.autoDispose<List<ServiceCatalogueRow>>((ref) async {
      final scope = ref.watch(destinationScopeProvider('shop-services-list'));
      if (scope == null) return const [];
      final repository = ref.watch(bookingRepositoryProvider);
      final services = await repository.loadServices();
      // FutureProvider discards superseded futures; never publish old scope data.
      if (!ref.mounted ||
          ref.read(destinationScopeProvider('shop-services-list')) != scope) {
        return const [];
      }
      return ServiceCatalogue(services).rows;
    }, retry: (_, _) => null);
