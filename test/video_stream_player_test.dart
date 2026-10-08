import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_source.dart';
import 'package:pronhub/widgets/video_stream_player.dart';
import 'package:media_kit/media_kit.dart';

class _PlayerPlatform extends PlatformPlayer {
  _PlayerPlatform() : super(configuration: const PlayerConfiguration());

  double get speed => state.rate;
  double get volume => state.volume / 100;
  Duration get position => state.position;
  Media? media;

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    media = playable as Media;
    state = state.copyWith(
      playing: play,
      duration: const Duration(minutes: 10),
      position: media!.start ?? Duration.zero,
    );
    playingController.add(play);
    durationController.add(state.duration);
  }

  @override
  Future<void> play() async {
    state = state.copyWith(playing: true);
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(playing: false);
    playingController.add(false);
  }

  @override
  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume);
    volumeController.add(volume);
  }

  @override
  Future<void> setRate(double rate) async {
    state = state.copyWith(rate: rate);
    rateController.add(rate);
  }

  @override
  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    positionController.add(position);
  }
}

void main() {
  testWidgets('portrait and fullscreen controls, locking, speed and seeking', (
    tester,
  ) async {
    final platform = _PlayerPlatform();
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
                playerFactory: () => Player(platformPlayer: platform),
                videoSurface: const ColoredBox(color: Color(0xFF293D42)),
                title: '测试视频',
                sources: [
                  VideoSource(
                    url: Uri.parse('https://example.com/video.m3u8'),
                    quality: '720p',
                  ),
                  VideoSource(
                    url: Uri.parse('https://example.com/480.m3u8'),
                    quality: '480p',
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
    expect(
      platform.media!.httpHeaders?['Referer'],
      'https://example.com/video',
    );
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
    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();
    final resumePosition = platform.position;
    final resumeVolume = platform.volume;
    await tester.tap(find.byTooltip('清晰度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('480p'));
    await tester.pumpAndSettle();
    expect(platform.media!.uri, 'https://example.com/480.m3u8');
    expect(platform.media!.start, resumePosition);
    expect(platform.state.playing, isFalse);
    expect(platform.speed, 1.5);
    expect(platform.volume, resumeVolume);
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
