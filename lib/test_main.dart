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
  await testGoogCoveredCallUnrealizedGains();

  // List<Market> markets = await Deribit.fetchMarkets(
  //     [Deribit.BTC], UrlFetcher(Duration(minutes: 15)));
  // List<Market> markets = await Deribit.fetchMarkets(
  //     [Deribit.USDC], UrlFetcher(Duration(minutes: 15)));
  // [Deribit.BTC, Deribit.ETH], UrlFetcher(Duration(minutes: 15)));
  // ArchOracle oracle = Oracle.fromMarkets(markets);

  // testMarketNavigator(oracle);

  // browseLinearContracts();
  // browseProbabilities(markets);
  // playWithCostBasis(markets);
  // browseCoveredCalls(markets);
  // printGeometricCoveredCalls(markets);
  // browseLongCalls(markets);
  // browseStraddles(markets);
  // coveredCallProbabilities(markets);

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

Future<void> testGoogCoveredCallUnrealizedGains() async {
  const numCoveredCalls = 1;
  const unitCostBasis = 62.0;
  const taxRate = 0.31;

  final urlFetcher = UrlFetcher(Duration(minutes: 15));
  YFinance yfinance = await YFinance.openConnection(urlFetcher);
  final List<Market> markets =
      await yfinance.fetchMarkets("GOOG", urlFetcher, minDTE: 364);

  final money = Commodity("USD");
  final underlying = Commodity("GOOG");
  final oracle = Oracle.fromMarkets(markets);

  // 45 covered calls = 4,500 shares with unitCostBasis of $20/share ($90,000 total)
  final totalShares = numCoveredCalls * 100.0;
  final heldStock = underlying.ofSize(totalShares, money.ofSize(unitCostBasis));
  final stockBasis = heldStock.costBasisIn(oracle, money);

  final spotMarket = oracle.marketFor(asset: underlying, money: money);
  final currentStockValue =
      oracle.markToMarket(position: heldStock, money: money).size;
  final currentStockGain = currentStockValue - stockBasis.size;
  final currentStockPostTaxValue =
      currentStockValue - (currentStockGain * taxRate);

  print(
      "====================================================================================================");
  print("GOOG Covered Calls Analysis");
  print(
      "Spot Price: \$${spotMarket.midPrice.toStringAsFixed(2)} | Target Price Mark: At Strike");
  print(
      "Holding: $numCoveredCalls Covered Calls ($totalShares shares @ \$${unitCostBasis.toStringAsFixed(2)} basis, Total Basis: \$${stockBasis.size.toStringAsFixed(2)})");
  print("Current Value of Shares: \$${currentStockValue.toStringAsFixed(2)}");
  print(
      "Current Post-Tax Value of Shares: \$${currentStockPostTaxValue.toStringAsFixed(2)} (Tax: \$${(currentStockGain * taxRate).toStringAsFixed(2)})");
  print("Capital Gains Tax Rate: ${(taxRate * 100).toStringAsFixed(1)}%");
  print(
      "====================================================================================================");

  final calls = markets
      .whereUnderlyingIs(underlying)
      .calls
      .coercedToMoney(money, oracle)
      .sortByStrike(Order.asc)
      .sortByExpiration(Order.asc)
      .toList();

  DateTime? lastExpiration;
  for (final callMarket in calls) {
    final option = callMarket.asset.toOption;
    final strike = option.strike;
    final expiration = option.expiration;
    final dte = expiration.daysLeft;

    if (expiration != lastExpiration) {
      if (lastExpiration != null) print("");
      print(
          "${'Expiration'.padRight(12)} | ${'DTE'.padLeft(5)} | ${'Strike'.padLeft(8)} | ${'Premium'.padLeft(11)} | ${'Pos Value@Strike'.padLeft(18)} | ${'Unrealized Gain'.padLeft(17)} | ${'Net (Post Tax) Value'.padLeft(20)}");
      print("-" * 103);
      lastExpiration = expiration;
    }
    final totalPremium = callMarket.midPrice * numCoveredCalls;

    // Covered call position: held stock + short call contracts
    final shortCall = callMarket.short() * numCoveredCalls.toDouble();
    final coveredCallPosition = heldStock + shortCall;

    final analyzer = PositionAnalyzer(coveredCallPosition,
        underlying: underlying, money: money);

    // Value of the open position at underlying price S = strike
    final valueAtStrike = analyzer.valueAt(strike);

    // Unrealized capital gain/loss before assignment
    final unrealizedGain = valueAtStrike - stockBasis.size;
    final tax = unrealizedGain * taxRate;
    final netPostTaxValue = valueAtStrike - tax;

    print(
        "${expiration.toIso8601String().substring(0, 10).padRight(12)} | ${dte.toString().padLeft(5)} | ${dollarify(strike).padLeft(8)} | ${dollarify(totalPremium).padLeft(11)} | ${dollarify(valueAtStrike).padLeft(18)} | ${dollarify(unrealizedGain).padLeft(17)} | ${dollarify(netPostTaxValue).padLeft(20)}");
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

void browseProbabilities(List<Market> markets) async {
  // final urlFetcher = UrlFetcher(Duration(minutes: 15));
  // YFinance yfinance = await YFinance.openConnection(urlFetcher);
  // final List<Market> markets = await yfinance.fetchMarkets("MU", urlFetcher);

  final money = Commodity("USD");
  // final underlying = Commodity("MU");
  final underlying = Commodity("BTC");

  print(" ============== Probabilities ==============");

  final spreads =
      VerticalSpread.generateAll(markets, underlying: underlying, money: money)
          .toList();
  final probs = Probabilities(spreads, underlying: underlying, money: money);

  for (final MapEntry<DateTime, Map<double, double>> entry
      in probs.distributions.entries) {
    final DateTime expiration = entry.key;
    final Map<double, double> strikeProbs = entry.value;

    print(
        "\nExpiration: ${expiration.toIso8601String()} (DTE: ${expiration.daysLeft})");
    if (probs.atmStrikes.containsKey(expiration)) {
      print(
          "  ATM Crossover Strike: ${probs.atmStrikes[expiration]?.toStringAsFixed(2)}");
    }
    print("  Strike | Probability");
    print("  -------|------------");

    final sortedStrikes = strikeProbs.keys.toList()..sort();
    for (final strike in sortedStrikes) {
      final prob = strikeProbs[strike]!;
      final contributing = probs.getContributingSpreads(expiration, strike);
      final spreadsStr = contributing.map((vs) {
        if (vs.type == VerticalSpreadType.over) {
          return "${vs.strategy} (maxProbAbove: ${vs.maxProbAbove?.toStringAsFixed(3)})";
        } else {
          final probBelow = vs.maxProbBelow;
          final impliedAbove = probBelow != null ? 1.0 - probBelow : null;
          return "${vs.strategy} (maxProbBelow: ${probBelow?.toStringAsFixed(3)}, minProbAbove: ${impliedAbove?.toStringAsFixed(3)})";
        }
      }).join("\n      ");
      print(
          "  ${strike.toStringAsFixed(2).padLeft(6)} | ${(prob * 100).toStringAsFixed(1)}% (Spreads:\n      $spreadsStr)");
    }
  }
}

void browseVerticalSpreads(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== Vertical Spreads ==============");

  final spreads =
      VerticalSpread.generateAll(markets, underlying: underlying, money: money)
          .toList();
  final probs = Probabilities(spreads, underlying: underlying, money: money);

  final Map<int, Map<double, double>> overProbsPerDte = {};
  final Map<int, Map<double, double>> underProbsPerDte = {};
  final Map<int, DateTime> dteToExpiration = {};

  for (VerticalSpread vs in spreads) {
    if (vs.shortMarket.bidPrice <= 0.0 ||
        vs.shortMarket.askPrice <= 0.0 ||
        vs.longMarket.bidPrice <= 0.0 ||
        vs.longMarket.askPrice <= 0.0) {
      continue;
    }
    final dte = vs.expiration.daysLeft;
    dteToExpiration[dte] = vs.expiration;
    if (vs.type == VerticalSpreadType.over) {
      final strike = vs.shortOption.strike;
      overProbsPerDte.putIfAbsent(dte, () => {})[strike] = vs.maxProbAbove;
    } else {
      final strike = vs.shortOption.strike;
      underProbsPerDte.putIfAbsent(dte, () => {})[strike] = vs.maxProbBelow;
    }
  }

  final dtes = {...overProbsPerDte.keys, ...underProbsPerDte.keys}.toList()
    ..sort();

  for (final dte in dtes) {
    print("\nDTE: $dte");
    final overMap = overProbsPerDte[dte] ?? {};
    final underMap = underProbsPerDte[dte] ?? {};
    final expiration = dteToExpiration[dte]!;

    final strikes = {...overMap.keys, ...underMap.keys}.toList()..sort();

    print(
        "  Strike | P(>= Strike) Raw | P(<= Strike) Raw | Sum Raw | P(>= Strike) Smoothed");
    print(
        "  -------|------------------|------------------|---------|----------------------");
    for (final strike in strikes) {
      final overProb = overMap[strike];
      final underProb = underMap[strike];
      final overStr =
          overProb != null ? "${(overProb * 100).toStringAsFixed(1)}%" : "-";
      final underStr =
          underProb != null ? "${(underProb * 100).toStringAsFixed(1)}%" : "-";
      final sumStr = (overProb != null && underProb != null)
          ? "${((overProb + underProb) * 100).toStringAsFixed(1)}%"
          : "-";

      String smoothStr = "-";
      try {
        final smoothProb =
            probs.getProbabilityExpiringAbove(expiration, strike);
        smoothStr = "${(smoothProb * 100).toStringAsFixed(1)}%";
      } catch (e) {
        // Extrapolation or not found in monotonic distribution
      }
      print(
          "  ${strike.toStringAsFixed(0).padLeft(6)} | ${overStr.padLeft(16)} | ${underStr.padLeft(16)} | ${sumStr.padLeft(7)} | ${smoothStr.padLeft(21)}");
    }
  }
}

void browseCoveredCalls(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

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

void coveredCallProbabilities(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== CC ==============");
  final Map<int, List<CoveredCall>> byDte = {};
  for (CoveredCall cc in CoveredCall.generateAll(markets,
      underlying: underlying, money: money)) {
    final dte = cc.expiration.daysLeft;
    byDte.putIfAbsent(dte, () => []).add(cc);
  }

  if (byDte.isEmpty) return;
  final sortedDtes = byDte.keys.toList()..sort();

  for (final dte in sortedDtes) {
    final List<CoveredCall> calls = byDte[dte]!
      ..sort(
          (a, b) => a.strikePrice.absolute.compareTo(b.strikePrice.absolute));

    CoveredCall? lower;
    CoveredCall? upper;
    for (int i = 0; i < calls.length - 1; i++) {
      final cc1 = calls[i];
      final cc2 = calls[i + 1];
      final diff1 = cc1.moneyYield - cc1.underlyingYield;
      final diff2 = cc2.moneyYield - cc2.underlyingYield;
      if (diff1 <= 0 && diff2 >= 0) {
        lower = cc1;
        upper = cc2;
        break;
      }
    }

    if (lower != null && upper != null) {
      final k1 = lower.strikePrice.absolute;
      final k2 = upper.strikePrice.absolute;
      final d1 = lower.underlyingYield - lower.moneyYield;
      final d2 = upper.moneyYield - upper.underlyingYield;
      final forwardPrice = k1 + (k2 - k1) * d1 / (d1 + d2);

      // Interpolate Y_U at the ATM forward price
      final yUnderATM = lower.underlyingYield +
          (upper.underlyingYield - lower.underlyingYield) *
              (forwardPrice - k1) /
              (k2 - k1);

      print("\nDTE: $dte");
      print(
          "Interpolated ATM (forward) price: ${forwardPrice.toStringAsFixed(2)}");
      print(
          "Interpolated ATM underlyingYield: ${yUnderATM.toStringAsFixed(6)}");

      for (final cc in calls) {
        final json = cc.toJson();
        final k = cc.strikePrice.absolute;
        final yUnder = cc.underlyingYield;

        double pAbove;
        if (k >= forwardPrice) {
          if (yUnderATM > 1.0) {
            pAbove = 0.5 * (yUnder - 1.0) / (yUnderATM - 1.0);
          } else {
            pAbove = 0.0;
          }
        } else {
          pAbove = 1.0 - 0.5 * (yUnderATM / yUnder);
        }
        pAbove = pAbove.clamp(0.0, 1.0);

        print("  ${json['id']} -- K: ${k.toStringAsFixed(0).padLeft(6)} "
            "| \$: ${json['moneyYield'].toStringAsFixed(4)} "
            "| U: ${json['underlyingYield'].toStringAsFixed(4)} "
            "| Prob(Above): ${(pAbove * 100).toStringAsFixed(1)}%");
      }
    } else {
      print("\nDTE: $dte - Crossover strikes not found.");
    }
  }
}

void browseLongCalls(List<Market> allMarkets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  print(" ============== Long Calls ==============");
  final oracle = Oracle.fromMarkets(allMarkets);
  final spotMarket = oracle.marketFor(asset: underlying, money: money);
  // final ccs =
  //     CoveredCall.generateAll(allMarkets, underlying: underlying, money: money);
  // for (final cc in ccs) {
  //   final callContract = cc.callMarket.asset.toOption;
  //   final longCall = cc.callMarket.long();
  //   final longCallAnalyzer =
  //       PositionAnalyzer(longCall, underlying: underlying, money: money);
  //   final breakeven = longCallAnalyzer.breakevens.singleOrNull;
  //   if (breakeven == null) {
  //     continue;
  //   }
  //   // Find breakeven vs spot long position of the same max loss.
  //   final longSpotAnalyzer = longCallAnalyzer.equalizeRisk(spotMarket.long());
  //   final strike = callContract.strike;
  //   final leverage = longCallAnalyzer.deltaAfter(strike) /
  //       longSpotAnalyzer.deltaAfter(strike);
  //   print("${callContract.toString().padLeft(32)} -->"
  //       " Leverage: ${leverage.toStringAsFixed(1).padLeft(5)}X"
  //       ", ITM @ ${percentify(asChange(strike, spotMarket.midPrice)).padLeft(7)}"
  //       ", profit @ ${percentify(asChange(breakeven.price, spotMarket.midPrice)).padLeft(7)}"
  //       " (\$${breakeven.price.toStringAsFixed(0).padLeft(6)})"
  //       ", CC b.e.: ${percentify(asChange(cc.breakEvenVsFullMoney.absolute, spotMarket.midPrice)).padLeft(7)}"
  //       " (\$${cc.breakEvenVsFullMoney.absolute.toStringAsFixed(0).padLeft(6)})"
  //       " cc max profit: ${percentify(cc.moneyYield - 1.0)}");
  // }

  for (LongCall s in LongCall.generateAll(allMarkets,
      underlying: underlying, money: money)) {
    final spot = s.spotMarket;
    // final equalSizeLongStrategy = cc.analyzer.equalizeRisk(spot.long());
    // final pricesWithSameMaxGain =
    //     equalSizeLongStrategy.whereValueIs(cc.analyzer.maxValue);

    // print("### ${s.option.name} moneySize: ${dollarify(s.moneyLeg.size)}, "
    //     "leverage=${s.underlyingYield}X, moneyYield=${s.moneyYield}");
    final callPrice = s.callMarket.midPrice;
    final leverageU = spot.midPrice / callPrice;

    final longCallMinusLongSpot = PositionAnalyzer(
        s.optionLeg - spotMarket.swap(s.moneyLeg) + s.moneyLeg,
        underlying: underlying,
        money: money);

    print("# ${s.option.name}: cost: ${dollarify(callPrice)}, "
        "leverage (U): ${leverageU.toStringAsFixed(2)}X, "
        "breakEvenVsFullMoney (hurdle): ${dollarify(s.breakEvenVsFullMoney.absolute)} (${percentify(s.breakEvenVsFullMoney.relative - 1.0)}), "
        "breakEvenVsFullUnderlying: ${dollarify(longCallMinusLongSpot.breakevens.last.price)}, "
        "${s.analyzer.valueAt(longCallMinusLongSpot.breakevens.last.price)} ==? ${PositionAnalyzer(spotMarket.toAsset(-s.moneyLeg), underlying: underlying, money: money).valueAt(longCallMinusLongSpot.breakevens.last.price)}");
  }
  print(spotMarket.midPrice);
}

void browseStraddles(List<Market> markets) {
  final money = Commodity("USD");
  final underlying = Commodity("BTC");

  final spotMarket =
      Oracle.fromMarkets(markets).marketFor(asset: underlying, money: money);
  print(" ============== Straddles ==============");
  for (Straddle s
      in Straddle.generateAll(markets, underlying: underlying, money: money)
          .toList()) {
    print("Strike: ${s.strikePrice.absolute}, "
        "DTE: ${s.expiration.daysLeft}, "
        "DistanceBetweenBreakEvens: ${dollarify(s.distanceBetweenBreakEvens.absolute)} (${percentify(s.distanceBetweenBreakEvens.relative, decimals: 1, sign: false)}), "
        "BEvsMoneyDown: ${s.breakEvenVsFullMoneyDown.absolute.toStringAsFixed(0)} (${percentify(s.breakEvenVsFullMoneyDown.relative - 1.0, decimals: 1)}), "
        "BEvsMoneyUp: ${s.breakEvenVsFullMoneyUp.absolute.toStringAsFixed(0)} (${percentify(s.breakEvenVsFullMoneyUp.relative - 1.0, decimals: 1)})");
  }
  print('Spot price: ${spotMarket.midPrice}');
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

void playWithCostBasis(List<Market> markets) {
  print(
      "==========================================================================");
  print(
      "                 EXPLORING COST BASIS WITH REAL DERIBIT DATA              ");
  print(
      "==========================================================================");

  final oracle = Oracle.fromMarkets(markets);
  final btc = Commodity.fromName(Deribit.BTC);
  final usd = Commodity.fromName('USD');

  final callMarket =
      markets.whereUnderlyingIs(btc).calls.sortByStrike(Order.asc).first;

  print("\n1. Fresh Long Option Market Trade:");
  print("   • Market: ${callMarket.asset} quoted in ${callMarket.money}");
  print("   • Buy Price: ${callMarket.buyPrice()} ${callMarket.money}");

  final longPos = callMarket.long();
  print("   • Position decomposes to:");
  for (final line in longPos.decompose()) {
    print("       - $line (costBasis: ${line.costBasis})");
  }
  print("   • Total Position costBasisSingle(${callMarket.money}): "
      "${longPos.costBasisSingle(callMarket.money as Commodity)}");

  print("\n2. Pre-Existing Asset Holding & Parameterized Cost Basis:");
  // Suppose we already bought 1.5 BTC at $45,000 USD each
  final holding = btc.ofSize(1.5, usd.ofSize(45000.0));
  print("   • Existing Holding: $holding");
  print("   • Holding unitCostBasis: ${holding.unitCostBasis}");
  print("   • Holding total costBasis: ${holding.costBasis}");

  print("\n3. Covered Call Combining Existing Stock + Short Call:");
  final shortCall = callMarket.short() * 1.5;
  final coveredCall = holding + shortCall;

  print("   • Strategy decomposes to:");
  for (final line in coveredCall.decompose()) {
    print(
        "       - ${line.asset.name}: size=${line.size}, unitCostBasis=${line.unitCostBasis}, totalCostBasis=${line.costBasis}");
  }
  print("   • Strategy aggregate costBasis (multi-currency):");
  for (final basisLine in coveredCall.costBasis!.decompose()) {
    print("       - $basisLine");
  }

  // Convert aggregate cost basis into USD using Oracle!
  final totalInUsd = coveredCall.costBasisIn(oracle, usd);
  print("   • Converted total costBasis in USD via Oracle: $totalInUsd");

  print("\n4. Market Reversal & Symmetry Invariance:");
  final revMarket = callMarket.reverse;
  print("   • Reverse Market: ${revMarket.asset} quoted in ${revMarket.money}");
  print("   • Reverse Long Position: ${revMarket.long()}");
  print("   • Reverse Long costBasis: ${revMarket.long().costBasis}");
  print(
      "==========================================================================\n");
}
