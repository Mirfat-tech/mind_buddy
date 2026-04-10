import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';

import 'journal_media.dart';

class JournalMediaViewer extends StatefulWidget {
  const JournalMediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  final List<JournalMediaItem> items;
  final int initialIndex;

  @override
  State<JournalMediaViewer> createState() => _JournalMediaViewerState();
}

class _JournalMediaViewerState extends State<JournalMediaViewer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: MbGlowBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          if (item.type == 'video') {
            return _VideoPage(item: item);
          }
          return _ImagePage(item: item);
        },
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.item});

  final JournalMediaItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedJournalMedia>(
      future: resolveJournalMedia(item, debugContext: 'media_viewer_image'),
      builder: (context, snap) {
        final resolved = snap.data;
        if (resolved?.file != null) {
          return Center(
            child: Image.file(resolved!.file!, fit: BoxFit.contain),
          );
        }
        if (resolved?.url != null && resolved!.url!.isNotEmpty) {
          return Center(
            child: Image.network(resolved.url!, fit: BoxFit.contain),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return const Center(child: Text('Image unavailable'));
      },
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.item});

  final JournalMediaItem item;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final resolved = await resolveJournalMedia(
        widget.item,
        debugContext: 'media_viewer_video',
      );
      final url = resolved.url;
      if (resolved.file == null && (url == null || url.isEmpty)) {
        if (mounted) {
          setState(() => _loadError = 'Video unavailable');
        }
        return;
      }
      _controller = resolved.file != null
          ? VideoPlayerController.file(resolved.file!)
          : VideoPlayerController.networkUrl(Uri.parse(url!));
      await _controller!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Video unavailable');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          IconButton(
            iconSize: 64,
            color: Colors.white,
            icon: Icon(
              _controller!.value.isPlaying
                  ? Icons.pause_circle
                  : Icons.play_circle,
            ),
            onPressed: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
          ),
        ],
      ),
    );
  }
}
