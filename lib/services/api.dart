import 'dart:isolate';

import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/models/category_item.dart';
import 'package:pronhub/services/webview_loader.dart';

abstract final class Api {
  static final homeUri = Uri.parse('https://cn.pornhub.com/');
  static Uri pageUri(int page, {String path = '/video'}) {
    final uri = homeUri.resolve(path);
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'page': '$page'},
    );
  }

  static Future<List<VideoItem>> videos(Uri uri) async {
    final html = await WebViewLoader.instance.load(uri);
    final videos = await Isolate.run(() => VideoItem.listFromHtml(html, uri));
    if (videos.isEmpty) throw FormatException('视频列表为空：$uri');
    return videos;
  }

  static Future<List<CategorySection>> categories(Uri uri) async {
    final html = await WebViewLoader.instance.load(
      uri,
      selector: '.categoriesPage',
    );
    final sections = await Isolate.run(
      () => CategorySection.listFromHtml(html, uri),
    );
    if (sections.isEmpty ||
        sections.every((section) => section.items.isEmpty)) {
      throw FormatException('分类列表为空：$uri');
    }
    return sections;
  }
}
