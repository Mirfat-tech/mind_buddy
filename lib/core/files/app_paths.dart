import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths._();

  static Future<Directory> applicationSupportDirectory() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final stabilized = _stabilizeAppleDirectory(
        directory,
        preferTemporary: false,
      );
      await stabilized.create(recursive: true);
      return stabilized;
    } catch (_) {}

    final home = Platform.environment['HOME'];

    if (home != null && home.isNotEmpty) {
      final basePath = switch (Platform.operatingSystem) {
        'ios' || 'macos' => p.join(home, 'Library', 'Application Support'),
        'android' => p.join(home, 'app_flutter'),
        'linux' => p.join(home, '.local', 'share'),
        _ => p.join(home, 'mind_buddy'),
      };
      final directory = Directory(basePath);
      await directory.create(recursive: true);
      return directory;
    }

    final fallback = await Directory.systemTemp.createTemp(
      'mind_buddy_support_',
    );
    return fallback;
  }

  static Future<String> databaseFilePath() async {
    final directory = await applicationSupportDirectory();
    return p.join(directory.path, 'mind_buddy.sqlite');
  }

  static Future<Directory> temporaryDirectory() async {
    try {
      final directory = await getTemporaryDirectory();
      final stabilized = _stabilizeAppleDirectory(
        directory,
        preferTemporary: true,
      );
      await stabilized.create(recursive: true);
      return stabilized;
    } catch (_) {}

    final home = Platform.environment['HOME'];

    if (home != null && home.isNotEmpty) {
      final basePath = switch (Platform.operatingSystem) {
        'ios' || 'macos' => p.join(home, 'Library', 'Caches'),
        'android' => p.join(home, 'cache'),
        'linux' => p.join(home, '.cache'),
        _ => p.join(home, 'mind_buddy_tmp'),
      };
      final directory = Directory(basePath);
      await directory.create(recursive: true);
      return directory;
    }

    return Directory.systemTemp.createTemp('mind_buddy_tmp_');
  }

  static Directory _stabilizeAppleDirectory(
    Directory directory, {
    required bool preferTemporary,
  }) {
    if (!(Platform.isIOS || Platform.isMacOS)) {
      return directory;
    }

    final path = p.normalize(directory.path);
    if (!path.contains(
      '${Platform.pathSeparator}tmp${Platform.pathSeparator}path_provider_foundation_',
    )) {
      return directory;
    }

    final containerBase = _appleContainerBaseFromTemp(
      Directory.systemTemp.path,
    );
    if (containerBase == null) {
      return directory;
    }

    final stablePath = preferTemporary
        ? p.join(containerBase, 'tmp')
        : p.join(containerBase, 'Library', 'Application Support');
    return Directory(stablePath);
  }

  static String? _appleContainerBaseFromTemp(String tempPath) {
    final normalized = p.normalize(tempPath);
    if (p.basename(normalized) == 'tmp') {
      return p.dirname(normalized);
    }

    final marker = '${Platform.pathSeparator}tmp';
    final markerIndex = normalized.lastIndexOf(marker);
    if (markerIndex <= 0) {
      return null;
    }
    return normalized.substring(0, markerIndex);
  }
}
