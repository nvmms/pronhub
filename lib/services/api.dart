import 'package:pronhub/config/page_selectors.dart';
import 'dart:isolate';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/models/category_item.dart';
import 'package:pronhub/models/video_detail.dart';
import 'package:pronhub/models/video_source.dart';
import 'package:pronhub/services/webview_loader.dart';
import 'package:webview_all/webview_all.dart';

/// Preserve browser cookie values, including JSON strings containing quotes.
@visibleForTesting
String browserCookieHeader(Iterable<WebViewCookie> cookies) =>
    cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

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

  static Future<VideoDetail> videoDetail(Uri uri) async {
    final html = await WebViewLoader.instance.load(
      uri,
      selectors: PageSelectors.detailBody,
    );
    return Isolate.run(() => VideoDetail.fromHtml(html, uri));
  }

  static Future<VideoDetail> videoDetailFromCurrentPage(Uri uri) async {
    final html = await WebViewLoader.instance.readCurrentPage(
      uri,
      selectors: PageSelectors.detailBody,
    );
    return Isolate.run(() => VideoDetail.fromHtml(html, uri));
  }

  /// Requests the signed resolver URL directly; does not reload the webpage.
  static Future<List<VideoSource>> refreshVideoSources(Uri pageUri) async {
    final html = await WebViewLoader.instance.readCurrentPage(pageUri);
    final resolvers = VideoSource.remoteUrlsFromHtml(html, pageUri);
    if (resolvers.isEmpty) {
      throw StateError('当前页面没有远程播放地址接口');
    }
    final client = HttpClient()..userAgent = WebViewLoader.desktopUserAgent;
    client.findProxy = (uri) => HttpClient.findProxyFromEnvironment(uri);
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      Object? lastError;
      for (final resolver in resolvers) {
        debugPrint('[备用播放地址] GET $resolver');
        try {
          final cookies = await WebViewCookieManager().getCookies(
            domain: resolver,
          );
          final request = await client
              .getUrl(resolver)
              .timeout(const Duration(seconds: 15));
          request.headers.set(HttpHeaders.refererHeader, pageUri.toString());
          if (cookies.isNotEmpty) {
            request.headers.set(
              HttpHeaders.cookieHeader,
              browserCookieHeader(cookies),
            );
          }
          final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
          debugPrint('[备用播放地址] HTTP ${response.statusCode}');
          final body = await utf8.decoder
              .bind(response)
              .join()
              .timeout(const Duration(seconds: 15));
          debugPrint('[备用播放地址] 响应：\n$body');
          if (response.statusCode != HttpStatus.ok) {
            throw HttpException('播放地址接口 HTTP ${response.statusCode}');
          }
          final definitions = jsonDecode(body);
          if (definitions is! List) {
            throw const FormatException('播放地址接口返回的不是列表');
          }
          final sources = VideoSource.fromDefinitions(
            definitions,
            includeMp4: true,
          );
          if (sources.isEmpty) throw const FormatException('播放地址接口没有返回可用地址');
          return sources;
        } catch (error) {
          debugPrint('[备用播放地址] 请求失败：$resolver\n$error');
          lastError = error;
        }
      }
      throw lastError ?? StateError('没有可用的播放地址接口');
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<CategorySection>> categories(Uri uri) async {
    final html = await WebViewLoader.instance.load(
      uri,
      selectors: PageSelectors.categoryPage,
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
