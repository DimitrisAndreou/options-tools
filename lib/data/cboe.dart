import 'dart:convert';

import '../assets.dart';
import '../markets.dart';
import 'url_fetcher.dart';

class Cboe {
  Cboe._();

  static const String _baseUrl =
      'https://cdn.cboe.com/api/global/delayed_quotes/options';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://www.cboe.com/',
  };

  static final RegExp _occRegex =
      RegExp(r'^([A-Z0-9._-]+?)(\d{6})([CP])(\d{8})$');

  static final RegExp _leadingPunctRegex = RegExp(r'^[\^._$/]+');
  static final RegExp _trailingDigitRegex = RegExp(r'\d$');

  static String normalizeTicker(String ticker) =>
      ticker.trim().toUpperCase().replaceFirst(_leadingPunctRegex, '');

  static ({String root, DateTime expiration, bool isCall, double strike})?
      parseOcc(String? symbol) {
    final cleaned = (symbol ?? '').trim().toUpperCase().replaceAll(' ', '');
    final match = _occRegex.firstMatch(cleaned);
    if (match == null) return null;

    final root = match.group(1)!;
    final yymmdd = match.group(2)!;
    final cp = match.group(3)!;
    final strikeDigits = match.group(4)!;

    final year = 2000 + int.parse(yymmdd.substring(0, 2));
    final month = int.parse(yymmdd.substring(2, 4));
    final day = int.parse(yymmdd.substring(4, 6));
    final expiration = DateTime.utc(year, month, day);
    final strike = int.parse(strikeDigits) / 1000.0;

    return (
      root: root,
      expiration: expiration,
      isCall: cp == 'C',
      strike: strike,
    );
  }

  static Future<List<Market>> fetchMarkets(
    String ticker,
    UrlFetcher urlFetcher, {
    int? minDTE,
    int? maxDTE,
  }) async {
    final raw = ticker.trim().toUpperCase();
    final clean = raw.replaceFirst(_leadingPunctRegex, '');
    final candidates = <String>[
      if (raw.startsWith('^') || raw.startsWith('_')) ...[
        '_$clean',
        clean,
      ] else ...[
        clean,
        '_$clean',
      ],
      if (clean.contains('.')) clean.replaceAll('.', ''),
    ];

    for (final candidate in candidates) {
      final url = '$_baseUrl/$candidate.json';
      String rawJson;
      try {
        rawJson = await urlFetcher.fetch(url, headers: _headers);
      } catch (e) {
        if (e.toString().contains('404')) {
          continue;
        }
        rethrow;
      }

      return parseMarketsFromJson(
        rawJson,
        ticker: clean,
        minDTE: minDTE,
        maxDTE: maxDTE,
      );
    }

    throw StateError('CBOE 404 for $ticker (tried $candidates)');
  }

  static List<Market> parseMarketsFromJson(
    String rawJson, {
    required String ticker,
    int? minDTE,
    int? maxDTE,
    DateTime? now,
  }) {
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};

    final spot = _firstPositive([
      data['current_price'],
      data['close'],
      data['prev_day_close'],
    ]);
    if (spot == null) {
      throw StateError('Did not find spot price for $ticker in CBOE response');
    }

    final clean = ticker.trim().toUpperCase().replaceFirst(_leadingPunctRegex, '');
    final money = Commodity('USD');
    final underlying = Commodity(clean, source: DataSource.cboe);
    final referenceNow = now ?? DateTime.now();

    final markets = <Market>[];
    final options = (data['options'] as List?) ?? const [];
    for (final rawItem in options) {
      if (rawItem is! Map<String, dynamic>) continue;

      final symbol = rawItem['option'] as String?;
      final parsed = parseOcc(symbol);
      if (parsed == null) continue;

      // Skip adjusted non-standard OCC deliverables (e.g. BITO1...),
      // while keeping standard weeklies/mini-root letters (e.g. SPXW).
      if (parsed.root != clean && _trailingDigitRegex.hasMatch(parsed.root)) {
        continue;
      }

      final dte = parsed.expiration.difference(referenceNow).inDays;
      if (minDTE != null && dte < minDTE) continue;
      if (maxDTE != null && dte > maxDTE) continue;

      final bidSize = (rawItem['bid_size'] as num?)?.toInt();
      var bid = (bidSize == 0)
          ? 0.0
          : ((rawItem['bid'] as num?)?.toDouble() ?? 0.0);
      var ask = (rawItem['ask'] as num?)?.toDouble() ?? 0.0;

      if (bid > ask) {
        (bid, ask) = (ask, bid);
      }
      if (bid <= 0.0 || ask <= 0.0) {
        continue;
      }

      const contractLot = 100.0;
      markets.add(Market.create(
        asset: Option(
          symbol!.trim(),
          underlying: underlying,
          money: money,
          strike: parsed.strike,
          isPut: !parsed.isCall,
          isCall: parsed.isCall,
          expiration: parsed.expiration,
          contractLot: contractLot,
          source: DataSource.cboe,
        ),
        money: money,
        bidPrice: bid * contractLot,
        askPrice: ask * contractLot,
      ));
    }

    markets.add(Market.create(
      asset: underlying,
      money: money,
      bidPrice: spot,
      askPrice: spot,
    ));

    return markets;
  }

  static double? _firstPositive(List<Object?> values) {
    for (final value in values) {
      if (value is num) {
        final d = value.toDouble();
        if (d > 0.0) return d;
      }
    }
    return null;
  }
}
