import 'dart:math';

import 'assets.dart';
import 'deribit.dart';
import 'markets.dart';
import 'oracle.dart';
import 'position_analyzer.dart';
import 'url_fetcher.dart';
import 'strategies.dart';

String percentify(double x, {int decimals = 1}) =>
    "${(100.0 * x).toStringAsFixed(decimals)}%";
String dollarify(double x) => "\$${x.toStringAsFixed(0)}";

void main() async {
  List<Market> markets = await Deribit.fetchMarkets(
      [DeribitCoin.BTC, DeribitCoin.ETH], UrlFetcher(Duration(minutes: 15)));

  browseVerticalSpreads(markets);
  // browseBonds(markets);
  // browseCoveredCalls(markets);
  // printGeometricCoveredCalls(markets);

  // printOptionChain(markets);

//   Iterable<Market> calls = markets
//       .whereUnderlyingIs(DeribitCoin.BTC.commodity)
//       .calls
//       .sortByStrike(Order.asc)
//       .sortByExpiration(Order.asc);
//   for (final call in calls.take(10)) {
//     print(
//         "Asset: [${call.asset}], sell price: ${call.sellPrice()} of ${call.money}");
//     // Do it in dollars? Underlying?
//   }
}

void browseVerticalSpreads(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== Vertical Spreads ==============");
  for (VerticalSpread vs in VerticalSpread.generateAll(markets,
          underlying: underlying, money: money)
      .take(20)) {
    print(" ## ${vs.toJson()}\n");

    /*
    Debit:
     {underlying: BTC, money: USD, moneySize: -851.9084999999995, spotPrice: 94656.5,
     shortLeg: BTC-6MAY25-96000-P, shortLegSize: -1.0, longLeg: BTC-6MAY25-97000-P,
     longLegSize: 1.0, DTE: 1, breakEven: 96148.0915, breakEvenAsChange: 1.015757940553475,
     maxYield: 0.17383498345186194, maxYieldAt: 96000.0, maxYieldAtChange: 1.0141934257024081,
     maxLossAt: 97000.0, maxLossAtChange: 1.024757940553475, yieldIfPriceUnchanged:
     0.17383498345186194, equivalentHodlerSellPrice: 111111.11111111117}
    
    Credit:
     {underlying: BTC, money: USD, moneySize: 283.9694999999999, spotPrice: 94656.5,
     shortLeg: BTC-6MAY25-95000-P, shortLegSize: -1.0, longLeg: BTC-6MAY25-94500-P,
     longLegSize: 1.0, DTE: 1, breakEven: 94716.0305, breakEvenAsChange: 1.0006289108513413,
     maxYield: 1.3144880005369604, maxYieldAt: 95000.0, maxYieldAtChange: 1.0036289108513414,
     maxLossAt: 94500.0, maxLossAtChange: 0.9983466534258081,
     yieldIfPriceUnchanged: -0.27556525583193137, equivalentHodlerSellPrice: 219081.3334228268}
     */
    // TODO: print minValue(At), maxValue(At)
    // print("${vs.shortLeg} && ${vs.longLeg}:: credit/debit: ${vs.moneyLeg}, "
    //     "maxLossAt: ${vs.maxLossAt}, maxYield (${vs.maxYield}) at ${vs.maxYieldAt}");
  }
}

void browseBonds(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");
  print(" ============== BONDS ==============");
  for (SyntheticBond bond in SyntheticBond.generateAll(markets,
      underlying: underlying, money: money)) {
    print("Bond: ${bond.toJson()}");
  }
}

void browseCoveredCalls(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== CC ==============");
  for (CoveredCall cc in CoveredCall.generateAll(markets,
      underlying: underlying, money: money)) {
    print(cc.toJson());
    print("  MinValue (Risk): ${cc.analyzer.minValue.first.value}");
    print("  MaxValue (Profit): ${cc.analyzer.maxValue.first.value}");
  }
}

void printOptionChain(List<Market> markets) {
  for (final MapEntry<DateTime,
          Map<double, ({Market? call, Market? put})>> expirationToStrike
      in markets
          .whereUnderlyingIs(Commodity("BTC"))
          .options
          .sortByExpiration(Order.desc)
          .groupByExpiration()
          .mapValues((ms) => ms.groupByStrike(Order.desc).mapValues(
              (ms) => (call: ms.calls.singleOrNull, put: ms.puts.singleOrNull)))
          .entries) {
    print("Date: ${expirationToStrike.key}");
    for (final strikeToOptions in expirationToStrike.value.entries) {
      final options = strikeToOptions.value;
      print(
          "  Strike: ${strikeToOptions.key} Call: ${options.call},  put: ${options.put}");
    }
  }
}

void printGeometricCoveredCalls(List<Market> markets) {
  final usd = Commodity("USD");
  final oracle = Oracle.fromMarkets(markets);
//   for (final underlying in [Commodity("BTC"), Commodity("ETH")]) {
  for (final underlying in [Commodity("BTC")]) {
    final spotMarket = oracle.marketFor(asset: underlying, money: usd);
    final spotPrice = spotMarket.midPrice;
    final slippage = 0.5;
    final Map<DateTime, Market> futures = markets
        .whereUnderlyingIs(underlying)
        .futures
        .withMoney(usd, oracle)
        .groupByExpiration()
        .mapValues((ms) => ms.single);

    print("====================== $underlying ======================");
    print("Spot price: $spotPrice\$");

    for (final optionsByExpiration in markets
        .whereUnderlyingIs(underlying)
        .calls
        .withMoney(usd, oracle)
        .groupByExpiration(Order.desc)
        .mapValues((ms) => ms.sortByStrike(Order.asc))
        .entries) {
      final expiration = optionsByExpiration.key;
      final options = optionsByExpiration.value;
      final future = futures[expiration];
      if (future == null) continue;
      final futurePrice = future.midPrice;
      final riskFreeYield = 1.0 + max(0.0, futurePrice / spotPrice - 1);
      final riskFreeAPR = (riskFreeYield - 1.0) *
          Duration(days: 365).inMinutes /
          expiration.minutesLeft;

      print("\n=========== Expiration: ${expiration.daysLeft} days and "
          "${expiration.hoursModuloDaysLeft} hours, "
          "risk-free yield: ${percentify(riskFreeYield - 1.0)} "
          "(APR: ${percentify(riskFreeAPR).padLeft(5)}) "
          "===========\n");

      for (final market in options) {
        final option = market.asset.toOption;
        final size = Deribit.getMinimumContract(
            DeribitCoin.values.byName(option.underlying.name));

        // includes +premium ($)
        final shortCall = market.short(slippage).position(1.0);
        // includes -cost basis ($)
        final longSpot = spotMarket.long(slippage).position(1.0);

        // Simplifies! +Underlying, -call, -$
        final coveredCall = SyntheticAsset([shortCall, longSpot]);
        final analyzer = PositionAnalyzer(coveredCall.position(size),
            underlying: option.underlying, money: usd);
        print("${option.name.toString().padLeft(21)}: "
            "breakeven=${analyzer.breakevens}, "
            "maxYield=${percentify(analyzer.maxYield)} "
            "achieved at ${analyzer.maxValue.first.price} "
            "(${percentify(analyzer.maxValue.first.price.fromPrice / spotPrice - 1.0)} from spot)");

        // if (maxYield <= riskFreeYield) continue;
        // final equivalentSellPrice = spotPrice * maxYield;
        // print("${option.name.toString().padLeft(21)}: "
        //     "breakeven ${percentify(breakEvenAsChange).padLeft(6)} "
        //     "(${dollarify(breakEven).padLeft(7)}), "
        //     "max yield ${percentify(maxYield - 1.0).padLeft(6)} "
        //     "(like selling at: ${dollarify(equivalentSellPrice).padLeft(7)})"
        //     ", achieved at >= ${dollarify(option.strike).padLeft(7)}). "
        //     "Buy ${initialHeld.toStringAsFixed(5)} ${option.underlying} (${dollarify(initialHeld * spotPrice)})");
      }
    }
  }
}
