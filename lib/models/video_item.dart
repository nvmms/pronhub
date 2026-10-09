import 'package:pronhub/config/page_selectors.dart';
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

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    id: json['id'] as String,
    title: json['title'] as String,
    url: Uri.parse(json['url'] as String),
    thumbnail: (json['thumbnail'] as String?) == null
        ? null
        : Uri.parse(json['thumbnail'] as String),
    duration: json['duration'] as String,
    views: json['views'] as String,
    uploader: json['uploader'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url.toString(),
    'thumbnail': thumbnail?.toString(),
    'duration': duration,
    'views': views,
    'uploader': uploader,
  };

  static List<VideoItem> listFromHtml(String html, Uri baseUri) {
    final fragment = html_parser.parseFragment(html);
    return [
      for (final element in fragment.selectAll(PageSelectors.videoItem))
        if (element.attributes.containsKey('data-video-id'))
          ?fromElement(element, baseUri),
    ];
  }

  static VideoItem? fromElement(Element element, Uri baseUri) {
    final link = element.selectFirst(PageSelectors.videoLink);
    final href = link?.attributes['href'];
    if (href == null || href.isEmpty) return null;

    final image = element.selectFirst(PageSelectors.videoThumbnail);
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
        element.selectFirst(PageSelectors.videoDuration)?.text ?? '',
      ),
      views: _text(
        element.selectFirst(PageSelectors.videoViews)?.text ??
            element.attributes['data-views'] ??
            '',
      ),
      uploader: _text(
        element.selectFirst(PageSelectors.videoUploader)?.text ?? '',
      ),
    );
  }

  static String _text(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
