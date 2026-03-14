import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collection/collection.dart';

import '../assets.dart';
import '../markets.dart';
import 'url_fetcher.dart';

class YFinance {
  static const String _baseUrl = 'https://query2.finance.yahoo.com';

  final Map<String, String> _headers;
  final String _crumb;

  YFinance(this._headers, this._crumb);

  Future<List<Market>> fetchMarket(String ticker, UrlFetcher urlFetcher) async {
    bool firstOptionChain = true;
    Market? spotMarket;
    List<Market> markets = [];
    final urlsToFetch = ['$_baseUrl/v7/finance/options/$ticker?crumb=$_crumb'];
    while (urlsToFetch.isNotEmpty) {
      final url = urlsToFetch.removeLast();
      print("About to fetch an option chain... $url, Headers: $_headers");
      final rawJson = await urlFetcher.fetch(url, headers: _headers);

      final data = json.decode(rawJson) as Map<String, dynamic>;
      final results = (data["optionChain"]?["result"] as List?)?.firstOrNull;

      final quote =
          results["quote"] ?? (throw StateError("Did not find quote"));
      final money = Commodity(quote["currency"]);
      final underlying = Commodity(quote["symbol"]);
      // Will add this to markets last, to have the latest value.
      spotMarket = Market.create(
          asset: underlying, // AAPL
          money: money, // USD
          bidPrice: quote["bid"]!,
          askPrice: quote["ask"]!);

      final optionChain = (results["options"] as List?)?.firstOrNull;
      if (firstOptionChain) {
        // Also remember to fetch the rest expirations.
        firstOptionChain = false;
        final expirations = results["expirationDates"].cast<int>().toSet();
        // Not the one we happen to get in the first, dateless request.
        expirations.remove(optionChain["expirationDate"]);
        print("TEMP: not adding more option chains"); // DO NOT SUBMIT
        for (int expiration in expirations) {
          urlsToFetch.add(
              '$_baseUrl/v7/finance/options/$ticker?crumb=$_crumb&date=$expiration');
        }
      }

      for (final (optionType, isCall) in [("calls", true), ("puts", false)]) {
        final options = optionChain[optionType] ??
            // TODO: catch & rethrow, to print more debug stuff if needed.
            (throw StateError("Did not find $optionType"));
        for (final option in options) {
          final optionMarket = Market.create(
              asset: Option(option["contractSymbol"],
                  underlying: underlying,
                  money: money,
                  strike: option["strike"],
                  isPut: !isCall,
                  isCall: isCall,
                  expiration: DateTime.fromMillisecondsSinceEpoch(
                      option["expiration"] * 1000),
                  contractLot: 100.0),
              money: Commodity(option["currency"]), // USD
              bidPrice: option["bid"]! * 100.0,
              askPrice: option["ask"]! * 100.0);
          markets.add(optionMarket);
        }
      }
    }
    markets.add(spotMarket!);
    return markets;
  }

  // static Future<YFinance> openConnection() async {
  //   final Map<String, String> headers = {
  //     'User-Agent':
  //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
  //             '(KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  //     'Accept': '*/*',
  //   };
  //   final cookieResponse =
  //       await http.get(Uri.parse('https://fc.yahoo.com'), headers: headers);

  //   headers['cookie'] = cookieResponse.headers['set-cookie'] ??
  //       (throw StateError("No cookie given by Yahoo"));

  //   final crumbResponse = await http.get(
  //     Uri.parse('$_baseUrl/v1/test/getcrumb'),
  //     headers: headers,
  //   );
  //   if (crumbResponse.statusCode != 200) {
  //     throw StateError("Failed to get crumb: ${crumbResponse.statusCode}");
  //   }
  //   // The API key a session.
  //   final crumb = crumbResponse.body;
  //   return YFinance(headers, crumb);
  // }

  // static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
  //   final Map<String, String> headers = {
  //     'User-Agent':
  //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...',
  //     'Accept': '*/*',
  //   };

  //   // 1. Get Cookie via Proxy
  //   // We fetch the full response so we can look at the headers
  //   final cookieTarget = 'https://fc.yahoo.com';
  //   final response = await http.get(
  //     Uri.parse('$_proxyUrl?target=${Uri.encodeComponent(cookieTarget)}'),
  //     headers: headers,
  //   );

  //   // 2. Extract our camouflaged cookie
  //   final String? cookie = response.headers['x-yahoo-cookie'];

  //   if (cookie == null) {
  //     throw StateError(
  //         "Yahoo Proxy failed to return X-Yahoo-Cookie. Check Worker deployment.");
  //   }

  //   headers['cookie'] = cookie;

  //   // 3. Get Crumb via Proxy
  //   final crumbTarget = 'https://query2.finance.yahoo.com/v1/test/getcrumb';
  //   final crumbResponse = await http.get(
  //     Uri.parse('$_proxyUrl?target=${Uri.encodeComponent(crumbTarget)}'),
  //     headers: headers,
  //   );

  //   if (crumbResponse.statusCode != 200) {
  //     throw StateError("Failed to get crumb: ${crumbResponse.statusCode}");
  //   }

  //   return YFinance(headers, crumbResponse.body);
  // }

  // static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
  //   final Map<String, String> headers = {
  //     'User-Agent':
  //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
  //             '(KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  //     'Accept': '*/*',
  //   };

  //   // Fetch the cookie.
  //   await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

  //   if (!headers.containsKey('cookie')) {
  //     throw StateError("No cookie obtained via proxy.");
  //   }

  //   // Fetch the crumb (API key).
  //   // This call will automatically include the new cookie in the headers.
  //   final crumb =
  //       await urlFetcher.fetch('$_baseUrl/v1/test/getcrumb', headers: headers);

  //   return YFinance(headers, crumb);
  // }

  // static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
  //   final Map<String, String> headers = {
  //     'User-Agent':
  //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...',
  //     'Accept': '*/*',
  //   };

  //   // 1. Get the session cookie (ignore the 404)
  //   await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

  //   // 2. Fetch the AAPL page instead of the crumb endpoint
  //   // This is less likely to trigger a 401 because it's a "public" page
  //   final html = await urlFetcher.fetch('https://finance.yahoo.com/quote/AAPL',
  //       headers: headers);

  //   // 3. Extract the crumb using Regex
  //   // Yahoo's format is: "crumb":"RANDOM_STRING"
  //   final RegExp crumbRegExp = RegExp(r'"crumb":"(.*?)"');
  //   final match = crumbRegExp.firstMatch(html);
  //   final crumb = match?.group(1);

  //   if (crumb == null || crumb.isEmpty) {
  //     print(html);
  //     throw StateError(
  //         "Found page, but couldn't find 'crumb' in HTML. Try refreshing.");
  //   }

  //   // Handle cases where characters like / are escaped as \u002F
  //   final cleanCrumb = crumb.replaceAll(r'\u002F', '/');
  //   print("Handshake Success! Crumb: $cleanCrumb");

  //   return YFinance(headers, cleanCrumb);
  // }

  // static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
  //   // Define it once
  //   final Map<String, String> headers = {
  //     'User-Agent': 'Mozilla/5.0...',
  //     'Accept': '*/*',
  //   };

  //   // The 'headers' object MUST be passed here
  //   await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

  //   // LOG: Verify the map changed locally
  //   print(
  //       "After fc.yahoo.com, headers contains cookie: ${headers.containsKey('cookie')}");
  //   print("Headers: $headers");

  //   // Now the second call uses the SAME 'headers' object
  //   await urlFetcher.fetch(
  //       'https://consent.yahoo.com/v2/collectConsent?sessionId=3_cc-pa_cp-all_0-0',
  //       headers: headers);
  //   // 2. HIT THE CONSENT DOMAIN
  //   // This "activates" the cookie for the finance subdomains.
  //   // We use a common consent collector URL used by Yahoo.
  //   await urlFetcher.fetch(
  //       'https://consent.yahoo.com/v2/collectConsent?sessionId=3_cc-pa_cp-all_0-0',
  //       headers: headers);

  //   // 3. Fetch the AAPL page again
  //   final html = await urlFetcher.fetch('https://finance.yahoo.com/quote/AAPL',
  //       headers: headers);

  //   // 4. NEW REGEX based on your snippets
  //   // We'll look for the 'jsapicrumb' or 'uh-crumb' inputs found in your logs
  //   final RegExp inputCrumb = RegExp(r'name="[a-z-]*crumb"\s+value="([^"]+)"');

  //   // Also keep the old one as fallback
  //   final RegExp jsonCrumb = RegExp(r'"crumb":"(.*?)"');

  //   final match = inputCrumb.firstMatch(html) ?? jsonCrumb.firstMatch(html);
  //   final crumb = match?.group(1);

  //   if (crumb == null || crumb.isEmpty) {
  //     // Final fallback: check for the "window.App.main" pattern
  //     final RegExp appMainCrumb = RegExp(r'\\"crumb\\":\\"(.*?)\\"');
  //     final match3 = appMainCrumb.firstMatch(html);
  //     final finalCrumb = match3?.group(1);

  //     if (finalCrumb == null)
  //       throw StateError(
  //           "Handshake failed: Crumb not found in any expected location.");
  //     return YFinance(headers, finalCrumb.replaceAll(r'\u002F', '/'));
  //   }

  //   return YFinance(headers, crumb.replaceAll(r'\u002F', '/'));
  // }

  // static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
  //   final Map<String, String> headers = {
  //     'User-Agent':
  //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  //     'Accept': '*/*',
  //   };

  //   // 1. Get the initial cookie
  //   await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

  //   // 2. Add the consent flags just to be safe
  //   if (headers.containsKey('cookie')) {
  //     headers['cookie'] = headers['cookie']! +
  //         "; GUC=AQEBAQ; CONSENT=YES+cb.20230531-04-p0.en+FX+999";
  //   }

  //   // 3. Fetch the AAPL page (This returned 200 in your last log!)
  //   final String html = await urlFetcher
  //       .fetch('https://finance.yahoo.com/quote/AAPL', headers: headers);

  //   print(html);

  //   // 4. Extract the crumb from the HTML using several potential patterns
  //   // Pattern A: The standard JSON key
  //   // Pattern B: The escaped JSON key (seen in your previous logs)
  //   final RegExp patternA = RegExp(r'"crumb":"(.*?)"');
  //   final RegExp patternB = RegExp(r'\\"crumb\\":\\"(.*?)\\"');

  //   final match = patternA.firstMatch(html) ?? patternB.firstMatch(html);
  //   String? crumb = match?.group(1);

  //   print("Crumb: $crumb");
  //   if (crumb == null || crumb.isEmpty) {
  //     // Debugging: If it fails, let's see if we even got the right page
  //     if (html.contains("Guillotine"))
  //       print("Stuck on Yahoo's redirector page.");
  //     if (html.contains("consent.yahoo.com")) print("Stuck on Consent page.");

  //     print("Unknown issue");
  //     throw StateError("Cookie accepted, but crumb not found in HTML source.");
  //   }

  //   // Clean up any double-escaped characters
  //   final cleanCrumb = crumb.replaceAll(r'\u002F', '/').replaceAll(r'\\', '');

  //   print("Handshake Success via Scraping! Crumb: $cleanCrumb");

  //   return YFinance(headers, cleanCrumb);
  // }

  // static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
  //   final Map<String, String> headers = {
  //     'User-Agent':
  //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...',
  //     'Accept':
  //         'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  //     'Accept-Language': 'en-US,en;q=0.5',
  //   };

  //   // 1. Get the "Guillotine" cookie (The basic tracker)
  //   await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

  //   // 2. Hit the ROOT finance page to "initialize" the session
  //   // This often triggers redirects that "upgrade" the cookie
  //   await urlFetcher.fetch('https://finance.yahoo.com/', headers: headers);

  //   // 3. NOW try the getcrumb API
  //   final crumb = await urlFetcher.fetch(
  //       'https://query2.finance.yahoo.com/v1/test/getcrumb',
  //       headers: headers);

  //   print("Handshake Success! Headers: $headers, Crumb: $crumb");
  //   return YFinance(headers, crumb);
  // }

  static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
    final Map<String, String> headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };

    print("Handshake: Phase 1 - Getting Initial Cookie");
    // Use fc.yahoo.com - it's much faster than the full home page
    await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

    print("Handshake: Phase 2 - Requesting Crumb");
    final crumb = await urlFetcher.fetch(
        'https://query2.finance.yahoo.com/v1/test/getcrumb',
        headers: headers);

    // If crumb looks like HTML, the session failed
    if (crumb.contains('<html')) {
      throw Exception("Crumb request returned HTML (Session Rejected)");
    }

    print("Handshake Success! Crumb: $crumb");
    return YFinance(headers, crumb);
  }
}
