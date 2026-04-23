abstract class LocalFirstRepository<T> {
  Future<T?> loadCached();

  Future<T> initialize();

  Future<void> syncPending();
}
