import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_item.dart';

void main() {
  final baseUri = Uri.parse('https://cn.pornhub.com/');

  test('parses PC video cards and skips ad cards', () {
    const html = '''
<ul class="full-row-thumbs display-grid col-3-sm col-4 videos" id="singleFeedSection">
  <li class="sniperModeEngaged alpha"><div>Advertisement</div></li>
  <li class="pcVideoListItem js-pop videoblock" data-video-id="491658865">
    <a class="latestThumb js-linkVideoThumb" href="/view_video.php?viewkey=abc">
      <img class="js-videoThumb thumb" src="https://pix-fl.phncdn.com/card.jpg?x=1&amp;y=2"
           data-mediumthumb="https://pix-fl.phncdn.com/other.jpg" alt="Fallback">
      <div class="marker-overlays"><var class="duration">15:14</var></div>
    </a>
    <div class="videoUploaderBlock"><div class="usernameWrap"><a>Luxure</a></div></div>
    <div class="videoDetailBlock"><span class="views"><var>26.9K</var></span></div>
    <a class="thumbnailTitle" href="/view_video.php?viewkey=abc">Video &amp; Title</a>
  </li>
  <li class="pcVideoListItem" data-video-id="2">
    <img class="js-videoThumb" src="https://example.com/second.jpg" alt="Second">
    <a class="thumbnailTitle" href="/view_video.php?viewkey=two">Second</a>
  </li>
</ul>
''';
    final items = VideoItem.listFromHtml(html, baseUri);
    expect(items, hasLength(2));
    expect(items.first.id, '491658865');
    expect(items.first.title, 'Video & Title');
    expect(
      items.first.url.toString(),
      'https://cn.pornhub.com/view_video.php?viewkey=abc',
    );
    expect(
      items.first.thumbnail.toString(),
      'https://pix-fl.phncdn.com/card.jpg?x=1&y=2',
    );
    expect(items.first.duration, '15:14');
    expect(items.first.views, '26.9K');
    expect(items.first.uploader, 'Luxure');
  });

  test('does not parse mobile video cards', () {
    const html = '''
<ul class="videoList latestThumbDesign">
  <li data-video-id="1">
    <a class="thumbnailTitle" href="/view_video.php?viewkey=one">One</a>
    <img class="videoThumb" data-path="https://example.com/one.jpg">
  </li>
</ul>
''';
    expect(VideoItem.listFromHtml(html, baseUri), isEmpty);
  });
}
