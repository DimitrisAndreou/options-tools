import 'package:web/web.dart' as web;

import 'dart:convert';
// import 'dart:js' as js;
import 'dart:js_interop';

import 'deribit.dart';
import 'geometric_covered_calls.dart';
import 'url_fetcher.dart';

@JS()
// Defined in main.js
external void jsMain();

@JS()
external set processTickerData(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 15));

Future<String> processTickerDataInDart(String ticker) async {
  String json = await _urlFetcher.fetch(deribitUriForOptionChain(ticker));
  DeribitResponse parsed = DeribitResponse.createFromJson(json);
  // DeribitResponse -> List<GeometricCoveredCalls> --> JSON
  // DeribitResponse -> List<Spread> --> JSON (over, under, touch bets, dont touch bets)

  // analyzeMarket("BTC") --> returns big fat json
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
  print("Setting up processTickerData...");
  processTickerData = (JSString json) {
    print("Hello from processTickerData...");
    return processTickerDataInDart(json.toDart)
        .then((value) => value.toJS)
        .toJS;
  }.toJS;

  jsMain();
}
