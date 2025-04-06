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
external set coveredCallsDart(JSFunction value);

@JS()
external set syntheticBondsDart(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<Market>> deribitMarkets() async {
  return await Deribit.fetchMarkets(
      [DeribitCoin.BTC, DeribitCoin.ETH], _urlFetcher);
}

Future<String> coveredCalls(String ticker) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(CoveredCall.generateAll(MarketsNavigator(markets),
          underlying: Commodity(ticker), money: Commodity("USD"))
      .toList());
}

Future<String> syntheticBonds(String ticker) async {
  List<Market> markets = await deribitMarkets();
  return jsonEncode(SyntheticBond.generateAll(MarketsNavigator(markets),
          underlying: Commodity(ticker), money: Commodity("USD"))
      .toList());
}

void main() {
  final now = DateTime.now();
  final element = web.document.querySelector('#output') as web.HTMLDivElement;
  element.text = 'The time is ${now.hour}:${now.minute} '
      'and your Dart web app is running!';
  coveredCallsDart = (JSString ticker) {
    return coveredCalls(ticker.toDart).then((value) => value.toJS).toJS;
  }.toJS;
  syntheticBondsDart = (JSString ticker) {
    return syntheticBonds(ticker.toDart).then((value) => value.toJS).toJS;
  }.toJS;

  jsMain();
}
