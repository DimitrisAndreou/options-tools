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

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<Market>> deribitMarkets() async {
  return await Deribit.fetchMarkets([Deribit.BTC, Deribit.ETH], _urlFetcher,
      errorListener: (instr, error) {
    /* If instruments are missing, add debugging code here */
  });
}

Future<String> deribitCoveredCalls(String ticker, double slippage) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .where((cc) => cc.breakeven != null)
      .toList());
}

Future<String> deribitVerticalSpreads(String ticker, double slippage) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(VerticalSpread.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> deribitSyntheticBonds(String ticker, double slippage) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(SyntheticBond.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> yfinanceCoveredCalls(String ticker, double slippage) async {
  List<Market> markets = await (await YFinance.openConnection(_urlFetcher))
      .fetchMarket(ticker, _urlFetcher);
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .where((cc) => cc.breakeven != null)
      .toList());
}

void setupJsInterop() {
  deribitCoveredCallsDart = (JSString ticker, JSNumber slippage) {
    return deribitCoveredCalls(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  deribitVerticalSpreadsDart = (JSString ticker, JSNumber slippage) {
    return deribitVerticalSpreads(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  deribitSyntheticBondsDart = (JSString ticker, JSNumber slippage) {
    return deribitSyntheticBonds(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  yfinanceCoveredCallsDart = (JSString ticker, JSNumber slippage) {
    return yfinanceCoveredCalls(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
}
