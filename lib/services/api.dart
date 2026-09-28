import 'dart:isolate';

import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/services/webview_loader.dart';

abstract final class Api {
  static final homeUri = Uri.parse('https://cn.pornhub.com/');

  static Future<List<VideoItem>> homeVideos() async {
    final html = await WebViewLoader.instance.load(homeUri);
    final items = await Isolate.run(
      () => VideoItem.listFromHtml(html, homeUri),
    );
    if (items.isEmpty) throw const FormatException('首页视频列表为空');
    return items;
  }
}
