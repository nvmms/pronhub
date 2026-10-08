import 'dart:async';
import 'dart:convert';

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

  Future<void>? _initializing;
  Future<void> _queue = Future<void>.value();

  _LoadTask? _active;
  Completer<void>? _blankPageFinished;

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
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  Future<String> load(
    Uri uri, {
    String selector = 'ul#videoCategory',
    Duration timeout = const Duration(seconds: 30),
  }) {
    final result = _queue.then((_) => _load(uri, selector, timeout));

    _queue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );

    return result;
  }

  Future<String> _load(Uri uri, String selector, Duration timeout) async {
    await _ensureInitialized();

    final controller = _controller!;
    final task = _LoadTask(uri, selector);
    _active = task;

    try {
      await controller.loadRequest(uri);

      return await task.result.future.timeout(timeout);
    } on TimeoutException {
      try {
        await controller.runJavaScript('window.stop()');
      } catch (_) {}

      throw TimeoutException('首页加载超时：$uri', timeout);
    } finally {
      if (identical(_active, task)) {
        _active = null;
      }

      // Unload video resources to release the decoder.
      final blankPageFinished = Completer<void>();
      _blankPageFinished = blankPageFinished;

      try {
        await controller.loadRequest(Uri.parse('about:blank'));

        await blankPageFinished.future.timeout(const Duration(seconds: 3));
      } catch (_) {}

      if (identical(_blankPageFinished, blankPageFinished)) {
        _blankPageFinished = null;
      }
    }
  }

  Future<void> _onPageFinished(String url) async {
    if (url == 'about:blank') {
      final completer = _blankPageFinished;

      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
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

      final targetSelector = task.selector == 'ul#videoCategory'
          ? 'ul#videoCategory li.pcVideoListItem'
          : task.selector;

      while (DateTime.now().isBefore(deadline)) {
        if (!identical(_active, task) || task.result.isCompleted) {
          return;
        }

        final found = await controller.runJavaScriptReturningResult(
          "document.querySelector("
          "${jsonEncode(targetSelector)}) "
          "? 'ready' : 'waiting'",
        );

        if (_decode(found) == 'ready') {
          final html = await controller.runJavaScriptReturningResult(
            "document.querySelector("
            "${jsonEncode(task.selector)})"
            "?.outerHTML ?? ''",
          );

          if (!task.result.isCompleted) {
            task.result.complete(_decode(html));
          }
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      throw TimeoutException('等待 PC 端视频列表超时');
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
    _session = null;
    _controller = null;
    _initializing = null;

    if (session != null) {
      await session.close();
    }
  }
}

class _LoadTask {
  _LoadTask(this.uri, this.selector);

  final Uri uri;
  final String selector;
  final result = Completer<String>();

  bool extracting = false;
}
