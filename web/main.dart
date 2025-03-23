import 'package:web/web.dart' as web;

import 'dart:convert';
import 'dart:js_interop';

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

Future<String> analyzeMarketDart(String ticker) async {
  List<Market> markets = await Deribit.fetchMarkets(
      [DeribitCoin.BTC, DeribitCoin.ETH], _urlFetcher);

  // DeribitResponse -> List<GeometricCoveredCalls> --> JSON
  // DeribitResponse -> List<Spread> --> JSON (over, under, touch bets, dont touch bets)

  // TODOs:
  // reimplement GCCs
  // BTC -> touch bets, etc
  // Maybe not as a big fat json, but via a wider API

  final contracts = parsed.contracts;

  final gccs = contracts
      .where((contract) => contract.isCall())
      .map((contract) => GeometricCoveredCall(contract, 1.0))
      .toList();

  return jsonEncode(gccs);
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
