import 'dart:io';

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
    final file = resolveMediaFile(item);
    final url = item.url ?? item.path ?? '';

    return Center(
      child: file != null
          ? Image.file(file, fit: BoxFit.contain)
          : Image.network(url, fit: BoxFit.contain),
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
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final file = resolveMediaFile(widget.item);
    _controller = file != null
        ? VideoPlayerController.file(file)
        : VideoPlayerController.networkUrl(
            Uri.parse(widget.item.url ?? widget.item.path ?? ''),
          );
    _controller.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
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
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          IconButton(
            iconSize: 64,
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
      ),
    );
  }
}
