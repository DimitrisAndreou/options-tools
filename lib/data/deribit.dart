// ignore_for_file: constant_identifier_names

import 'dart:convert';
import '../assets.dart';
import '../markets.dart';
import 'url_fetcher.dart';

class Deribit {
  Deribit._();

  static final BTC = "BTC";
  static final ETH = "ETH";
  static final USDC = "USDC";
  // The rest aren't needed; all of them can be fetched via USDC.
  // Note that "USD" itself is not supported.
  static final USDT = "USDT";
  static final BNB = "BNB";
  static final PAXG = "PAXG";
  static final SOL = "SOL";
  static final XRP = "XRP";

  static Future<List<Market>> fetchMarkets(
      List<String> coins, UrlFetcher urlFetcher,
      {void Function(ListedInstrument instr, String error)? errorListener,
      int? minDTE,
      int? maxDTE}) async {
    final coinToResponse = {};
    for (final coin in coins) {
      // Hit Deribit sequentially; maybe less likely to get throttled.
      final coinInstrumentsJson = await urlFetcher.fetch(
          'https://www.deribit.com/api/v2/public/get_book_summary_by_currency'
          '?currency=$coin');
      coinToResponse[coin] = coinInstrumentsJson;
    }
    final Iterable<ListedInstrument> instruments =
        coinToResponse.values.expand((rawJson) {
      final data = json.decode(rawJson) as Map<String, dynamic>;
      final rawInstruments = (data["result"] as List<dynamic>);
      return rawInstruments
          .map((rawInstrument) => ListedInstrument.fromJson(rawInstrument))
          .where((instrument) => instrument != null)
          .cast<ListedInstrument>();
    });
    final mostRecents = {
      for (final instr in instruments) instr.instrument_name: instr
    };
    return mostRecents.values
        .followedBy(_implicitUsdInstruments(["USDC", "USDT"]))
        .map((instrument) => instrument.toMarket(
            errorListener: errorListener, minDTE: minDTE, maxDTE: maxDTE))
        .nonNulls
        .toList();
  }

  static Iterable<ListedInstrument> _implicitUsdInstruments(
      List<String> stableCoins) sync* {
    for (String stableCoin in stableCoins) {
      yield ListedInstrument(
          instrument_name: "${stableCoin}_USD",
          base_currency: stableCoin,
          quote_currency: "USD",
          mark_price: 1.0,
          bid_price: 1.0,
          ask_price: 1.0);
    }
  }
}

extension ListedInstrumentDeribitUtils on ListedInstrument {
  Market? toMarket(
      {void Function(ListedInstrument instr, String)? errorListener,
      int? minDTE,
      int? maxDTE}) {
    final errorsSink = errorListener ?? (instr, error) {};
    // TODO: produced assets might want a reference to this DeribitInstrument
    if (bid_price == null || ask_price == null) {
      errorsSink(this, "No bid or no ask");
      // TODO: can use markPrice +- defaultSlippage
      return null;
    }
    // Only the underlying & the money are registered in the registry.
    final underlying = Commodity(base_currency);
    final money = Commodity(quote_currency);
    makeMarket(Asset asset) => Market.create(
        asset: asset, money: money, bidPrice: bid_price!, askPrice: ask_price!);

    Match? match = _instrumentRegex.firstMatch(instrument_name);
    if (match == null) {
      errorsSink(this, "UNPROCESSED: $instrument_name");
      return null;
    }
    final String? strat = match.group(2);
    if (strat != null) {
      // A custom strategy or a perpetual ("PERPETUAL"); ignore.
      errorsSink(this, "Ignoring strat: $instrument_name ($strat)");
      return null;
    }
    final String? dates = match.group(3);
    if (dates == null) {
      // Spot market.
      return makeMarket(underlying);
    }
    final String assetNames = match.group(1)!;
    final assetsList = assetNames.split('_');
    if (assetsList.length > 2) {
      errorsSink(this, "Too many assets: $assetsList");
      return null;
    }
    final datesList = dates.split('_');
    if (datesList.length != 1) {
      errorsSink(this, "Multiple dates: $datesList");
      return null;
    }
    final expirationDate = _parseDate(datesList.first);
    final dte = expirationDate.difference(DateTime.now()).inDays;
    if (minDTE != null && dte < minDTE) return null;
    if (maxDTE != null && dte > maxDTE) return null;

    final String? strikes = match.group(4);
    final String? optionType = match.group(5);
    if (strikes == null) {
      // A dated future.
      if (optionType != null) {
        errorsSink(this, "A dated future with an option type?!");
        return null;
      }
      return makeMarket(DatedFuture(instrument_name,
          underlying: underlying,
          expiration: expirationDate,
          contractLot: 1.0,
          minSize: 0.0001));
    }
    final strikesList = strikes.split('_');
    if (strikesList.length != 1) {
      errorsSink(this, "An option with multiple strikes");
      return null;
    }
    final strike = double.parse(strikesList.first);

    if (optionType == null) {
      errorsSink(this, "An option without a type");
      return null;
    }
    final bool isPut = optionType == "P";
    final bool isCall = optionType == "C";
    return makeMarket(Option(instrument_name,
        underlying: underlying,
        // All deribit strikes refer to USD!
        money: Commodity("USD"),
        strike: strike,
        isPut: isPut,
        isCall: isCall,
        expiration: expirationDate,
        contractLot: 1.0,
        minSize: underlying.name == Deribit.BTC ? 0.1 : 1.0));
  }

  // BTC-22NOV24-85000-P
  static final RegExp _instrumentRegex =
      // ASSET[-STRAT][-DATES][-STRIKES][-P|C]
      RegExp(
          r"^([\w_]+)(?:-([\w_]+))??(?:-((?:\d+[A-Z]+\d+)|_)+)?(?:-([\d_]+))?(?:-(P|C))?$");

  // 29NOV2024
  static final RegExp _dateRegex = RegExp(r"^(\d+)(\w*?)(\d+)$");

  static final Map<String, int> _monthToNum = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  static DateTime _parseDate(String dateStr) {
    Match dateMatch = _dateRegex.firstMatch(dateStr)!;
    final dd = int.parse(dateMatch.group(1)!);
    final mmm = dateMatch.group(2)!;
    final yy = int.parse(dateMatch.group(3)!);
    return DateTime.utc(2000 + yy, _monthToNum[mmm]!, dd, /*hour: */ 9)
        .toLocal();
  }
}

class ListedInstrument {
  final String instrument_name;
  final String base_currency;
  final String quote_currency;
  final double mark_price;
  final double? estimated_delivery_price;
  final double? last;
  final double? low;
  final double? bid_price;
  final double? mid_price;
  final double? ask_price;
  final double? high;
  final String? underlying_index;
  final double? underlying_price;
  final double? price_change;

  ListedInstrument(
      {required this.instrument_name,
      required this.base_currency,
      required this.quote_currency,
      required this.mark_price,
      this.estimated_delivery_price,
      this.last,
      this.low,
      this.bid_price,
      this.mid_price,
      this.ask_price,
      this.high,
      this.underlying_index,
      this.underlying_price,
      this.price_change});

  static ListedInstrument? fromJson(Map<String, dynamic> data) =>
      ListedInstrument(
          instrument_name: data['instrument_name'] as String,
          base_currency: data['base_currency'] as String,
          quote_currency: data['quote_currency'] as String,
          mark_price: data['mark_price'] as double,
          estimated_delivery_price: data['estimated_delivery_price'] as double?,
          last: data['last'] as double?,
          low: data['low'] as double?,
          bid_price: data['bid_price'] as double?,
          mid_price: data['mid_price'] as double?,
          ask_price: data['ask_price'] as double?,
          high: data['high'] as double?,
          underlying_index: data['underlying_index'] as String?,
          underlying_price: data['underlying_price'] as double?,
          price_change: data['price_change'] as double?);

  @override
  String toString() => 'instrument_name: $instrument_name,'
      'base_currency: $base_currency,'
      'quote_currency: $quote_currency,'
      'mark_price: $mark_price,'
      'estimated_delivery_price: $estimated_delivery_price,'
      'last: $last,'
      'low: $low,'
      'bid_price: $bid_price,'
      'mid_price: $mid_price,'
      'ask_price: $ask_price,'
      'high: $high,'
      'underlying_index: $underlying_index,'
      'underlying_price: $underlying_price,'
      'price_change: $price_change,';
}
