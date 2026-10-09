import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_source.dart';
import 'package:pronhub/services/playback_route_observer.dart';
import 'package:pronhub/widgets/video_stream_player.dart';
import 'package:media_kit/media_kit.dart';

class _PlayerPlatform extends PlatformPlayer {
  _PlayerPlatform() : super(configuration: const PlayerConfiguration());

  double get speed => state.rate;
  double get volume => state.volume / 100;
  Duration get position => state.position;
  Media? media;
  Completer<void>? openGate;
  final openPlayFlags = <bool>[];
  int playCalls = 0;

  void emitError(String error) => errorController.add(error);

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    openPlayFlags.add(play);
    await openGate?.future;
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
    playCalls++;
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
  testWidgets('loading player stays paused after leaving its route', (
    tester,
  ) async {
    final platform = _PlayerPlatform()..openGate = Completer<void>();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [playbackRouteObserver],
        home: Scaffold(
          body: VideoStreamPlayer(
            playerFactory: () => Player(platformPlayer: platform),
            videoSurface: const SizedBox(),
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
    );
    await tester.pump();
    expect(platform.openPlayFlags, [false]);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    platform.openGate!.complete();
    await tester.pumpAndSettle();
    expect(platform.state.playing, isFalse);
    expect(platform.playCalls, 0);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(platform.state.playing, isTrue);
    await platform.pause();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(platform.state.playing, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('player created beneath another route does not autoplay', (
    tester,
  ) async {
    final platform = _PlayerPlatform()..openGate = Completer<void>();
    final navigatorKey = GlobalKey<NavigatorState>();
    final loaded = ValueNotifier<bool>(false);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [playbackRouteObserver],
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: loaded,
            builder: (context, ready, child) => ready
                ? VideoStreamPlayer(
                    playerFactory: () => Player(platformPlayer: platform),
                    videoSurface: const SizedBox(),
                    sources: [
                      VideoSource(
                        url: Uri.parse('https://example.com/video.m3u8'),
                        quality: '720p',
                      ),
                    ],
                    pageUrl: Uri.parse('https://example.com/video'),
                  )
                : const SizedBox(),
          ),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    loaded.value = true;
    await tester.pump();
    await tester.pump();
    expect(platform.openPlayFlags, [false]);
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    platform.openGate!.complete();
    await tester.pumpAndSettle();
    expect(platform.playCalls, 1);
    expect(platform.state.playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    loaded.dispose();
  });

  testWidgets('mouse reveals controls and keeps hovered controls visible', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final fullscreenCalls = <bool>[];
    const windowChannel = MethodChannel('pronhub/window');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      (call) async => fullscreenCalls.add(call.arguments as bool),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        windowChannel,
        null,
      ),
    );
    final platform = _PlayerPlatform();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [playbackRouteObserver],
        home: Scaffold(
          body: VideoStreamPlayer(
            playerFactory: () => Player(platformPlayer: platform),
            videoSurface: const SizedBox(),
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
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byTooltip('暂停'), findsNothing);
    expect(find.byTooltip('返回'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(const Offset(200, 200));
    await tester.pump();
    expect(find.byTooltip('暂停'), findsOneWidget);
    await mouse.moveTo(tester.getCenter(find.byTooltip('暂停')));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await mouse.moveTo(tester.getCenter(find.byTooltip('界面内全屏')));
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.byTooltip('暂停'), findsOneWidget);
    await mouse.moveTo(const Offset(200, 200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.byTooltip('暂停'), findsNothing);
    await mouse.moveTo(const Offset(210, 210));
    await tester.pump();
    await tester.tap(find.byTooltip('桌面系统全屏'));
    await tester.pump();
    expect(fullscreenCalls, [true]);
    expect(find.byTooltip('退出系统全屏'), findsOneWidget);
    expect(find.byTooltip('退出界面全屏'), findsNothing);
    expect(find.byTooltip('界面内全屏'), findsNothing);
    await tester.tap(find.byTooltip('退出系统全屏'));
    await tester.pump();
    expect(fullscreenCalls, [true, false]);
    expect(find.byTooltip('界面内全屏'), findsOneWidget);
    expect(find.byTooltip('退出界面全屏'), findsNothing);
    expect(find.byTooltip('桌面系统全屏'), findsOneWidget);
    await tester.tap(find.byTooltip('界面内全屏'));
    await tester.pump();
    await tester.tap(find.byTooltip('桌面系统全屏'));
    await tester.pump();
    expect(find.byTooltip('退出界面全屏'), findsNothing);
    await tester.tap(find.byTooltip('退出系统全屏'));
    await tester.pump();
    expect(fullscreenCalls, [true, false, true, false]);
    expect(find.byTooltip('退出界面全屏'), findsOneWidget);
    expect(find.byTooltip('界面内全屏'), findsNothing);
    await tester.tap(find.byTooltip('退出界面全屏'));
    await tester.pump();
    await mouse.removePointer();
    expect(platform.state.playing, isTrue);
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('New page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.state.playing, isFalse);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(platform.state.playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    '410 refreshes silently once and resumed progress clears errors',
    (tester) async {
      final platform = _PlayerPlatform();
      var refreshes = 0;
      final freshSources = Completer<List<VideoSource>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoStreamPlayer(
              playerFactory: () => Player(platformPlayer: platform),
              videoSurface: const SizedBox(),
              sources: [
                VideoSource(
                  url: Uri.parse('https://example.com/old.m3u8'),
                  quality: '720p',
                ),
              ],
              pageUrl: Uri.parse('https://example.com/video'),
              refreshSources: () async {
                refreshes++;
                return freshSources.future;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await platform.pause();
      platform.emitError('Failed to open media');
      await tester.pump();
      expect(refreshes, 1);
      expect(find.text('Failed to open media'), findsNothing);
      expect(find.text('HTTP error 410 Gone'), findsNothing);
      platform.emitError('HTTP error 410 Gone');
      platform.emitError('Failed to open media');
      await tester.pump();
      expect(refreshes, 1);
      expect(find.text('HTTP error 410 Gone'), findsNothing);
      expect(find.text('Failed to open media'), findsNothing);
      freshSources.complete([
        VideoSource(
          url: Uri.parse('https://example.com/fresh.m3u8'),
          quality: '720p',
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(refreshes, 1);
      expect(platform.media!.uri, 'https://example.com/fresh.m3u8');
      expect(platform.state.playing, isTrue);
      platform.emitError('Failed to open fresh.m3u8');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(refreshes, 1);
      expect(find.text('Failed to open fresh.m3u8'), findsOneWidget);
      expect(find.byTooltip('返回'), findsOneWidget);
      await platform.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump();
      expect(find.text('Failed to open fresh.m3u8'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  test('Windows video proxy honors HTTPS configuration and bypasses', () {
    final environment = {
      'HTTPS_PROXY': 'http://127.0.0.1:7897',
      'HTTP_PROXY': 'http://127.0.0.1:7890',
      'NO_PROXY': 'localhost,.example.com,private.test:8443',
    };
    expect(
      windowsVideoProxy(Uri.parse('https://cdn.test/video.m3u8'), environment),
      'http://127.0.0.1:7897',
    );
    expect(
      windowsVideoProxy(
        Uri.parse('https://cdn.example.com/video'),
        environment,
      ),
      isNull,
    );
    expect(
      windowsVideoProxy(
        Uri.parse('https://private.test:8443/video'),
        environment,
      ),
      isNull,
    );
    expect(
      windowsVideoProxy(Uri.parse('https://private.test/video'), environment),
      'http://127.0.0.1:7897',
    );
    expect(
      windowsVideoProxy(Uri.parse('https://cdn.test/video'), {'NO_PROXY': '*'}),
      isNull,
    );
  });

  testWidgets('portrait and fullscreen controls, locking, speed and seeking', (
    tester,
  ) async {
    final platform = _PlayerPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.display.size = const Size(390, 844);
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.display.reset);
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
    expect(platform.media!.httpHeaders?['User-Agent'], contains('Mozilla/5.0'));
    platform.emitError('HTTP error 403 Forbidden');
    await tester.pump();
    await tester.pump();
    expect(find.text('HTTP error 403 Forbidden'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('HTTP error 403 Forbidden'), findsNothing);
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
    tester.view.display.size = const Size(1200, 800);
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    expect(find.byTooltip('锁定控制'), findsNothing);
    expect(
      find.byKey(const ValueKey('fullscreen-volume-gesture')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fullscreen-brightness-gesture')),
      findsNothing,
    );
    expect(find.byTooltip('播放速度'), findsOneWidget);
    expect(find.byTooltip('清晰度'), findsOneWidget);
    final tabletVolume = platform.volume;
    await tester.dragFrom(const Offset(1100, 400), const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 400));
    expect(platform.volume, tabletVolume);
    await tester.tap(find.byTooltip('退出全屏'));
    await tester.pump();
    expect(find.byTooltip('界面内全屏'), findsOneWidget);
    expect(find.byTooltip('桌面系统全屏'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}
