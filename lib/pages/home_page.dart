import 'package:flutter/material.dart';
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/models/sort_option.dart';
import 'package:pronhub/pages/language_page.dart';
import 'package:pronhub/services/api.dart';
import 'package:pronhub/services/data_cache.dart';
import 'package:pronhub/pages/category_page.dart';
import 'package:pronhub/widgets/thumbnail_image.dart';
import 'package:pronhub/widgets/skeleton.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title, this.path});

  final String title;
  final String? path;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  List<VideoItem>? _videos;
  SortOption _selectedSort = SortOption.all.first;
  int _nextPage = 2;
  bool _hasMore = true;
  Object? _error;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  int _listVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (_loading || _loadingMore) return;
    final uri = widget.path == null
        ? Api.pageUri(1, path: _selectedSort.path)
        : Api.homeUri.resolve(widget.path!);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_videos == null) {
        final cached = await DataCache.videos(uri);
        if (!mounted) return;
        if (cached != null && cached.isNotEmpty) {
          setState(() => _videos = cached);
        }
      }
      final videos = await Api.videos(uri);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _nextPage = 2;
        _hasMore = true;
        _loadMoreFailed = false;
        _listVersion++;
      });
      await DataCache.saveVideos(uri, videos);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      if (_videos != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载页面失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading || _loadingMore || _loadMoreFailed) {
      return;
    }
    final uri = Api.pageUri(_nextPage, path: widget.path ?? _selectedSort.path);
    setState(() => _loadingMore = true);
    var showedCachedPage = false;
    var cachedNewVideos = false;
    try {
      final cached = await DataCache.videos(uri);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        final existingIds = _videos!.map((video) => video.id).toSet();
        final cachedVideos = cached
            .where((video) => existingIds.add(video.id))
            .toList();
        cachedNewVideos = cachedVideos.isNotEmpty;
        setState(() => _videos = [..._videos!, ...cachedVideos]);
        showedCachedPage = true;
      }
      final videos = await Api.videos(uri);
      if (!mounted) return;
      final existingIds = _videos!.map((video) => video.id).toSet();
      final newVideos = videos
          .where((video) => existingIds.add(video.id))
          .toList();
      setState(() {
        _videos = [..._videos!, ...newVideos];
        _nextPage++;
        _hasMore = cachedNewVideos || newVideos.isNotEmpty;
      });
      await DataCache.saveVideos(uri, videos);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (showedCachedPage) {
          _nextPage++;
        } else {
          _loadMoreFailed = true;
        }
      });
      debugPrint('[next page error] uri=$uri error=$error');
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onScroll();
        });
      }
    }
  }

  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadMore();
  }

  void _selectSort(SortOption option) {
    if (_loading || _loadingMore || _selectedSort.value == option.value) {
      return;
    }
    setState(() {
      _selectedSort = option;
      _videos = null;
      _error = null;
    });
    _loadInitial();
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
      body: Row(
        children: [
          if (widget.path == null)
            SizedBox(
              width: 160,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final option in SortOption.all)
                    ListTile(
                      dense: true,
                      title: Text(option.label),
                      selected: _selectedSort.value == option.value,
                      onTap: () => _selectSort(option),
                    ),
                  Spacer(),
                  Divider(),
                  ListTile(
                    dense: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LanguagePage(language: "chinese"),
                      ),
                    ),
                    title: const Text('中文视频'),
                  ),
                  ListTile(
                    dense: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CategoryPage(),
                      ),
                    ),
                    title: const Text('所有分类'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _videos == null && _loading
                ? const VideoSkeletonGrid()
                : _videos == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error?.toString() ?? '暂无视频'),
                        TextButton(
                          onPressed: _loadInitial,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (_loading) const LinearProgressIndicator(),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadInitial,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const spacing = 12.0;
                              final columns = (constraints.maxWidth / 220)
                                  .floor()
                                  .clamp(2, 8);
                              final cardWidth =
                                  (constraints.maxWidth -
                                      spacing * (columns + 1)) /
                                  columns;
                              return GridView.builder(
                                key: ValueKey(_listVersion),
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(spacing),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        Text(
                                          [item.duration, item.views]
                                              .where(
                                                (value) => value.isNotEmpty,
                                              )
                                              .join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      if (_loadingMore) const LinearProgressIndicator(),
                      if (_loadMoreFailed)
                        SafeArea(
                          top: false,
                          child: TextButton(
                            onPressed: _retryLoadMore,
                            child: const Text('下一页加载失败，点击重试'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
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
