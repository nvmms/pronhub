import 'package:flutter/material.dart';
import 'package:pronhub/models/category_item.dart';
import 'package:pronhub/services/api.dart';
import 'package:pronhub/widgets/skeleton.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  Uri _uri = Api.homeUri.resolve('/categories');
  int _loadVersion = 0;
  List<CategorySection>? _sections;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sections = await Api.categories(_uri);
      if (mounted && version == _loadVersion) {
        setState(() => _sections = sections);
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectOrientation(String path) {
    if (_uri.path == path) return;
    setState(() {
      _uri = Api.homeUri.resolve(path);
      _sections = null;
    });
    _load();
  }

  void _open(CategoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _CategoryLinkPage(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, path) in [
                  ('异性恋', '/categories'),
                  ('男同', '/gay/categories'),
                  ('女女萨福系', '/lesbian/categories'),
                ])
                  ListTile(
                    dense: true,
                    title: Text(label),
                    selected: _uri.path == path,
                    onTap: () => _selectOrientation(path),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (_loading) const LinearProgressIndicator(),
                Expanded(
                  child: _sections == null
                      ? _error == null
                          ? const CategorySkeletonGrid()
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('加载分类失败：$_error'),
                                  TextButton(
                                    onPressed: _load,
                                    child: const Text('重试'),
                                  ),
                                ],
                              ),
                            )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = (constraints.maxWidth / 180)
                                .floor()
                                .clamp(2, 6);
                            return ListView(
                              children: [
                                for (final section in _sections!)
                                  if (section.items.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        section.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            mainAxisExtent: 155,
                                          ),
                                      itemCount: section.items.length,
                                      itemBuilder: (context, index) {
                                        final item = section.items[index];
                                        return InkWell(
                                          onTap: () => _open(item),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: item.image == null
                                                    ? const ColoredBox(
                                                        color: Colors.black12,
                                                      )
                                                    : Image.network(
                                                        item.image.toString(),
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        headers: {
                                                          'Referer': _uri
                                                              .toString(),
                                                        },
                                                        errorBuilder:
                                                            (_, _, _) =>
                                                                const ColoredBox(
                                                                  color: Colors
                                                                      .black12,
                                                                ),
                                                      ),
                                              ),
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (item.count.isNotEmpty)
                                                Text(
                                                  '${item.count} 视频',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                              ],
                            );
                          },
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

class _CategoryLinkPage extends StatefulWidget {
  const _CategoryLinkPage({required this.item});
  final CategoryItem item;

  @override
  State<_CategoryLinkPage> createState() => _CategoryLinkPageState();
}

class _CategoryLinkPageState extends State<_CategoryLinkPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.item.url);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.item.name)),
    body: WebViewWidget(controller: _controller),
  );
}
