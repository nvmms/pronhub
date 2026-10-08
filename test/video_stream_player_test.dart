import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_source.dart';
import 'package:pronhub/widgets/video_stream_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _PlayerPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  int nextId = 0;
  double speed = 1;
  double volume = 1;
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = nextId++;
    streams[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1280, 720),
          duration: const Duration(minutes: 10),
        ),
      );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    await streams[playerId]!.close();
  }

  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    this.speed = speed;
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Color(0xFF293D42));
}

void main() {
  testWidgets('portrait and fullscreen controls, locking, speed and seeking', (
    tester,
  ) async {
    final previous = VideoPlayerPlatform.instance;
    final platform = _PlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoStreamPlayer(
                title: '测试视频',
                sources: [
                  VideoSource(
                    url: Uri.parse('https://example.com/video.m3u8'),
                    quality: '720p',
                  ),
                ],
                pageUrl: Uri.parse('https://example.com/video'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('暂停'), findsOneWidget);
    expect(find.byTooltip('全屏播放'), findsOneWidget);
    expect(find.byTooltip('播放速度'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('全屏播放'));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('测试视频'), findsOneWidget);
    expect(find.byTooltip('播放速度'), findsOneWidget);
    expect(find.byTooltip('清晰度'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('fullscreen-volume-gesture')),
      const Offset(0, 80),
    );
    await tester.pump();
    expect(platform.volume, lessThan(1));
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('fullscreen-brightness-gesture')),
      const Offset(0, -50),
    );
    await tester.pump();
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    final slider = find.byType(Slider);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byTooltip('播放速度'), findsNothing);
    final previousVolume = platform.volume;
    await tester.dragFrom(const Offset(750, 190), const Offset(0, 60));
    await tester.pump();
    expect(platform.volume, lessThan(previousVolume));
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.byTooltip('播放速度'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.dragFrom(const Offset(80, 190), const Offset(0, 60));
    await tester.pump();
    expect(find.byIcon(Icons.arrow_drop_up), findsOneWidget);
    expect(find.byTooltip('播放速度'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tapAt(const Offset(300, 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getCenter(slider).dy,
      closeTo(tester.getCenter(find.text('倍速')).dy, 1),
    );
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();
    expect(platform.position, greaterThan(Duration.zero));
    await tester.tap(find.byTooltip('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(platform.speed, 1.5);
    await tester.tap(find.byTooltip('锁定控制'));
    await tester.pump();
    expect(find.byTooltip('播放速度'), findsNothing);
    await tester.tap(find.byTooltip('解锁'));
    await tester.pump();
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pump();
    expect(find.byTooltip('全屏播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
