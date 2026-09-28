import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/category_item.dart';
import 'package:pronhub/services/api.dart';

void main() {
  test('parses both category sections and their links', () {
    const html = '''
<div class="categoriesPage">
  <div class="nf-videos">
    <div class="categoriesTitle"><h1>热门色情片类型</h1></div>
    <ul class="categoriesListSection">
      <li class="catPic"><div class="relativeWrapper">
        <img src="/popular.jpg">
        <span class="categoryTitleWrapper"><a href="/video?c=28">
          <strong>熟女</strong><span class="videoCount"><var>48,431</var></span>
        </a></span>
      </div></li>
    </ul>
  </div>
  <div class="nf-videos">
    <div class="categoriesTitle"><h2>所有色情片类型</h2></div>
    <ul class="categoriesListSection">
      <li class="catPic"><div class="relativeWrapper">
        <img src="/teen.jpg">
        <span class="categoryTitleWrapper"><a href="/categories/teen">
          <strong>18-25歲</strong><span class="videoCount"><var>311,655</var></span>
        </a></span>
      </div></li>
    </ul>
  </div>
</div>
''';
    final sections = CategorySection.listFromHtml(
      html,
      Api.homeUri.resolve('/categories'),
    );
    expect(sections, hasLength(2));
    expect(sections.first.title, '热门色情片类型');
    expect(sections.first.items.single.name, '熟女');
    expect(sections.first.items.single.count, '48,431');
    expect(sections.first.items.single.url.toString(),
        'https://cn.pornhub.com/video?c=28');
    expect(sections.last.items.single.url.toString(),
        'https://cn.pornhub.com/categories/teen');
  });
}
