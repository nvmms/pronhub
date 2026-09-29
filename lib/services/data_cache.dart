import 'dart:convert';

import 'package:pronhub/models/category_item.dart';
import 'package:pronhub/models/video_item.dart';
import 'package:pronhub/models/video_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class DataCache {
  static String _key(String type, Uri uri) => '$type:${uri.toString()}';

  static Future<VideoDetail?> videoDetail(Uri uri) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key('videoDetail', uri));
      return raw == null ? null : VideoDetail.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveVideoDetail(Uri uri, VideoDetail detail) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key('videoDetail', uri), jsonEncode(detail.toJson()));
    } catch (_) {
      // Cache failures must not prevent fresh data from being shown.
    }
  }

  static Future<List<VideoItem>?> videos(Uri uri) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key('videos', uri));
      if (raw == null) return null;
      return [
        for (final value in jsonDecode(raw) as List<dynamic>)
          VideoItem.fromJson(value as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveVideos(Uri uri, List<VideoItem> videos) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _key('videos', uri),
        jsonEncode([for (final video in videos) video.toJson()]),
      );
    } catch (_) {
      // Cache failures must not prevent fresh data from being shown.
    }
  }

  static Future<List<CategorySection>?> categories(Uri uri) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key('categories', uri));
      if (raw == null) return null;
      return [
        for (final value in jsonDecode(raw) as List<dynamic>)
          CategorySection.fromJson(value as Map<String, dynamic>),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCategories(
    Uri uri,
    List<CategorySection> sections,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _key('categories', uri),
        jsonEncode([for (final section in sections) section.toJson()]),
      );
    } catch (_) {
      // Cache failures must not prevent fresh data from being shown.
    }
  }
}
