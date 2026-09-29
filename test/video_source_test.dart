import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_source.dart';

void main() {
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
    expect(sources.map((source) => source.quality),
        ['1080p', '720p', '480p', '240p']);
    expect(sources[1].url.toString(),
        'https://cdn.example.com/master.m3u8?h=abc');
  });
}
