import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/services/api.dart';

void main() {
  test('uses /video?page=1 as the first page', () {
    expect(Api.pageUri(1).toString(), 'https://cn.pornhub.com/video?page=1');
    expect(Api.pageUri(2).toString(), 'https://cn.pornhub.com/video?page=2');
  });

  test('parses the PC /video listing and skips ads', () {
    const html = '''
<ul id="videoCategory" class="nf-videos videos search-video-thumbs">
  <li class="sniperModeEngaged alpha"><div>Advertisement</div></li>
  <li class="pcVideoListItem js-pop videoblock videoBox" data-video-id="491683545">
    <a class="linkVideoThumb" href="/view_video.php?viewkey=abc">
      <img class="js-videoThumb thumb"
           src="https://pix-fl.phncdn.com/page.jpg?x=1&amp;y=2"
           alt="Fallback">
      <div class="marker-overlays"><var class="duration">15:14</var></div>
    </a>
    <div class="videoUploaderBlock"><div class="usernameWrap"><a>Creator</a></div></div>
    <div class="videoDetailBlock"><span class="views"><var>26.9K</var></span></div>
    <span class="title"><a class="gtm-event-thumb-click"
      href="/view_video.php?viewkey=abc">Video &amp; Title</a></span>
  </li>
</ul>
''';
    final items = VideoItem.listFromHtml(html, Api.pageUri(1));
    expect(items, hasLength(1));
    expect(items.single.id, '491683545');
    expect(items.single.title, 'Video & Title');
    expect(
      items.single.url.toString(),
      'https://cn.pornhub.com/view_video.php?viewkey=abc',
    );
    expect(
      items.single.thumbnail.toString(),
      'https://pix-fl.phncdn.com/page.jpg?x=1&y=2',
    );
    expect(items.single.duration, '15:14');
    expect(items.single.views, '26.9K');
    expect(items.single.uploader, 'Creator');
  });
}
