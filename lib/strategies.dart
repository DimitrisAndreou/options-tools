import 'dart:convert';
import 'dart:collection';
import 'dart:math';

import 'assets.dart';
import 'markets.dart';
import 'oracle.dart';
import 'position_analyzer.dart';
import 'renderers.dart';

export 'taxes.dart';

class ExecutionInstruction {
  final String action;
  final double size;
  final String unit;
  final double price;
  final String priceUnit;

  const ExecutionInstruction({
    required this.action,
    required this.size,
    required this.unit,
    required this.price,
    required this.priceUnit,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'size': size,
        'unit': unit,
        'price': price,
        'priceUnit': priceUnit,
      };
}

class CoveredCallMetrics {
  final double moneyYield;
  final double underlyingYield;
  final double moneyProfit;
  final Line premiumToReceive;
  final double unassignedTax;
  final PriceInfo? breakEvenVsFullUnderlying;
  final PriceInfo? breakEvenVsFullMoney;

  const CoveredCallMetrics({
    required this.moneyYield,
    required this.underlyingYield,
    required this.moneyProfit,
    required this.premiumToReceive,
    this.unassignedTax = 0.0,
    required this.breakEvenVsFullUnderlying,
    required this.breakEvenVsFullMoney,
  });

  Map<String, dynamic> toJson() => {
        'moneyYield': moneyYield,
        'underlyingYield': underlyingYield,
        'moneyProfit': moneyProfit,
        'premiumToReceive': premiumToReceive.size,
        if (unassignedTax != 0.0) 'unassignedTax': unassignedTax,
        'breakEvenVsFullUnderlying': breakEvenVsFullUnderlying?.toJson(),
        'breakEvenVsFullMoney': breakEvenVsFullMoney?.toJson(),
      };
}

class PositionPnL {
  final double pnl;
  final double yield;

  const PositionPnL({
    required this.pnl,
    required this.yield,
  });

  Map<String, dynamic> toJson() => {
        'pnl': pnl,
        'yield': yield,
      };
}

class ExistingPosition {
  final double unitsHeld;
  final double costBasis;
  final double currentValue;
  final PositionPnL preTax;
  final PositionPnL? postTax;

  const ExistingPosition({
    required this.unitsHeld,
    required this.costBasis,
    required this.currentValue,
    required this.preTax,
    this.postTax,
  });

  Map<String, dynamic> toJson() => {
        'unitsHeld': unitsHeld,
        'costBasis': costBasis,
        'currentValue': currentValue,
        'preTax': preTax.toJson(),
        if (postTax != null) 'postTax': postTax!.toJson(),
      };
}

class CoveredCall {
  final Commodity underlying;
  final Commodity money;
  final Option option;
  final DateTime expiration;
  final Market spotMarket;
  final Market callMarket;
  final TaxProfile taxes;

  final PositionAnalyzer analyzer;
  late final PositionAnalyzer postTaxAnalyzer;

  final Position strategy;
  final Line optionLeg;
  final Line underlyingLeg;
  final Line moneyLeg;

  // This is an imaginary approach to executing the trade:
  // First buy this much underlying asset (via spot market),
  // then open the option leg.
  late final Line underlyingToBuy;

  final double spotPrice;
  final PriceInfo strikePrice;
  final double? moneyProbability;
  final double? underlyingProbability;

  late final CoveredCallMetrics preTax;
  late final CoveredCallMetrics? postTax;
  late final ExistingPosition? existingPosition;

  Line get premiumToReceive => preTax.premiumToReceive;
  double get moneyProfit => preTax.moneyProfit;
  double get moneyYield => preTax.moneyYield;
  double get underlyingYield => preTax.underlyingYield;
  PriceInfo? get breakEvenVsFullUnderlying => preTax.breakEvenVsFullUnderlying;
  PriceInfo? get breakEvenVsFullMoney => preTax.breakEvenVsFullMoney;

  final double? avgPrice;

  double get unitCostBasis =>
      underlyingLeg.unitCostBasis?.size ?? (costBasis / underlyingLeg.size);
  double get costBasis => analyzer.costBasisBefore(option.strike);

  double get callPrice {
    final lot = option.contractLot > 0 ? option.contractLot : 1.0;
    final total = optionLeg.unitCostBasis?.size ?? callMarket.sellPrice();
    return total / lot;
  }

  double get callContractPrice =>
      (optionLeg.unitCostBasis?.size ?? callMarket.sellPrice()) *
      option.minSize;

  double get contractLot => option.contractLot;

  double get minSize => option.minSize;

  String? get callURL => optionLeg.asset.url;

  String? get underlyingURL => underlying.url;

  String? get strategyURL {
    final costBasis = underlyingLeg.unitCostBasis?.size ?? spotPrice;
    final optionCostBasis =
        optionLeg.unitCostBasis?.size ?? callMarket.sellPrice();
    final posWithCostBasis = strategy.withCostBasis({
      underlying: money.ofSize(costBasis),
      option: money.ofSize(optionCostBasis),
    });
    return underlying.source?.strategyUrl(posWithCostBasis);
  }

  List<ExecutionInstruction> get instructions => [
        if (avgPrice == null)
          ExecutionInstruction(
            action: 'Buy',
            size: underlyingToBuy.size,
            unit: underlying.name,
            price: -moneyLeg.size,
            priceUnit: money.name,
          ),
        ExecutionInstruction(
          action: 'Sell',
          size: -optionLeg.size,
          unit: 'call(s)',
          price: avgPrice == null
              ? preTax.premiumToReceive.size
              : analyzer.realizedPnLBefore(option.strike),
          priceUnit: avgPrice == null ? underlying.name : money.name,
        ),
      ];

  Map<String, dynamic> toJson() => {
        'id':
            '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}',
        'strategyType': 'coveredCall',
        'strategyURL': strategyURL,
        'underlying': underlying.name,
        'underlyingURL': underlyingURL,
        'underlyingToBuy': underlyingToBuy.size,
        'money': money.name,
        'moneySize': moneyLeg.size,
        'spotPrice': spotPrice,
        'call': optionLeg.asset.name,
        'callURL': callURL,
        'callSize': optionLeg.size,
        'callPrice': callPrice,
        'callContractPrice': callContractPrice,
        'contractLot': contractLot,
        'minSize': minSize,
        if (avgPrice != null) 'avgPrice': avgPrice,
        if (avgPrice != null) 'underlyingHeld': underlyingLeg.size,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'strikeAbsolute': strikePrice.absolute,
        'strikeRelative': strikePrice.relative,
        'moneyProbability': moneyProbability,
        'underlyingProbability': underlyingProbability,
        'unitCostBasis': unitCostBasis,
        'costBasis': costBasis,
        'underlyingTaxRate': taxes.underlyingTaxRate,
        'derivativeTaxRate': taxes.derivativeTaxRate,
        'instructions': instructions.map((i) => i.toJson()).toList(),
        'preTax': preTax.toJson(),
        if (postTax != null) 'postTax': postTax!.toJson(),
        if (existingPosition != null)
          'existingPosition': existingPosition!.toJson(),
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
      this.underlyingProbability,
      this.avgPrice,
      PositionAnalyzer? existingAnalyzer,
      this.taxes = TaxProfile.none})
      : analyzer = PositionAnalyzer(strategy,
            underlying: underlying,
            money: money,
            maxRisk: existingAnalyzer?.maxRisk),
        moneyLeg = strategy[money],
        underlyingLeg = strategy[underlying],
        optionLeg = strategy[option],
        strikePrice = PriceInfo.fromAbsolute(option.strike, spotPrice) {
    postTaxAnalyzer = analyzer.withTaxes(taxes);
    underlyingToBuy = (strategy[underlying] -
            spotMarket.toAsset(
                money.ofSize(analyzer.realizedPnLBefore(option.strike))))
        .singleton(underlying);

    CoveredCallMetrics metricsFrom(PositionAnalyzer a) {
      final premium = spotMarket
          .toAsset(money.ofSize(a.realizedPnLBefore(option.strike)))
          .singleton(underlying);
      final undBreakevens =
          a.analyzeVersus(moneyLeg + underlyingToBuy).breakevens;
      final beUnd = undBreakevens.isEmpty
          ? null
          : PriceInfo.fromAbsolute(undBreakevens.last.fromPrice, spotPrice);
      // Breakeven could be a whole range (for a zero-profit strategy) or empty
      // (when moneyProfit < 0, i.e. negative money yield).
      final moneyBreakevens = a.breakevens;
      final beMoney = moneyBreakevens.isEmpty
          ? null
          : PriceInfo.fromAbsolute(
              moneyBreakevens.first.fromPrice, spotPrice);

      return CoveredCallMetrics(
        moneyYield: a.yieldAfter(option.strike),
        underlyingYield: premium.size / underlyingToBuy.size + 1.0,
        moneyProfit: a.valueAfter(option.strike),
        premiumToReceive: premium,
        unassignedTax:
            analyzer.valueBefore(option.strike) - a.valueBefore(option.strike),
        breakEvenVsFullUnderlying: beUnd,
        breakEvenVsFullMoney: beMoney,
      );
    }

    preTax = metricsFrom(analyzer);
    postTax = taxes.isTaxFree ? null : metricsFrom(postTaxAnalyzer);

    if (existingAnalyzer == null) {
      existingPosition = null;
    } else {
      PositionPnL evaluateExisting(PositionAnalyzer a) => PositionPnL(
            pnl: a.valueAt(spotPrice),
            yield: a.yieldAt(spotPrice),
          );
      final currentValue = PositionAnalyzer(
        underlyingLeg,
        underlying: underlying,
        money: money,
      ).valueAt(spotPrice);
      existingPosition = ExistingPosition(
        unitsHeld: underlyingLeg.size,
        costBasis: existingAnalyzer.costBasisBefore(spotPrice),
        currentValue: currentValue,
        preTax: evaluateExisting(existingAnalyzer),
        postTax: taxes.isTaxFree
            ? null
            : evaluateExisting(
                existingAnalyzer.withTaxes(taxes).liquidateAt(spotPrice)),
      );
    }

    if (!preTax.moneyYield.isFinite ||
        !preTax.underlyingYield.isFinite ||
        !preTax.moneyProfit.isFinite ||
        (postTax != null &&
            (!postTax!.moneyYield.isFinite ||
                !postTax!.underlyingYield.isFinite ||
                !postTax!.moneyProfit.isFinite)) ||
        (existingPosition != null &&
            (!existingPosition!.currentValue.isFinite ||
                !existingPosition!.preTax.pnl.isFinite ||
                !existingPosition!.preTax.yield.isFinite ||
                (existingPosition!.postTax != null &&
                    (!existingPosition!.postTax!.pnl.isFinite ||
                        !existingPosition!.postTax!.yield.isFinite))))) {
      throw Exception(
          "Non-finite metrics in CoveredCall!\nStrategy: $strategy\n"
          "Analyzer: $analyzer");
    }
  }

  static Iterable<CoveredCall> generateAll(Iterable<Market> allMarkets,
      {required Commodity underlying,
      required Commodity money,
      double slippage = 0.5,
      double? avgPrice,
      int size = 1,
      TaxProfile taxes = TaxProfile.none}) sync* {
    if (size < 1) {
      throw ArgumentError.value(size, 'size', 'Must be at least 1');
    }
    final oracle = Oracle.fromMarkets(allMarkets);
    final spotMarket = oracle.marketFor(asset: underlying, money: money);
    final underlyingMarket = avgPrice == null
        ? spotMarket
        : Market.create(
            asset: spotMarket.asset,
            money: spotMarket.money,
            bidPrice: avgPrice,
            askPrice: avgPrice);
    // Implied probabilities are a property of the market order book rather than
    // the user's execution slippage, so evaluate vertical spreads at mid-price (0.5).
    final spreads = VerticalSpread.generateAll(allMarkets,
        underlying: underlying, money: money, slippage: 0.5);
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
          moneyProb =
              probs.getProbabilityExpiringAbove(expiration, option.strike);
          underlyingProb = 1.0 - moneyProb;
        } catch (_) {
          // Out of bounds or not found
        }

        final Position underlyingPosition = underlyingMarket.long(slippage) *
            option.contractLot *
            option.minSize *
            size.toDouble();
        final Position strategy =
            call.short(slippage) * option.minSize * size.toDouble() +
                underlyingPosition;
        final PositionAnalyzer? existingAnalyzer = avgPrice == null
            ? null
            : PositionAnalyzer(underlyingPosition,
                underlying: underlying, money: money);

        yield CoveredCall._(
          strategy,
          spotMarket: spotMarket,
          callMarket: call,
          underlying: underlying,
          money: money,
          option: option,
          expiration: expiration,
          spotPrice: spotMarket.midPrice,
          moneyProbability: moneyProb,
          underlyingProbability: underlyingProb,
          avgPrice: avgPrice,
          existingAnalyzer: existingAnalyzer,
          taxes: taxes,
        );
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

  String? get callURL => optionLeg.asset.url;

  String? get underlyingURL => underlying.url;

  String? get strategyURL => underlying.source?.strategyUrl(strategy);

  Map<String, dynamic> toJson() => {
        'id':
            '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}~C',
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
    if (!maxLeverage.isFinite) {
      throw Exception(
          "Non-finite maxLeverage in LongCall!\nStrategy: $strategy\n"
          "Analyzer: $analyzer");
    }
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

  String? get putURL => optionLeg.asset.url;

  String? get underlyingURL => underlying.url;

  String? get strategyURL => underlying.source?.strategyUrl(strategy);

  Map<String, dynamic> toJson() => {
        'id':
            '${_formatDate(expiration)}~${_formatDouble(strikePrice.absolute)}~P',
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
    if (!maxLeverage.isFinite ||
        !maxMoneyYield.isFinite ||
        !maxMoneyProfit.isFinite) {
      throw Exception("Non-finite metrics in LongPut!\nStrategy: $strategy\n"
          "Analyzer: $analyzer");
    }
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

  String? get shortLegURL => shortLeg.asset.url;
  String? get longLegURL => longLeg.asset.url;
  String? get underlyingURL => underlying.url;
  String? get strategyURL => underlying.source?.strategyUrl(strategy);

  Map<String, dynamic> toJson() => {
        'id':
            '${_formatDate(expiration)}~${_formatDouble(shortOption.strike)}~${_formatDouble(longOption.strike)}~${shortOption.isCall ? 'call' : 'put'}',
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
      VerticalSpread makeSpread(Position position, Option shortOption,
              Option longOption, Market shortMarket, Market longMarket) =>
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
            makeSpread(
                highCall.long(slippage) + lowCall.short(slippage),
                lowCall.asset.toOption,
                highCall.asset.toOption,
                lowCall,
                highCall),
        ]);

        // over @ highStrike
        VerticalSpread? over = keepBestValidSpread([
          if (lowCall != null && highCall != null)
            makeSpread(
                highCall.short(slippage) + lowCall.long(slippage),
                highCall.asset.toOption,
                lowCall.asset.toOption,
                highCall,
                lowCall),
          if (lowPut != null && highPut != null)
            makeSpread(highPut.short(slippage) + lowPut.long(slippage),
                highPut.asset.toOption, lowPut.asset.toOption, highPut, lowPut),
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

  Map<String, dynamic> toJson() => {
        'absolute': absolute,
        'relative': relative,
      };
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
  final Map<DateTime, Map<double, List<VerticalSpread>>> _contributingSpreads =
      {};
  final Map<DateTime, double> _atmStrikes = {};
  final Map<DateTime, double> _discountFactors = {};

  Map<DateTime, Map<double, double>> get distributions => _probs;
  Map<DateTime, double> get atmStrikes => _atmStrikes;
  Map<DateTime, double> get discountFactors => _discountFactors;

  static double _unitMidPrice(Market m) {
    final lot = m.asset.toOption.contractLot;
    return m.midPrice / (lot > 0.0 ? lot : 1.0);
  }

  static double _unitSpread(Market m) {
    final lot = m.asset.toOption.contractLot;
    return (m.askPrice - m.bidPrice) / (lot > 0.0 ? lot : 1.0);
  }

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

      // Collect all call and put option markets for this expiration.
      final Map<double, Market> callMarkets = {};
      final Map<double, Market> putMarkets = {};
      for (final vs in expSpreads) {
        for (final option in [vs.shortOption, vs.longOption]) {
          final market =
              (option == vs.shortOption) ? vs.shortMarket : vs.longMarket;
          if (option.isCall) {
            callMarkets[option.strike] = market;
          } else {
            putMarkets[option.strike] = market;
          }
        }
      }

      // 2a. Put-Call Parity & Box Spreads:
      // By European Put-Call Parity per unit of underlying:
      //   c(K) - p(K) = D * (F - K)
      // where F = E[S_T] is the implied forward price (where c(K) == p(K)) and
      // D = exp(-r * T) = 1 / (1 + R) is the risk-free discount factor to expiration.
      // Note: F is the risk-neutral MEAN, not the median (for a lognormal asset,
      // P(S_T > F) = N(-0.5 * sigma * sqrt(T)) < 0.5), so we record F in
      // _atmStrikes without artificially pinning P(S_T > F) = 0.5.
      final commonStrikes = callMarkets.keys
          .where((s) => putMarkets.containsKey(s))
          .toList()
        ..sort();
      double? atmStrike;

      for (final strike in commonStrikes) {
        final diff = _unitMidPrice(callMarkets[strike]!) -
            _unitMidPrice(putMarkets[strike]!);
        if (diff == 0.0) {
          atmStrike = strike;
          break;
        }
      }

      double weightedDiscountSum = 0.0;
      double discountWeightTotal = 0.0;

      for (int i = 0; i < commonStrikes.length - 1; i++) {
        final k1 = commonStrikes[i];
        final k2 = commonStrikes[i + 1];
        final width = k2 - k1;
        if (width <= 0.0) continue;

        final mCall1 = callMarkets[k1]!;
        final mPut1 = putMarkets[k1]!;
        final mCall2 = callMarkets[k2]!;
        final mPut2 = putMarkets[k2]!;

        final diff1 = _unitMidPrice(mCall1) - _unitMidPrice(mPut1);
        final diff2 = _unitMidPrice(mCall2) - _unitMidPrice(mPut2);

        if (atmStrike == null && diff1 > 0.0 && diff2 < 0.0) {
          final t = -diff1 / (diff2 - diff1);
          atmStrike = k1 + t * width;
        }

        // Box Spread Identity on [k1, k2]:
        // Buying the bull call spread (c(k1) - c(k2)) and the bear put spread
        // (p(k2) - p(k1)) pays a guaranteed (k2 - k1) at expiration.
        // Thus its present value per unit width equals the discount factor D:
        //   D = ((c(k1) - c(k2)) + (p(k2) - p(k1))) / (k2 - k1) = (diff1 - diff2) / width
        final boxDiscount = (diff1 - diff2) / width;
        if (boxDiscount > 0.0) {
          final boxSpreadNoise = (
                  _unitSpread(mCall1) +
                  _unitSpread(mPut1) +
                  _unitSpread(mCall2) +
                  _unitSpread(mPut2)) /
              width +
              mCall1.relativeSpread +
              mPut1.relativeSpread +
              mCall2.relativeSpread +
              mPut2.relativeSpread;
          final w = boxSpreadNoise <= 0.0 ? 1e9 : 1.0 / boxSpreadNoise;
          weightedDiscountSum += boxDiscount * w;
          discountWeightTotal += w;
        }
      }

      if (atmStrike != null) {
        _atmStrikes[expiration] = atmStrike;
      }

      final double discountFactor = discountWeightTotal > 0.0
          ? (weightedDiscountSum / discountWeightTotal).clamp(0.1, 1.0)
          : 1.0;
      _discountFactors[expiration] = discountFactor;

      // 2b. Group vertical spreads by their strike interval [lowStrike, highStrike].
      // By Breeden-Litzenberger, P(S_T > K) = -(1 / D) * dC/dK.
      // A vertical spread across [K_1, K_2] is a finite-difference secant slope
      // that estimates the cumulative probability at the interval MIDPOINT
      // M = (K_1 + K_2) / 2, rather than at K_1 or K_2.
      final Map<(double, double), List<VerticalSpread>> byInterval = {};
      for (final vs in expSpreads) {
        final k1 = vs.shortOption.strike;
        final k2 = vs.longOption.strike;
        final lowStrike = min(k1, k2);
        final highStrike = max(k1, k2);
        if (highStrike > lowStrike) {
          byInterval.putIfAbsent((lowStrike, highStrike), () => []).add(vs);
        }
      }

      final Map<double, double> rawProbs = {};
      final Map<double, List<VerticalSpread>> strikeToSpreads = {};
      final Map<double, double> strikeWeights = {};

      for (final intervalEntry in byInterval.entries) {
        final (lowStrike, highStrike) = intervalEntry.key;
        final midpoint = (lowStrike + highStrike) / 2.0;
        final width = highStrike - lowStrike;
        final intervalSpreads = intervalEntry.value;

        double weightedProbSum = 0.0;
        double totalWeight = 0.0;
        final List<VerticalSpread> usedSpreads = [];

        for (final vs in intervalSpreads) {
          final isCall = vs.shortOption.isCall;
          final lowMarket =
              vs.shortOption.strike < vs.longOption.strike ? vs.shortMarket : vs.longMarket;
          final highMarket =
              vs.shortOption.strike > vs.longOption.strike ? vs.shortMarket : vs.longMarket;

          // Evaluate the spread's mid-price value per unit of underlying,
          // independent of any user execution slippage, and un-discount by D
          // to convert present-value premium into expiration-date probability:
          //   - Call spread: (c(K_1) - c(K_2)) / (D * width) = P(S_T > M)
          //   - Put spread:  (p(K_2) - p(K_1)) / (D * width) = P(S_T <= M)
          final double probAbove;
          if (isCall) {
            final callSpreadVal = _unitMidPrice(lowMarket) - _unitMidPrice(highMarket);
            probAbove = (callSpreadVal / (discountFactor * width)).clamp(0.0, 1.0);
          } else {
            final putSpreadVal = _unitMidPrice(highMarket) - _unitMidPrice(lowMarket);
            final probBelow = (putSpreadVal / (discountFactor * width)).clamp(0.0, 1.0);
            probAbove = 1.0 - probBelow;
          }

          // Market quality weight of this spread estimate:
          // Combines the probability-scale bid-ask uncertainty ((ask - bid) / width,
          // which penalizes deep ITM options with wide dollar spreads) and the
          // leg relative spreads (which penalizes noisy 1-tick far OTM options).
          final probUncertainty =
              (_unitSpread(lowMarket) + _unitSpread(highMarket)) / width;
          final relSpread = lowMarket.relativeSpread + highMarket.relativeSpread;
          final noise = probUncertainty + relSpread;
          final w = noise <= 0.0 ? 1e9 : 1.0 / noise;

          weightedProbSum += probAbove * w;
          totalWeight += w;
          usedSpreads.add(vs);
        }

        if (totalWeight > 0.0) {
          rawProbs[midpoint] = (weightedProbSum / totalWeight).clamp(0.0, 1.0);
          strikeWeights[midpoint] = totalWeight;
          strikeToSpreads[midpoint] = usedSpreads;
        }
      }

      // 2c. Enforce non-increasing monotonicity across midpoints via the
      // weighted Pool Adjacent Violators Algorithm (PAVA) for isotonic regression.
      // Rather than greedily deleting points that have minor quote inversions,
      // PAVA pools adjacent violating blocks into their liquidity-weighted average,
      // finding the exact L2-optimal non-increasing cumulative distribution.
      final sortedMidpoints = rawProbs.keys.toList()..sort();
      final List<({List<double> strikes, double prob, double weight})> blocks =
          [];

      for (final strike in sortedMidpoints) {
        var currentStrikes = <double>[strike];
        var currentProb = rawProbs[strike]!;
        var currentWeight = strikeWeights[strike]!;

        while (blocks.isNotEmpty && blocks.last.prob < currentProb) {
          final prev = blocks.removeLast();
          final mergedWeight = prev.weight + currentWeight;
          currentProb =
              (prev.prob * prev.weight + currentProb * currentWeight) /
                  mergedWeight;
          currentWeight = mergedWeight;
          currentStrikes = [...prev.strikes, ...currentStrikes];
        }

        blocks.add((
          strikes: currentStrikes,
          prob: currentProb,
          weight: currentWeight,
        ));
      }

      final Map<double, double> sortedMonotonicProbs = {};
      for (final block in blocks) {
        final clampedProb = block.prob.clamp(0.0, 1.0);
        for (final s in block.strikes) {
          sortedMonotonicProbs[s] = clampedProb;
        }
      }

      _probs[expiration] = sortedMonotonicProbs;
      _contributingSpreads[expiration] = strikeToSpreads;
    }
  }

  List<VerticalSpread> getContributingSpreads(
      DateTime expiration, double strike) {
    return _contributingSpreads[expiration]?[strike] ?? const [];
  }

  double getProbabilityExpiringAbove(DateTime expiration, double strike) {
    final expProbs = _probs[expiration];
    if (expProbs == null || expProbs.isEmpty) {
      throw ArgumentError(
          "No probability distribution found for expiration $expiration");
    }

    final strikes = expProbs.keys.toList()..sort();
    if (strike < strikes.first || strike > strikes.last) {
      throw ArgumentError(
          "Extrapolation is not allowed. Strike $strike is outside the known range [${strikes.first}, ${strikes.last}]");
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

  double getProbabilityExpiringBelow(DateTime expiration, double strike) =>
      1.0 - getProbabilityExpiringAbove(expiration, strike);

  /// Returns the implied 50/50 median strike where P(S_T > K) == 0.50,
  /// linearly interpolated from the distribution for [expiration], or null
  /// if 0.50 lies outside the observed probability range.
  double? getMedianStrike(DateTime expiration) {
    final expProbs = _probs[expiration];
    if (expProbs == null || expProbs.isEmpty) return null;

    final strikes = expProbs.keys.toList()..sort();
    final exactMatches =
        strikes.where((k) => (expProbs[k]! - 0.5).abs() < 1e-12).toList();
    if (exactMatches.isNotEmpty) {
      return (exactMatches.first + exactMatches.last) / 2.0;
    }

    for (int i = 0; i < strikes.length - 1; i++) {
      final kLower = strikes[i];
      final kUpper = strikes[i + 1];
      final pLower = expProbs[kLower]!;
      final pUpper = expProbs[kUpper]!;
      if (pLower > 0.5 && pUpper < 0.5) {
        final t = (0.5 - pLower) / (pUpper - pLower);
        return kLower + t * (kUpper - kLower);
      }
    }
    return null;
  }

  /// Implied probability in [0, 1] that the underlying price touches
  /// [targetPrice] at any time between now and [expiration].
  ///
  /// By theOptional Stopping Theorem on a tight vertical spread centered at
  /// [targetPrice] (closed at 50% of its discounted width when touched):
  ///   - Upside target (P_above <= 0.5):   P_touch = 2 * P_above
  ///   - Downside target (P_below <= 0.5): P_touch = 2 * P_below
  double getProbabilityOfTouch(DateTime expiration, double targetPrice) {
    final pAbove = getProbabilityExpiringAbove(expiration, targetPrice);
    final pBelow = 1.0 - pAbove;
    return (2.0 * min(pAbove, pBelow)).clamp(0.0, 1.0);
  }

  /// Implied probability in [0, 1] that the underlying price NEVER touches
  /// [targetPrice] between now and [expiration].
  double getProbabilityOfNoTouch(DateTime expiration, double targetPrice) =>
      1.0 - getProbabilityOfTouch(expiration, targetPrice);
}

enum TouchBetType { touch, noTouch }

/// A binary-style "Touch" or "No-Touch" bet constructed from an adjacent-strike
/// [VerticalSpread] centered at [targetPrice] = (lowStrike + highStrike) / 2,
/// combined with a rule to close the spread at 50% of its discounted box width
/// ([touchExitValue]) if the underlying touches [targetPrice] before expiration.
///
/// - [TouchBetType.touch]: Uses the OTM vertical spread (`over` above the median,
///   `under` below the median) and places a GTC take-profit order at [touchExitValue].
/// - [TouchBetType.noTouch]: Uses the ITM vertical spread (`under` above the median,
///   `over` below the median), holding to expiration for full profit if untouched,
///   or closing at [touchExitValue] as a stop-loss if [targetPrice] is touched.
class TouchBet {
  final VerticalSpread spread;
  final TouchBetType betType;
  final PriceInfo targetPrice;
  final double lowStrike;
  final double highStrike;
  final double discountFactor;
  final double winProbability;
  final double touchExitValue;
  final double maxProfit;
  final double maxRisk;
  final double maxYield;

  Commodity get underlying => spread.underlying;
  Commodity get money => spread.money;
  DateTime get expiration => spread.expiration;
  double get spotPrice => spread.spotPrice;
  String? get strategyURL => spread.strategyURL;

  TouchBet._({
    required this.spread,
    required this.betType,
    required this.targetPrice,
    required this.lowStrike,
    required this.highStrike,
    required this.discountFactor,
    required this.winProbability,
    required this.touchExitValue,
    required this.maxProfit,
    required this.maxRisk,
    required this.maxYield,
  });

  List<ExecutionInstruction> get instructions {
    final longCost =
        spread.longLeg.costBasisSingle(spread.money)?.size.abs() ??
            (spread.longMarket.buyPrice() * spread.longLeg.size.abs());
    final shortProceeds =
        spread.shortLeg.costBasisSingle(spread.money)?.size.abs() ??
            (spread.shortMarket.sellPrice() * spread.shortLeg.size.abs());
    final exitAction = betType == TouchBetType.touch
        ? 'GTC Take-Profit on Touch'
        : 'Stop-Loss on Touch';

    return [
      ExecutionInstruction(
        action: 'Buy',
        size: spread.longLeg.size.abs(),
        unit: spread.longOption.name,
        price: longCost,
        priceUnit: money.name,
      ),
      ExecutionInstruction(
        action: 'Sell',
        size: spread.shortLeg.size.abs(),
        unit: spread.shortOption.name,
        price: shortProceeds,
        priceUnit: money.name,
      ),
      ExecutionInstruction(
        action: exitAction,
        size: 1.0,
        unit: 'spread @ ${_formatDouble(targetPrice.absolute)}',
        price: touchExitValue,
        priceUnit: money.name,
      ),
    ];
  }

  Map<String, dynamic> toJson() => {
        'id':
            '${_formatDate(expiration)}~${_formatDouble(targetPrice.absolute)}~${betType.name}',
        'strategyType': 'touchBet',
        'betType': betType.name,
        'spreadType': spread.type.name,
        'strategyURL': strategyURL,
        'underlying': underlying.name,
        'underlyingURL': spread.underlyingURL,
        'money': money.name,
        'moneySize': spread.moneyLeg.size,
        'spotPrice': spotPrice,
        'shortLeg': spread.shortLeg.asset.name,
        'shortLegURL': spread.shortLegURL,
        'longLeg': spread.longLeg.asset.name,
        'longLegURL': spread.longLegURL,
        'lowStrike': lowStrike,
        'highStrike': highStrike,
        'targetPriceAbsolute': targetPrice.absolute,
        'targetPriceRelative': targetPrice.relative,
        'discountFactor': discountFactor,
        'winProbability': winProbability,
        'touchExitValue': touchExitValue,
        'maxProfit': maxProfit,
        'maxRisk': maxRisk,
        'maxYield': maxYield,
        'DTE': expiration.daysLeft,
        'formattedDate': expiration.formattedDate,
        'instructions': instructions.map((i) => i.toJson()).toList(),
      };

  @override
  String toString() => jsonEncode(this);

  static Iterable<TouchBet> generateAll(
    Iterable<Market> allMarkets, {
    required Commodity underlying,
    required Commodity money,
    double slippage = 0.5,
  }) sync* {
    // Evaluate order-book probabilities at mid-price (0.5), while constructing
    // the executable spreads at the caller's requested [slippage].
    final midSpreads = VerticalSpread.generateAll(
      allMarkets,
      underlying: underlying,
      money: money,
      slippage: 0.5,
    ).toList();
    final probs = Probabilities(
      midSpreads,
      underlying: underlying,
      money: money,
    );

    final execSpreads = slippage == 0.5
        ? midSpreads
        : VerticalSpread.generateAll(
            allMarkets,
            underlying: underlying,
            money: money,
            slippage: slippage,
          ).toList();

    for (final vs in execSpreads) {
      final expiration = vs.expiration;
      final k1 = vs.shortOption.strike;
      final k2 = vs.longOption.strike;
      final lowStrike = min(k1, k2);
      final highStrike = max(k1, k2);
      final midpoint = (lowStrike + highStrike) / 2.0;

      final double pAbove;
      final double pTouch;
      try {
        pAbove = probs.getProbabilityExpiringAbove(expiration, midpoint);
        pTouch = probs.getProbabilityOfTouch(expiration, midpoint);
      } catch (_) {
        continue;
      }

      // Above the median (pAbove <= 0.5):
      //   - `over` is the OTM "Touch" bet
      //   - `under` is the ITM "No-Touch" bet
      // Below the median (pAbove > 0.5):
      //   - `under` is the OTM "Touch" bet
      //   - `over` is the ITM "No-Touch" bet
      final bool isUpsideTarget = pAbove <= 0.5;
      final TouchBetType betType;
      if (isUpsideTarget) {
        betType = vs.type == VerticalSpreadType.over
            ? TouchBetType.touch
            : TouchBetType.noTouch;
      } else {
        betType = vs.type == VerticalSpreadType.under
            ? TouchBetType.touch
            : TouchBetType.noTouch;
      }

      final winProb =
          betType == TouchBetType.touch ? pTouch : (1.0 - pTouch);
      final discountFactor = probs.discountFactors[expiration] ?? 1.0;

      // Full expiration payoff range of the spread in money (width * contractLot):
      final spreadPayoffWidth = vs.analyzer.maxValue - vs.analyzer.minValue;
      if (spreadPayoffWidth <= 0.0) continue;

      // At the moment the underlying touches the midpoint, the spread is ATM
      // and valued at 50% of its discounted box width:
      final touchExitValue = 0.5 * discountFactor * spreadPayoffWidth;
      final netCashEntry = vs.moneyLeg.size; // negative for debit, positive for credit

      final double maxProfit;
      final double maxRisk;
      if (betType == TouchBetType.touch) {
        // Touch bet: wins when closed at touchExitValue, loses entry risk if never touched.
        if (netCashEntry < 0.0) {
          final debitPaid = -netCashEntry;
          maxProfit = touchExitValue - debitPaid;
          maxRisk = debitPaid;
        } else {
          // Credit representation of an OTM touch bet:
          maxProfit = netCashEntry - touchExitValue;
          maxRisk = vs.analyzer.maxRisk;
        }
      } else {
        // No-Touch bet: wins full expiration maxProfit if never touched;
        // stops out at touchExitValue if touched.
        maxProfit = vs.analyzer.maxProfit;
        if (netCashEntry < 0.0) {
          final debitPaid = -netCashEntry;
          maxRisk = debitPaid - touchExitValue;
        } else {
          maxRisk = touchExitValue - netCashEntry;
        }
      }

      if (maxProfit <= 0.0 || maxRisk <= 0.0) continue;
      final maxYield = 1.0 + maxProfit / maxRisk;
      if (!maxYield.isFinite) continue;

      yield TouchBet._(
        spread: vs,
        betType: betType,
        targetPrice: PriceInfo.fromAbsolute(midpoint, vs.spotPrice),
        lowStrike: lowStrike,
        highStrike: highStrike,
        discountFactor: discountFactor,
        winProbability: winProb,
        touchExitValue: touchExitValue,
        maxProfit: maxProfit,
        maxRisk: maxRisk,
        maxYield: maxYield,
      );
    }
  }
}
