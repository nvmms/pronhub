import 'package:html/parser.dart' as parser;
import 'package:pronhub/models/video_item.dart';

class VideoDetail {
  const VideoDetail({required this.title, required this.author, required this.avatar,
    required this.videoCount, required this.subscribers, required this.categories,
    required this.tags, required this.language, required this.related});

  final String title;
  final String author;
  final Uri? avatar;
  final String videoCount;
  final String subscribers;
  final List<String> categories;
  final List<String> tags;
  final String language;
  final List<VideoItem> related;

  factory VideoDetail.fromJson(Map<String, dynamic> json) => VideoDetail(
    title: json['title'] as String,
    author: json['author'] as String,
    avatar: (json['avatar'] as String?) == null ? null : Uri.parse(json['avatar'] as String),
    videoCount: json['videoCount'] as String,
    subscribers: json['subscribers'] as String,
    categories: (json['categories'] as List<dynamic>).cast<String>(),
    tags: (json['tags'] as List<dynamic>).cast<String>(),
    language: json['language'] as String,
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
    'tags': tags,
    'language': language,
    'related': [for (final item in related) item.toJson()],
  };

  static VideoDetail fromHtml(String html, Uri baseUri) {
    final document = parser.parse(html);
    String text(String selector) => _clean(document.querySelector(selector)?.text ?? '');
    List<String> texts(String selector) => document.querySelectorAll(selector)
        .map((element) => _clean(element.text)).where((value) => value.isNotEmpty).toList();
    final avatarSrc = document.querySelector('.video-detailed-info .userAvatar img')?.attributes['src'];
    final userStats = document.querySelectorAll('.video-detailed-info .userInfo > span')
        .map((element) => _clean(element.text)).where((value) => value.isNotEmpty).toList();
    final related = <VideoItem>[
      for (final element in document.querySelectorAll('#relatedVideosListing li.pcVideoListItem'))
        ?VideoItem.fromElement(element, baseUri),
    ];
    final title = text('h1.title').isNotEmpty ? text('h1.title') :
        text('.videoTitle').isNotEmpty ? text('.videoTitle') :
        text('meta[property="og:title"]');
    final metaTitle = document.querySelector('meta[property="og:title"]')?.attributes['content'] ?? '';
    return VideoDetail(
      title: title.isNotEmpty ? title : _clean(metaTitle),
      author: text('.video-detailed-info .usernameWrap a'),
      avatar: avatarSrc == null || avatarSrc.isEmpty ? null : baseUri.resolve(avatarSrc),
      videoCount: userStats.isNotEmpty ? userStats.first : '',
      subscribers: userStats.length > 1 ? userStats[1] : '',
      categories: texts('.video-detailed-info .categoriesWrapper a.item'),
      tags: texts('.video-detailed-info .tagsWrapper a.item'),
      language: text('.video-detailed-info .langSpokenWrapper a.item'),
      related: related,
    );
  }

  static String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
