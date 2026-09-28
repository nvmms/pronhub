import 'package:flutter/material.dart';
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/services/api.dart';
import 'package:pronhub/widgets/thumbnail_image.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<VideoItem>? _videos;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final videos = await Api.homeVideos();
      if (!mounted) return;
      setState(() => _videos = videos);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(VideoItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _VideoPage(url: item.url, title: item.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _videos == null && _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error?.toString() ?? '暂无视频'),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final columns = (constraints.maxWidth / 220).floor().clamp(
                    2,
                    8,
                  );
                  final cardWidth =
                      (constraints.maxWidth - spacing * (columns + 1)) /
                      columns;
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(spacing),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: cardWidth * 9 / 16 + 98,
                    ),
                    itemCount: _videos!.length,
                    itemBuilder: (context, index) {
                      final item = _videos![index];
                      return InkWell(
                        onTap: () => _open(item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ThumbnailImage(
                                url: item.thumbnail,
                                videoId: item.id,
                                referer: Api.homeUri,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.uploader.isNotEmpty)
                              Text(
                                item.uploader,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            Text(
                              [
                                item.duration,
                                item.views,
                              ].where((value) => value.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.url, required this.title});

  final Uri url;
  final String title;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: WebViewWidget(controller: _controller),
  );
}
