import 'package:pronhub/extensions/build_context_extensions.dart';
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
      appBar: context.isPhone ? AppBar(title: Text(widget.language)) : null,
      body: VideoView(
        path: '/language/${Uri.encodeComponent(widget.language)}',
      ),
    );
  }
}
