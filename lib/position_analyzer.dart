import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';

import 'assets.dart';
import 'oracle.dart';
import 'taxes.dart';

export 'taxes.dart';

class PositionAnalyzer {
  final Position position;
  final Commodity underlying;
  final Commodity money;
  final TaxProfile taxes;
  final List<_PnLSegment> _segments;

  PositionAnalyzer._(this.position,
      {required this.underlying,
      required this.money,
      required this.taxes,
      required List<_PnLSegment> segments})
      : _segments = segments;

  PositionAnalyzer(this.position,
      {required this.underlying,
      required this.money,
      this.taxes = TaxProfile.none})
      : _segments = [] {
    final Set<DateTime> expirations = {};
    final interestingPoints = SplayTreeSet<double>()..add(0.0);

    for (final inner in position.decompose()) {
      final innerAsset = inner.asset;
      if (innerAsset.isCommodity &&
          innerAsset != underlying &&
          innerAsset != money) {
        throw ArgumentError(
            "A PositionAnalyzer(underlying=$underlying, money=$money) cannot "
            "analyze commodity $innerAsset");
      }
      // We could use an Oracle to do: inner.costBasisIn(oracle, money) if
      // we want, but is an overkill for now.
      if (inner.unitCostBasis != null && inner.unitCostBasis!.asset != money) {
        throw ArgumentError("A PositionAnalyzer(money=$money) cannot "
            "analyze $inner because its cost basis is in "
            "${inner.unitCostBasis!.asset}");
      }
      if (innerAsset.isExpirable) {
        final expirable = innerAsset.toExpirable;
        if (expirable.underlying != underlying) {
          throw ArgumentError(
              "A PositionAnalyzer(underlying=$underlying) cannot "
              "analyze $expirable because its underlying is "
              "${expirable.underlying}");
        }
        expirations.add(expirable.expiration);
        if (expirations.length >= 2) {
          throw ArgumentError("At least 2 different option expirations "
              "involved in position: $position, impossible to analyze");
        }
      }
      if (innerAsset.isOption) {
        final option = innerAsset.toOption;
        if (option.money != money) {
          throw ArgumentError("A PositionAnalyzer(money=$money) cannot "
              "analyze an option $option because its strike is of "
              "a different money: ${option.money}");
        }
        if (option.strike < 0.0) {
          throw ArgumentError(
              "Option strike (${option.strike}) cannot be negative: $option");
        }
        interestingPoints.add(option.strike);
      }
    }

    final oracle = SimulatedOracle();
    double priceToValue(double price) =>
        (oracle..setPrice(asset: underlying, money: money, price: price))
            .intrinsicValue(position: position, money: money)
            .size;

    double prevPrice = interestingPoints.first;
    for (final nextPrice in interestingPoints.skip(1)) {
      final settled = _PnLSegment._settle(position,
          underlying: underlying,
          money: money,
          minPrice: prevPrice,
          maxPrice: nextPrice);
      _segments.add(_PnLSegment.closed(priceToValue,
          minPrice: prevPrice,
          maxPrice: nextPrice,
          costBasis: settled.costBasis,
          realizedUnderlyingPnL: settled.realizedUnderlyingPnL,
          realizedDerivativePnL: settled.realizedDerivativePnL,
          tax: taxes.computeTax(
              realizedUnderlyingPnL: settled.realizedUnderlyingPnL,
              realizedDerivativePnL: settled.realizedDerivativePnL)));
      prevPrice = nextPrice;
    }
    final settledOpen = _PnLSegment._settle(position,
        underlying: underlying,
        money: money,
        minPrice: prevPrice,
        maxPrice: double.infinity);
    _segments.add(_PnLSegment.open(priceToValue,
        minPrice: prevPrice,
        costBasis: settledOpen.costBasis,
        realizedUnderlyingPnL: settledOpen.realizedUnderlyingPnL,
        realizedDerivativePnL: settledOpen.realizedDerivativePnL,
        tax: taxes.computeTax(
            realizedUnderlyingPnL: settledOpen.realizedUnderlyingPnL,
            realizedDerivativePnL: settledOpen.realizedDerivativePnL)));
  }

  /// Returns a [PositionAnalyzer] for this position with [taxes] applied to
  /// each segment's realized PnL. Calling [withTaxes] on an already taxed
  /// analyzer replaces (rather than compounds) the tax profile.
  PositionAnalyzer withTaxes(TaxProfile taxes) {
    if (this.taxes == taxes) return this;
    return PositionAnalyzer._(
      position,
      underlying: underlying,
      money: money,
      taxes: taxes,
      segments: _segments
          .map((segment) => segment.withTaxes(taxes))
          .toList(growable: false),
    );
  }

  double get minValue => _segments.map((segment) => segment.minValue).min;
  double get maxValue => _segments.map((segment) => segment.maxValue).max;

  Iterable<PriceRange> get breakevens => whereValueIs(0.0);
  Iterable<PriceRange> get bestPrices => whereValueIs(maxValue);
  Iterable<PriceRange> get worstPrices => whereValueIs(minValue);

  Iterable<PriceRange> whereValueIs(double value) => PriceRange._mergeAdjacents(
      _segments.map((segment) => segment.whereValueIs(value)).nonNulls);

  _PnLSegment _segmentBefore(double price) {
    for (final segment in _segments) {
      if (segment.includes(price)) {
        return segment;
      }
    }
    throw StateError("No segment included price $price, segments: $_segments");
  }

  _PnLSegment _segmentAfter(double price) {
    for (final segment in _segments.reversed) {
      if (segment.includes(price)) {
        return segment;
      }
    }
    throw StateError("No segment included price $price, segments: $_segments");
  }

  // The delta for prices just below the specified one.
  double deltaBefore(double price) => _segmentBefore(price).delta;

  // The delta for prices just above the specified one.
  double deltaAfter(double price) => _segmentAfter(price).delta;

  // The remaining cost basis (in money) for prices just below the specified one.
  double costBasisBefore(double price) => _segmentBefore(price).costBasis;

  // The remaining cost basis (in money) for prices just above the specified one.
  double costBasisAfter(double price) => _segmentAfter(price).costBasis;

  // The realized PnL (in money) for prices just below the specified one.
  double realizedPnLBefore(double price) => _segmentBefore(price).realizedPnL;

  // The realized PnL (in money) for prices just above the specified one.
  double realizedPnLAfter(double price) => _segmentAfter(price).realizedPnL;

  // The unrealized PnL (in money) at [price], evaluated on the segment just below [price].
  double unrealizedPnLBefore(double price) =>
      _segmentBefore(price).unrealizedPnLAt(price);

  // The unrealized PnL (in money) at [price], evaluated on the segment just above [price].
  double unrealizedPnLAfter(double price) =>
      _segmentAfter(price).unrealizedPnLAt(price);

  // The value (in money) at [price], evaluated on the segment just below [price].
  double valueBefore(double price) => _segmentBefore(price).valueAt(price)!;

  // The value (in money) at [price], evaluated on the segment just above [price].
  double valueAfter(double price) => _segmentAfter(price).valueAt(price)!;

  // Transforms a position to a position of different size, such as
  // the resulting position has the same maxRisk as this PositionAnalyzer.
  // TODO: unused
  PositionAnalyzer equalizeRisk(Position position) => PositionAnalyzer(
      position *
          (maxRisk /
              PositionAnalyzer(position,
                      underlying: underlying, money: money, taxes: taxes)
                  .maxRisk),
      underlying: underlying,
      money: money,
      taxes: taxes);

  // Can be negative for profitless strategies.
  double get maxProfit => max(maxValue, 0.0);
  double get maxRisk => max(-minValue, 0.0);

  double get maxYield => 1.0 + maxProfit / maxRisk;
  double yieldAt(double price) => 1.0 + valueAt(price) / maxRisk;

  double valueAt(double price) =>
      _segments.map((segment) => segment.valueAt(price)).nonNulls.first;

  @override
  String toString() =>
      "PositionAnalyzer(position: $position, underlying: $underlying, money: $money, "
      "minValue: $minValue, maxValue: $maxValue, breakevens: $breakevens), "
      "segments: $_segments";
}

// Inclusive range.
class PriceRange {
  final double fromPrice;
  final double toPrice;

  PriceRange(this.fromPrice, this.toPrice);
  PriceRange.point(final double price) : this(price, price);

  bool get isPoint => fromPrice == toPrice;

  double get price {
    if (!isPoint) {
      throw ArgumentError("isPoint == false");
    }
    return fromPrice;
  }

  static List<PriceRange> _mergeAdjacents(Iterable<PriceRange> pnvs) =>
      pnvs.fold(
          [],
          (List<PriceRange> previous, PriceRange next) => switch (previous) {
                [] => [next],
                [...List<PriceRange> rest, PriceRange last] =>
                  last.toPrice >= next.fromPrice
                      ? [
                          ...rest,
                          PriceRange(
                              last.fromPrice, max(last.toPrice, next.toPrice))
                        ]
                      : [...rest, last, next],
              });

  @override
  String toString() => isPoint ? "$fromPrice" : "[$fromPrice..$toPrice]";
}

class _PnLSegment {
  // Price of the underlying (in money).
  final double minPrice;
  final double maxPrice;
  final double _preTaxValueAtMinPrice;
  final double _preTaxValueAtMaxPrice;
  // Value change for a unit of price change
  // Critical to have correct sign here, i.e. if it is zero, it must be
  // zero, not 0.00000000009
  final double delta;

  // Remaining cost basis (in money) of open underlying units on this segment.
  final double costBasis;
  // Realized PnL (in money) from closed underlying units on this segment.
  final double realizedUnderlyingPnL;
  // Realized PnL (in money) from OTM options expiring worthless on this segment.
  final double realizedDerivativePnL;
  // Tax (in money) on realized PnL on this segment.
  final double tax;

  double get valueAtMinPrice => _preTaxValueAtMinPrice - tax;
  double get valueAtMaxPrice => _preTaxValueAtMaxPrice - tax;

  double get realizedPnL =>
      realizedUnderlyingPnL + realizedDerivativePnL - tax;

  double unrealizedPnLAt(double price) => delta * price - costBasis;

  _PnLSegment(
      {required this.minPrice,
      required double valueAtMinPrice,
      required this.maxPrice,
      required double valueAtMaxPrice,
      required this.delta,
      this.costBasis = 0.0,
      this.realizedUnderlyingPnL = 0.0,
      this.realizedDerivativePnL = 0.0,
      this.tax = 0.0})
      : _preTaxValueAtMinPrice = valueAtMinPrice,
        _preTaxValueAtMaxPrice = valueAtMaxPrice {
    if (!minPrice.isFinite) {
      throw ArgumentError("minPrice ($minPrice) must be finite");
    }
    if (minPrice >= maxPrice) {
      throw ArgumentError("minPrice ($minPrice) >= maxPrice ($maxPrice)");
    }
  }

  _PnLSegment withTaxes(TaxProfile taxes) => _PnLSegment(
      minPrice: minPrice,
      valueAtMinPrice: _preTaxValueAtMinPrice,
      maxPrice: maxPrice,
      valueAtMaxPrice: _preTaxValueAtMaxPrice,
      delta: delta,
      costBasis: costBasis,
      realizedUnderlyingPnL: realizedUnderlyingPnL,
      realizedDerivativePnL: realizedDerivativePnL,
      tax: taxes.computeTax(
          realizedUnderlyingPnL: realizedUnderlyingPnL,
          realizedDerivativePnL: realizedDerivativePnL));

  factory _PnLSegment.closed(double Function(double) priceToValue,
      {required double minPrice,
      required double maxPrice,
      double costBasis = 0.0,
      double realizedUnderlyingPnL = 0.0,
      double realizedDerivativePnL = 0.0,
      double tax = 0.0}) {
    if (!maxPrice.isFinite) {
      throw ArgumentError("maxPrice ($maxPrice) must be finite");
    }
    double valueAtMinPrice = priceToValue(minPrice);
    double valueAtMaxPrice = priceToValue(maxPrice);
    return _PnLSegment(
        minPrice: minPrice,
        valueAtMinPrice: valueAtMinPrice,
        maxPrice: maxPrice,
        valueAtMaxPrice: valueAtMaxPrice,
        delta: _calcDelta(
            x1: minPrice,
            x2: maxPrice,
            y1: valueAtMinPrice,
            y2: valueAtMaxPrice),
        costBasis: costBasis,
        realizedUnderlyingPnL: realizedUnderlyingPnL,
        realizedDerivativePnL: realizedDerivativePnL,
        tax: tax);
  }

  factory _PnLSegment.open(double Function(double) priceToValue,
      {required double minPrice,
      double costBasis = 0.0,
      double realizedUnderlyingPnL = 0.0,
      double realizedDerivativePnL = 0.0,
      double tax = 0.0}) {
    double valueAtMinPrice = priceToValue(minPrice);
    final List<double> deltas = [];
    double prevPrice = minPrice;
    double prevValue = valueAtMinPrice;
    final medianIndex = 2;
    for (int i = 0; i < medianIndex * 2 + 1; ++i) {
      double nextPrice = (prevPrice + 1.0) * 1.5;
      double nextValue = priceToValue(nextPrice);
      deltas.add(_calcDelta(
          x1: prevPrice, x2: nextPrice, y1: prevValue, y2: nextValue));
      prevPrice = nextPrice;
      prevValue = nextValue;
    }
    final double delta = (deltas..sort())[medianIndex];

    return _PnLSegment(
        minPrice: minPrice,
        valueAtMinPrice: valueAtMinPrice,
        maxPrice: double.infinity,
        valueAtMaxPrice: switch (delta.sign) {
          1.0 => double.infinity,
          -1.0 => double.negativeInfinity,
          _ => valueAtMinPrice
        },
        delta: delta,
        costBasis: costBasis,
        realizedUnderlyingPnL: realizedUnderlyingPnL,
        realizedDerivativePnL: realizedDerivativePnL,
        tax: tax);
  }

  static ({
    double costBasis,
    double realizedUnderlyingPnL,
    double realizedDerivativePnL,
  }) _settle(
    Position position, {
    required Commodity underlying,
    required Commodity money,
    required double minPrice,
    required double maxPrice,
  }) {
    double longUnderlyingSize = 0.0;
    double longUnderlyingCost = 0.0;
    double shortUnderlyingSize = 0.0;
    double shortUnderlyingProceeds = 0.0;
    double realizedDerivativePnL = 0.0;

    void addUnderlying(double size, double costBasis) {
      if (size > 0.0) {
        longUnderlyingSize += size;
        longUnderlyingCost += costBasis;
      } else if (size < 0.0) {
        shortUnderlyingSize += -size;
        shortUnderlyingProceeds += -costBasis;
      }
    }

    for (final line in position.decompose()) {
      final asset = line.asset;
      final costBasis = line.costBasisSingle(money)?.size ?? 0.0;

      if (asset == money) {
        continue;
      } else if (asset == underlying) {
        addUnderlying(line.size, costBasis);
      } else if (asset.isDatedFuture) {
        final future = asset.toDatedFuture;
        addUnderlying(line.size * future.contractLot, costBasis);
      } else if (asset.isOption) {
        final option = asset.toOption;
        final isExercised = option.isCall
            ? minPrice >= option.strike
            : maxPrice <= option.strike;
        if (isExercised) {
          final underlyingDelta =
              line.size * option.contractLot * (option.isCall ? 1.0 : -1.0);
          final exercisedCostBasis =
              underlyingDelta * option.strike + costBasis;
          addUnderlying(underlyingDelta, exercisedCostBasis);
        } else {
          realizedDerivativePnL -= costBasis;
        }
      }
    }

    final closedSize = min(longUnderlyingSize, shortUnderlyingSize);
    final double realizedUnderlyingPnL;
    if (closedSize == 0.0) {
      realizedUnderlyingPnL = 0.0;
    } else if (longUnderlyingSize == shortUnderlyingSize) {
      realizedUnderlyingPnL = shortUnderlyingProceeds - longUnderlyingCost;
    } else {
      realizedUnderlyingPnL = closedSize *
          (shortUnderlyingProceeds / shortUnderlyingSize -
              longUnderlyingCost / longUnderlyingSize);
    }

    final netUnderlyingSize = longUnderlyingSize - shortUnderlyingSize;
    final double remainingCostBasis;
    if (netUnderlyingSize.abs() < 1e-9) {
      remainingCostBasis = 0.0;
    } else if (netUnderlyingSize > 0.0) {
      remainingCostBasis = shortUnderlyingSize == 0.0
          ? longUnderlyingCost
          : longUnderlyingCost * (netUnderlyingSize / longUnderlyingSize);
    } else {
      remainingCostBasis = longUnderlyingSize == 0.0
          ? -shortUnderlyingProceeds
          : -shortUnderlyingProceeds *
              (-netUnderlyingSize / shortUnderlyingSize);
    }

    return (
      costBasis: remainingCostBasis,
      realizedUnderlyingPnL: realizedUnderlyingPnL,
      realizedDerivativePnL: realizedDerivativePnL,
    );
  }

  static double _calcDelta(
      {required double x1,
      required double x2,
      required double y1,
      required double y2}) {
    final d = (y2 - y1) / (x2 - x1);
    return d.abs() < 1e-9 ? 0.0 : d;
  }

  double get minValue => minOrMaxValue(delta);
  double get maxValue => minOrMaxValue(-delta);
  double minOrMaxValue(double delta) => switch (delta.sign) {
        -1.0 => valueAtMaxPrice,
        _ => valueAtMinPrice,
      };

  bool includes(double price) => minPrice <= price && price <= maxPrice;

  PriceRange? whereValueIs(double value) {
    if (delta == 0.0) {
      return valueAtMinPrice == value ? PriceRange(minPrice, maxPrice) : null;
    }
    if (value == valueAtMinPrice) return PriceRange.point(minPrice);
    if (value == valueAtMaxPrice) return PriceRange.point(maxPrice);
    final diffFromValueAtMinPrice = valueAtMinPrice - value;
    final diffFromValueAtMaxPrice = valueAtMaxPrice - value;
    if (diffFromValueAtMinPrice.sign == diffFromValueAtMaxPrice.sign) {
      return null;
    }
    return PriceRange.point(minPrice - diffFromValueAtMinPrice / delta);
  }

  double? valueAt(double price) => minPrice <= price && price <= maxPrice
      ? valueAtMinPrice + (price - minPrice) * delta
      : null;

  @override
  String toString() => "[($minPrice..$maxPrice), "
      "minValue=$minValue, maxValue=$maxValue, delta=$delta, "
      "costBasis=$costBasis, realizedPnL=$realizedPnL]";
}

extension PositionAnalysis on Position {
  /// Analyzes the relative performance of this position compared to another,
  /// useful for determining crossover points (breakevens) between two strategies.
  PositionAnalyzer analyzeVersus(Position other,
      {required Commodity underlying, required Commodity money}) {
    return PositionAnalyzer(this - other, underlying: underlying, money: money);
  }
}
