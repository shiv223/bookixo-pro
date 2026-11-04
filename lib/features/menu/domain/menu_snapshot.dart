/// Stable account/shop ownership. Token rotation is deliberately not identity.
class MenuScope {
  const MenuScope(this.userId, this.subject, this.shopId);
  final String userId;
  final String? subject;
  final int shopId;
  @override
  bool operator ==(Object other) =>
      other is MenuScope &&
      other.userId == userId &&
      other.subject == subject &&
      other.shopId == shopId;
  @override
  int get hashCode => Object.hash(userId, subject, shopId);
}

/// Only exact keys and Shop Setup's immediate edges are cached.
class MenuSnapshot {
  MenuSnapshot(
    this.scope,
    Set<String> keys,
    this.fetchedAt, {
    Set<String> shopSetupChildren = const {},
  }) : keys = Set.unmodifiable(keys),
       shopSetupChildren = Set.unmodifiable(shopSetupChildren);
  static const schemaVersion = 2;
  static const refreshInterval = Duration(seconds: 60);
  final MenuScope scope;
  final Set<String> keys;
  final Set<String> shopSetupChildren;
  final DateTime fetchedAt;
  bool needsRefresh(DateTime now) =>
      now.difference(fetchedAt) >= refreshInterval;
}
