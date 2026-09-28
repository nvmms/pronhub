import 'package:flutter/material.dart';
import 'package:pronhub/views/video_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: const VideoView(path: "/video"));
}
