import 'package:web/web.dart' as web;

import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop';

import 'deribit.dart';
import 'geometric_covered_calls.dart';

@JS()
// Defined in main.js
external void jsMain();

String processTickerData(JSString jsonFeed) {
  // fetch option chain for ticker
  // produce all data
// DeribitResponse -> List<GeometricCoveredCalls> --> JSON
// DeribitResponse -> List<Spread> --> JSON (over, under, touch bets, dont touch bets)
  final json = jsonFeed.toDart;
  final response = DeribitResponse.createFromJson(json);
  final contracts = response.contracts;

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

  js.context['processTickerData'] = js.allowInterop(processTickerData);

  jsMain();
}
