import 'package:flutter_test/flutter_test.dart';
import 'package:pronhub/services/api.dart';
import 'package:webview_all/webview_all.dart';

void main() {
  test('preserves quoted JSON cookie values for browser requests', () {
    const value = '{"i":0,"l":"179156332775","b":"signed+value/="}';
    expect(
      browserCookieHeader([
        const WebViewCookie(
          name: 'session',
          value: 'abc',
          domain: 'example.com',
        ),
        const WebViewCookie(name: 'state', value: value, domain: 'example.com'),
      ]),
      'session=abc; state=$value',
    );
    expect(browserCookieHeader([]), isEmpty);
  });
}
