import 'dart:convert';

class VideoSource {
  const VideoSource({required this.url, required this.quality});

  final Uri url;
  final String quality;

  static List<VideoSource> fromHtml(String html) {
    final match = RegExp(
      r'var\s+flashvars_\d+\s*=\s*(\{.*?\});',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return const [];

    try {
      final flashvars = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      final definitions = flashvars['mediaDefinitions'] as List<dynamic>? ?? [];
      final sources = <VideoSource>[];
      for (final value in definitions) {
        if (value is! Map<String, dynamic> || value['format'] != 'hls') {
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
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }
}
