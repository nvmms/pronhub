import 'package:html/dom.dart';

/// CSS 选择器按顺序尝试；找到匹配后停止。修改后需重新编译。
abstract final class PageSelectors {
  static const videoList = <String>['ul#videoCategory', 'ul#videoSearchResult'];
  static const videoItem = <String>['li.pcVideoListItem'];
  static const videoLink = <String>['.title a[href*="/view_video.php"]'];
  static const videoThumbnail = <String>['img.js-videoThumb'];
  static const videoDuration = <String>['.marker-overlays .duration'];
  static const videoViews = <String>[
    '.videoDetailBlock .views',
    '.views',
    '.videoViews',
    '.video-views',
  ];
  static const videoUploader = <String>['.usernameWrap a'];
  static const detailBody = <String>['body'];
  static const categoryPage = <String>['.categoriesPage'];
  static const categorySections = <String>['.categoriesPage .nf-videos'];
  static const categorySectionTitle = <String>[
    '.categoriesTitle h1',
    '.categoriesTitle h2',
  ];
  static const categoryCards = <String>['.categoriesListSection > li.catPic'];
  static const categoryLink = <String>['.categoryTitleWrapper a[href]'];
  static const categoryName = <String>['strong'];
  static const categoryImage = <String>['.relativeWrapper img'];
  static const categoryCount = <String>['.videoCount var'];
  static const detailLanguage = <String>[
    '.video-detailed-info .langSpokenWrapper a.item',
  ];
  static const detailAvatar = <String>['.video-detailed-info .userAvatar img'];
  static const detailUserStats = <String>[
    '.video-detailed-info .userInfo > span',
  ];
  static const relatedVideos = <String>[
    '#relatedVideosListing li.pcVideoListItem',
  ];
  static const detailTitle = <String>['h1.title', '.videoTitle'];
  static const detailMetaTitle = <String>['meta[property="og:title"]'];
  static const detailAuthor = <String>['.video-detailed-info .usernameWrap a'];
  static const detailCategories = <String>[
    '.video-detailed-info .categoriesWrapper a.item',
  ];
  static const detailCategoryLinks = <String>[
    '.video-detailed-info .categoriesWrapper a.item[href]',
  ];
  static const detailTags = <String>[
    '.video-detailed-info .tagsWrapper a.item',
  ];
  static const detailTagLinks = <String>[
    '.video-detailed-info .tagsWrapper a.item[href]',
  ];
}

/// 对每组候选选择器，只使用第一个有匹配结果的选择器。
extension SelectorFallback on Node {
  List<Element> selectAll(List<String> selectors) {
    for (final selector in selectors) {
      final matches = switch (this) {
        Document node => node.querySelectorAll(selector),
        DocumentFragment node => node.querySelectorAll(selector),
        Element node => node.querySelectorAll(selector),
        _ => <Element>[],
      };
      if (matches.isNotEmpty) return matches;
    }
    return <Element>[];
  }

  Element? selectFirst(List<String> selectors) {
    final matches = selectAll(selectors);
    return matches.isEmpty ? null : matches.first;
  }
}
