import 'package:flutter/material.dart';
import 'package:pronhub/views/video_view.dart';

///
/// /language/${language}
///
class LanguagePage extends StatefulWidget {
  final String language;
  const LanguagePage({super.key, required this.language});

  @override
  State<StatefulWidget> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoView(
        path: '/language/${Uri.encodeComponent(widget.language)}',
      ),
    );
  }
}
