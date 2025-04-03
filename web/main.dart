import 'package:web/web.dart' as web;

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
external set analyzeMarket(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<Market>> deribitMarkets() async {
  return await Deribit.fetchMarkets(
      [DeribitCoin.BTC, DeribitCoin.ETH], _urlFetcher);
}

Future<String> analyzeMarketDart(String ticker) async {
  List<Market> markets = await deribitMarkets();
  Iterable<CoveredCall> ccs = CoveredCall.generateAll(MarketsNavigator(markets),
          underlying: Commodity("BTC"), money: Commodity("USD"))
      .take(30)
      .toList();
  for (final cc in ccs) {
    print("maxValue: ${cc.analyzer.maxValue}");
    print(jsonEncode(cc));
  }
  return jsonEncode(ccs);
}

void main() {
  final now = DateTime.now();
  final element = web.document.querySelector('#output') as web.HTMLDivElement;
  element.text = 'The time is ${now.hour}:${now.minute} '
      'and your Dart web app is running!';
  analyzeMarket = (JSString ticker) {
    return analyzeMarketDart(ticker.toDart).then((value) => value.toJS).toJS;
  }.toJS;

  jsMain();
}
