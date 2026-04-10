import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:video_player/video_player.dart';

import 'journal_media.dart';

class LocalImageEmbedBuilder extends quill.EmbedBuilder {
  const LocalImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final data = embedContext.node.value.data?.toString() ?? '';
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final payload = _parseEmbedPayload(data);
    final item = JournalMediaItem(
      type: 'image',
      url: payload.url,
      path: payload.path,
      bucket: payload.bucket,
    );
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'quill_image_embed'),
      builder: (context, snap) {
        final resolved = snap.data;
        if (resolved?.file != null) {
          return _imageContainer(
            Image.file(
              resolved!.file!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _errorBox('Image unavailable'),
            ),
          );
        }
        final url = resolved?.url;
        if (url != null && url.isNotEmpty) {
          return _imageContainer(
            Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loading) {
                if (loading == null) return child;
                return const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, error, ___) {
                developer.log(
                  'journal_media event=render_failed data={context: quill_image_embed, url: $url, error: $error}',
                  name: 'journal_media',
                );
                return _errorBox('Image unavailable');
              },
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return _loadingBox();
        }
        return _errorBox('Image unavailable');
      },
    );
  }

  Widget _imageContainer(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black12,
      child: Text(message),
    );
  }

  Widget _loadingBox() {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class LocalVideoEmbedBuilder extends quill.EmbedBuilder {
  const LocalVideoEmbedBuilder();

  @override
  String get key => 'video';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final data = embedContext.node.value.data?.toString() ?? '';
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final payload = _parseEmbedPayload(data);
    final item = JournalMediaItem(
      type: 'video',
      url: payload.url,
      path: payload.path,
      bucket: payload.bucket,
    );
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'quill_video_embed'),
      builder: (context, snap) {
        final resolved = snap.data;
        if (resolved?.file != null) {
          return _videoContainer(_EmbeddedVideoPlayer.file(resolved!.file!));
        }
        final url = resolved?.url;
        if (url != null && url.isNotEmpty) {
          return _videoContainer(_EmbeddedVideoPlayer.network(url));
        }
        if (snap.connectionState != ConnectionState.done) {
          return _videoContainer(
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return _videoContainer(
          Container(
            height: 180,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text('Video unavailable'),
          ),
        );
      },
    );
  }

  Widget _videoContainer(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }
}

class _EmbeddedVideoPlayer extends StatefulWidget {
  const _EmbeddedVideoPlayer.file(this.file) : url = null;
  const _EmbeddedVideoPlayer.network(this.url) : file = null;

  final File? file;
  final String? url;

  @override
  State<_EmbeddedVideoPlayer> createState() => _EmbeddedVideoPlayerState();
}

class _EmbedPayload {
  const _EmbedPayload({this.url, this.path, this.bucket});

  final String? url;
  final String? path;
  final String? bucket;
}

_EmbedPayload _parseEmbedPayload(String data) {
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      return _EmbedPayload(
        url: map['url']?.toString(),
        path: map['path']?.toString(),
        bucket: map['bucket']?.toString(),
      );
    }
  } catch (_) {}
  return const _EmbedPayload();
}

class _EmbeddedVideoPlayerState extends State<_EmbeddedVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        height: 180,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: _durationChip(_controller.value.duration),
        ),
        IconButton(
          iconSize: 48,
          color: Colors.white,
          icon: Icon(
            _controller.value.isPlaying
                ? Icons.pause_circle
                : Icons.play_circle,
          ),
          onPressed: () {
            setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            });
          },
        ),
      ],
    );
  }

  Widget _durationChip(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$minutes:$seconds',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
