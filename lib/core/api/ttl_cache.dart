/// Short in-memory cache so screens do not refetch users/locations/products
/// on every open. Writes should call [invalidate].
class TtlCache<T> {
  TtlCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  T? _value;
  DateTime? _cachedAt;
  Future<T>? _inflight;

  Future<T> getOrLoad(Future<T> Function() load) async {
    final cached = _value;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < ttl) {
      return cached;
    }
    final pending = _inflight;
    if (pending != null) return pending;
    final future = load();
    _inflight = future;
    try {
      final value = await future;
      _value = value;
      _cachedAt = DateTime.now();
      return value;
    } finally {
      if (identical(_inflight, future)) {
        _inflight = null;
      }
    }
  }

  void invalidate() {
    _value = null;
    _cachedAt = null;
  }
}
