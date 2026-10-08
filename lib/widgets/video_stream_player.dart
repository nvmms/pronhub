import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pronhub/services/orientation_policy.dart';
import 'package:pronhub/models/video_source.dart';
import 'package:video_player/video_player.dart';

class VideoStreamPlayer extends StatefulWidget {
  const VideoStreamPlayer({
    super.key,
    required this.sources,
    required this.pageUrl,
  });

  final List<VideoSource> sources;
  final Uri pageUrl;

  @override
  State<VideoStreamPlayer> createState() => VideoStreamPlayerState();
}

class VideoStreamPlayerState extends State<VideoStreamPlayer> {
  VideoPlayerController? _controller;
  VideoSource? _selected;
  Object? _error;
  bool _isFullscreen = false;
  bool _disposing = false;
  OverlayEntry? _fullscreenOverlay;
  LocalHistoryEntry? _fullscreenHistory;

  VideoSource _preferredSource() {
    for (final source in widget.sources) {
      if (source.quality == '720p') return source;
    }
    return widget.sources.first;
  }

  @override
  void initState() {
    super.initState();
    if (widget.sources.isNotEmpty) {
      _open(_preferredSource());
    }
  }

  @override
  void didUpdateWidget(covariant VideoStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sources.isNotEmpty &&
        (oldWidget.sources.isEmpty ||
            oldWidget.sources.first.url != widget.sources.first.url)) {
      _open(_preferredSource());
    }
  }

  Future<void> _open(VideoSource source) async {
    final previous = _controller;
    final resumePosition = previous?.value.isInitialized == true
        ? previous!.value.position
        : Duration.zero;
    final controller = VideoPlayerController.networkUrl(
      source.url,
      formatHint: VideoFormat.hls,
      httpHeaders: {'Referer': widget.pageUrl.toString()},
    );
    setState(() {
      _selected = source;
      _controller = controller;
      _error = null;
    });
    _fullscreenOverlay?.markNeedsBuild();
    if (previous != null) await previous.dispose();
    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;
      if (resumePosition > Duration.zero) {
        final duration = controller.value.duration;
        await controller.seekTo(
          resumePosition < duration ? resumePosition : duration,
        );
      }
      if (!mounted || !identical(_controller, controller)) return;
      setState(() {});
      _fullscreenOverlay?.markNeedsBuild();
      await controller.play();
    } catch (error) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _error = error);
        _fullscreenOverlay?.markNeedsBuild();
      }
    }
  }

  @override
  void dispose() {
    _disposing = true;
    final history = _fullscreenHistory;
    _fullscreenHistory = null;
    history?.remove();
    _removeFullscreenOverlay();
    _controller?.dispose();
    super.dispose();
  }

  void _removeFullscreenOverlay() {
    final overlay = _fullscreenOverlay;
    if (overlay == null) return;
    overlay.remove();
    overlay.dispose();
    _fullscreenOverlay = null;
    OrientationPolicy.instance.exitFullscreen();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  void hideFullscreen() {
    if (_disposing || !_isFullscreen) return;
    final history = _fullscreenHistory;
    _fullscreenHistory = null;
    if (history != null) {
      history.remove();
      return;
    }
    _removeFullscreenOverlay();
    setState(() => _isFullscreen = false);
  }

  void showFullscreen() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isFullscreen) {
      return;
    }
    setState(() => _isFullscreen = true);
    OrientationPolicy.instance.setFullscreen(context, true);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _fullscreenOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(color: Colors.black, child: _fullscreenContent()),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_fullscreenOverlay!);
    _fullscreenHistory = LocalHistoryEntry(
      onRemove: () {
        _fullscreenHistory = null;
        hideFullscreen();
      },
    );
    ModalRoute.of(context)?.addLocalHistoryEntry(_fullscreenHistory!);
  }

  Widget _fullscreenContent() {
    final controller = _controller;
    if (_error != null) {
      return _fullscreenStatus(
        TextButton(
          onPressed: () => _open(_selected!),
          child: const Text('播放地址加载失败，点击重试'),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return _fullscreenStatus(const CircularProgressIndicator());
    }
    return _playerSurface(
      controller,
      fullscreen: true,
      onFullscreenPressed: hideFullscreen,
    );
  }

  Widget _fullscreenStatus(Widget child) => Stack(
    children: [
      Center(child: child),
      Positioned(
        top: 16,
        right: 16,
        child: IconButton(
          color: Colors.white,
          tooltip: '退出全屏',
          icon: const Icon(Icons.fullscreen_exit),
          onPressed: hideFullscreen,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: Text('没有可用的播放地址', style: TextStyle(color: Colors.white70)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('播放地址加载失败', style: TextStyle(color: Colors.white)),
            TextButton(
              onPressed: () => _open(_selected!),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isFullscreen) return const ColoredBox(color: Colors.black);
    return _playerSurface(controller);
  }

  Widget _playerSurface(
    VideoPlayerController controller, {
    bool fullscreen = false,
    VoidCallback? onFullscreenPressed,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          if (controller.value.isBuffering)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: () => controller.value.isPlaying
                        ? controller.pause()
                        : controller.play(),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<VideoSource>(
                    value: _selected,
                    dropdownColor: Colors.black87,
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final source in widget.sources)
                        DropdownMenuItem(
                          value: source,
                          child: Text(source.quality),
                        ),
                    ],
                    onChanged: (source) {
                      if (source != null && source != _selected) _open(source);
                    },
                  ),
                  IconButton(
                    color: Colors.white,
                    tooltip: fullscreen ? '退出全屏' : '全屏播放',
                    icon: Icon(
                      fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                    onPressed: fullscreen
                        ? onFullscreenPressed
                        : showFullscreen,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
