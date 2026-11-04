import '../../menu/domain/menu_snapshot.dart';
import 'offer.dart';

/// Independent, scoped read-only Offers resources.
abstract interface class OffersRepository {
  Future<ResourcePage<Offer>> offers(MenuScope scope, int page);
  Future<ResourcePage<OfferTarget>> targets(MenuScope scope, int page);
  Future<ResourcePage<ScheduleRule>> rules(MenuScope scope, int page);
}

class ResourcePage<T> {
  ResourcePage(
    List<T> content,
    this.number,
    this.size,
    this.totalElements,
    this.totalPages,
    this.last,
  ) : content = List.unmodifiable(content);
  final List<T> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}
