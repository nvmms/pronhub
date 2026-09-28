import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.duration,
    required this.views,
    required this.uploader,
  });

  final String id;
  final String title;
  final Uri url;
  final Uri? thumbnail;
  final String duration;
  final String views;
  final String uploader;

  static List<VideoItem> listFromHtml(String html, Uri baseUri) {
    final fragment = html_parser.parseFragment(html);
    return [
      for (final element in fragment.querySelectorAll(
        'li.pcVideoListItem[data-video-id]',
      ))
        ?fromElement(element, baseUri),
    ];
  }

  static VideoItem? fromElement(Element element, Uri baseUri) {
    final link = element.querySelector('.title a[href*="/view_video.php"]');
    final href = link?.attributes['href'];
    if (href == null || href.isEmpty) return null;

    final image = element.querySelector('img.js-videoThumb');
    final imageUrl = image?.attributes['src']?.trim();
    final title = _text(link?.text ?? '');
    if (title.isEmpty) return null;

    return VideoItem(
      id: element.attributes['data-video-id'] ?? '',
      title: title,
      url: baseUri.resolve(href),
      thumbnail: imageUrl == null || imageUrl.isEmpty
          ? null
          : baseUri.resolve(imageUrl),
      duration: _text(
        element.querySelector('.marker-overlays .duration')?.text ?? '',
      ),
      views: _text(
        element.querySelector('.videoDetailBlock .views')?.text ?? '',
      ),
      uploader: _text(element.querySelector('.usernameWrap a')?.text ?? ''),
    );
  }

  static String _text(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
