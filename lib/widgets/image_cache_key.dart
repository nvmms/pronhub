String imageCacheKey(Uri url) => url.toString().split(RegExp(r'[?#]')).first;
