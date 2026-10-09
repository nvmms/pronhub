import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pronhub/pages/home_page.dart';
import 'package:pronhub/services/orientation_policy.dart';
import 'package:pronhub/services/playback_route_observer.dart';
import 'package:pronhub/services/webview_loader.dart';
import 'package:webview_all/webview_all.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static final _orientationPolicy = OrientationPolicy.instance;
  bool _webViewInFront = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.keyR ||
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    if (event is KeyDownEvent) {
      setState(() => _webViewInFront = !_webViewInFront);
    }
    return true;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pronhub',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_orientationPolicy, playbackRouteObserver],
      builder: (context, child) {
        _orientationPolicy.update(context);
        return IndexedStack(
          index: _webViewInFront ? 0 : 1,
          children: [
            ValueListenableBuilder<WebViewController?>(
              valueListenable: WebViewLoader.instance.controllerNotifier,
              builder: (context, controller, child) {
                if (controller == null) {
                  return const SizedBox.shrink();
                }

                return WebViewWidget(controller: controller);
              },
            ),
            child!,
          ],
        );
      },
      themeMode: ThemeMode.system,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomePage(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE98732),
      brightness: brightness,
      surface: dark ? const Color(0xFF121417) : const Color(0xFFF7F8FA),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1C2025) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
