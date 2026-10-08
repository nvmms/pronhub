import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pronhub/extensions/build_context_extensions.dart';

class OrientationPolicy extends NavigatorObserver {
  static const playbackRoute = '/playback';
  static final instance = OrientationPolicy();

  bool _fullscreen = false;
  bool _isPhone = false;
  String? _lastMode;

  void update(BuildContext context) {
    _isPhone = context.isPhone;
    _apply();
  }

  void _apply() {
    final mode = _isPhone ? (_fullscreen ? 'fullscreen' : 'phone') : 'large';
    if (mode == _lastMode) return;
    _lastMode = mode;
    unawaited(
      SystemChrome.setPreferredOrientations(switch (mode) {
        'phone' => [DeviceOrientation.portraitUp],
        _ => [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      }),
    );
  }

  void setFullscreen(BuildContext context, bool fullscreen) {
    _fullscreen = fullscreen;
    update(context);
  }

  void exitFullscreen() {
    _fullscreen = false;
    _apply();
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute is! PageRoute) return;
    _fullscreen = false;
    final context = navigator?.context;
    if (context != null) update(context);
  }
}
