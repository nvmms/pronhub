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
    this.title = '',
  });

  final List<VideoSource> sources;
  final Uri pageUrl;
  final String title;

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
  final _fullscreenRevision = ValueNotifier<int>(0);
  Timer? _controlsTimer;
  Timer? _adjustmentTimer;
  bool _controlsVisible = true;
  bool _locked = false;
  String? _adjustment;
  double _brightness = 1;
  double _speed = 1;

  void _startAdjustment(String kind) {
    _adjustmentTimer?.cancel();
    _controlsTimer?.cancel();
    setState(() {
      _adjustment = kind;
    });
    _fullscreenRevision.value++;
  }

  void _dragAdjustment(DragUpdateDetails details) {
    final controller = _controller;
    if (controller == null || _adjustment == null) return;
    final change = -details.delta.dy / 200;
    if (_adjustment == 'brightness') {
      setState(() => _brightness = (_brightness + change).clamp(.2, 1.0));
    } else {
      controller.setVolume((controller.value.volume + change).clamp(0.0, 1.0));
    }
    _fullscreenRevision.value++;
  }

  void _endAdjustment() {
    _adjustmentTimer?.cancel();
    _adjustmentTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _adjustment = null);
      _fullscreenRevision.value++;
    });
    _refreshControls();
  }

  Widget _sideAdjustment(String kind, VideoPlayerController controller) {
    final active = _adjustment == kind;
    final brightness = kind == 'brightness';
    final level = brightness
        ? (_brightness - .2) / .8
        : controller.value.volume;
    final icon = brightness
        ? Icons.brightness_6_outlined
        : (controller.value.volume == 0
              ? Icons.volume_off_outlined
              : Icons.volume_up_outlined);
    return Semantics(
      label: brightness ? '画面亮度，上下滑动调节' : '音量，上下滑动调节',
      value: '${(level * 100).round()}%',
      child: GestureDetector(
        key: ValueKey('fullscreen-$kind-gesture'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _startAdjustment(kind),
        onVerticalDragUpdate: _dragAdjustment,
        onVerticalDragEnd: (_) => _endAdjustment(),
        onVerticalDragCancel: _endAdjustment,
        onTap: () {
          _startAdjustment(kind);
          _endAdjustment();
        },
        child: SizedBox(
          width: 100,
          height: 220,
          child: active
              ? Row(
                  textDirection: brightness ? TextDirection.ltr : TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_drop_up, color: Colors.white),
                        Container(
                          width: 46,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 3,
                      height: 190,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(color: Colors.white24),
                          FractionallySizedBox(
                            heightFactor: level,
                            child: Container(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ),
        ),
      ),
    );
  }

  void _refreshControls() {
    _controlsTimer?.cancel();
    if (_controller?.value.isPlaying != true) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _controlsVisible = false;
        _adjustment = null;
      });
      _fullscreenRevision.value++;
    });
  }

  void _changeControls(VoidCallback change) {
    setState(change);
    _fullscreenRevision.value++;
    _refreshControls();
  }

  String _time(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

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
    final resumePlaying = previous?.value.isPlaying ?? true;
    final volume = previous?.value.volume ?? 1.0;
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
    _fullscreenRevision.value++;
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
      _fullscreenRevision.value++;
      await controller.setVolume(volume);
      if (resumePlaying) await controller.play();
      await controller.setPlaybackSpeed(_speed);
      _refreshControls();
    } catch (error) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _error = error);
        _fullscreenRevision.value++;
      }
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _controlsTimer?.cancel();
    _adjustmentTimer?.cancel();
    final history = _fullscreenHistory;
    _fullscreenHistory = null;
    history?.remove();
    _removeFullscreenOverlay();
    _controller?.dispose();
    _fullscreenRevision.dispose();
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
    setState(() {
      _isFullscreen = false;
      _locked = false;
      _controlsVisible = true;
      _adjustment = null;
    });
    _refreshControls();
  }

  void showFullscreen() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isFullscreen) {
      return;
    }
    setState(() {
      _isFullscreen = true;
      _controlsVisible = true;
    });
    _refreshControls();
    OrientationPolicy.instance.setFullscreen(context, true);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _fullscreenOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Material(
              color: Colors.black,
              child: ValueListenableBuilder<int>(
                valueListenable: _fullscreenRevision,
                builder: (_, _, _) => _fullscreenContent(),
              ),
            ),
          ),
        ),
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

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap) =>
      IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withValues(alpha: .16),
        ),
        onPressed: onTap,
        icon: Icon(icon),
      );

  Widget _playerSurface(
    VideoPlayerController controller, {
    bool fullscreen = false,
    VoidCallback? onFullscreenPressed,
  }) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final value = controller.value;
      final visible = _controlsVisible || !value.isPlaying;
      final duration = value.duration.inMilliseconds.toDouble();
      final position = value.position.inMilliseconds.toDouble().clamp(
        0.0,
        duration,
      );
      final progress = SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          activeTrackColor: Colors.white,
          inactiveTrackColor: Colors.white38,
          thumbColor: Colors.white,
        ),
        child: Slider(
          value: position,
          max: duration > 0 ? duration : 1,
          onChangeStart: (_) => _controlsTimer?.cancel(),
          onChanged: (milliseconds) =>
              controller.seekTo(Duration(milliseconds: milliseconds.round())),
          onChangeEnd: (_) => _refreshControls(),
        ),
      );
      return DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: fullscreen && !_locked
                  ? (details) => _startAdjustment(
                      details.localPosition.dx <
                              MediaQuery.sizeOf(context).width / 2
                          ? 'brightness'
                          : 'volume',
                    )
                  : null,
              onVerticalDragUpdate: fullscreen && !_locked
                  ? _dragAdjustment
                  : null,
              onVerticalDragEnd: fullscreen && !_locked
                  ? (_) => _endAdjustment()
                  : null,
              onVerticalDragCancel: fullscreen && !_locked
                  ? _endAdjustment
                  : null,
              onTap: () => _changeControls(() => _controlsVisible = !visible),
              onDoubleTap: _locked
                  ? null
                  : () {
                      value.isPlaying ? controller.pause() : controller.play();
                      _changeControls(() => _controlsVisible = true);
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 1 - _brightness),
                    ),
                  ),
                ],
              ),
            ),
            if (value.isBuffering)
              const IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            if (visible && !_locked) ...[
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black45,
                        Colors.transparent,
                        Colors.black54,
                      ],
                      stops: const [0, .45, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: fullscreen ? 16 : 4,
                left: 4,
                right: 60,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            color: Colors.white,
                            tooltip: fullscreen ? '退出全屏' : '返回',
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 22,
                            ),
                            onPressed: fullscreen
                                ? onFullscreenPressed
                                : () => Navigator.maybePop(context),
                          ),
                          if (fullscreen)
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: value.isPlaying ? '暂停' : '播放',
                      iconSize: 60,
                      color: Colors.white,
                      icon: Icon(
                        value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: () {
                        value.isPlaying
                            ? controller.pause()
                            : controller.play();
                        _changeControls(() => _controlsVisible = true);
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: fullscreen ? 8 : 0,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Text(
                        fullscreen
                            ? '${_time(value.position)} / ${_time(value.duration)}'
                            : _time(value.position),
                      ),
                      Expanded(child: progress),
                      if (fullscreen) ...[
                        PopupMenuButton<double>(
                          tooltip: '播放速度',
                          initialValue: _speed,
                          onOpened: () => _controlsTimer?.cancel(),
                          onCanceled: _refreshControls,
                          onSelected: (speed) {
                            controller.setPlaybackSpeed(speed);
                            _changeControls(() => _speed = speed);
                          },
                          itemBuilder: (_) => [
                            for (final speed in [.5, .75, 1.0, 1.25, 1.5, 2.0])
                              PopupMenuItem(
                                value: speed,
                                child: Text('${speed}x'),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_speed == 1 ? '倍速' : '${_speed}x'),
                          ),
                        ),
                        PopupMenuButton<VideoSource>(
                          tooltip: '清晰度',
                          initialValue: _selected,
                          onOpened: () => _controlsTimer?.cancel(),
                          onCanceled: _refreshControls,
                          onSelected: (source) {
                            if (source != _selected) _open(source);
                            _refreshControls();
                          },
                          itemBuilder: (_) => [
                            for (final source in widget.sources)
                              PopupMenuItem(
                                value: source,
                                child: Text(source.quality),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_selected?.quality ?? '清晰度'),
                          ),
                        ),
                      ] else ...[
                        Text(_time(value.duration)),
                        IconButton(
                          color: Colors.white,
                          tooltip: '全屏播放',
                          icon: const Icon(Icons.screen_rotation_rounded),
                          onPressed: showFullscreen,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (fullscreen && !_locked) ...[
              if (visible || _adjustment == 'brightness')
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _sideAdjustment('brightness', controller),
                  ),
                ),
              if (visible || _adjustment == 'volume')
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _sideAdjustment('volume', controller)),
                ),
            ],
            if (fullscreen && visible)
              Positioned(
                top: 100,
                right: 12,
                child: _roundButton(
                  _locked ? Icons.lock_outline : Icons.lock_open_outlined,
                  _locked ? '解锁' : '锁定控制',
                  () => _changeControls(() {
                    _locked = !_locked;
                    _adjustment = null;
                  }),
                ),
              ),
          ],
        ),
      );
    },
  );
}
