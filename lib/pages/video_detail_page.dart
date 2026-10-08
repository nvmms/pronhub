import 'package:pronhub/extensions/build_context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:pronhub/services/orientation_policy.dart';
import 'package:pronhub/models/video_detail.dart';
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/services/api.dart';
import 'package:pronhub/services/data_cache.dart';
import 'package:pronhub/widgets/thumbnail_image.dart';
import 'package:pronhub/widgets/video_stream_player.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({super.key, required this.video});
  final VideoItem video;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  late Future<VideoDetail> _detail;
  VideoDetail? _cachedDetail;
  final _playerKey = GlobalKey<VideoStreamPlayerState>();
  final _expandedSections = <String>{};

  @override
  void initState() {
    super.initState();
    _detail = _loadDetail();
  }

  Future<VideoDetail> _loadDetail() async {
    final cached = await DataCache.videoDetail(widget.video.url);
    if (cached != null && mounted) setState(() => _cachedDetail = cached);
    try {
      final fresh = await Api.videoDetail(widget.video.url);
      await DataCache.saveVideoDetail(widget.video.url, fresh);
      return fresh;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  void _retry() => setState(() => _detail = _loadDetail());

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<VideoDetail>(
      future: _detail,
      builder: (context, snapshot) {
        final detail = snapshot.data ?? _cachedDetail;
        if (context.isPhone) {
          return SafeArea(
            child: Column(
              children: [
                Stack(
                  children: [
                    _player(snapshot.data),
                    if (snapshot.data == null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          tooltip: '返回',
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.black54,
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _information(detail, snapshot),
                          if (detail != null) ...[
                            const SizedBox(height: 24),
                            _metadata(detail),
                          ],
                          const SizedBox(height: 32),
                          Text(
                            '相关推荐',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 14),
                          if (detail != null)
                            _related(
                              detail.related,
                              (constraints.maxWidth - 32).clamp(
                                0.0,
                                double.infinity,
                              ),
                            )
                          else if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const LinearProgressIndicator(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final contentWidth = (constraints.maxWidth - 48).clamp(
              0.0,
              double.infinity,
            );
            final sideWidth = wide ? contentWidth * .34 : contentWidth;
            final playerWidth = wide
                ? contentWidth - sideWidth - 24
                : contentWidth;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: playerWidth,
                              child: _player(snapshot.data),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: sideWidth,
                              child: _information(detail, snapshot),
                            ),
                          ],
                        )
                      else ...[
                        _player(snapshot.data),
                        const SizedBox(height: 24),
                        _information(detail, snapshot),
                      ],
                      if (detail != null) ...[
                        const SizedBox(height: 24),
                        _metadata(detail),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        '相关推荐',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 14),
                      if (detail != null)
                        _related(detail.related, contentWidth)
                      else if (snapshot.connectionState ==
                          ConnectionState.waiting)
                        const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Widget _player(VideoDetail? detail) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: detail == null
          ? const CircularProgressIndicator()
          : VideoStreamPlayer(
              key: _playerKey,
              sources: detail.sources,
              pageUrl: widget.video.url,
              title: detail.title.isEmpty ? widget.video.title : detail.title,
              refreshSources: () async {
                final fresh = await Api.videoDetail(widget.video.url);
                await DataCache.saveVideoDetail(widget.video.url, fresh);
                return fresh.sources;
              },
            ),
    ),
  );

  Widget _information(
    VideoDetail? detail,
    AsyncSnapshot<VideoDetail> snapshot,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail?.title.isNotEmpty == true ? detail!.title : widget.video.title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (snapshot.hasError) ...[
          Text('详情加载失败：${snapshot.error}'),
          TextButton(onPressed: _retry, child: const Text('重试')),
        ] else if (detail == null)
          const LinearProgressIndicator()
        else ...[
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: detail.avatar == null
                    ? null
                    : NetworkImage(detail.avatar.toString()),
                child: detail.avatar == null
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.author.isEmpty
                          ? widget.video.uploader
                          : detail.author,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      [
                        detail.videoCount,
                        detail.subscribers,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section('分类', detail.categories, maxRows: context.isPhone ? 2 : 3),
          if (!context.isPhone)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                enabledMouseCursor: SystemMouseCursors.click,
              ),
              onPressed: snapshot.data?.sources.isNotEmpty == true
                  ? () => _playerKey.currentState?.showFullscreen()
                  : null,
              icon: const Icon(Icons.fullscreen),
              label: const Text('全屏播放'),
            ),
        ],
      ],
    );
  }

  Widget _metadata(VideoDetail detail) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section('标签', detail.tags, maxRows: context.isPhone ? 2 : null),
      if (detail.language.isNotEmpty) _section('语言', [detail.language]),
    ],
  );

  Widget _section(String title, List<String> values, {int? maxRows}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (values.isEmpty)
          const Text('—')
        else if (maxRows != null)
          _limitedRows(
            title,
            values,
            _expandedSections.contains(title) ? null : maxRows,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final value in values) _MetadataTag(label: value)],
          ),
      ],
    ),
  );

  Widget _limitedRows(
    String title,
    List<String> values,
    int? maxRows,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
      final textDirection = Directionality.of(context);
      double itemWidth(String value) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: textDirection,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final width = (painter.width + 18).clamp(0.0, constraints.maxWidth);
        painter.dispose();
        return width;
      }

      final widths = [for (final value in values) itemWidth(value)];
      final moreWidth = itemWidth('更多…');
      bool fits(int count, {bool withMore = false}) {
        var row = 1;
        var usedWidth = 0.0;
        for (final width in [...widths.take(count), if (withMore) moreWidth]) {
          final needed = usedWidth == 0 ? width : width + 8;
          if (usedWidth > 0 && usedWidth + needed > constraints.maxWidth) {
            row++;
            usedWidth = 0;
          }
          if (maxRows != null && row > maxRows) return false;
          usedWidth += usedWidth == 0 ? width : width + 8;
        }
        return true;
      }

      final hasMore = maxRows != null && !fits(values.length);
      var visibleCount = values.length;
      if (hasMore) {
        visibleCount = 0;
        while (visibleCount < values.length &&
            fits(visibleCount + 1, withMore: true)) {
          visibleCount++;
        }
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in values.take(visibleCount))
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: _MetadataTag(label: value, compact: true),
              ),
            ),
          if (hasMore)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _expandedSections.add(title)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '更多…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _related(List<VideoItem> videos, double width) {
    if (videos.isEmpty) return const Text('暂无相关推荐');
    final columns = context.isPhone ? 2 : (width / 220).floor().clamp(1, 6);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: (width - 16 * (columns - 1)) / columns * 9 / 16 + 76,
      ),
      itemBuilder: (context, index) {
        final video = videos[index];
        return InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              settings: const RouteSettings(
                name: OrientationPolicy.playbackRoute,
              ),
              builder: (_) => VideoDetailPage(video: video),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ThumbnailImage(
                  url: video.thumbnail,
                  videoId: video.id,
                  referer: Api.homeUri,
                ),
              ),
              const SizedBox(height: 6),
              Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

class _MetadataTag extends StatefulWidget {
  const _MetadataTag({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  State<_MetadataTag> createState() => _MetadataTagState();
}

class _MetadataTagState extends State<_MetadataTag> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: _hovered ? scheme.primary : null,
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.compact
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _hovered ? scheme.primaryContainer : Colors.transparent,
                border: Border.all(
                  color: _hovered ? scheme.primary : scheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            )
          : Chip(
              mouseCursor: SystemMouseCursors.click,
              label: Text(widget.label),
              labelStyle: _hovered ? style : null,
              backgroundColor: _hovered ? scheme.primaryContainer : null,
              side: _hovered ? BorderSide(color: scheme.primary) : null,
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}
