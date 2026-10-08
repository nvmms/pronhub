import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

extension BuildContextExtensions on BuildContext {
  bool get isPhone {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final display = View.of(this).display;
    return display.size.shortestSide / display.devicePixelRatio < 600;
  }
}
