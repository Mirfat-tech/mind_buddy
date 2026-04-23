import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class PathProviderFoundation extends PathProviderPlatform {
  PathProviderFoundation();

  static void registerWith() {
    PathProviderPlatform.instance = PathProviderFoundation();
  }

  @override
  Future<String?> getTemporaryPath() async {
    final directory = await _directory(_DirectoryKind.caches);
    return directory.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    final directory = await _directory(_DirectoryKind.applicationSupport);
    return directory.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    final directory = await _directory(_DirectoryKind.library);
    return directory.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final directory = await _directory(_DirectoryKind.documents);
    return directory.path;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    final directory = await _directory(_DirectoryKind.caches);
    return directory.path;
  }

  @override
  Future<String?> getDownloadsPath() async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Functionality only available on macOS');
    }
    final directory = await _directory(_DirectoryKind.downloads);
    return directory.path;
  }

  @override
  Future<String?> getExternalStoragePath() {
    throw UnsupportedError('Functionality only available on Android');
  }

  @override
  Future<List<String>?> getExternalCachePaths() {
    throw UnsupportedError('Functionality only available on Android');
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) {
    throw UnsupportedError('Functionality only available on Android');
  }

  Future<String?> getContainerPath({
    required String appGroupIdentifier,
  }) async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return null;
    }
    final directory = Directory(
      '$home/Library/Group Containers/$appGroupIdentifier',
    );
    await directory.create(recursive: true);
    return directory.path;
  }

  Future<Directory> _directory(_DirectoryKind kind) async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      final fallback = await Directory.systemTemp.createTemp(
        'path_provider_foundation_',
      );
      return fallback;
    }

    final path = switch (kind) {
      _DirectoryKind.documents => '$home/Documents',
      _DirectoryKind.caches => '$home/Library/Caches',
      _DirectoryKind.library => '$home/Library',
      _DirectoryKind.applicationSupport => '$home/Library/Application Support',
      _DirectoryKind.downloads => '$home/Downloads',
    };

    final directory = Directory(path);
    await directory.create(recursive: true);
    return directory;
  }
}

enum _DirectoryKind {
  documents,
  caches,
  library,
  applicationSupport,
  downloads,
}
