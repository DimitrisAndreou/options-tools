import 'package:http/http.dart' as http;
import 'package:memory_cache/memory_cache.dart';

class UrlFetcher {
  final MemoryCache _cache = MemoryCache();
  final Duration _duration;

  UrlFetcher(Duration duration) : _duration = duration;

  Future<String> fetch(String uri) async {
    String? cached = _cache.read<String>(uri);
    if (cached != null) {
      return cached;
    }
    try {
      http.Response response = await http.get(Uri.parse(uri));
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch $uri, got error: ${response.statusCode}');
      }
      String value = response.body;
      _cache.create(uri, value, expiry: _duration);
      return value;
    } catch (e) {
      print('Failed while fetching url: [$uri], error: $e');
      rethrow;
    }
  }
}
