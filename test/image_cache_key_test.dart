import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/widgets/image_cache_key.dart';

void main() {
  test('image cache key ignores query parameters and fragment', () {
    final first = Uri.parse('https://example.com/photo.jpg?token=old#preview');
    final second = Uri.parse('https://example.com/photo.jpg?token=new');

    expect(imageCacheKey(first), 'https://example.com/photo.jpg');
    expect(imageCacheKey(second), imageCacheKey(first));
  });
}
