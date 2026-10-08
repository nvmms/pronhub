import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/models/video_detail.dart';

void main() {
  test('category links retain actual paths through the detail cache', () {
    final detail = VideoDetail.fromHtml('''
      <div class="video-detailed-info"><div class="categoriesWrapper">
        <a class="item" href="/video?c=42&amp;o=mr">Example category</a>
      </div><div class="tagsWrapper">
        <a class="item" href="/video/search?search=example">Example tag</a>
      </div><div class="langSpokenWrapper">
        <a class="item" href="/language/chinese">中文</a>
      </div></div>
    ''', Uri.parse('https://example.com/view_video.php?id=1'));
    expect(detail.categories, ['Example category']);
    expect(detail.categoryPaths['Example category'],
        'https://example.com/video?c=42&o=mr');
    expect(VideoDetail.fromJson(detail.toJson()).categoryPaths,
        detail.categoryPaths);
    expect(detail.tagPaths['Example tag'],
        'https://example.com/video/search?search=example');
    expect(VideoDetail.fromJson(detail.toJson()).tagPaths, detail.tagPaths);
    expect(detail.language, '中文');
    expect(detail.languageCode, 'chinese');
    expect(VideoDetail.fromJson(detail.toJson()).languageCode, 'chinese');
    final oldCache = detail.toJson()..remove('categoryPaths');
    expect(VideoDetail.fromJson(oldCache).categoryPaths, isEmpty);
  });
}
