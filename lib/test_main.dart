import 'dart:collection';
import 'dart:math';

import 'package:options_tools/market_analyzer.dart';

import 'assets.dart';
import 'data/deribit.dart';
import 'data/url_fetcher.dart';
import 'data/yfinance.dart';
import 'markets.dart';
import 'oracle.dart';
import 'position_analyzer.dart';
import 'strategies.dart';

String percentify(double x, {int decimals = 1, bool sign = true}) =>
    "${sign && x >= 0.0 ? "+" : ""}${(100.0 * x).toStringAsFixed(decimals)}%";
String dollarify(double x) => "\$${x.toStringAsFixed(0)}";
double asChange(double changedValue, double originalValue) =>
    changedValue / originalValue - 1.0;

void main() async {
  // testYFinance();

  List<Market> markets = await Deribit.fetchMarkets(
      [Deribit.USDC], UrlFetcher(Duration(minutes: 15)));
  // [Deribit.BTC, Deribit.ETH], UrlFetcher(Duration(minutes: 15)));
  // ArchOracle oracle = Oracle.fromMarkets(markets);

  // testMarketNavigator(oracle);

  // browseLinearContracts();
  // browseVerticalSpreads(markets);
  // browseBonds(markets);
  browseCoveredCalls(markets);
  // printGeometricCoveredCalls(markets);
  // browseLongCalls(markets);

  // printOptionChain(markets);

//   Iterable<Market> calls = markets
//       .whereUnderlyingIs(Deribit.BTC.commodity)
//       .calls
//       .sortByStrike(Order.asc)
//       .sortByExpiration(Order.asc);
//   for (final call in calls.take(10)) {
//     print(
//         "Asset: [${call.asset}], sell price: ${call.sellPrice()} of ${call.money}");
//     // Do it in dollars? Underlying?
//   }
}

void testYFinance() async {
  final urlFetcher = UrlFetcher(Duration(minutes: 15));
  YFinance yfinance = await YFinance.openConnection(urlFetcher);
  final List<Market> markets = await yfinance.fetchMarkets("GOOG", urlFetcher);

  // for (final MapEntry<DateTime,
  //         Map<double, ({Market? call, Market? put})>> expirationToStrike
  //     in markets.options
  //         .sortByExpiration(Order.desc)
  //         .groupByExpiration()
  //         .mapValues((ms) => ms.groupByStrike(Order.desc).mapValues(
  //             (ms) => (call: ms.calls.singleOrNull, put: ms.puts.singleOrNull)))
  //         .entries) {
  //   print("Date: ${expirationToStrike.key}");
  //   for (final strikeToOptions in expirationToStrike.value.entries) {
  //     final options = strikeToOptions.value;
  //     print(
  //         "  Strike: ${strikeToOptions.key} Call: ${options.call},  put: ${options.put}");
  //   }
  //   break;
  // }

  final money = Commodity("USD");
  final underlying = Commodity("GOOG");

  print(" ============== GOOG CC ==============");
  for (CoveredCall cc in CoveredCall.generateAll(markets,
      underlying: underlying, money: money)) {
    final spot = cc.spotMarket;
    final equalSizeLongStrategy = cc.analyzer.equalizeRisk(spot.long());
    final pricesWithSameMaxGain =
        equalSizeLongStrategy.whereValueIs(cc.analyzer.maxValue);
    print("Spot: $spot");
    print("Call: ${cc.option}");
    // print("Call premium: ${cc.callMarket.midPrice}");
    // print("Analyzer: ${cc.analyzer}");
    // print("max risk: ${cc.analyzer.maxRisk}");
    print(cc);
    // print("Long spot: $equalSizeLongStrategy");
    // print("pricesWithSameMaxGain: $pricesWithSameMaxGain");
    final p = cc.analyzer.position;
    print("  #### : Original: $p");
    print("  #### : Shares: ${p[spot.asset]}");
    print(
        "  #### : but instructions: ${cc.underlyingToBuy} + ${cc.premiumToReceive} = ${(cc.underlyingToBuy + cc.premiumToReceive)[spot.asset]}");
    // print(
    //     "### CC: ${cc.analyzer.position.decompose()}, maxYield: ${cc.maxYield}, spotPrice: ${cc.spotPrice}"
    //     "\n    equalSizedLongSpot: ${equalSizeLongStrategy.position.decompose()}"
    //     "\n    breakevenVsHolder: $pricesWithSameMaxGain"
    //     "\n");
  }
}

void testMarketNavigator(ArchOracle oracle) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");
  MarketNavigator nav =
      MarketNavigator.create(oracle, underlying: underlying, money: money);
}

void browseLinearContracts() async {
  List<Market> usdcMarkets = await Deribit.fetchMarkets(
      [Deribit.BTC, Deribit.ETH, Deribit.USDC],
      UrlFetcher(Duration(minutes: 15)));
  for (final m in usdcMarkets) {
    print(m);
  }
}

void browseVerticalSpreads(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== Vertical Spreads ==============");
  for (VerticalSpread vs in VerticalSpread.generateAll(markets,
          underlying: underlying, money: money)
      .take(20)) {
    print(" ## ${vs.toJson()}\n");
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
  final underlying = Commodity("TRX");

  print(" ============== CC ==============");
  for (CoveredCall cc in CoveredCall.generateAll(markets,
      underlying: underlying, money: money)) {
    final spot = cc.spotMarket;
    final equalSizeLongStrategy = cc.analyzer.equalizeRisk(spot.long());
    final pricesWithSameMaxGain =
        equalSizeLongStrategy.whereValueIs(cc.analyzer.maxValue);
    print(
        "### CC: ${cc.analyzer.position.decompose()}, maxYield: ${cc.moneyYield}, spotPrice: ${cc.spotPrice}"
        "\n    equalSizedLongSpot: ${equalSizeLongStrategy.position.decompose()}"
        "\n    breakevenVsHolder: $pricesWithSameMaxGain"
        "\n");
    print(cc.callMarket);
  }
}

void browseLongCalls(List<Market> allMarkets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== Long Calls ==============");
  final oracle = Oracle.fromMarkets(allMarkets);
  final spotMarket = oracle.marketFor(asset: underlying, money: money);
  final ccs =
      CoveredCall.generateAll(allMarkets, underlying: underlying, money: money);
  for (final cc in ccs) {
    final callContract = cc.callMarket.asset.toOption;
    final longCall = cc.callMarket.long();
    final longCallAnalyzer =
        PositionAnalyzer(longCall, underlying: underlying, money: money);
    final breakeven = longCallAnalyzer.breakevens.singleOrNull;
    if (breakeven == null) {
      continue;
    }
    // Find breakeven vs spot long position of the same max loss.
    final longSpotAnalyzer = longCallAnalyzer.equalizeRisk(spotMarket.long());
    final strike = callContract.strike;
    final leverage = longCallAnalyzer.deltaAfter(strike) /
        longSpotAnalyzer.deltaAfter(strike);
    print("${callContract.toString().padLeft(32)} -->"
        " Leverage: ${leverage.toStringAsFixed(1).padLeft(5)}X"
        ", ITM @ ${percentify(asChange(strike, spotMarket.midPrice)).padLeft(7)}"
        ", profit @ ${percentify(asChange(breakeven.price, spotMarket.midPrice)).padLeft(7)}"
        " (\$${breakeven.price.toStringAsFixed(0).padLeft(6)})"
        ", CC b.e.: ${percentify(asChange(cc.breakEvenVsFullMoney.absolute, spotMarket.midPrice)).padLeft(7)}"
        " (\$${cc.breakEvenVsFullMoney.absolute.toStringAsFixed(0).padLeft(6)})"
        " cc max profit: ${percentify(cc.moneyYield - 1.0)}");
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
        .coercedToMoney(usd, oracle)
        .groupByExpiration()
        .mapValues((ms) => ms.single);

    print("====================== $underlying ======================");
    print("Spot price: $spotPrice\$");

    for (final optionsByExpiration in markets
        .whereUnderlyingIs(underlying)
        .calls
        .coercedToMoney(usd, oracle)
        .groupByExpiration(Order.desc)
        .mapValues((ms) => ms.sortByStrike(Order.asc))
        .entries) {
      final expiration = optionsByExpiration.key;
      final options = optionsByExpiration.value;
      final future = futures[expiration];
      if (future == null) continue;
      final futurePrice = future.midPrice;
      final riskFreeYield = 1.0 + max(0.0, asChange(futurePrice, spotPrice));
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

        // includes +premium ($)
        final shortCall = market.short(slippage);
        // includes -cost basis ($)
        final longSpot = spotMarket.long(slippage);

        // Simplifies! +Underlying, -call, -$
        final coveredCall = shortCall + longSpot;
        final analyzer = PositionAnalyzer(coveredCall,
            underlying: option.underlying, money: usd);
        print("${option.name.toString().padLeft(21)}: "
            "breakeven=${analyzer.breakevens}, "
            "maxYield=${percentify(analyzer.maxYield)} "
            "achieved at ${analyzer.bestPrices.first.price} "
            "(${percentify(asChange(analyzer.bestPrices.first.fromPrice, spotPrice))} from spot)");

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
