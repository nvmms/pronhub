import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_source.dart';

void main() {
  test(
    'extracts signed remote resolver URLs without treating them as media',
    () {
      const html = '''
      <script>var flashvars_123 = {"mediaDefinitions":[
        {"format":"hls","remote":true,"quality":"720","videoUrl":"https://example.com/resolve?token=a%2Bb&expires=123"},
        {"format":"mp4","quality":[],"videoUrl":"/get_media?key=abc"},
        {"format":"hls","quality":"720","videoUrl":"https://cdn.example.com/video.m3u8"}
      ]};</script>
    ''';
      expect(
        VideoSource.remoteUrlsFromHtml(
          html,
          Uri.parse('https://example.com/video'),
        ).map((uri) => uri.toString()),
        [
          'https://example.com/resolve?token=a%2Bb&expires=123',
          'https://example.com/get_media?key=abc',
        ],
      );
      expect(
        VideoSource.fromHtml(html).single.url.toString(),
        'https://cdn.example.com/video.m3u8',
      );
    },
  );

  test('resolver responses supply playable HLS and MP4 sources', () {
    final sources = VideoSource.fromDefinitions([
      {
        'format': 'mp4',
        'quality': '720',
        'videoUrl': 'https://cdn.example.com/fresh.mp4',
      },
      {
        'format': 'hls',
        'quality': '1080',
        'videoUrl': 'https://cdn.example.com/fresh.m3u8',
      },
      {
        'format': 'mp4',
        'quality': [],
        'videoUrl': 'https://example.com/get_media',
      },
      {
        'format': 'hls',
        'remote': true,
        'quality': '240',
        'videoUrl': 'https://example.com/resolve',
      },
    ], includeMp4: true);
    expect(sources.map((source) => source.quality), ['1080p', '720p']);
  });

  test('reads HLS sources and ignores the MP4 resolver', () {
    const html = '''
      <script>
      var flashvars_123 = {"mediaDefinitions":[
        {"format":"hls","quality":"720","videoUrl":"https:\\/\\/cdn.example.com\\/master.m3u8?h=abc"},
        {"format":"hls","quality":"240","videoUrl":"https:\\/\\/cdn.example.com\\/240.m3u8"},
        {"format":"hls","quality":"1080","videoUrl":"https:\\/\\/cdn.example.com\\/1080.m3u8"},
        {"format":"hls","quality":"480","videoUrl":"https:\\/\\/cdn.example.com\\/480.m3u8"},
        {"format":"mp4","quality":[],"videoUrl":"https:\\/\\/example.com\\/get_media"}
      ]};
      </script>
    ''';

    final sources = VideoSource.fromHtml(html);
    expect(sources.map((source) => source.quality), [
      '1080p',
      '720p',
      '480p',
      '240p',
    ]);
    expect(
      sources[1].url.toString(),
      'https://cdn.example.com/master.m3u8?h=abc',
    );
  });
}
