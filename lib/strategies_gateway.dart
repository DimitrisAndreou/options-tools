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
external set yfinanceVerticalSpreadsDart(JSFunction value);

@JS()
external set deribitTouchBetsDart(JSFunction value);

@JS()
external set yfinanceTouchBetsDart(JSFunction value);

@JS()
external set yfinanceCoveredCallsDart(JSFunction value);

@JS()
external set deribitLongOptionsDart(JSFunction value);

@JS()
external set yfinanceLongOptionsDart(JSFunction value);

UrlFetcher _urlFetcher = UrlFetcher(Duration(minutes: 5));

Future<List<Market>> deribitMarkets(
    String ticker, int minDTE, int maxDTE) async {
  return await DataSource.deribit
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
}

Future<String> deribitCoveredCalls(
    String ticker, double slippage, int minDTE, int maxDTE,
    {double? avgPrice,
    double underlyingTaxRate = 0.0,
    double derivativeTaxRate = 0.0,
    int size = 1}) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker, source: DataSource.deribit),
          money: Commodity("USD"),
          slippage: slippage,
          avgPrice: avgPrice,
          size: size,
          taxes: TaxProfile(
            underlyingTaxRate: underlyingTaxRate,
            derivativeTaxRate: derivativeTaxRate,
          ))
      .toList());
}

Future<String> deribitLongOptions(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  final underlying = Commodity(ticker, source: DataSource.deribit);
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
          underlying: Commodity(ticker, source: DataSource.deribit),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> deribitTouchBets(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await deribitMarkets(ticker, minDTE, maxDTE);
  return jsonEncode(TouchBet.generateAll(markets,
          underlying: Commodity(ticker, source: DataSource.deribit),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> yfinanceCoveredCalls(
    String ticker, double slippage, int minDTE, int maxDTE,
    {double? avgPrice,
    double underlyingTaxRate = 0.0,
    double derivativeTaxRate = 0.0,
    int size = 1}) async {
  List<Market> markets = await DataSource.yfinance
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
  return jsonEncode(CoveredCall.generateAll(markets,
          underlying: Commodity(ticker, source: DataSource.yfinance),
          money: Commodity("USD"),
          slippage: slippage,
          avgPrice: avgPrice,
          size: size,
          taxes: TaxProfile(
            underlyingTaxRate: underlyingTaxRate,
            derivativeTaxRate: derivativeTaxRate,
          ))
      .toList());
}

Future<String> yfinanceLongOptions(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await DataSource.yfinance
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
  final underlying = Commodity(ticker, source: DataSource.yfinance);
  final money = Commodity("USD");
  final calls = LongCall.generateAll(markets,
          underlying: underlying, money: money, slippage: slippage)
      .map((e) => e.toJson());
  final puts = LongPut.generateAll(markets,
          underlying: underlying, money: money, slippage: slippage)
      .map((e) => e.toJson());
  return jsonEncode([...calls, ...puts]);
}

Future<String> yfinanceVerticalSpreads(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await DataSource.yfinance
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
  return jsonEncode(VerticalSpread.generateAll(markets,
          underlying: Commodity(ticker, source: DataSource.yfinance),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

Future<String> yfinanceTouchBets(
    String ticker, double slippage, int minDTE, int maxDTE) async {
  List<Market> markets = await DataSource.yfinance
      .fetchMarkets(ticker, _urlFetcher, minDTE: minDTE, maxDTE: maxDTE);
  return jsonEncode(TouchBet.generateAll(markets,
          underlying: Commodity(ticker, source: DataSource.yfinance),
          money: Commodity("USD"),
          slippage: slippage)
      .toList());
}

@JS('Error')
external JSObject _newJsError(JSString message);

JSPromise<JSString> _toJsPromise(Future<String> future) {
  return JSPromise<JSString>(
    (JSFunction resolve, JSFunction reject) {
      future.then(
        (value) {
          resolve.callAsFunction(null, value.toJS);
        },
        onError: (Object error, StackTrace stackTrace) {
          print("Dart error: $error\n$stackTrace");
          String msg = error.toString();
          if (error is JsonUnsupportedObjectError && error.cause != null) {
            msg = "$msg (cause: ${error.cause})";
          }
          reject.callAsFunction(null, _newJsError(msg.toJS));
        },
      );
    }.toJS,
  );
}

void setupJsInterop() {
  deribitCoveredCallsDart = (JSString ticker, JSNumber slippage,
      JSNumber minDTE, JSNumber maxDTE,
      [JSNumber? avgPrice,
      JSNumber? underlyingTaxRate,
      JSNumber? derivativeTaxRate,
      JSNumber? size]) {
    return _toJsPromise(deribitCoveredCalls(
      ticker.toDart,
      slippage.toDartDouble,
      minDTE.toDartInt,
      maxDTE.toDartInt,
      avgPrice: avgPrice?.toDartDouble,
      underlyingTaxRate: underlyingTaxRate?.toDartDouble ?? 0.0,
      derivativeTaxRate: derivativeTaxRate?.toDartDouble ?? 0.0,
      size: size?.toDartInt ?? 1,
    ));
  }.toJS;
  deribitVerticalSpreadsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return _toJsPromise(deribitVerticalSpreads(ticker.toDart,
        slippage.toDartDouble, minDTE.toDartInt, maxDTE.toDartInt));
  }.toJS;
  yfinanceVerticalSpreadsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return _toJsPromise(yfinanceVerticalSpreads(ticker.toDart,
        slippage.toDartDouble, minDTE.toDartInt, maxDTE.toDartInt));
  }.toJS;
  deribitTouchBetsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return _toJsPromise(deribitTouchBets(ticker.toDart, slippage.toDartDouble,
        minDTE.toDartInt, maxDTE.toDartInt));
  }.toJS;
  yfinanceTouchBetsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return _toJsPromise(yfinanceTouchBets(ticker.toDart, slippage.toDartDouble,
        minDTE.toDartInt, maxDTE.toDartInt));
  }.toJS;
  yfinanceCoveredCallsDart = (JSString ticker, JSNumber slippage,
      JSNumber minDTE, JSNumber maxDTE,
      [JSNumber? avgPrice,
      JSNumber? underlyingTaxRate,
      JSNumber? derivativeTaxRate,
      JSNumber? size]) {
    return _toJsPromise(yfinanceCoveredCalls(
      ticker.toDart,
      slippage.toDartDouble,
      minDTE.toDartInt,
      maxDTE.toDartInt,
      avgPrice: avgPrice?.toDartDouble,
      underlyingTaxRate: underlyingTaxRate?.toDartDouble ?? 0.0,
      derivativeTaxRate: derivativeTaxRate?.toDartDouble ?? 0.0,
      size: size?.toDartInt ?? 1,
    ));
  }.toJS;

  deribitLongOptionsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return _toJsPromise(deribitLongOptions(ticker.toDart, slippage.toDartDouble,
        minDTE.toDartInt, maxDTE.toDartInt));
  }.toJS;

  yfinanceLongOptionsDart =
      (JSString ticker, JSNumber slippage, JSNumber minDTE, JSNumber maxDTE) {
    return _toJsPromise(yfinanceLongOptions(ticker.toDart,
        slippage.toDartDouble, minDTE.toDartInt, maxDTE.toDartInt));
  }.toJS;
}
