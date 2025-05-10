import 'dart:convert';
import 'dart:collection';
import 'dart:math';

import 'assets.dart';
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
    // We know that in CCs we're looking at a single max value segment
    maxYieldAt = analyzer.maxValue.single.price.fromPrice;
    maxYieldAtChange = maxYieldAt / spotPrice;
    yieldIfPriceUnchanged =
        analyzer.valueAt(spotPrice) / (-analyzer.minValue.single.value);
    equivalentHodlerSellPrice = spotPrice * maxYield;
    // TODO: use Oracle.extrinsicValue to compute timeValue
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
              [call.short(slippage).unit, spotMarket.long(slippage).unit]).unit,
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
      required this.spotPrice,
      required Oracle oracle}) {
    for (final p in strategy.decompose()) {
      if (p.asset == money) {
        moneyLeg = p;
      } else if (p.asset == underlying) {
        underlyingLeg = p;
      } else {
        futureLeg = p;
      }
    }
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
    final spotPrice = spotMarket.midPrice;
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
          spotPrice: spotPrice,
          oracle: oracle);
    }
  }
}

// touch is OTM Over/Under which closes on touch
// not touch is ITM Over/Under which closes on touch

enum VerticalSpreadType { over, under }

class VerticalSpread {
  final Commodity underlying;
  final Commodity money;
  final DateTime expiration;

  final PositionAnalyzer analyzer;

  late final Position strategy;
  late final Position shortLeg;
  late final Position longLeg;
  late final Position moneyLeg;
  late final VerticalSpreadType type;

  final double spotPrice;

  late final double? breakeven;
  late final double? breakevenAsChange;
  late final double maxYield;
  late final double maxYieldAt;
  late final double maxYieldAtChange;
  late final double maxRisk;
  late final double maxRiskAt;
  late final double maxRiskAtChange;
  late final double yieldIfPriceUnchanged;

  Map<String, dynamic> toJson() => {
        'underlying': underlying.name,
        'money': money.name,
        'credit': moneyLeg.size,
        'spotPrice': spotPrice,
        'shortLeg': shortLeg.asset.name,
        'longLeg': longLeg.asset.name,
        'type': type.name,
        'DTE': expiration.daysLeft,
        'breakEven': breakeven,
        'breakEvenAsChange': breakevenAsChange,
        'maxYield': maxYield,
        'maxYieldAt': maxYieldAt,
        'maxYieldAtChange': maxYieldAtChange,
        'maxRisk': maxRisk,
        'maxRiskAt': maxRiskAt,
        'maxRiskAtChange': maxRiskAtChange,
        'yieldIfPriceUnchanged': yieldIfPriceUnchanged,
      };

  VerticalSpread._(this.strategy,
      {required this.underlying,
      required this.money,
      required this.expiration,
      required this.spotPrice})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money) {
    for (final p in strategy.decompose()) {
      if (p.asset == money) {
        moneyLeg = p;
      } else if (p.size > 0) {
        longLeg = p;
      } else {
        shortLeg = p;
      }
    }
    type = longLeg.asset.toOption.strike > shortLeg.asset.toOption.strike
        ? VerticalSpreadType.over
        : VerticalSpreadType.under;
    breakeven = analyzer.breakevens.singleOrNull?.price;
    breakevenAsChange = breakeven != null ? breakeven! / spotPrice : null;
    maxYield = analyzer.maxYield;
    maxYieldAt = pickNearestBoundary(spotPrice, analyzer.maxValue);
    maxYieldAtChange = maxYieldAt / spotPrice;
    maxRisk = analyzer.maxRisk;
    maxRiskAt = pickNearestBoundary(spotPrice, analyzer.minValue);
    maxRiskAtChange = maxRiskAt / spotPrice;
    yieldIfPriceUnchanged = analyzer.yieldAt(spotPrice);
  }

  static double pickNearestBoundary(
          double target, Iterable<PriceAndValue> pnvs) =>
      pickNearest(target,
          pnvs.expand((pnv) => [pnv.price.fromPrice, pnv.price.toPrice]));

  static double pickNearest(double target, Iterable<double> candidates) {
    final it = candidates.iterator;
    if (!it.moveNext()) {
      throw ArgumentError("No candidates to pick from");
    }
    double candidate = it.current;
    double distance = (target - candidate).abs();
    while (it.moveNext()) {
      double newDistance = (target - it.current).abs();
      if (newDistance < distance) {
        distance = newDistance;
        candidate = it.current;
      }
    }
    return candidate;
  }

  static Iterable<VerticalSpread> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    final spotPrice = spotMarket.midPrice;

    for (final MapEntry<DateTime,
            Map<double, ({Market? call, Market? put})>> expirationToStrike
        in allMarkets
            .whereUnderlyingIs(underlying)
            .options
            .withMoney(money, oracle)
            .groupByExpiration(Order.asc)
            .mapValues((ms) => ms.groupByStrike(Order.asc).mapValues((ms) =>
                (call: ms.calls.singleOrNull, put: ms.puts.singleOrNull)))
            .entries) {
      final expiration = expirationToStrike.key,
          strikeToOptions = expirationToStrike.value;
      VerticalSpread makeSpread(Iterable<Position> positions) =>
          VerticalSpread._(SyntheticAsset(positions).unit,
              underlying: underlying,
              money: money,
              expiration: expiration,
              spotPrice: spotPrice);

      for (final (lowStrike, highStrike) in _pairUp(strikeToOptions.keys)) {
        final (call: lowCall, put: lowPut) = strikeToOptions[lowStrike]!;
        final (call: highCall, put: highPut) = strikeToOptions[highStrike]!;

        // under @ lowStrike
        VerticalSpread? under = keepBestValidSpread([
          if (lowPut != null && highPut != null)
            makeSpread(
                [highPut.long(slippage).unit, lowPut.short(slippage).unit]),
          if (lowCall != null && highCall != null)
            makeSpread(
                [highCall.long(slippage).unit, lowCall.short(slippage).unit]),
        ]);

        // over @ highStrike
        VerticalSpread? over = keepBestValidSpread([
          if (lowPut != null && highPut != null)
            makeSpread(
                [highPut.short(slippage).unit, lowPut.long(slippage).unit]),
          if (lowCall != null && highCall != null)
            makeSpread(
                [highCall.short(slippage).unit, lowCall.long(slippage).unit]),
        ]);

        yield* [under, over].nonNulls;
      }
    }
  }

  static VerticalSpread? keepBestValidSpread(
          Iterable<VerticalSpread> spreads) =>
      spreads
          // Remove riskless or profitless spreads (these can arise due to
          // wide bid/ask spreads)
          .where((vs) => vs.maxRisk > 0.0)
          .where((vs) => vs.maxYield > 1.0)
          .fold<VerticalSpread?>(
              null,
              (vs1, vs2) =>
                  vs1 != null && vs1.maxYield >= vs2.maxYield ? vs1 : vs2);

  static Iterable<(T, T)> _pairUp<T>(Iterable<T> iterable) sync* {
    final it = iterable.iterator;
    if (!it.moveNext()) {
      return;
    }
    T previous = it.current;
    while (it.moveNext()) {
      T current = it.current;
      yield (previous, current);
      previous = current;
    }
  }
}
