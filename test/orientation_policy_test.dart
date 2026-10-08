import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/extensions/build_context_extensions.dart';
import 'package:pronhub/services/orientation_policy.dart';

void main() {
  testWidgets(
    'phone stays portrait on playback and rotates only in fullscreen',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.display.size = const Size(390, 844);
      tester.view.display.devicePixelRatio = 1;
      addTearDown(tester.view.display.reset);
      final requests = <List<dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            requests.add(call.arguments as List<dynamic>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      final policy = OrientationPolicy();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [policy],
          builder: (context, child) {
            policy.update(context);
            return child!;
          },
          home: const SizedBox(),
        ),
      );
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      void openPlayer() {
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(
              name: OrientationPolicy.playbackRoute,
            ),
            builder: (_) => const SizedBox(),
          ),
        );
      }

      openPlayer();
      await tester.pumpAndSettle();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      policy.setFullscreen(navigatorKey.currentContext!, true);
      await tester.pump();
      expect(requests.last, [
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      policy.exitFullscreen();
      await tester.pump();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      openPlayer();
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
      debugDefaultTargetPlatformOverride = null;
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(requests.last, ['DeviceOrientation.portraitUp']);
    },
  );

  testWidgets('tablet and desktop stay in large layout in portrait windows', (
    tester,
  ) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(tester.view.display.reset);
    tester.view.display.devicePixelRatio = 1;
    for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.display.size = platform == TargetPlatform.android
          ? const Size(800, 1200)
          : const Size(390, 844);
      bool? isPhone;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isPhone = context.isPhone;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(isPhone, isFalse);
      await tester.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
