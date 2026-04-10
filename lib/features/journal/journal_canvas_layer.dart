import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:mind_buddy/features/journal/journal_media.dart';
import 'package:mind_buddy/features/journal/journal_sticker_catalog.dart';
import 'package:mind_buddy/services/journal_canvas_objects.dart';

class JournalCanvasLayer extends StatelessWidget {
  const JournalCanvasLayer({
    super.key,
    required this.objects,
    required this.selectedObjectId,
    required this.onSelectObject,
    required this.onUpdateObject,
    required this.onDeleteObject,
    this.editable = false,
    this.interactionEnabled = false,
    this.uploadProgressByPath = const <String, double>{},
    this.failedPaths = const <String>{},
  });

  final List<JournalCanvasObject> objects;
  final String? selectedObjectId;
  final ValueChanged<String?> onSelectObject;
  final ValueChanged<JournalCanvasObject> onUpdateObject;
  final ValueChanged<String> onDeleteObject;
  final bool editable;
  final bool interactionEnabled;
  final Map<String, double> uploadProgressByPath;
  final Set<String> failedPaths;

  @override
  Widget build(BuildContext context) {
    final ordered = [...objects]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return IgnorePointer(
      ignoring: editable && !interactionEnabled,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: editable ? () => onSelectObject(null) : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final object in ordered)
                  _CanvasObjectItem(
                    key: ValueKey(object.id),
                    object: object,
                    canvasSize: canvasSize,
                    editable: editable,
                    interactionEnabled: interactionEnabled,
                    isSelected: object.id == selectedObjectId,
                    onSelect: () => onSelectObject(object.id),
                    onUpdate: onUpdateObject,
                    onDelete: () => onDeleteObject(object.id),
                    uploadProgressByPath: uploadProgressByPath,
                    failedPaths: failedPaths,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CanvasObjectItem extends StatefulWidget {
  const _CanvasObjectItem({
    super.key,
    required this.object,
    required this.canvasSize,
    required this.editable,
    required this.interactionEnabled,
    required this.isSelected,
    required this.onSelect,
    required this.onUpdate,
    required this.onDelete,
    required this.uploadProgressByPath,
    required this.failedPaths,
  });

  final JournalCanvasObject object;
  final Size canvasSize;
  final bool editable;
  final bool interactionEnabled;
  final bool isSelected;
  final VoidCallback onSelect;
  final ValueChanged<JournalCanvasObject> onUpdate;
  final VoidCallback onDelete;
  final Map<String, double> uploadProgressByPath;
  final Set<String> failedPaths;

  @override
  State<_CanvasObjectItem> createState() => _CanvasObjectItemState();
}

class _CanvasObjectItemState extends State<_CanvasObjectItem> {
  late JournalCanvasObject _gestureStartObject;
  late Offset _gestureStartFocalPoint;

  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    final width = object.width * widget.canvasSize.width;
    final height = object.height * widget.canvasSize.height;
    final left = object.x * widget.canvasSize.width;
    final top = object.y * widget.canvasSize.height;
    final showDeleteBadge = widget.editable &&
        (widget.isSelected || widget.interactionEnabled);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.editable ? widget.onSelect : null,
        onScaleStart: widget.editable && widget.interactionEnabled
            ? (details) {
                widget.onSelect();
                _gestureStartObject = widget.object;
                _gestureStartFocalPoint = details.focalPoint;
              }
            : null,
        onScaleUpdate: widget.editable && widget.interactionEnabled
            ? (details) {
                final dx =
                    (details.focalPoint.dx - _gestureStartFocalPoint.dx) /
                    widget.canvasSize.width;
                final dy =
                    (details.focalPoint.dy - _gestureStartFocalPoint.dy) /
                    widget.canvasSize.height;
                final minSize = widget.object.isSticker ? 0.14 : 0.18;
                final maxWidth = widget.object.isSticker ? 0.42 : 0.78;
                final maxHeight = widget.object.isSticker ? 0.42 : 0.62;
                final width = (_gestureStartObject.width * details.scale).clamp(
                  minSize,
                  maxWidth,
                );
                final height =
                    (_gestureStartObject.height * details.scale).clamp(
                      minSize,
                      maxHeight,
                    );
                final x = (_gestureStartObject.x + dx).clamp(0.0, 1.0 - width);
                final y = (_gestureStartObject.y + dy).clamp(
                  0.0,
                  1.0 - height,
                );
                widget.onUpdate(
                  widget.object.copyWith(
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    rotation: _gestureStartObject.rotation + details.rotation,
                  ),
                );
              }
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Transform.rotate(
                angle: object.rotation,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned.fill(
                      child: _CanvasObjectSurface(
                        object: object,
                        uploadProgressByPath: widget.uploadProgressByPath,
                        failedPaths: widget.failedPaths,
                      ),
                    ),
                    if (widget.editable && widget.isSelected)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.6),
                                width: 1.4,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showDeleteBadge)
              Positioned(
                top: -14,
                right: -14,
                child: _CanvasDeleteBadge(
                  onPressed: widget.onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CanvasDeleteBadge extends StatelessWidget {
  const _CanvasDeleteBadge({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.16),
              blurRadius: 12,
              spreadRadius: 0.8,
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: 'Delete item',
          iconSize: 20,
          padding: const EdgeInsets.all(7),
          constraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          splashRadius: 22,
          icon: Icon(
            Icons.close_rounded,
            color: colorScheme.primary,
            weight: 700,
          ),
        ),
      ),
    );
  }
}

class _CanvasObjectSurface extends StatelessWidget {
  const _CanvasObjectSurface({
    required this.object,
    required this.uploadProgressByPath,
    required this.failedPaths,
  });

  final JournalCanvasObject object;
  final Map<String, double> uploadProgressByPath;
  final Set<String> failedPaths;

  @override
  Widget build(BuildContext context) {
    final isSticker = object.isSticker;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSticker ? Colors.transparent : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: isSticker
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSticker ? 0 : 22),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            switch (object.type) {
              JournalCanvasObjectType.image => _CanvasImage(object: object),
              JournalCanvasObjectType.video => _CanvasVideo(object: object),
              JournalCanvasObjectType.gif => _CanvasGif(object: object),
              JournalCanvasObjectType.sticker => _CanvasSticker(object: object),
            },
            if (_uploadProgress(object) case final progress?)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(value: progress),
                    ),
                  ),
                ),
              ),
            if (_isFailed(object))
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      'Upload failed',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double? _uploadProgress(JournalCanvasObject object) {
    final path = object.path;
    if (path == null || path.isEmpty) return null;
    final value = uploadProgressByPath[path];
    if (value == null || value >= 1) return null;
    return value.clamp(0, 1);
  }

  bool _isFailed(JournalCanvasObject object) {
    final path = object.path;
    if (path == null || path.isEmpty) return false;
    return failedPaths.contains(path);
  }
}

class _CanvasImage extends StatelessWidget {
  const _CanvasImage({required this.object});

  final JournalCanvasObject object;

  @override
  Widget build(BuildContext context) {
    final item = JournalMediaItem(
      type: 'image',
      url: object.url,
      path: object.path,
      bucket: object.bucket,
    );
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'canvas_image'),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved?.file case final File file?) {
          return Image.file(file, fit: BoxFit.cover);
        }
        if (resolved?.url case final String url?) {
          return Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _CanvasUnavailableBox(icon: Icons.photo),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return const _CanvasUnavailableBox(icon: Icons.broken_image_outlined);
      },
    );
  }
}

class _CanvasVideo extends StatelessWidget {
  const _CanvasVideo({required this.object});

  final JournalCanvasObject object;

  @override
  Widget build(BuildContext context) {
    final item = JournalMediaItem(
      type: 'video',
      url: object.url,
      path: object.path,
      bucket: object.bucket,
    );
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'canvas_video'),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved?.file case final File file?) {
          return _CanvasVideoPlayer(file: file);
        }
        if (resolved?.url case final String url?) {
          return _CanvasVideoPlayer(url: url);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return const _CanvasUnavailableBox(icon: Icons.videocam_off_outlined);
      },
    );
  }
}

class _CanvasGif extends StatelessWidget {
  const _CanvasGif({required this.object});

  final JournalCanvasObject object;

  @override
  Widget build(BuildContext context) {
    final item = JournalMediaItem(
      type: 'gif',
      url: object.url,
      path: object.path,
      bucket: object.bucket,
    );
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'canvas_gif'),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved?.file case final File file?) {
          return Image.file(file, fit: BoxFit.cover, gaplessPlayback: true);
        }
        if (resolved?.url case final String url?) {
          return Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) =>
                const _CanvasUnavailableBox(icon: Icons.gif_box_outlined),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return const _CanvasUnavailableBox(icon: Icons.gif_box_outlined);
      },
    );
  }
}

class _CanvasSticker extends StatelessWidget {
  const _CanvasSticker({required this.object});

  final JournalCanvasObject object;

  @override
  Widget build(BuildContext context) {
    final sticker = JournalStickerCatalog.byId(object.stickerId);
    if (sticker == null) {
      return const _CanvasUnavailableBox(icon: Icons.hide_image_outlined);
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: JournalStickerArt(definition: sticker),
    );
  }
}

class _CanvasUnavailableBox extends StatelessWidget {
  const _CanvasUnavailableBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(icon, size: 34)),
    );
  }
}

class _CanvasVideoPlayer extends StatefulWidget {
  const _CanvasVideoPlayer({this.file, this.url})
    : assert(file != null || url != null);

  final File? file;
  final String? url;

  @override
  State<_CanvasVideoPlayer> createState() => _CanvasVideoPlayerState();
}

class _CanvasVideoPlayerState extends State<_CanvasVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
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
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: IconButton.filled(
            onPressed: () {
              setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.32),
              foregroundColor: Colors.white,
            ),
            iconSize: 38,
            icon: Icon(
              _controller.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                _formatDuration(_controller.value.duration),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
