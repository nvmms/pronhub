import 'dart:isolate';

import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/services/webview_loader.dart';

abstract final class Api {
  static final homeUri = Uri.parse('https://cn.pornhub.com/');
  static Uri pageUri(int page) => homeUri.resolve('/video?page=$page');

  static Future<List<VideoItem>> videos(Uri uri) async {
    final html = await WebViewLoader.instance.load(uri);
    final videos = await Isolate.run(() => VideoItem.listFromHtml(html, uri));
    if (videos.isEmpty) throw FormatException('视频列表为空：$uri');
    return videos;
  }
}
