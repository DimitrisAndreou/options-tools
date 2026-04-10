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
    print("Fetching $ticker ...");
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
      // Not using quote["bid"] and quote["ask"] because they tend
      // to be very wide.
      spotMarket = Market.create(
          asset: underlying, // AAPL
          money: money, // USD
          bidPrice: quote["regularMarketPrice"]!,
          askPrice: quote["regularMarketPrice"]!);
      print("Quote: $quote");
      final isMarketOpen = quote["marketState"] == "REGULAR";

      final optionChain = (results["options"] as List?)?.firstOrNull;
      if (firstOptionChain) {
        print("First option chain: $optionChain");
        // Also remember to fetch the rest expirations.
        firstOptionChain = false;
        final expirations = results["expirationDates"].cast<int>().toSet();
        // Not the one we happen to get in the first, dateless request.
        expirations.remove(optionChain["expirationDate"]);
        for (int expiration in expirations) {
          urlsToFetch.add(
              '$_baseUrl/v7/finance/options/$ticker?crumb=$_crumb&date=$expiration');
        }
      }

      for (final (optionType, isCall) in [("calls", true), ("puts", false)]) {
        final options = optionChain[optionType] ??
            (throw StateError("Did not find $optionType"));
        for (final option in options) {
          final lastPrice = option["lastPrice"] ?? 0.0;
          double bid = isMarketOpen ? (option["bid"] ?? 0.0) : lastPrice;
          double ask = isMarketOpen ? (option["ask"] ?? 0.0) : lastPrice;
          if (bid > ask) {
            (bid, ask) = (ask, bid);
          }
          if (bid == 0.0 || ask == 0.0) {
            print("Skipping option due to bad bid/ask: $option");
            continue;
          }
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
              bidPrice: bid * 100.0,
              askPrice: ask * 100.0);
          markets.add(optionMarket);
        }
      }
    }
    markets.add(spotMarket!);
    return markets;
  }

  static Future<YFinance> openConnection(UrlFetcher urlFetcher) async {
    final Map<String, String> headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };

    // Handshake: Phase 1 - Getting Initial Cookie
    // Use fc.yahoo.com - it's much faster than the full home page
    await urlFetcher.fetch('https://fc.yahoo.com', headers: headers);

    // Handshake: Phase 2 - Requesting Crumb
    final crumb = await urlFetcher.fetch(
        'https://query2.finance.yahoo.com/v1/test/getcrumb',
        headers: headers);

    // If crumb looks like HTML, the session failed
    if (crumb.contains('<html')) {
      throw Exception("Crumb request returned HTML (Session Rejected)");
    }

    // Success! Got crumb (cookie).
    return YFinance(headers, crumb);
  }
}
