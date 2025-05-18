// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'assets.dart';
import 'markets.dart';
import 'listed_instruments.dart';
import 'url_fetcher.dart';

enum DeribitCoin {
  BTC(Commodity("BTC")),
  ETH(Commodity("ETH")),
  USDC(Commodity("USDC")),
  // The rest aren't needed; all of them can be fetched via USDC.
  // Note that "USD" itself is not supported.
  USDT(Commodity("USDT")),
  BNB(Commodity("BNB")),
  PAXG(Commodity("PAXG")),
  SOL(Commodity("SOL")),
  XRP(Commodity("XRP"));

  final Commodity commodity;
  const DeribitCoin(this.commodity);

  // Reminder: DeribitCoin.values.byName("BTC")
}

class Deribit {
  Deribit._();

  static Future<List<Market>> fetchMarkets(
      List<DeribitCoin> coins, UrlFetcher urlFetcher,
      {void Function(ListedInstrument instr, String)? errorListener}) async {
    final coinToResponse = {};
    for (final coin in coins) {
      // Hit Deribit sequentially; maybe less likely to get throttled.
      final coinInstrumentsJson = await urlFetcher.fetch(
          'https://www.deribit.com/api/v2/public/get_book_summary_by_currency'
          '?currency=${coin.name}');
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
        .map((instrument) => instrument.toMarket(errorListener: errorListener))
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

  static double getOptionSize(Commodity underlying) {
    if (underlying.name == DeribitCoin.BTC.name) {
      return 0.1;
    }
    return 1.0;
  }
}

extension ListedInstrumentDeribitUtils on ListedInstrument {
  Market? toMarket(
      {void Function(ListedInstrument instr, String)? errorListener}) {
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
      // A custom strategy or a perpetual; ignore.
      errorsSink(this, "Ignoring strat: $instrument_name");
      return null;
    }
    final String? dates = match.group(3);
    if (dates == null) {
      // Spot market.
      return makeMarket(underlying);
    }
    final String assetNames = match.group(1)!;
    final assetsList = assetNames.split('_');
    if (assetsList.length != 1) {
      errorsSink(this, "Multiple assets: $assetsList");
      return null;
    }
    final datesList = dates.split('_');
    if (datesList.length != 1) {
      errorsSink(this, "Multiple dates: $datesList");
      return null;
    }
    final expirationDate = _parseDate(datesList.first);

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
          contractLot: 1.0));
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
        contractLot: 1.0));
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
