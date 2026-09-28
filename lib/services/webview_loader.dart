import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

/// Serializes page loads through one JavaScript-enabled WebView.
class WebViewLoader {
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/154.0.0.0 Safari/537.36';

  WebViewLoader._() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
          onWebResourceError: _onError,
        ),
      );
  }

  static final instance = WebViewLoader._();
  late final WebViewController _controller;
  Future<void> _queue = Future<void>.value();
  _LoadTask? _active;

  Future<String> load(
    Uri uri, {
    String selector = 'ul#videoCategory',
    Duration timeout = const Duration(seconds: 30),
  }) {
    final result = _queue.then((_) => _load(uri, selector, timeout));
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<String> _load(Uri uri, String selector, Duration timeout) async {
    final task = _LoadTask(uri, selector);
    _active = task;
    try {
      await _controller.setUserAgent(_desktopUserAgent);
      await _controller.loadRequest(uri);
      return await task.result.future.timeout(timeout);
    } on TimeoutException {
      try {
        await _controller.runJavaScript('window.stop()');
      } catch (_) {}
      throw TimeoutException('首页加载超时：$uri', timeout);
    } finally {
      if (identical(_active, task)) _active = null;
    }
  }

  Future<void> _onPageFinished(String url) async {
    final task = _active;
    if (task == null || task.extracting || task.result.isCompleted) return;
    final loadedUri = Uri.tryParse(url);
    if (task.uri.path == '/video' &&
        loadedUri?.path != '/video' &&
        loadedUri?.path != '/video/') {
      task.result.completeError(
        FormatException('视频页面被重定向：${task.uri} → $url'),
      );
      return;
    }
    task.extracting = true;
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        if (!identical(_active, task) || task.result.isCompleted) return;
        final found = await _controller.runJavaScriptReturningResult(
          "document.querySelector(${jsonEncode(task.selector == 'ul#videoCategory' ? 'ul#videoCategory li.pcVideoListItem' : task.selector)}) ? 'ready' : 'waiting'",
        );
        if (_decode(found) == 'ready') {
          final html = await _controller.runJavaScriptReturningResult(
            "document.querySelector(${jsonEncode(task.selector)})?.outerHTML ?? ''",
          );
          if (!task.result.isCompleted) task.result.complete(_decode(html));
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      throw TimeoutException('等待 PC 端视频列表超时');
    } catch (error, stack) {
      if (!task.result.isCompleted) task.result.completeError(error, stack);
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
    final value = result.toString();
    try {
      final decoded = jsonDecode(value);
      if (decoded is String) return decoded;
    } on FormatException {
      // iOS may return the string without JSON encoding.
    }
    return value;
  }
}

class _LoadTask {
  _LoadTask(this.uri, this.selector);

  final Uri uri;
  final String selector;
  final result = Completer<String>();
  bool extracting = false;
}
