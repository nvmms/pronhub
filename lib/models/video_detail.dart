import 'package:html/parser.dart' as parser;
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/models/video_source.dart';

class VideoDetail {
  const VideoDetail({
    required this.title,
    required this.author,
    required this.avatar,
    required this.videoCount,
    required this.subscribers,
    required this.categories,
    this.categoryPaths = const {},
    required this.tags,
    this.tagPaths = const {},
    required this.language,
    this.languageCode,
    required this.related,
    this.sources = const [],
  });

  final String title;
  final String author;
  final Uri? avatar;
  final String videoCount;
  final String subscribers;
  final List<String> categories;
  final Map<String, String> categoryPaths;
  final List<String> tags;
  final Map<String, String> tagPaths;
  final String language;
  final String? languageCode;
  final List<VideoItem> related;

  /// Signed playback URLs are intentionally excluded from the persistent cache.
  final List<VideoSource> sources;

  factory VideoDetail.fromJson(Map<String, dynamic> json) => VideoDetail(
    title: json['title'] as String,
    author: json['author'] as String,
    avatar: (json['avatar'] as String?) == null
        ? null
        : Uri.parse(json['avatar'] as String),
    videoCount: json['videoCount'] as String,
    subscribers: json['subscribers'] as String,
    categories: (json['categories'] as List<dynamic>).cast<String>(),
    categoryPaths: (json['categoryPaths'] as Map<String, dynamic>? ?? {})
        .cast<String, String>(),
    tags: (json['tags'] as List<dynamic>).cast<String>(),
    tagPaths: (json['tagPaths'] as Map<String, dynamic>? ?? {})
        .cast<String, String>(),
    language: json['language'] as String,
    languageCode: json['languageCode'] as String?,
    related: [
      for (final item in json['related'] as List<dynamic>)
        VideoItem.fromJson(item as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'avatar': avatar?.toString(),
    'videoCount': videoCount,
    'subscribers': subscribers,
    'categories': categories,
    'categoryPaths': categoryPaths,
    'tags': tags,
    'tagPaths': tagPaths,
    'language': language,
    'languageCode': languageCode,
    'related': [for (final item in related) item.toJson()],
  };

  static VideoDetail fromHtml(String html, Uri baseUri) {
    final document = parser.parse(html);
    final languageHref = document
        .querySelector('.video-detailed-info .langSpokenWrapper a.item')
        ?.attributes['href'];
    final languageSegments = languageHref == null
        ? <String>[]
        : baseUri.resolve(languageHref).pathSegments;
    final languageIndex = languageSegments.indexOf('language');
    String text(String selector) =>
        _clean(document.querySelector(selector)?.text ?? '');
    List<String> texts(String selector) => document
        .querySelectorAll(selector)
        .map((element) => _clean(element.text))
        .where((value) => value.isNotEmpty)
        .toList();
    final avatarSrc = document
        .querySelector('.video-detailed-info .userAvatar img')
        ?.attributes['src'];
    final userStats = document
        .querySelectorAll('.video-detailed-info .userInfo > span')
        .map((element) => _clean(element.text))
        .where((value) => value.isNotEmpty)
        .toList();
    final related = document
        .querySelectorAll('#relatedVideosListing li.pcVideoListItem')
        .map((element) => VideoItem.fromElement(element, baseUri))
        .whereType<VideoItem>()
        .toList();
    final title = text('h1.title').isNotEmpty
        ? text('h1.title')
        : text('.videoTitle').isNotEmpty
        ? text('.videoTitle')
        : text('meta[property="og:title"]');
    final metaTitle =
        document
            .querySelector('meta[property="og:title"]')
            ?.attributes['content'] ??
        '';
    return VideoDetail(
      title: title.isNotEmpty ? title : _clean(metaTitle),
      author: text('.video-detailed-info .usernameWrap a'),
      avatar: avatarSrc == null || avatarSrc.isEmpty
          ? null
          : baseUri.resolve(avatarSrc),
      videoCount: userStats.isNotEmpty ? userStats.first : '',
      subscribers: userStats.length > 1 ? userStats[1] : '',
      categories: texts('.video-detailed-info .categoriesWrapper a.item'),
      categoryPaths: {
        for (final link in document.querySelectorAll(
          '.video-detailed-info .categoriesWrapper a.item[href]',
        ))
          if (_clean(link.text).isNotEmpty &&
              (link.attributes['href'] ?? '').isNotEmpty)
            _clean(link.text): baseUri
                .resolve(link.attributes['href']!)
                .toString(),
      },
      tags: texts('.video-detailed-info .tagsWrapper a.item'),
      tagPaths: {
        for (final link in document.querySelectorAll(
          '.video-detailed-info .tagsWrapper a.item[href]',
        ))
          if (_clean(link.text).isNotEmpty &&
              (link.attributes['href'] ?? '').isNotEmpty)
            _clean(link.text): baseUri
                .resolve(link.attributes['href']!)
                .toString(),
      },
      language: text('.video-detailed-info .langSpokenWrapper a.item'),
      languageCode:
          languageIndex >= 0 && languageIndex + 1 < languageSegments.length
          ? languageSegments[languageIndex + 1]
          : null,
      related: related,
      sources: VideoSource.fromHtml(html),
    );
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
