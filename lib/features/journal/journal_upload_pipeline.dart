import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreparedJournalImage {
  const PreparedJournalImage({
    required this.bytes,
    required this.extension,
    required this.contentType,
    required this.cachedPath,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
  final String cachedPath;
}

class JournalUploadPipeline {
  static const int maxImageDimension = 1080;
  static const int imageQuality = 80;

  static const Set<String> _supportedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  static bool isSupportedImageExtension(String extension) {
    return _supportedImageExtensions.contains(extension.toLowerCase());
  }

  static String extensionFromFilename(
    String filename, {
    String fallback = 'bin',
  }) {
    final dot = filename.lastIndexOf('.');
    if (dot == -1 || dot == filename.length - 1) return fallback;
    return filename.substring(dot + 1).toLowerCase();
  }

  static String contentTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<PreparedJournalImage?> prepareImageForUpload(
    File sourceFile,
    String filename,
  ) async {
    final sourceExt = extensionFromFilename(filename);
    if (!isSupportedImageExtension(sourceExt)) return null;

    final bool keepPng = sourceExt == 'png';
    final String outputExt = keepPng ? 'png' : 'jpg';
    final CompressFormat format = keepPng
        ? CompressFormat.png
        : CompressFormat.jpeg;

    Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      sourceFile.path,
      minWidth: maxImageDimension,
      minHeight: maxImageDimension,
      quality: imageQuality,
      format: format,
      keepExif: true,
    );
    compressed ??= await sourceFile.readAsBytes();

    final tempDir = await getTemporaryDirectory();
    final String cachedPath =
        '${tempDir.path}/journal_up_'
        '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}.$outputExt';
    final cacheFile = File(cachedPath);
    await cacheFile.writeAsBytes(compressed, flush: true);

    return PreparedJournalImage(
      bytes: compressed,
      extension: outputExt,
      contentType: contentTypeFromExtension(outputExt),
      cachedPath: cachedPath,
    );
  }

  static Future<void> uploadBinaryWithRetry({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
    Duration timeout = const Duration(seconds: 45),
    int retryAttempts = 2,
  }) async {
    await Supabase.instance.client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: contentType,
          ),
          retryAttempts: retryAttempts,
        )
        .timeout(timeout);
  }
}
