import 'dart:convert';
import 'dart:js_interop';

import 'package:options_tools/assets.dart';
import 'package:options_tools/deribit.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/strategies.dart';
import 'package:options_tools/url_fetcher.dart';

@JS()
// Defined in main.js
external void jsMain();

@JS()
external set coveredCallsDart(JSFunction value);

@JS()
external set verticalSpreadsDart(JSFunction value);

@JS()
external set syntheticBondsDart(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<Market>> deribitMarkets() async {
  return await Deribit.fetchMarkets(
      // TODO: add SOL, PAXG, XRP
      [DeribitCoin.BTC, DeribitCoin.ETH],
      _urlFetcher);
}

Future<String> coveredCalls(String ticker, double slippage) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .where((cc) => cc.breakeven != null)
      .toList());
}

Future<String> verticalSpreads(String ticker, double slippage) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(VerticalSpread.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> syntheticBonds(String ticker, double slippage) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(SyntheticBond.generateAll(markets,
          underlying: Commodity(ticker),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

void main() {
  // TODO:
  // Over/Under (Touch/NotTouch)
  // Probabilities distribution
  coveredCallsDart = (JSString ticker, JSNumber slippage) {
    return coveredCalls(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  verticalSpreadsDart = (JSString ticker, JSNumber slippage) {
    return verticalSpreads(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;
  syntheticBondsDart = (JSString ticker, JSNumber slippage) {
    return syntheticBonds(ticker.toDart, slippage.toDartDouble)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  jsMain();
}
