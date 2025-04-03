// List<Market> deribitMarketLoader()  // fetch BTC/ETH
// all synthetic bonds
// then produce all CC's
// all over/under (touch/don't touch)
// all box spreads (or the best per expiration)
// probabilities of touch by date

// Each JS exposed function fetches a JSON ready for visualization
// takes a slippage as parameter
// and coin, I guess.
// And most importantly:
// Translate all options to RELATIVE:
// not strikes but moves (%). Not dates but days.
// Especially for touch probabilities, so they can be screenshot
// and compared.

import 'dart:convert';

import 'package:options_tools/assets.dart';
import 'package:options_tools/deribit.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/position_analyzer.dart';

class CoveredCall {
  final Commodity underlying;
  final Commodity money;
  final DateTime expiration;

  final PositionAnalyzer analyzer;

  late final Position strategy;
  late final Position optionLeg;
  late final Position underlyingLeg;
  late final Position moneyLeg;

  final double spotPrice;
  late final double breakeven;
  late final double maxYield;
  late final double maxYieldAt;
  late final double maxYieldAtChange;
  late final double yieldIfPriceUnchanged;
  late final double equivalentHodlerSellPrice;

  Map<String, dynamic> toJson() => {
        'underlying': underlying.name,
        'underlyingSize': underlyingLeg.size,
        'money': money.name,
        'moneySize': moneyLeg.size,
        'call': optionLeg.asset.name,
        'callSize': optionLeg.size,
        'DTE': expiration.daysLeft,
        'breakEven': breakeven,
        'maxYield': maxYield,
        'maxYieldAt': maxYieldAt,
        'maxYieldAtChange': maxYieldAtChange,
        'yieldIfPriceUnchanged': yieldIfPriceUnchanged,
        'equivalentHodlerSellPrice': equivalentHodlerSellPrice,
      };

  @override
  String toString() => jsonEncode(this);

  CoveredCall._(this.strategy,
      {required this.underlying,
      required this.money,
      required this.expiration,
      required this.spotPrice})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money) {
    for (final p in strategy.decompose()) {
      if (p.asset == money) {
        moneyLeg = p;
      } else if (p.asset == underlying) {
        underlyingLeg = p;
      } else {
        optionLeg = p;
      }
    }
    breakeven = analyzer.breakevens.single.price;
    maxYield = analyzer.maxYield;
    maxYieldAt = analyzer.maxValue.single.price.fromPrice;
    maxYieldAtChange = maxYieldAt / spotPrice;
    yieldIfPriceUnchanged =
        analyzer.valueAt(spotPrice) / (-analyzer.minValue.single.value);
    equivalentHodlerSellPrice = spotPrice * (1.0 + maxYield);
  }

  static Iterable<CoveredCall> generateAll(MarketsNavigator navigator,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final spotMarket = navigator.bestMarket(asset: underlying, money: money);
    for (final call in navigator.allMarkets
        .whereUnderlyingIs(underlying)
        .calls
        .withMoney(money, navigator)
        .sortByExpiration(Order.asc)
        .sortByStrike(Order.asc)) {
      yield CoveredCall._(
          SyntheticAsset([
            call.short(slippage).unit(),
            spotMarket.long(slippage).unit()
          ]).position(Deribit.getMinimumContract(
              DeribitCoin.values.byName(underlying.name))),
          underlying: underlying,
          money: money,
          expiration: call.asset.toOption.expiration,
          spotPrice: spotMarket.midPrice);
    }
  }
}
