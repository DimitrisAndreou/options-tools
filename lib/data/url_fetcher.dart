import 'package:http/http.dart' as http;
import 'package:memory_cache/memory_cache.dart';

class UrlFetcher {
  final MemoryCache _cache = MemoryCache();
  final Duration _duration;

  // Cloudflare worker.
  static const String _proxyBase =
      'https://yahoo-proxy.jim-andreou.workers.dev';

  UrlFetcher(Duration duration) : _duration = duration;

  Future<String> fetch(String uri, {Map<String, String>? headers}) async {
    final cacheKey = '$uri|$headers';
    String? cached = _cache.read<String>(cacheKey);
    if (cached != null) {
      print("Return cached...");
      return cached;
    }

    try {
      // 1. Determine if we need to proxy (is it a Yahoo URL?)
      bool isYahoo = uri.contains('yahoo.com');
      print("isYahoo: $isYahoo");
      Uri finalUri = isYahoo
          ? Uri.parse('$_proxyBase?target=${Uri.encodeComponent(uri)}')
          : Uri.parse(uri);
      print("finalUri: $finalUri");

      // 2. Execute the request
      http.Response response = await http.get(finalUri, headers: headers);

      // 3. Status Code Validation
      // We allow Yahoo's 404 on the cookie-granting endpoint (fc.yahoo.com)
      // because it still provides the necessary session headers.
      if (response.statusCode != 200) {
        bool isYahooCookieWall = isYahoo &&
            uri.contains('fc.yahoo.com') &&
            response.statusCode == 404;

        if (!isYahooCookieWall) {
          throw Exception(
              'Failed to fetch $uri, got error: ${response.statusCode}');
        }
      }

      // 4. Extract Camouflaged Cookie
      // If the Worker sent back our custom header, inject it into the mutable
      // headers map so the next call (the Crumb or Data) already has it.
      if (isYahoo) {
        // Check for lowercase and original case
        String? cookieHeader = response.headers['x-yahoo-cookie'] ??
            response.headers['X-Yahoo-Cookie'];

        if (cookieHeader != null) {
          if (headers != null) {
            print("Raw cookie: $cookieHeader");
            headers['x-proxy-cookie'] = _cleanCookieHeader(cookieHeader);
            print("Cleaned x-proxy-cookie: ${headers['x-proxy-cookie']}");
            print("Successfully captured cookie!");
          }
        } else {
          print("No x-yahoo-cookie found. Available: ${response.headers.keys}");
        }
      }

      // 5. Cache and Return
      String value = response.body;
      _cache.create(cacheKey, value, expiry: _duration);
      return value;
    } catch (e) {
      print('Failed while fetching url: [$uri], error: $e');
      rethrow;
    }
  }

  String _cleanCookieHeader(String rawCookie) {
    // Split by comma to get individual cookies, but be careful of commas inside dates
    // A better approach for Yahoo: extract only the key=value pairs that don't match metadata
    final List<String> cleanParts = [];
    final parts = rawCookie.split(
        RegExp(r',(?=[^;]*=)')); // Split only on commas followed by a key=

    final metadata = {
      'expires',
      'domain',
      'path',
      'samesite',
      'max-age',
      'secure',
      'httponly'
    };

    for (var part in parts) {
      final subParts = part.split(';');
      for (var sub in subParts) {
        final trimmed = sub.trim();
        if (trimmed.contains('=')) {
          final key = trimmed.split('=')[0].toLowerCase();
          if (!metadata.contains(key)) {
            cleanParts.add(trimmed);
          }
        }
      }
    }
    // Remove duplicates and join with semicolon
    return cleanParts.toSet().join('; ');
  }
}
