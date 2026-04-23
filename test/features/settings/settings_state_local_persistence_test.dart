import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/settings/data/local/settings_local_data_source.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings state local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('settings-state-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists ordinary settings across database reopen', () async {
      final firstDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      final firstDataSource = SettingsLocalDataSource(firstDatabase);
      final settings = SettingsModel.defaults().copyWith(
        quietHoursEnabled: true,
        quietStart: '21:30',
        quietEnd: '06:45',
        dailyCheckInEnabled: true,
        dailyCheckInTime: '08:15',
        hapticsEnabled: false,
        soundsEnabled: false,
        keepInstructionsEnabled: false,
        updatedAt: DateTime.utc(2026, 4, 18, 11, 0).toIso8601String(),
      );

      await firstDataSource.save(
        scopeId: 'user-1',
        userId: 'user-1',
        settings: settings,
        syncStatus: SyncStatus.pendingUpsert,
      );
      await firstDatabase.close();

      final secondDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
      );
      addTearDown(secondDatabase.close);
      final secondDataSource = SettingsLocalDataSource(secondDatabase);

      final restored = await secondDataSource.load('user-1');

      expect(restored, isNotNull);
      expect(restored!.settings.quietHoursEnabled, isTrue);
      expect(restored.settings.quietStart, '21:30');
      expect(restored.settings.quietEnd, '06:45');
      expect(restored.settings.dailyCheckInEnabled, isTrue);
      expect(restored.settings.dailyCheckInTime, '08:15');
      expect(restored.settings.hapticsEnabled, isFalse);
      expect(restored.settings.soundsEnabled, isFalse);
      expect(restored.settings.keepInstructionsEnabled, isFalse);
    });
  });
}
