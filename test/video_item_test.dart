import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_item.dart';

void main() {
  test('parses a homepage video card', () {
    const html = '''
<ul class="videoList clearfix latestThumbDesign">
  <li data-video-id="491330925">
    <a class="imageLink" href="/view_video.php?viewkey=abc">
      <img class="videoThumb" src="https://example.com/placeholder.gif"
           data-path="https://example.com/thumb.jpg" alt="Fallback">
    </a>
    <div class="duration"><span class="time">1:17</span></div>
    <a class="uploaderLink">Creator</a>
    <div class="videoViews">27.9K</div>
    <a class="thumbnailTitle" href="/view_video.php?viewkey=abc">  Video &amp; Title </a>
  </li>
</ul>
''';

    final items = VideoItem.listFromHtml(
      html,
      Uri.parse('https://cn.pornhub.com/'),
    );
    expect(items, hasLength(1));
    expect(items.single.id, '491330925');
    expect(items.single.title, 'Video & Title');
    expect(
      items.single.url.toString(),
      'https://cn.pornhub.com/view_video.php?viewkey=abc',
    );
    expect(items.single.thumbnail.toString(), 'https://example.com/thumb.jpg');
    expect(items.single.duration, '1:17');
    expect(items.single.views, '27.9K');
    expect(items.single.uploader, 'Creator');
  });

  test(
    'uses data-path rather than a lazy placeholder or another attribute',
    () {
      const html = '''
<ul class="videoList">
  <li data-video-id="490868065">
    <a class="imageLink" href="/view_video.php?viewkey=abc">
      <img class="videoThumb"
           src="https://ei.phncdn.com/www-static/images/blank.gif"
           data-lazy-src="https://pix-fl.phncdn.com/real.jpg?x=1&amp;y=2"
           data-path="https://pix-fl.phncdn.com/path.jpg?x=1&amp;y=2"
           alt="Video">
    </a>
  </li>
</ul>
''';

      final items = VideoItem.listFromHtml(
        html,
        Uri.parse('https://cn.pornhub.com/'),
      );
      expect(
        items.single.thumbnail.toString(),
        'https://pix-fl.phncdn.com/path.jpg?x=1&y=2',
      );
    },
  );

  test('uses data-path even when src is a real image', () {
    const html = '''
<li data-video-id="62520495">
  <a class="imageLink" href="/view_video.php?viewkey=abc">
    <img class="js-videoThumb thumb js-videoPreview"
         src="https://pix-fl.phncdn.com/real.jpg?x=1&amp;y=2"
         data-path="https://pix-fl.phncdn.com/path.jpg?x=1&amp;y=2"
         alt="Naughty TS Loves Missionary">
  </a>
</li>
''';

    final items = VideoItem.listFromHtml(
      html,
      Uri.parse('https://cn.pornhub.com/'),
    );
    expect(items.single.title, 'Naughty TS Loves Missionary');
    expect(
      items.single.thumbnail.toString(),
      'https://pix-fl.phncdn.com/path.jpg?x=1&y=2',
    );
  });

  test('does not use img src when data-path is absent', () {
    const html = '''
<li class="pcVideoListItem" data-video-id="491658865">
  <a class="latestThumb js-linkVideoThumb" href="/view_video.php?viewkey=abc">
    <img class="js-videoThumb thumb" src="https://pix-fl.phncdn.com/card.jpg"
         data-mediumthumb="https://pix-fl.phncdn.com/other.jpg"
         alt="Anissa Kate in sexy lingerie for a DP">
  </a>
  <a class="thumbnailTitle" href="/view_video.php?viewkey=abc">Anissa Kate in sexy lingerie for a DP</a>
</li>
''';
    final items = VideoItem.listFromHtml(
      html,
      Uri.parse('https://cn.pornhub.com/'),
    );
    expect(items.single.id, '491658865');
    expect(items.single.thumbnail, isNull);
  });

  test('does not use data-mediumthumb when data-path is absent', () {
    const html = '''
<li data-video-id="123">
  <a class="thumbnailTitle" href="/view_video.php?viewkey=abc">Video</a>
  <img class="js-videoThumb thumb"
       src="https://ei.phncdn.com/www-static/images/blank.gif"
       data-mediumthumb="https://pix-fl.phncdn.com/real.jpg">
</li>
''';
    final items = VideoItem.listFromHtml(
      html,
      Uri.parse('https://cn.pornhub.com/'),
    );
    expect(items.single.thumbnail, isNull);
  });
}
