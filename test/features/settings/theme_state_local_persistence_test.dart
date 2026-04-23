import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/core/sync/sync_status.dart';
import 'package:mind_buddy/features/settings/data/local/settings_local_data_source.dart';
import 'package:mind_buddy/features/settings/settings_model.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme state local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('theme-state-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists selected theme and custom themes across database reopen',
      () async {
        final firstDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        final firstDataSource = SettingsLocalDataSource(firstDatabase);
        final customTheme = PaperStyle(
          id: 'sunset_custom',
          name: 'Sunset Custom',
          paper: const Color(0xFFFFF6EC),
          boxFill: const Color(0xFFFFE1C7),
          border: const Color(0xFFDD8A5A),
          text: const Color(0xFF4A2B1A),
          mutedText: const Color(0xFF8D5F45),
          accent: const Color(0xFFEF7F45),
        );
        final settings = SettingsModel.defaults().copyWith(
          themeId: customTheme.id,
          customThemes: <PaperStyle>[customTheme],
          updatedAt: DateTime.utc(2026, 4, 18, 10, 0).toIso8601String(),
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
        expect(restored!.settings.themeId, customTheme.id);
        expect(restored.settings.customThemes, hasLength(1));
        expect(restored.settings.customThemes.single.id, customTheme.id);
        expect(restored.settings.customThemes.single.name, 'Sunset Custom');
      },
    );
  });
}
