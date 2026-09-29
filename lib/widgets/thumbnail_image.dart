import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pronhub/widgets/image_cache_key.dart';

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
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (url == null) return ColoredBox(color: placeholderColor);

    return CachedNetworkImage(
      imageUrl: url.toString(),
      cacheKey: imageCacheKey(url!),
      httpHeaders: {'Referer': referer.toString()},
      fit: BoxFit.cover,
      placeholder: (context, url) => ColoredBox(color: placeholderColor),
      errorWidget: (context, url, error) {
        debugPrint('[thumbnail error] id=$videoId url=$url error=$error');
        return ColoredBox(color: placeholderColor);
      },
    );
  }
}
