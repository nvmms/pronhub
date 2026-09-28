import 'package:flutter/material.dart';

class ThumbnailImage extends StatelessWidget {
  const ThumbnailImage({
    super.key,
    required this.url,
    required this.videoId,
    required this.referer,
  });

  final Uri? url;
  final String videoId;
  final Uri referer;

  @override
  Widget build(BuildContext context) {
    debugPrint('[thumbnail] id=$videoId url=${url ?? '(missing)'}');
    if (url == null) return const ColoredBox(color: Colors.black12);

    return Image.network(
      url.toString(),
      headers: {'Referer': referer.toString()},
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[thumbnail error] id=$videoId url=$url error=$error');
        return const ColoredBox(color: Colors.black12);
      },
    );
  }
}
