import 'package:pronhub/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:pronhub/views/video_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: context.isPhone ? AppBar(title: const Text('Pronhub')) : null,
    body: const VideoView(path: "/video"),
  );
}
