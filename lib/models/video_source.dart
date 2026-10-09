import 'dart:convert';

class VideoSource {
  const VideoSource({required this.url, required this.quality});

  final Uri url;
  final String quality;

  static List<VideoSource> fromHtml(String html) {
    return fromDefinitions(_definitionsFromHtml(html));
  }

  /// Remote entries describe a JSON resolver, not a playable media URL.
  static List<Uri> remoteUrlsFromHtml(String html, Uri baseUri) {
    final urls = <Uri>{};
    for (final value in _definitionsFromHtml(html)) {
      if (value is! Map<String, dynamic>) continue;
      final remote =
          value['remote'] == true ||
          (value['format'] == 'mp4' && value['quality'] is List);
      final url = value['videoUrl'];
      if (!remote || url is! String || url.isEmpty) continue;
      final uri = baseUri.resolve(url);
      if (uri.scheme == 'https' && uri.host.isNotEmpty) urls.add(uri);
    }
    return urls.toList();
  }

  static List<dynamic> _definitionsFromHtml(String html) {
    final match = RegExp(
      r'var\s+flashvars_\d+\s*=\s*(\{.*?\});',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return const [];

    try {
      final flashvars = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      return flashvars['mediaDefinitions'] as List<dynamic>? ?? [];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  static List<VideoSource> fromDefinitions(
    List<dynamic> definitions, {
    bool includeMp4 = false,
  }) {
    final sources = <VideoSource>[];
    for (final value in definitions) {
      if (value is! Map<String, dynamic> ||
          value['remote'] == true ||
          value['quality'] is List ||
          (value['format'] != 'hls' &&
              !(includeMp4 && value['format'] == 'mp4'))) {
        continue;
      }
      final uri = Uri.tryParse(value['videoUrl']?.toString() ?? '');
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      sources.add(VideoSource(url: uri, quality: '${value['quality']}p'));
    }
    sources.sort((a, b) {
      final aHeight = int.tryParse(a.quality.replaceAll('p', '')) ?? 0;
      final bHeight = int.tryParse(b.quality.replaceAll('p', '')) ?? 0;
      return bHeight.compareTo(aHeight);
    });
    return sources;
  }
}
