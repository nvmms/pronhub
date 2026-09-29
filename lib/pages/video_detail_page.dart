import 'package:flutter/material.dart';
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
            return LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final availableWidth =
                  (constraints.maxWidth - 48).clamp(0.0, double.infinity);
              final contentWidth =
                  availableWidth > 1380 ? 1380.0 : availableWidth;
              final sideWidth = wide ? contentWidth * .34 : contentWidth;
              final playerWidth =
                  wide ? contentWidth - sideWidth - 24 : contentWidth;
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
                                    child: _player(snapshot.data)),
                                const SizedBox(width: 24),
                                SizedBox(
                                    width: sideWidth,
                                    child: _information(detail, snapshot)),
                              ])
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
                        Text('相关推荐',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 14),
                        if (detail != null)
                          _related(detail.related, contentWidth)
                        else if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          const LinearProgressIndicator(),
                      ]),
                )),
              );
            });
          },
        ),
      );

  Widget _player(VideoDetail? detail) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.black, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: detail == null
              ? const CircularProgressIndicator()
              : VideoStreamPlayer(
                  key: _playerKey,
                  sources: detail.sources,
                  pageUrl: widget.video.url),
        ),
      );

  Widget _information(
      VideoDetail? detail, AsyncSnapshot<VideoDetail> snapshot) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          detail?.title.isNotEmpty == true ? detail!.title : widget.video.title,
          style: theme.textTheme.titleLarge),
      const SizedBox(height: 16),
      if (snapshot.hasError) ...[
        Text('详情加载失败：${snapshot.error}'),
        TextButton(onPressed: _retry, child: const Text('重试')),
      ] else if (detail == null)
        const LinearProgressIndicator()
      else ...[
        Row(children: [
          CircleAvatar(
              radius: 25,
              backgroundImage: detail.avatar == null
                  ? null
                  : NetworkImage(detail.avatar.toString()),
              child: detail.avatar == null
                  ? const Icon(Icons.person_outline)
                  : null),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    detail.author.isEmpty
                        ? widget.video.uploader
                        : detail.author,
                    style: theme.textTheme.titleMedium),
                Text(
                    [detail.videoCount, detail.subscribers]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: theme.textTheme.bodySmall),
              ])),
        ]),
        const SizedBox(height: 20),
        _section('分类', detail.categories, maxRows: 3),
        OutlinedButton.icon(
          onPressed: snapshot.data?.sources.isNotEmpty == true
              ? () => _playerKey.currentState?.showFullscreen()
              : null,
          icon: const Icon(Icons.fullscreen),
          label: const Text('全屏播放'),
        ),
      ],
    ]);
  }

  Widget _metadata(VideoDetail detail) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('标签', detail.tags),
          if (detail.language.isNotEmpty) _section('语言', [detail.language]),
        ],
      );

  Widget _section(String title, List<String> values, {int? maxRows}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (values.isEmpty)
            const Text('—')
          else if (maxRows != null)
            _limitedRows(values, maxRows)
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final value in values)
                Chip(label: Text(value), visualDensity: VisualDensity.compact),
            ]),
        ]),
      );

  Widget _limitedRows(List<String> values, int maxRows) => LayoutBuilder(
        builder: (context, constraints) {
          final style =
              Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
          final textDirection = Directionality.of(context);
          final visible = <String>[];
          var row = 1;
          var usedWidth = 0.0;
          for (final value in values) {
            final painter = TextPainter(
              text: TextSpan(text: value, style: style),
              textDirection: textDirection,
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final chipWidth = painter.width + 18;
            final width = chipWidth.clamp(0.0, constraints.maxWidth);
            final needed = usedWidth == 0 ? width : width + 8;
            if (usedWidth > 0 && usedWidth + needed > constraints.maxWidth) {
              row++;
              usedWidth = 0;
            }
            if (row > maxRows) break;
            visible.add(value);
            usedWidth += usedWidth == 0 ? width : width + 8;
          }
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final value in visible)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style),
                ),
              ),
          ]);
        },
      );

  Widget _related(List<VideoItem> videos, double width) {
    if (videos.isEmpty) return const Text('暂无相关推荐');
    final columns = (width / 220).floor().clamp(1, 6);
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
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => VideoDetailPage(video: video))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
                aspectRatio: 16 / 9,
                child: ThumbnailImage(
                    url: video.thumbnail,
                    videoId: video.id,
                    referer: Api.homeUri)),
            const SizedBox(height: 6),
            Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        );
      },
    );
  }
}
