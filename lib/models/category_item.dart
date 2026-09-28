import 'package:html/parser.dart' as html_parser;

class CategoryItem {
  const CategoryItem({
    required this.name,
    required this.url,
    this.image,
    this.count = '',
  });

  final String name;
  final Uri url;
  final Uri? image;
  final String count;

  factory CategoryItem.fromJson(Map<String, dynamic> json) => CategoryItem(
    name: json['name'] as String,
    url: Uri.parse(json['url'] as String),
    image: (json['image'] as String?) == null
        ? null
        : Uri.parse(json['image'] as String),
    count: json['count'] as String,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url.toString(),
    'image': image?.toString(),
    'count': count,
  };
}

class CategorySection {
  const CategorySection({required this.title, required this.items});

  final String title;
  final List<CategoryItem> items;

  factory CategorySection.fromJson(Map<String, dynamic> json) =>
      CategorySection(
        title: json['title'] as String,
        items: [
          for (final value in json['items'] as List<dynamic>)
            CategoryItem.fromJson(value as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
    'title': title,
    'items': [for (final item in items) item.toJson()],
  };

  static List<CategorySection> listFromHtml(String html, Uri baseUri) {
    final root = html_parser.parseFragment(html);
    return [
      for (final section in root.querySelectorAll('.categoriesPage .nf-videos'))
        CategorySection(
          title:
              section
                  .querySelector('.categoriesTitle h1, .categoriesTitle h2')
                  ?.text
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim() ??
              '分类',
          items: [
            for (final card in section.querySelectorAll(
              '.categoriesListSection > li.catPic',
            ))
              if (card.querySelector('.categoryTitleWrapper a[href]')
                  case final link?)
                if ((link.attributes['href'] ?? '').isNotEmpty)
                  CategoryItem(
                    name: link.querySelector('strong')?.text.trim() ?? '',
                    url: baseUri.resolve(link.attributes['href']!),
                    image: switch (card
                        .querySelector('.relativeWrapper img')
                        ?.attributes['src']) {
                      final String src when src.isNotEmpty => baseUri.resolve(
                        src,
                      ),
                      _ => null,
                    },
                    count:
                        card.querySelector('.videoCount var')?.text.trim() ??
                        '',
                  ),
          ],
        ),
    ];
  }
}
