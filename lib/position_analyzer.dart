import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';

import 'assets.dart';
import 'oracle.dart';

class PositionAnalyzer {
  final Position position;
  final Commodity underlying;
  final Commodity money;
  final List<_PnLSegment> _segments = [];

  PositionAnalyzer(this.position,
      {required this.underlying, required this.money}) {
    final Set<DateTime> expirations = {};
    final interestingPoints = SplayTreeSet<double>();

    for (final inner in position.decompose()) {
      final innerAsset = inner.asset;
      if (innerAsset.isExpirable) {
        expirations.add(innerAsset.toExpirable.expiration);
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
        interestingPoints.add(option.strike);
      }
    }

    final oracle = SimulatedOracle();
    double priceToValue(double price) =>
        (oracle..setPrice(asset: underlying, money: money, price: price))
            .intrinsicValue(position: position, money: money)
            .size;

    double prevPrice = 0.0;
    for (final nextPrice in interestingPoints) {
      _segments.add(_PnLSegment.closed(priceToValue,
          minPrice: prevPrice, maxPrice: nextPrice));
      prevPrice = nextPrice;
    }
    _segments.add(_PnLSegment.open(priceToValue, minPrice: prevPrice));
  }

  double get minValue => _segments.map((segment) => segment.minValue).min;
  double get maxValue => _segments.map((segment) => segment.maxValue).max;

  Iterable<PriceRange> get breakevens => whereValueIs(0.0);
  Iterable<PriceRange> get bestPrices => whereValueIs(maxValue);
  Iterable<PriceRange> get worstPrices => whereValueIs(minValue);

  Iterable<PriceRange> whereValueIs(double value) => PriceRange._mergeAdjacents(
      _segments.map((segment) => segment.whereValueIs(value)).nonNulls);

  // The delta for prices just below the specified one.
  double deltaBefore(double price) {
    for (final segment in _segments) {
      if (segment.includes(price)) {
        return segment.delta;
      }
    }
    throw StateError("No segment included price $price, segments: $_segments");
  }

  // The delta for prices just above the specified one.
  double deltaAfter(double price) {
    for (final segment in _segments.reversed) {
      if (segment.includes(price)) {
        return segment.delta;
      }
    }
    throw StateError("No segment included price $price, segments: $_segments");
  }

  // Transforms a position to a same position but with an adjusted size,
  // so that the resulting position has the specified maximum risk.
  static Position scalePositionToRisk(Position position, double desiredMaxRisk,
          {required Commodity underlying, required Commodity money}) =>
      position *
      (desiredMaxRisk /
          PositionAnalyzer(position, underlying: underlying, money: money)
              .maxRisk);

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
  late final double valueAtMinPrice;
  late final double valueAtMaxPrice;
  // Value change for a unit of price change
  // Critical to have correct sign here, i.e. if it is zero, it must be
  // zero, not 0.00000000009
  late final double delta;

  _PnLSegment(
      {required this.minPrice,
      required this.valueAtMinPrice,
      required this.maxPrice,
      required this.valueAtMaxPrice,
      required this.delta}) {
    if (!minPrice.isFinite) {
      throw ArgumentError("minPrice ($minPrice) must be finite");
    }
    if (minPrice >= maxPrice) {
      throw ArgumentError("minPrice ($minPrice) >= maxPrice ($maxPrice)");
    }
  }

  factory _PnLSegment.closed(double Function(double) priceToValue,
      {required double minPrice, required double maxPrice}) {
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
            y2: valueAtMaxPrice));
  }

  factory _PnLSegment.open(double Function(double) priceToValue,
      {required double minPrice}) {
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
    final double tentativeDelta = (deltas..sort())[medianIndex];
    final double delta =
        tentativeDelta.abs() < 0.0000000000000001 ? 0.0 : tentativeDelta;

    return _PnLSegment(
        minPrice: minPrice,
        valueAtMinPrice: valueAtMinPrice,
        maxPrice: double.infinity,
        valueAtMaxPrice: switch (delta.sign) {
          1.0 => double.infinity,
          -1.0 => double.negativeInfinity,
          _ => valueAtMinPrice
        },
        delta: delta);
  }

  static double _calcDelta(
          {required double x1,
          required double x2,
          required double y1,
          required double y2}) =>
      (y2 - y1) / (x2 - x1);

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
      "minValue=$minValue, maxValue=$maxValue, delta=$delta]";
}
