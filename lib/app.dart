import 'package:flutter/material.dart';
import 'package:pronhub/pages/home_page.dart';
import 'package:pronhub/services/orientation_policy.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final _orientationPolicy = OrientationPolicy.instance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pronhub',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_orientationPolicy],
      builder: (context, child) {
        _orientationPolicy.update(context);
        return child!;
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
