import 'dart:convert';
import 'dart:math';

import 'assets.dart';
import 'deribit.dart';
import 'markets.dart';
import 'oracle.dart';
import 'position_analyzer.dart';

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
  late final double? breakeven;
  late final double? breakevenAsChange;
  late final double maxYield;
  late final double maxYieldAt;
  late final double maxYieldAtChange;
  late final double yieldIfPriceUnchanged;
  late final double equivalentHodlerSellPrice;

  late final double? timeValue;

  Map<String, dynamic> toJson() => {
        'underlying': underlying.name,
        'underlyingSize': underlyingLeg.size,
        'money': money.name,
        'moneySize': moneyLeg.size,
        'spotPrice': spotPrice,
        'call': optionLeg.asset.name,
        'callSize': optionLeg.size,
        'DTE': expiration.daysLeft,
        'breakEven': breakeven,
        'breakEvenAsChange': breakevenAsChange,
        'maxYield': maxYield,
        'maxYieldAt': maxYieldAt,
        'maxYieldAtChange': maxYieldAtChange,
        'yieldIfPriceUnchanged': yieldIfPriceUnchanged,
        'equivalentHodlerSellPrice': equivalentHodlerSellPrice,
        'timeValue': timeValue,
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
    breakeven = analyzer.breakevens.singleOrNull?.price;
    breakevenAsChange = breakeven != null ? breakeven! / spotPrice : null;
    maxYield = analyzer.maxYield;
    maxYieldAt = analyzer.maxValue.single.price.fromPrice;
    maxYieldAtChange = maxYieldAt / spotPrice;
    yieldIfPriceUnchanged =
        analyzer.valueAt(spotPrice) / (-analyzer.minValue.single.value);
    equivalentHodlerSellPrice = spotPrice * (1.0 + maxYield);
    timeValue = breakeven == null
        ? 0.0
        : (min(maxYieldAt, spotPrice) - breakeven!) / spotPrice;
  }

  static Iterable<CoveredCall> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    for (final call in allMarkets
        .whereUnderlyingIs(underlying)
        .calls
        .withMoney(money, oracle)
        .sortByStrike(Order.asc)
        .sortByExpiration(Order.asc)) {
      yield CoveredCall._(
          SyntheticAsset(
                  [call.short(slippage).unit, spotMarket.long(slippage).unit])
              .position(Deribit.getMinimumContract(
                  DeribitCoin.values.byName(underlying.name))),
          underlying: underlying,
          money: money,
          expiration: call.asset.toExpirable.expiration,
          spotPrice: spotMarket.midPrice);
    }
  }
}

class SyntheticBond {
  final Commodity underlying;
  final Commodity money;
  final DateTime expiration;

  late final Position strategy;
  late final Position futureLeg;
  late final Position underlyingLeg;
  late final Position moneyLeg;

  final double spotPrice;
  late final double interestRate;
  late final double apr;

  Map<String, dynamic> toJson() => {
        'underlying': underlying.name,
        'underlyingSize': underlyingLeg.size,
        'money': money.name,
        'moneyProfit': moneyLeg.size,
        'future': futureLeg.asset.name,
        'futureSize': futureLeg.size,
        'spotPrice': spotPrice,
        'DTE': expiration.daysLeft,
        'interestRate': interestRate,
        'apr': apr,
      };

  SyntheticBond._(this.strategy,
      {required this.underlying,
      required this.money,
      required this.expiration,
      required Market spotMarket,
      required Oracle oracle})
      : spotPrice = spotMarket.midPrice {
    for (final p in strategy.decompose()) {
      if (p.asset == money) {
        moneyLeg = p;
      } else if (p.asset == underlying) {
        underlyingLeg = p;
      } else {
        futureLeg = p;
      }
    }
    print(
        "     moneyLeg: $moneyLeg, underlyingLeg: $underlyingLeg (${spotMarket.exchange(underlyingLeg).size})");
    // "\n  intrinsic: ${oracle.intrinsicValue(asset: bond.futureLeg, money: money)}"
    // "\n  extrinsic: ${oracle.extrinsicValue(asset: bond.futureLeg, money: money)}"
    // "\n  rate:      ${1.0 + oracle.extrinsicValue(asset: bond.futureLeg, money: money).size / oracle.intrinsicValue(asset: bond.futureLeg, money: money).size}");
    final intrinsic = oracle.intrinsicValue(asset: futureLeg, money: money);
    final extrinsic = oracle.extrinsicValue(asset: futureLeg, money: money);
    interestRate = extrinsic / intrinsic;
    apr = expiration.rateToAnnualRate(interestRate);
  }

  static Iterable<SyntheticBond> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    for (final future in allMarkets
        .whereUnderlyingIs(underlying)
        .futures
        .withMoney(money, oracle)
        .sortByExpiration(Order.asc)) {
      yield SyntheticBond._(
          SyntheticAsset(
                  [future.short(slippage).unit, spotMarket.long(slippage).unit])
              .unit,
          underlying: underlying,
          money: money,
          expiration: future.asset.toExpirable.expiration,
          spotMarket: spotMarket,
          oracle: oracle);
    }
  }
}

// touch is OTM Over/Under which closes on touch
// not touch is ITM Over/Under which closes on touch

class Over {}

class Under {}
