import 'package:pronhub/config/page_selectors.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_all/webview_all.dart';

/// Serializes page loads through one JavaScript-enabled
/// offscreen WebView.
///
/// Supports Android, iOS and Windows.
class WebViewLoader {
  static const desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/154.0.0.0 Safari/537.36';

  WebViewLoader._();

  static final instance = WebViewLoader._();

  OffscreenWebViewSession? _session;
  WebViewController? _controller;
  WebViewController? get controller => _controller;
  final controllerNotifier = ValueNotifier<WebViewController?>(null);

  Future<void>? _initializing;
  Future<void> _queue = Future<void>.value();

  _LoadTask? _active;

  Future<void> _ensureInitialized() {
    return _initializing ??= _initialize().catchError((
      Object error,
      StackTrace stack,
    ) {
      _initializing = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _initialize() async {
    final session = await OffscreenWebViewSession.create();
    try {
      final controller = session.controller;

      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      await controller.setUserAgent(desktopUserAgent);

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
          onWebResourceError: _onError,
        ),
      );

      _controller = controller;
      _session = session;
      controllerNotifier.value = controller;
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  Future<String> load(
    Uri uri, {
    List<String> selectors = PageSelectors.videoList,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final candidates = List<String>.of(selectors);
    final result = _queue.then((_) => _load(uri, candidates, timeout));

    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );

    return result;
  }

  Future<String> _load(
    Uri uri,
    List<String> selectors,
    Duration timeout,
  ) async {
    await _ensureInitialized();

    final controller = _controller!;
    final task = _LoadTask(uri, selectors);
    _active = task;

    try {
      await controller.loadRequest(uri);

      return await task.result.future.timeout(timeout);
    } on TimeoutException {
      if (task.extracting) {
        throw FormatException(
          '页面已加载，但未能完成内容提取（目标元素：${selectors.join(", ")}）：$uri',
        );
      }

      try {
        await controller.runJavaScript('window.stop()');
      } catch (_) {}

      throw TimeoutException('页面加载超时：$uri', timeout);
    } finally {
      if (identical(_active, task)) {
        _active = null;
      }
    }
  }

  /// Reads the existing DOM without navigating or refreshing the WebView.
  Future<String> readCurrentPage(
    Uri expectedUri, {
    List<String> selectors = PageSelectors.detailBody,
  }) {
    final candidates = List<String>.of(selectors);
    final result = _queue.then((_) async {
      final controller = _controller;
      if (controller == null) throw StateError('WebView 尚未加载页面');
      final snapshot = await controller.runJavaScriptReturningResult(
        "JSON.stringify({url: location.href, html: (() => {"
        "for (const selector of ${jsonEncode(candidates)}) {"
        "const element = document.querySelector(selector);"
        "if (element) return element.outerHTML;"
        "} return ''; })()})",
      );
      final page = jsonDecode(_decode(snapshot)) as Map<String, dynamic>;
      final currentUri = Uri.parse(page['url'] as String);
      final expectedKey = expectedUri.queryParameters['viewkey'];
      if (currentUri.host != expectedUri.host ||
          currentUri.path != expectedUri.path ||
          (expectedKey != null &&
              currentUri.queryParameters['viewkey'] != expectedKey)) {
        throw StateError('WebView 当前页面不是此视频页面：$currentUri');
      }
      final html = page['html'] as String;
      if (html.isEmpty) {
        throw FormatException('当前页面未找到目标元素：${candidates.join(", ")}');
      }
      return html;
    });
    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> _onPageFinished(String url) async {
    if (url == 'about:blank') {
      return;
    }

    final task = _active;

    if (task == null || task.extracting || task.result.isCompleted) {
      return;
    }

    final loadedUri = Uri.tryParse(url);

    if (task.uri.path == '/video' &&
        loadedUri?.path != '/video' &&
        loadedUri?.path != '/video/') {
      task.result.completeError(FormatException('视频页面被重定向：${task.uri} → $url'));
      return;
    }

    task.extracting = true;

    try {
      final controller = _controller!;
      final deadline = DateTime.now().add(const Duration(seconds: 15));

      // 视频列表需要至少有一个 item；其他页面只需容器存在。
      final isVideoList = listEquals(task.selectors, PageSelectors.videoList);
      final findContainerScript =
          "(() => {"
          "const selectors = ${jsonEncode(task.selectors)};"
          "const items = ${jsonEncode(PageSelectors.videoItem)};"
          "for (const selector of selectors) {"
          "const container = document.querySelector(selector);"
          "if (!container) continue;"
          "if (${isVideoList ? 'true' : 'false'} && "
          "!items.some(item => container.querySelector(item))) continue;"
          "return container;"
          "} return null; })()";

      while (DateTime.now().isBefore(deadline)) {
        if (!identical(_active, task) || task.result.isCompleted) {
          return;
        }

        final html = await controller.runJavaScriptReturningResult(
          "($findContainerScript)?.outerHTML ?? ''",
        );
        final decodedHtml = _decode(html);

        if (decodedHtml.isNotEmpty) {
          if (!task.result.isCompleted) {
            task.result.complete(decodedHtml);
          }
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      throw FormatException(
        '页面已加载，但未找到目标内容：${task.selectors.join(", ")}'
        '${isVideoList ? "（视频项：${PageSelectors.videoItem.join(", ")}）" : ""}（$url）',
      );
    } catch (error, stack) {
      if (!task.result.isCompleted) {
        task.result.completeError(error, stack);
      }
    }
  }

  void _onError(WebResourceError error) {
    final task = _active;

    if (task == null ||
        error.isForMainFrame != true ||
        task.result.isCompleted) {
      return;
    }

    task.result.completeError(Exception('页面加载失败：${error.description}'));
  }

  static String _decode(Object result) {
    if (result is String) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is String) return decoded;
      } on FormatException {
        // Some platforms return plain strings.
      }
      return result;
    }

    return result.toString();
  }

  /// Call when the loader is no longer needed.
  /// Do not call while load() tasks are running.
  Future<void> dispose() async {
    await _queue;

    final initializing = _initializing;
    if (initializing != null) {
      try {
        await initializing;
      } catch (_) {}
    }

    final session = _session;
    controllerNotifier.value = null;
    _session = null;
    _controller = null;
    _initializing = null;

    if (session != null) {
      await session.close();
    }
  }
}

class _LoadTask {
  _LoadTask(this.uri, this.selectors);

  final Uri uri;
  final List<String> selectors;
  final result = Completer<String>();

  bool extracting = false;
}
