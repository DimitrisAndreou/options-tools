import 'dart:convert';
import 'dart:js_interop';

import 'package:options_tools/assets.dart';
import 'package:options_tools/data/deribit.dart';
import 'package:options_tools/data/yfinance.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/strategies.dart';
import 'package:options_tools/data/url_fetcher.dart';

@JS()
external set deribitCoveredCallsDart(JSFunction value);

@JS()
external set deribitVerticalSpreadsDart(JSFunction value);

@JS()
external set deribitSyntheticBondsDart(JSFunction value);

@JS()
external set yfinanceCoveredCallsDart(JSFunction value);

@JS()
external set deribitLongOptionsDart(JSFunction value);

@JS()
external set yfinanceLongOptionsDart(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<Market>> deribitMarkets(
    String ticker, int minDTE, int maxDTE) async {
  final tickerToFetch = switch (ticker) {
    'BTC' || 'ETH' => ticker,
    'SOL' || 'AVAX' || 'XRP' || 'TRX' => 'USDC',
    _ => throw 'Unknown ticker: $ticker',
  };
  return await Deribit.fetchMarkets([tickerToFetch], _urlFetcher,
      errorListener: (instr, error) {}, minDTE: minDTE, maxDTE: maxDTE);
}

Future<String> deribitCoveredCalls(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker, venues: const {Venue.Deribit}),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> deribitLongOptions(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  final underlying = Commodity(ticker, venues: const {Venue.Deribit});
  final money = Commodity("USD");
  final calls = LongCall.generateAll(markets,
          underlying: underlying, money: money, slippage: slippage)
      .map((e) => e.toJson());
  final puts = LongPut.generateAll(markets,
          underlying: underlying, money: money, slippage: slippage)
      .map((e) => e.toJson());
  return jsonEncode([...calls, ...puts]);
}

Future<String> deribitVerticalSpreads(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  return jsonEncode(VerticalSpread.generateAll(markets,
          underlying: Commodity(ticker, venues: const {Venue.Deribit}),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> deribitSyntheticBonds(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  return jsonEncode(SyntheticBond.generateAll(markets,
          underlying: Commodity(ticker, venues: const {Venue.Deribit}),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> yfinanceCoveredCalls(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await (await YFinance.openConnection(_urlFetcher))
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker, venues: const {Venue.OptionStrat}),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> yfinanceLongOptions(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await (await YFinance.openConnection(_urlFetcher))
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
  final underlying = Commodity(ticker, venues: const {Venue.OptionStrat});
  final money = Commodity("USD");
  final calls = LongCall.generateAll(markets,
          underlying: underlying, money: money, slippage: slippage)
      .map((e) => e.toJson());
  final puts = LongPut.generateAll(markets,
          underlying: underlying, money: money, slippage: slippage)
      .map((e) => e.toJson());
  return jsonEncode([...calls, ...puts]);
}

void setupJsInterop() {
  deribitCoveredCallsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return deribitCoveredCalls(ticker.toDart, slippage.toDartDouble,
            minDTE.toDartInt, maxDTE.toDartInt)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  deribitVerticalSpreadsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return deribitVerticalSpreads(ticker.toDart, slippage.toDartDouble,
            minDTE.toDartInt, maxDTE.toDartInt)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  deribitSyntheticBondsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return deribitSyntheticBonds(ticker.toDart, slippage.toDartDouble,
            minDTE.toDartInt, maxDTE.toDartInt)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  yfinanceCoveredCallsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return yfinanceCoveredCalls(ticker.toDart, slippage.toDartDouble,
            minDTE.toDartInt, maxDTE.toDartInt)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  deribitLongOptionsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return deribitLongOptions(ticker.toDart, slippage.toDartDouble,
            minDTE.toDartInt, maxDTE.toDartInt)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  yfinanceLongOptionsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return yfinanceLongOptions(ticker.toDart, slippage.toDartDouble,
            minDTE.toDartInt, maxDTE.toDartInt)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
}
