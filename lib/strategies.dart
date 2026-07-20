import 'dart:convert';
import 'dart:collection';
import 'dart:math';

import 'assets.dart';
import 'markets.dart';
import 'oracle.dart';
import 'position_analyzer.dart';
import 'renderers.dart';

class CoveredCall {
  final Commodity underlying;
  final Commodity money;
  final Option option;
  final DateTime expiration;
  final Market spotMarket;
  final Market callMarket;

  final PositionAnalyzer analyzer;

  final Position strategy;
  final Line optionLeg;
  final Line underlyingLeg;
  final Line moneyLeg;

  // This is an imaginary approach to executing the trade:
  // First buy this much underlying asset (via spot market),
  // then open the option leg.
  final Line underlyingToBuy;
  late final Line premiumToReceive;

  final double spotPrice;
  final PriceInfo strikePrice;
  late final double moneyProfit; // of minimum position.

  late final double moneyYield;
  late final double underlyingYield;
  late final PriceInfo breakEvenVsFullUnderlying;
  late final PriceInfo breakEvenVsFullMoney;
  final double? moneyProbability;
  final double? underlyingProbability;

  String? get callURL => AssetRenderer.tryRenderFirst(optionLeg.asset);

  String? get underlyingURL => AssetRenderer.tryRenderFirst(underlying);

  String? get strategyURL => PositionRenderer.tryRenderFirst(strategy);

  Map<String, dynamic> toJson() => {
        'id': '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}',
        'strategyType': 'coveredCall',
        'strategyURL': strategyURL,
        'moneyYield': moneyYield,
        'underlyingYield': underlyingYield,

        'underlying': underlying.name,
        'underlyingURL': underlyingURL,
        'underlyingToBuy': underlyingToBuy.size,
        'premiumToReceive': premiumToReceive.size,
        'money': money.name,
        'moneySize': moneyLeg.size,
        'moneyProfit': moneyProfit,
        'spotPrice': spotPrice,
        'call': optionLeg.asset.name,
        'callURL': callURL,
        'callSize': optionLeg.size,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'strikeAbsolute': strikePrice.absolute,
        'strikeRelative': strikePrice.relative,

        // Where does this CC meet with the strategy of 100% underlying?
        'breakEvenVsFullUnderlyingAbsolute': breakEvenVsFullUnderlying.absolute,
        'breakEvenVsFullUnderlyingRelative': breakEvenVsFullUnderlying.relative,
        // Where does this CC meet with the strategy of 100% money?
        'breakEvenVsFullMoneyAbsolute': breakEvenVsFullMoney.absolute,
        'breakEvenVsFullMoneyRelative': breakEvenVsFullMoney.relative,
        'moneyProbability': moneyProbability,
        'underlyingProbability': underlyingProbability,
      };

  @override
  String toString() => jsonEncode(this);

  CoveredCall._(this.strategy,
      {required this.spotMarket,
      required this.callMarket,
      required this.underlying,
      required this.money,
      required this.option,
      required this.expiration,
      required this.spotPrice,
      this.moneyProbability,
      this.underlyingProbability})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money),
        moneyLeg = strategy[money],
        underlyingLeg = strategy[underlying],
        optionLeg = strategy[option],
        underlyingToBuy = spotMarket.toAsset(-strategy[money]),
        strikePrice = PriceInfo.fromAbsolute(option.strike, spotPrice) {
    premiumToReceive =
        (strategy[underlying] - underlyingToBuy).singleton(underlying);
    moneyYield = analyzer.maxYield;
    underlyingYield = premiumToReceive.size / underlyingToBuy.size + 1.0;
    moneyProfit = analyzer.maxProfit;
    breakEvenVsFullUnderlying = PriceInfo.fromAbsolute(
        strategy
            .analyzeVersus(moneyLeg + spotMarket.toAsset(-moneyLeg),
                underlying: underlying, money: money)
            .breakevens
            .last
            .price,
        spotPrice);
    if (analyzer.breakevens.isEmpty) {
      throw Exception("No breakeven!\nStrategy: $strategy\n"
          "Analyzer: $analyzer");
    }
    // Breakeven could be a whole range, for a profit-less strategy.
    breakEvenVsFullMoney =
        PriceInfo.fromAbsolute(analyzer.breakevens.first.fromPrice, spotPrice);
  }

  static Iterable<CoveredCall> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    final spreads = VerticalSpread.generateAll(allMarkets,
        underlying: underlying, money: money, slippage: slippage);
    final probs = Probabilities(spreads, underlying: underlying, money: money);

    for (final call in allMarkets
        .whereUnderlyingIs(underlying)
        .calls
        .coercedToMoney(money, oracle)
        .sortByStrike(Order.asc)
        .sortByExpiration(Order.asc)) {
      try {
        final option = call.asset.toOption;
        final expiration = call.asset.toExpirable.expiration;
        double? moneyProb;
        double? underlyingProb;
        try {
          moneyProb = probs.getProbabilityExpiringAbove(expiration, option.strike);
          underlyingProb = 1.0 - moneyProb;
        } catch (_) {
          // Out of bounds or not found
        }

        yield CoveredCall._(
            (call.short(slippage) +
                    spotMarket.long(slippage) *
                        option.contractLot) *
                option.minSize,
            spotMarket: spotMarket,
            callMarket: call,
            underlying: underlying,
            money: money,
            option: option,
            expiration: expiration,
            spotPrice: spotMarket.midPrice,
            moneyProbability: moneyProb,
            underlyingProbability: underlyingProb);
      } catch (e) {
        print("Skipped Covered Call on $call due to error: $e");
      }
    }
  }
}

class LongCall {
  final Commodity underlying;
  final Commodity money;
  final Option option;
  final DateTime expiration;
  final Market spotMarket;
  final Market callMarket;

  final PositionAnalyzer analyzer;

  final Position strategy;
  final Line optionLeg;
  final Line moneyLeg;

  final double spotPrice;
  final PriceInfo strikePrice;
  // Cost of the call in units of underlying.
  final Line costInUnderlying;
  late final double maxLeverage;

  late final PriceInfo breakEvenVsFullUnderlying;
  // This is also the hurdle.
  late final PriceInfo breakEvenVsFullMoney;

  String? get callURL => AssetRenderer.tryRenderFirst(optionLeg.asset);

  String? get underlyingURL => AssetRenderer.tryRenderFirst(underlying);

  String? get strategyURL => PositionRenderer.tryRenderFirst(strategy);

  Map<String, dynamic> toJson() => {
        'id': '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}~C',
        'strategyType': 'longCall',
        'strategyURL': strategyURL,
        'maxLeverage': maxLeverage,

        'underlying': underlying.name,
        'underlyingURL': underlyingURL,
        'costInUnderlying': costInUnderlying.size,
        'moneySize': moneyLeg.size,
        'money': money.name,
        'spotPrice': spotPrice,
        'call': optionLeg.asset.name,
        'callURL': callURL,
        'callSize': optionLeg.size,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'strikeAbsolute': strikePrice.absolute,
        'strikeRelative': strikePrice.relative,

        // Where does this Long Call meet with the strategy of 100% underlying?
        'breakEvenVsFullUnderlyingAbsolute': breakEvenVsFullUnderlying.absolute,
        'breakEvenVsFullUnderlyingRelative': breakEvenVsFullUnderlying.relative,
        // Where does this Long Call meet with the strategy of 100% money?
        'breakEvenVsFullMoneyAbsolute': breakEvenVsFullMoney.absolute,
        'breakEvenVsFullMoneyRelative': breakEvenVsFullMoney.relative,
      };

  @override
  String toString() => jsonEncode(this);

  LongCall._(this.strategy,
      {required this.spotMarket,
      required this.callMarket,
      required this.underlying,
      required this.money,
      required this.option,
      required this.expiration,
      required this.spotPrice})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money),
        optionLeg = strategy[option],
        moneyLeg = strategy[money],
        costInUnderlying = spotMarket.toAsset(-strategy[money]),
        strikePrice = PriceInfo.fromAbsolute(option.strike, spotPrice) {
    if (analyzer.breakevens.isEmpty) {
      throw Exception("No breakeven!\nStrategy: $strategy\n"
          "Analyzer: $analyzer");
    }
    breakEvenVsFullMoney =
        PriceInfo.fromAbsolute(analyzer.breakevens.first.fromPrice, spotPrice);

    final breakevensVsUnderlying = strategy
        .analyzeVersus(moneyLeg + spotMarket.toAsset(-moneyLeg),
            underlying: underlying, money: money)
        .breakevens;
    breakEvenVsFullUnderlying =
        PriceInfo.fromAbsolute(breakevensVsUnderlying.last.price, spotPrice);

    // TODO: compute this as follows:
    // analyzer.deltaAfter(double.infinity) /
    // analyzer(fullUnderlyingStrategy).deltaAfter(double.infinity)
    maxLeverage = optionLeg.size / costInUnderlying.size;
  }

  static Iterable<LongCall> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    for (final call in allMarkets
        .whereUnderlyingIs(underlying)
        .calls
        .coercedToMoney(money, oracle)
        .sortByStrike(Order.asc)
        .sortByExpiration(Order.asc)) {
      try {
        yield LongCall._(call.long(slippage) * call.asset.toOption.minSize,
            spotMarket: spotMarket,
            callMarket: call,
            underlying: underlying,
            money: money,
            option: call.asset.toOption,
            expiration: call.asset.toExpirable.expiration,
            spotPrice: spotMarket.midPrice);
      } catch (e) {
        print("Skipped Long Call on $call due to error: $e");
      }
    }
  }
}

class LongPut {
  final Commodity underlying;
  final Commodity money;
  final Option option;
  final DateTime expiration;
  final Market spotMarket;
  final Market putMarket;

  final PositionAnalyzer analyzer;

  final Position strategy;
  final Line optionLeg;
  final Line moneyLeg;

  final double spotPrice;
  final PriceInfo strikePrice;
  // Cost of the put in units of underlying.
  final Line costInUnderlying;
  late final double maxLeverage;

  // Referring to the money Yield (the profit, relative to the capital used) if the underlying goes to zero!
  late final double maxMoneyYield;
  // Referring to the money Profit (the absolute profit) if the underlying goes to zero!
  late final double maxMoneyProfit;

  late final PriceInfo breakEvenVsFullUnderlying;
  // This is also the hurdle.
  late final PriceInfo breakEvenVsFullMoney;

  String? get putURL => AssetRenderer.tryRenderFirst(optionLeg.asset);

  String? get underlyingURL => AssetRenderer.tryRenderFirst(underlying);

  String? get strategyURL => PositionRenderer.tryRenderFirst(strategy);

  Map<String, dynamic> toJson() => {
        'id': '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}~P',
        'strategyType': 'longPut',
        'strategyURL': strategyURL,
        'maxLeverage': maxLeverage,
        'maxMoneyYield': maxMoneyYield,
        'maxMoneyProfit': maxMoneyProfit,
        'underlying': underlying.name,
        'underlyingURL': underlyingURL,
        'costInUnderlying': costInUnderlying.size,
        'moneySize': moneyLeg.size,
        'money': money.name,
        'spotPrice': spotPrice,
        'put': optionLeg.asset.name,
        'putURL': putURL,
        'putSize': optionLeg.size,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'strikeAbsolute': strikePrice.absolute,
        'strikeRelative': strikePrice.relative,

        // Where does this Long Put meet with the strategy of 100% underlying?
        'breakEvenVsFullUnderlyingAbsolute': breakEvenVsFullUnderlying.absolute,
        'breakEvenVsFullUnderlyingRelative': breakEvenVsFullUnderlying.relative,
        // Where does this Long Put meet with the strategy of 100% money?
        'breakEvenVsFullMoneyAbsolute': breakEvenVsFullMoney.absolute,
        'breakEvenVsFullMoneyRelative': breakEvenVsFullMoney.relative,
      };

  @override
  String toString() => jsonEncode(this);

  LongPut._(this.strategy,
      {required this.spotMarket,
      required this.putMarket,
      required this.underlying,
      required this.money,
      required this.option,
      required this.expiration,
      required this.spotPrice})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money),
        optionLeg = strategy[option],
        moneyLeg = strategy[money],
        costInUnderlying = spotMarket.toAsset(-strategy[money]),
        strikePrice = PriceInfo.fromAbsolute(option.strike, spotPrice) {
    if (analyzer.breakevens.isEmpty) {
      throw Exception("No breakeven!\nStrategy: $strategy\n"
          "Analyzer: $analyzer");
    }
    breakEvenVsFullMoney =
        PriceInfo.fromAbsolute(analyzer.breakevens.first.fromPrice, spotPrice);

    final breakevensVsUnderlying = strategy
        .analyzeVersus(moneyLeg + spotMarket.toAsset(-moneyLeg),
            underlying: underlying, money: money)
        .breakevens;
    breakEvenVsFullUnderlying =
        PriceInfo.fromAbsolute(breakevensVsUnderlying.last.price, spotPrice);

    // TODO: compute this as follows:
    // analyzer.deltaBefore(0.0) /
    // analyzer(fullUnderlyingStrategy).deltaBefore(0.0)
    maxLeverage = optionLeg.size / costInUnderlying.size;
    maxMoneyYield = analyzer.maxYield;
    maxMoneyProfit = analyzer.maxProfit;
  }

  static Iterable<LongPut> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    for (final put in allMarkets
        .whereUnderlyingIs(underlying)
        .puts
        .coercedToMoney(money, oracle)
        .sortByStrike(Order.desc)
        .sortByExpiration(Order.asc)) {
      try {
        yield LongPut._(put.long(slippage) * put.asset.toOption.minSize,
            spotMarket: spotMarket,
            putMarket: put,
            underlying: underlying,
            money: money,
            option: put.asset.toOption,
            expiration: put.asset.toExpirable.expiration,
            spotPrice: spotMarket.midPrice);
      } catch (e) {
        print("Skipped Long Put on $put due to error: $e");
      }
    }
  }
}

class Straddle {
  final Commodity underlying;
  final Commodity money;
  final Option callOption;
  final Option putOption;
  final DateTime expiration;
  final Market spotMarket;
  final Market callMarket;
  final Market putMarket;
  final double slippage;

  final PositionAnalyzer analyzer;

  final Position strategy;
  final Line callLeg;
  final Line putLeg;
  final Line moneyLeg;

  final double spotPrice;
  final PriceInfo strikePrice;
  // Cost of the straddle in units of underlying.
  final Line costInUnderlying;
  late final PriceInfo distanceBetweenBreakEvens;

  late final PriceInfo breakEvenVsFullUnderlyingDown;
  late final PriceInfo breakEvenVsFullUnderlyingUp;
  late final PriceInfo breakEvenVsFullMoneyDown;
  late final PriceInfo breakEvenVsFullMoneyUp;

  String? get callURL => AssetRenderer.tryRenderFirst(callLeg.asset);
  String? get putURL => AssetRenderer.tryRenderFirst(putLeg.asset);
  String? get underlyingURL => AssetRenderer.tryRenderFirst(underlying);
  String? get strategyURL => PositionRenderer.tryRenderFirst(strategy);

  Map<String, dynamic> toJson() => {
        'id': '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}',
        'strategyType': 'straddle',
        'strategyURL': strategyURL,
        'underlying': underlying.name,
        'underlyingURL': underlyingURL,
        'costInUnderlying': costInUnderlying.size,
        'moneySize': moneyLeg.size,
        'money': money.name,
        'spotPrice': spotPrice,
        'call': callLeg.asset.name,
        'callURL': callURL,
        'callSize': callLeg.size,
        'callCostInMoney': callLeg.size * callMarket.buyPrice(slippage),
        'callCostInUnderlying': spotMarket
            .toAsset(money.ofSize(callLeg.size * callMarket.buyPrice(slippage)),
                slippage)
            .size,
        'put': putLeg.asset.name,
        'putURL': putURL,
        'putSize': putLeg.size,
        'putCostInMoney': putLeg.size * putMarket.buyPrice(slippage),
        'putCostInUnderlying': spotMarket
            .toAsset(money.ofSize(putLeg.size * putMarket.buyPrice(slippage)),
                slippage)
            .size,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'strikeAbsolute': strikePrice.absolute,
        'strikeRelative': strikePrice.relative,
        'distanceBetweenBreakEvensAbsolute': distanceBetweenBreakEvens.absolute,
        'distanceBetweenBreakEvensRelative': distanceBetweenBreakEvens.relative,
        'breakEvenVsFullMoneyDownAbsolute': breakEvenVsFullMoneyDown.absolute,
        'breakEvenVsFullMoneyDownRelative': breakEvenVsFullMoneyDown.relative,
        'breakEvenVsFullMoneyUpAbsolute': breakEvenVsFullMoneyUp.absolute,
        'breakEvenVsFullMoneyUpRelative': breakEvenVsFullMoneyUp.relative,
        'breakEvenVsFullUnderlyingDownAbsolute':
            breakEvenVsFullUnderlyingDown.absolute,
        'breakEvenVsFullUnderlyingDownRelative':
            breakEvenVsFullUnderlyingDown.relative,
        'breakEvenVsFullUnderlyingUpAbsolute':
            breakEvenVsFullUnderlyingUp.absolute,
        'breakEvenVsFullUnderlyingUpRelative':
            breakEvenVsFullUnderlyingUp.relative,
      };

  @override
  String toString() => jsonEncode(this);

  Straddle._(this.strategy,
      {required this.spotMarket,
      required this.callMarket,
      required this.putMarket,
      required this.underlying,
      required this.money,
      required this.expiration,
      required this.spotPrice,
      required this.slippage})
      : callOption = callMarket.asset.toOption,
        putOption = putMarket.asset.toOption,
        analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money),
        callLeg = strategy[callMarket.asset.toOption],
        putLeg = strategy[putMarket.asset.toOption],
        moneyLeg = strategy[money],
        costInUnderlying = spotMarket.toAsset(-strategy[money]),
        strikePrice = PriceInfo.fromAbsolute(
            callMarket.asset.toOption.strike, spotPrice) {
    // ignore: unused_local_variable
    final size = callLeg.size;
    final bvsMoney = analyzer.breakevens.toList();
    if (bvsMoney.length < 2) {
      throw Exception(
          "Expected at least two breakevens versus money for Straddle!\n"
          "Strategy: $strategy\n"
          "Analyzer: $analyzer");
    }
    breakEvenVsFullMoneyDown =
        PriceInfo.fromAbsolute(bvsMoney.first.fromPrice, spotPrice);
    breakEvenVsFullMoneyUp =
        PriceInfo.fromAbsolute(bvsMoney.last.fromPrice, spotPrice);
    distanceBetweenBreakEvens = PriceInfo.fromAbsolute(
        breakEvenVsFullMoneyUp.absolute - breakEvenVsFullMoneyDown.absolute,
        spotPrice);

    final breakevensVsUnderlying = strategy
        .analyzeVersus(moneyLeg + spotMarket.toAsset(-moneyLeg),
            underlying: underlying, money: money)
        .breakevens
        .toList();
    if (breakevensVsUnderlying.length < 2) {
      throw Exception(
          "Expected at least two breakevens versus underlying for Straddle!\n"
          "Strategy: $strategy\n"
          "Analyzer: $analyzer");
    }
    breakEvenVsFullUnderlyingDown = PriceInfo.fromAbsolute(
        breakevensVsUnderlying.first.fromPrice, spotPrice);
    breakEvenVsFullUnderlyingUp = PriceInfo.fromAbsolute(
        breakevensVsUnderlying.last.fromPrice, spotPrice);
  }

  static Iterable<Straddle> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5}) sync* {
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    final spotPrice = spotMarket.midPrice;

    // Group option markets by expiration, then by strike
    final expirationGroups = allMarkets
        .whereUnderlyingIs(underlying)
        .optionsWithStrikeInMoney(money)
        .coercedToMoney(money, oracle)
        .groupByExpiration(Order.asc);

    for (final entry in expirationGroups.entries) {
      final expiration = entry.key;
      final strikeGroups = entry.value.groupByStrike(Order.asc);

      Straddle? bestStraddle;

      for (final strikeEntry in strikeGroups.entries) {
        final markets = strikeEntry.value;
        final callMarket = markets.calls.singleOrNull;
        final putMarket = markets.puts.singleOrNull;

        if (callMarket != null && putMarket != null) {
          try {
            final minSize = max(callMarket.asset.toOption.minSize,
                putMarket.asset.toOption.minSize);
            final strategy = (callMarket.long(slippage) * minSize) +
                (putMarket.long(slippage) * minSize);
            final straddle = Straddle._(
              strategy,
              callMarket: callMarket,
              putMarket: putMarket,
              spotMarket: spotMarket,
              underlying: underlying,
              money: money,
              expiration: expiration,
              spotPrice: spotPrice,
              slippage: slippage,
            );

            // Retain the centered straddle (closest to spot price).
            if (bestStraddle == null ||
                (straddle.strikePrice.absolute - spotPrice).abs() <
                    (bestStraddle.strikePrice.absolute - spotPrice).abs()) {
              bestStraddle = straddle;
            }
          } catch (e) {
            print("Skipped Straddle at ${strikeEntry.key} due to error: $e");
          }
        }
      }

      if (bestStraddle != null) {
        yield bestStraddle;
      }
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

  final Option shortOption;
  final Option longOption;
  final Market shortMarket;
  final Market longMarket;

  final Position strategy;
  final Line shortLeg;
  final Line longLeg;
  final Line moneyLeg;
  late final VerticalSpreadType type;

  final Market spotMarket;
  final double spotPrice;

  late final PriceInfo? breakEvenVsFullMoney;
  late final PriceInfo? breakEvenVsFullUnderlying;
  late final double maxYield;
  late final PriceInfo maxYieldAt;
  late final double maxRisk;
  late final PriceInfo maxRiskAt;
  late final double maxProbBelow;
  late final double maxProbAbove;

  String? get shortLegURL => AssetRenderer.tryRenderFirst(shortLeg.asset);
  String? get longLegURL => AssetRenderer.tryRenderFirst(longLeg.asset);
  String? get underlyingURL => AssetRenderer.tryRenderFirst(underlying);
  String? get strategyURL => PositionRenderer.tryRenderFirst(strategy);

  Map<String, dynamic> toJson() => {
        'id': '${_formatDate(expiration)}~${_formatDouble(shortOption.strike)}~${_formatDouble(longOption.strike)}~${shortOption.isCall ? 'call' : 'put'}',
        'strategyType': 'verticalSpread',
        'strategyURL': strategyURL,
        'underlying': underlying.name,
        'underlyingURL': underlyingURL,
        'money': money.name,
        'moneySize': moneyLeg.size,
        'spotPrice': spotPrice,
        'shortLeg': shortLeg.asset.name,
        'shortLegURL': shortLegURL,
        'longLeg': longLeg.asset.name,
        'longLegURL': longLegURL,
        'type': type.name,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'breakEvenVsFullMoneyAbsolute': breakEvenVsFullMoney?.absolute,
        'breakEvenVsFullMoneyRelative': breakEvenVsFullMoney?.relative,
        'breakEvenVsFullUnderlyingAbsolute':
            breakEvenVsFullUnderlying?.absolute,
        'breakEvenVsFullUnderlyingRelative':
            breakEvenVsFullUnderlying?.relative,
        'maxYield': maxYield,
        'maxYieldAtAbsolute': maxYieldAt.absolute,
        'maxYieldAtRelative': maxYieldAt.relative,
        'maxRisk': maxRisk,
        'maxRiskAtAbsolute': maxRiskAt.absolute,
        'maxRiskAtRelative': maxRiskAt.relative,
        'maxProbBelow': maxProbBelow,
        'maxProbAbove': maxProbAbove,
      };

  VerticalSpread._(this.strategy,
      {required this.underlying,
      required this.money,
      required this.shortOption,
      required this.longOption,
      required this.shortMarket,
      required this.longMarket,
      required this.expiration,
      required this.spotMarket,
      required this.spotPrice})
      : analyzer =
            PositionAnalyzer(strategy, underlying: underlying, money: money),
        moneyLeg = strategy[money],
        shortLeg = strategy[shortOption],
        longLeg = strategy[longOption] {
    type = longOption.strike < shortOption.strike
        ? VerticalSpreadType.over
        : VerticalSpreadType.under;

    final denom = analyzer.maxValue - analyzer.minValue;
    final r = (denom > 0.0 ? -analyzer.minValue / denom : 0.0).clamp(0.0, 1.0);
    if (type == VerticalSpreadType.over) {
      maxProbAbove = r;
      maxProbBelow = 1.0;
    } else {
      maxProbBelow = r;
      maxProbAbove = 1.0;
    }

    final double? breakevenDouble =
        pickNearestBoundary(spotPrice, analyzer.breakevens);
    breakEvenVsFullMoney = breakevenDouble != null
        ? PriceInfo.fromAbsolute(breakevenDouble, spotPrice)
        : null;

    final breakevensVsUnderlying = strategy
        .analyzeVersus(moneyLeg + spotMarket.toAsset(-moneyLeg),
            underlying: underlying, money: money)
        .breakevens;
    final double? breakevenUnderlyingDouble =
        pickNearestBoundary(spotPrice, breakevensVsUnderlying);
    breakEvenVsFullUnderlying = breakevenUnderlyingDouble != null
        ? PriceInfo.fromAbsolute(breakevenUnderlyingDouble, spotPrice)
        : null;

    maxYield = analyzer.maxYield;
    maxYieldAt = PriceInfo.fromAbsolute(
        pickNearestBoundary(spotPrice, analyzer.bestPrices)!, spotPrice);
    maxRisk = analyzer.maxRisk;
    maxRiskAt = PriceInfo.fromAbsolute(
        pickNearestBoundary(spotPrice, analyzer.worstPrices)!, spotPrice);
  }

  static double? pickNearestBoundary(
          double target, Iterable<PriceRange> priceRanges) =>
      pickNearest(
          target,
          priceRanges.expand(
              (priceRange) => [priceRange.fromPrice, priceRange.toPrice]));

  static double? pickNearest(double target, Iterable<double> candidates) {
    final it = candidates.iterator;
    if (!it.moveNext()) {
      return null;
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
            .optionsWithStrikeInMoney(money)
            .coercedToMoney(money, oracle)
            .groupByExpiration(Order.asc)
            .mapValues((ms) => ms.groupByStrike(Order.asc).mapValues((ms) =>
                (call: ms.calls.singleOrNull, put: ms.puts.singleOrNull)))
            .entries) {
      final expiration = expirationToStrike.key,
          strikeToOptions = expirationToStrike.value;
      VerticalSpread makeSpread(
              Position position, Option shortOption, Option longOption,
              Market shortMarket, Market longMarket) =>
          VerticalSpread._(position,
              underlying: underlying,
              money: money,
              shortOption: shortOption,
              longOption: longOption,
              shortMarket: shortMarket,
              longMarket: longMarket,
              expiration: expiration,
              spotMarket: spotMarket,
              spotPrice: spotPrice);

      for (final (lowStrike, highStrike) in _pairUp(strikeToOptions.keys)) {
        final (call: lowCall, put: lowPut) = strikeToOptions[lowStrike]!;
        final (call: highCall, put: highPut) = strikeToOptions[highStrike]!;

        // under @ lowStrike
        VerticalSpread? under = keepBestValidSpread([
          if (lowPut != null && highPut != null)
            makeSpread(highPut.long(slippage) + lowPut.short(slippage),
                lowPut.asset.toOption, highPut.asset.toOption, lowPut, highPut),
          if (lowCall != null && highCall != null)
            makeSpread(highCall.long(slippage) + lowCall.short(slippage),
                lowCall.asset.toOption, highCall.asset.toOption, lowCall, highCall),
        ]);

        // over @ highStrike
        VerticalSpread? over = keepBestValidSpread([
          if (lowPut != null && highPut != null)
            makeSpread(highPut.short(slippage) + lowPut.long(slippage),
                highPut.asset.toOption, lowPut.asset.toOption, highPut, lowPut),
          if (lowCall != null && highCall != null)
            makeSpread(highCall.short(slippage) + lowCall.long(slippage),
                highCall.asset.toOption, lowCall.asset.toOption, highCall, lowCall),
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

class PriceInfo {
  final double absolute;
  final double relative;

  PriceInfo(this.absolute, this.relative);

  static PriceInfo fromAbsolute(
          double absoluteTargetPrice, double baseAbsolutePrice) =>
      PriceInfo(absoluteTargetPrice, absoluteTargetPrice / baseAbsolutePrice);

  static PriceInfo fromRelative(
          double relativeTargetPrice, double baseAbsolutePrice) =>
      fromAbsolute(relativeTargetPrice * baseAbsolutePrice, baseAbsolutePrice);
}

String _formatDate(DateTime dt) =>
    "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

String _formatDouble(double val) {
  if (val == val.toInt()) {
    return val.toInt().toString();
  }
  return val.toString();
}

class Probabilities {
  final Map<DateTime, Map<double, double>> _probs = {};
  final Map<DateTime, Map<double, List<VerticalSpread>>> _contributingSpreads = {};
  final Map<DateTime, double> _atmStrikes = {};

  Map<DateTime, Map<double, double>> get distributions => _probs;
  Map<DateTime, double> get atmStrikes => _atmStrikes;

  Probabilities(Iterable<VerticalSpread> spreads,
      {required Commodity underlying, required Commodity money}) {
    // 1. Group spreads by expiration
    final Map<DateTime, List<VerticalSpread>> byExpiration = {};
    for (final vs in spreads) {
      if (vs.underlying != underlying || vs.money != money) continue;

      // Exclude spreads with missing/non-existent bids or asks
      if (vs.shortMarket.bidPrice <= 0.0 ||
          vs.shortMarket.askPrice <= 0.0 ||
          vs.longMarket.bidPrice <= 0.0 ||
          vs.longMarket.askPrice <= 0.0) {
        continue;
      }

      byExpiration.putIfAbsent(vs.expiration, () => []).add(vs);
    }

    // 2. Process each expiration
    for (final entry in byExpiration.entries) {
      final expiration = entry.key;
      final expSpreads = entry.value;

      // Group spreads by strike
      final Map<double, List<VerticalSpread>> byStrike = {};
      for (final vs in expSpreads) {
        byStrike.putIfAbsent(vs.shortOption.strike, () => []).add(vs);
      }

      // Find all call and put options for this expiration to locate the ATM flip point
      final Map<double, Market> callMarkets = {};
      final Map<double, Market> putMarkets = {};
      for (final vs in expSpreads) {
        for (final option in [vs.shortOption, vs.longOption]) {
          final market = (option == vs.shortOption) ? vs.shortMarket : vs.longMarket;
          if (option.isCall) {
            callMarkets[option.strike] = market;
          } else {
            putMarkets[option.strike] = market;
          }
        }
      }

      final commonStrikes = callMarkets.keys.where((s) => putMarkets.containsKey(s)).toList()..sort();
      double? atmStrike;

      for (final strike in commonStrikes) {
        final mCall = callMarkets[strike]!;
        final mPut = putMarkets[strike]!;
        final diff = (mCall.bidPrice + mCall.askPrice) / 2.0 -
            (mPut.bidPrice + mPut.askPrice) / 2.0;
        if (diff == 0.0) {
          atmStrike = strike;
          break;
        }
      }

      if (atmStrike == null) {
        for (int i = 0; i < commonStrikes.length - 1; i++) {
          final k1 = commonStrikes[i];
          final k2 = commonStrikes[i + 1];

          final mCall1 = callMarkets[k1]!;
          final mPut1 = putMarkets[k1]!;
          final mCall2 = callMarkets[k2]!;
          final mPut2 = putMarkets[k2]!;

          final diff1 = (mCall1.bidPrice + mCall1.askPrice) / 2.0 -
              (mPut1.bidPrice + mPut1.askPrice) / 2.0;
          final diff2 = (mCall2.bidPrice + mCall2.askPrice) / 2.0 -
              (mPut2.bidPrice + mPut2.askPrice) / 2.0;

          if (diff1 > 0.0 && diff2 < 0.0) {
            final t = -diff1 / (diff2 - diff1);
            atmStrike = k1 + t * (k2 - k1);
            break;
          }
        }
      }

      final Map<double, double> rawProbs = {};
      final Map<double, List<VerticalSpread>> strikeToSpreads = {};
      final Map<double, double> strikeWeights = {};

      for (final strikeEntry in byStrike.entries) {
        final strike = strikeEntry.key;
        final strikeSpreads = strikeEntry.value;

        VerticalSpread? overSpread;
        VerticalSpread? underSpread;

        for (final vs in strikeSpreads) {
          if (vs.type == VerticalSpreadType.over) {
            overSpread = vs;
          } else if (vs.type == VerticalSpreadType.under) {
            underSpread = vs;
          }
        }

        double prob;
        // Represents the market quality (reliability) of the probability estimate at this strike.
        // It is computed as the sum of the inverse relative spreads of the contributing vertical spreads.
        // Higher weight indicates tighter bid-ask spreads (higher liquidity and accuracy).
        double weight;
        if (overSpread != null && underSpread != null) {
          final maxProbAbove = overSpread.maxProbAbove;
          final minProbAbove = 1.0 - underSpread.maxProbBelow;

          final spreadOver = overSpread.shortMarket.relativeSpread +
              overSpread.longMarket.relativeSpread;
          final spreadUnder = underSpread.shortMarket.relativeSpread +
              underSpread.longMarket.relativeSpread;

          final weightOver = spreadOver <= 0.0 ? 1e9 : 1.0 / spreadOver;
          final weightUnder = spreadUnder <= 0.0 ? 1e9 : 1.0 / spreadUnder;

          prob = (maxProbAbove * weightOver + minProbAbove * weightUnder) / (weightOver + weightUnder);
          weight = weightOver + weightUnder;
        } else if (overSpread != null) {
          prob = overSpread.maxProbAbove;
          final spreadOver = overSpread.shortMarket.relativeSpread +
              overSpread.longMarket.relativeSpread;
          weight = spreadOver <= 0.0 ? 1e9 : 1.0 / spreadOver;
        } else if (underSpread != null) {
          prob = 1.0 - underSpread.maxProbBelow;
          final spreadUnder = underSpread.shortMarket.relativeSpread +
              underSpread.longMarket.relativeSpread;
          weight = spreadUnder <= 0.0 ? 1e9 : 1.0 / spreadUnder;
        } else {
          continue;
        }

        rawProbs[strike] = prob;
        strikeWeights[strike] = weight;
        if (overSpread != null || underSpread != null) {
          strikeToSpreads[strike] = [
            if (overSpread != null) overSpread,
            if (underSpread != null) underSpread,
          ];
        }
      }

      if (atmStrike != null) {
        _atmStrikes[expiration] = atmStrike;
        rawProbs[atmStrike] = 0.5;
        strikeWeights[atmStrike] = 1e12; // Top priority anchor
      }

      // Enforce monotonicity by prioritizing strikes with higher market quality (larger weights)
      final sortedByWeight = rawProbs.keys.toList()
        ..sort((a, b) {
          final cmp = strikeWeights[b]!.compareTo(strikeWeights[a]!);
          if (cmp == 0) return a.compareTo(b);
          return cmp;
        });

      final Map<double, double> monotonicProbs = {};

      for (final strike in sortedByWeight) {
        final prob = rawProbs[strike]!;
        bool isCompatible = true;
        for (final acceptedStrike in monotonicProbs.keys) {
          final acceptedProb = monotonicProbs[acceptedStrike]!;
          if (strike < acceptedStrike && prob < acceptedProb) {
            isCompatible = false;
            break;
          }
          if (strike > acceptedStrike && prob > acceptedProb) {
            isCompatible = false;
            break;
          }
        }
        if (isCompatible) {
          monotonicProbs[strike] = prob;
        }
      }

      // Sort the final map by strike price ascending
      final sortedStrikes = monotonicProbs.keys.toList()..sort();
      final Map<double, double> sortedMonotonicProbs = {
        for (final s in sortedStrikes) s: monotonicProbs[s]!
      };

      _probs[expiration] = sortedMonotonicProbs;
      _contributingSpreads[expiration] = strikeToSpreads;
    }
  }

  List<VerticalSpread> getContributingSpreads(DateTime expiration, double strike) {
    return _contributingSpreads[expiration]?[strike] ?? const [];
  }

  double getProbabilityExpiringAbove(DateTime expiration, double strike) {
    final expProbs = _probs[expiration];
    if (expProbs == null || expProbs.isEmpty) {
      throw ArgumentError("No probability distribution found for expiration $expiration");
    }

    final strikes = expProbs.keys.toList()..sort();
    if (strike < strikes.first || strike > strikes.last) {
      throw ArgumentError("Extrapolation is not allowed. Strike $strike is outside the known range [${strikes.first}, ${strikes.last}]");
    }

    if (expProbs.containsKey(strike)) {
      return expProbs[strike]!;
    }

    int i = 0;
    while (i < strikes.length && strikes[i] < strike) {
      i++;
    }
    final kLower = strikes[i - 1];
    final kUpper = strikes[i];
    final pLower = expProbs[kLower]!;
    final pUpper = expProbs[kUpper]!;

    final t = (strike - kLower) / (kUpper - kLower);
    return pLower + t * (pUpper - pLower);
  }
}
