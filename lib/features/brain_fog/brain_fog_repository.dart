import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mind_buddy/core/database/database_providers.dart';
import 'package:mind_buddy/features/brain_fog/data/local/brain_fog_local_data_source.dart';

class BrainFogRepository {
  BrainFogRepository(this._localDataSource)
    : _memoryState = null,
      _onMemoryMutated = null;

  BrainFogRepository.memory({VoidCallback? onMutated})
    : _localDataSource = null,
      _memoryState = null,
      _onMemoryMutated = onMutated;

  final BrainFogLocalDataSource? _localDataSource;
  BrainFogLocalStateRecord? _memoryState;
  final VoidCallback? _onMemoryMutated;

  Future<BrainFogLocalStateRecord?> loadState({required String userId}) {
    if (_localDataSource == null) {
      return SynchronousFuture<BrainFogLocalStateRecord?>(_memoryState);
    }
    return _localDataSource.load(userId: userId);
  }

  Future<void> saveState({
    required String userId,
    required List<BrainFogThoughtRecord> thoughts,
    required bool isDeleteMode,
    required bool figureOutMode,
    required int figureStep,
    required Set<String> controllableIds,
    required List<String> focusOrder,
    required String reason,
  }) {
    if (_localDataSource == null) {
      _memoryState = BrainFogLocalStateRecord(
        userId: userId,
        thoughts: List<BrainFogThoughtRecord>.from(thoughts),
        isDeleteMode: isDeleteMode,
        figureOutMode: figureOutMode,
        figureStep: figureStep,
        controllableIds: Set<String>.from(controllableIds),
        focusOrder: List<String>.from(focusOrder),
        updatedAt: DateTime.now().toUtc(),
      );
      _onMemoryMutated?.call();
      return SynchronousFuture<void>(null);
    }
    return _localDataSource
        .save(
          userId: userId,
          thoughts: thoughts,
          isDeleteMode: isDeleteMode,
          figureOutMode: figureOutMode,
          figureStep: figureStep,
          controllableIds: controllableIds,
          focusOrder: focusOrder,
          reason: reason,
        )
        .then((_) {
          debugPrint(
            'BRAINFOG_QUEUE_SYNC userId=$userId reason=$reason action=brain_fog_state_updated',
          );
          debugPrint(
            'BRAINFOG_REMOTE_SKIPPED_OFFLINE userId=$userId reason=brain_fog_sync_not_enabled',
          );
        });
  }
}

final brainFogRepositoryProvider = Provider<BrainFogRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return BrainFogRepository(BrainFogLocalDataSource(database));
});
