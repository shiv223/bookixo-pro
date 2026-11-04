import 'booking_workspace.dart';

/// Resolves acyclic parent chains. Direct orphans remain roots.
class ServiceCatalogue {
  ServiceCatalogue(List<BookingService> services)
    : byId = {for (final service in services) service.id: service};

  final Map<String, BookingService> byId;

  BookingService? parentOf(BookingService service) {
    final seen = {service.id};
    var cursor = service;
    final direct = byId[service.parentId];
    while (true) {
      final id = cursor.parentId;
      if (id == null) return direct;
      final parent = byId[id];
      if (parent == null) return direct;
      if (!seen.add(id)) return null;
      cursor = parent;
    }
  }

  /// Parent headings precede descendants, with every record displayed once.
  List<ServiceCatalogueRow> get rows {
    final children = <String, List<BookingService>>{};
    final roots = <BookingService>[];
    for (final service in byId.values) {
      final parent = parentOf(service);
      if (parent == null) {
        roots.add(service);
      } else {
        (children[parent.id] ??= []).add(service);
      }
    }
    final result = <ServiceCatalogueRow>[];
    // Iterative traversal avoids stack overflow on a deeply nested catalogue.
    final pending = [
      for (final root in roots.reversed) (service: root, depth: 0),
    ];
    while (pending.isNotEmpty) {
      final entry = pending.removeLast();
      final descendants = children[entry.service.id] ?? const [];
      result.add(
        ServiceCatalogueRow(
          entry.service,
          entry.depth,
          descendants.isNotEmpty || !entry.service.isBookable,
        ),
      );
      for (final child in descendants.reversed) {
        pending.add((service: child, depth: entry.depth + 1));
      }
    }
    return List.unmodifiable(result);
  }
}

class ServiceCatalogueRow {
  const ServiceCatalogueRow(this.service, this.depth, this.isHeading);
  final BookingService service;
  final int depth;
  final bool isHeading;
}
