import 'package:flutter/material.dart';
import 'package:pronhub/pages/home_page.dart';

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
    return HomePage(
      title: widget.language == 'chinese' ? '中文视频' : widget.language,
      path: '/language/${Uri.encodeComponent(widget.language)}',
    );
  }
}
