import 'package:pronhub/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:pronhub/services/orientation_policy.dart';
import 'package:pronhub/models/category_item.dart';
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/models/sort_option.dart';
import 'package:pronhub/pages/language_page.dart';
import 'package:pronhub/pages/video_detail_page.dart';
import 'package:pronhub/services/api.dart';
import 'package:pronhub/services/data_cache.dart';
import 'package:pronhub/pages/category_page.dart';
import 'package:pronhub/widgets/thumbnail_image.dart';
import 'package:pronhub/widgets/skeleton.dart';
import 'package:pronhub/widgets/browse_layout.dart';

class VideoView extends StatefulWidget {
  const VideoView({super.key, this.path, this.category});

  final String? path;
  final CategoryItem? category;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
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

  String get _sortPath {
    if (widget.path == null) return _selectedSort.path;
    final uri = Uri.parse(widget.path!);
    final query = Map<String, String>.from(uri.queryParameters);
    if (_selectedSort == SortOption.all.first) {
      query.remove('o');
    } else {
      query['o'] = _selectedSort.value;
    }
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }

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
        ? Api.pageUri(1, path: _sortPath)
        : Api.homeUri.resolve(_sortPath);
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
    final uri = Api.pageUri(_nextPage, path: _sortPath);
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
        settings: const RouteSettings(name: OrientationPolicy.playbackRoute),
        builder: (_) => VideoDetailPage(video: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrowseLayout(
      title:
          widget.category?.name ?? (widget.path == '/video' ? '视频精选' : '视频列表'),
      actions: [
        for (final option in SortOption.all)
          BrowseAction(
            option.label,
            Icons.sort_rounded,
            () => _selectSort(option),
            selected: _selectedSort.value == option.value,
          ),
      ],
      bottomActions: [
        if (widget.path == null || widget.path == '/video') ...[
          BrowseAction(
            '中文视频',
            Icons.language_rounded,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LanguagePage(language: 'chinese'),
              ),
            ),
          ),
          BrowseAction(
            '所有分类',
            Icons.grid_view_rounded,
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CategoryPage()),
            ),
          ),
        ],
        if (widget.path != '/video' && !context.isPhone)
          BrowseAction(
            '返回',
            Icons.arrow_back_rounded,
            () => Navigator.pop(context),
          ),
      ],
      child: _videos == null && _loading
          ? const VideoSkeletonGrid()
          : _videos == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error?.toString() ?? '暂无视频'),
                  TextButton(onPressed: _loadInitial, child: const Text('重试')),
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
                        final columns = context.isPhone
                            ? 2
                            : (constraints.maxWidth / 250).floor().clamp(1, 6);
                        final cardWidth =
                            (constraints.maxWidth - spacing * (columns + 1)) /
                            columns;
                        return GridView.builder(
                          key: ValueKey(_listVersion),
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                mainAxisExtent: cardWidth * 9 / 16 + 96,
                              ),
                          itemCount: _videos!.length,
                          itemBuilder: (context, index) {
                            final item = _videos![index];
                            return InkWell(
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              onTap: () => _open(item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        ThumbnailImage(
                                          url: item.thumbnail,
                                          videoId: item.id,
                                          referer: Api.homeUri,
                                        ),
                                        if (item.duration.isNotEmpty)
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.78,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.duration,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            if (item.uploader.isNotEmpty) ...[
                                              Icon(
                                                Icons.person_outline,
                                                size: 15,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  item.uploader,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.views.isEmpty ? '—' : item.views,
                                        maxLines: 1,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
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
    );
  }
}
