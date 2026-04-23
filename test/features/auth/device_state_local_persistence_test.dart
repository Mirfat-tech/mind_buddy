import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/core/database/app_database.dart';
import 'package:mind_buddy/features/auth/data/local/device_state_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device state local persistence', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('device-state-local-');
      databaseFile = File('${tempDir.path}/mind_buddy_test.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'persists cached device display state across database reopen',
      () async {
        final firstDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        final firstDataSource = DeviceStateLocalDataSource(firstDatabase);

        await firstDataSource.save(
          userId: 'user-1',
          localDeviceId: 'device-local',
          sessions: const <LocalDeviceSessionRecord>[
            LocalDeviceSessionRecord(
              deviceId: 'device-local',
              deviceName: 'My iPhone',
              platform: 'iOS',
              lastSeen: '2026-04-18 10:15',
              sortKey: '2026-04-18T09:15:00.000Z',
            ),
            LocalDeviceSessionRecord(
              deviceId: 'device-other',
              deviceName: 'My iPad',
              platform: 'iOS',
              lastSeen: '2026-04-17 19:20',
              sortKey: '2026-04-17T18:20:00.000Z',
            ),
          ],
        );
        await firstDatabase.close();

        final secondDatabase = AppDatabase.forTesting(
          NativeDatabase(databaseFile),
        );
        addTearDown(secondDatabase.close);
        final secondDataSource = DeviceStateLocalDataSource(secondDatabase);

        final cached = await secondDataSource.load(userId: 'user-1');

        expect(cached, isNotNull);
        expect(cached!.localDeviceId, 'device-local');
        expect(cached.sessions, hasLength(2));
        expect(cached.sessions.first.deviceName, 'My iPhone');
        expect(cached.sessions.last.deviceId, 'device-other');
      },
    );
  });
}
