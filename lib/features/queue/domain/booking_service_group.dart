import 'booking_workspace.dart';
import 'service_catalogue.dart';

/// A visible set of bookable options, optionally headed by their parent name.
class BookingServiceGroup {
  const BookingServiceGroup({this.name, required this.services});

  final String? name;
  final List<BookingService> services;

  /// Resolves parents against the full catalogue before filtering by search or
  /// usual status, so a hidden/non-bookable parent still names its children.
  static List<BookingServiceGroup> filter(
    List<BookingService> catalogue, {
    required bool usual,
    required String search,
  }) {
    final resolver = ServiceCatalogue(catalogue);
    final parentOf = resolver.parentOf;

    final parentIds = {
      for (final service in catalogue)
        if (parentOf(service) case final parent?) parent.id,
    };
    final query = search.trim().toLowerCase();
    final groups = <String, List<BookingService>>{};
    final names = <String, String>{};
    for (final service in catalogue) {
      if (!service.isBookable || service.usual != usual) continue;
      final parent = parentOf(service);
      final group = parent ?? (parentIds.contains(service.id) ? service : null);
      if (!service.name.toLowerCase().contains(query) &&
          !(group?.name.toLowerCase().contains(query) ?? false)) {
        continue;
      }
      // Ungrouped roots share a heading-free wrap; each parent has its own.
      final key = group?.id ?? '';
      if (group != null) names[key] = group.name;
      (groups[key] ??= []).add(service);
    }
    return [
      for (final entry in groups.entries)
        BookingServiceGroup(
          name: names[entry.key],
          services: List.unmodifiable(entry.value),
        ),
    ];
  }
}
