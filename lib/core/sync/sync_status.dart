enum SyncStatus {
  synced('synced'),
  pendingUpsert('pending_upsert'),
  pendingDelete('pending_delete'),
  syncFailed('sync_failed');

  const SyncStatus(this.value);

  final String value;

  static SyncStatus fromValue(String value) {
    return SyncStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SyncStatus.synced,
    );
  }
}

enum SyncJobAction {
  upsert('upsert'),
  delete('delete');

  const SyncJobAction(this.value);

  final String value;

  static SyncJobAction fromValue(String value) {
    return SyncJobAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => SyncJobAction.upsert,
    );
  }
}

enum SyncJobState {
  pending('pending'),
  running('running'),
  completed('completed'),
  failed('failed');

  const SyncJobState(this.value);

  final String value;

  static SyncJobState fromValue(String value) {
    return SyncJobState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => SyncJobState.pending,
    );
  }
}
