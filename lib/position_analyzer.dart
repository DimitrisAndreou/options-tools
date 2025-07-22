import 'dart:collection';
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

  Iterable<PriceAndValue> get minValue {
    final minValues = _segments.map((segment) => segment.minValue);
    final globalMinValue =
        minValues.map((priceAndValue) => priceAndValue.value).min;
    return PriceAndValue._mergeAdjacents(minValues
        .where((priceAndValue) => priceAndValue.value == globalMinValue));
  }

  Iterable<PriceAndValue> get maxValue {
    final maxValues = _segments.map((segment) => segment.maxValue);
    final globalMaxValue =
        maxValues.map((priceAndValue) => priceAndValue.value).max;
    return PriceAndValue._mergeAdjacents(maxValues
        .where((priceAndValue) => priceAndValue.value == globalMaxValue));
  }

  Iterable<PriceRange> get breakevens =>
      _segments.map((segment) => segment.breakeven).nonNulls;

  // Can be negative for profitless strategies.
  double get maxProfit => maxValue.first.value;
  // Can be negative for riskless strategies.
  double get maxRisk => -minValue.first.value;

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
    if (!isPoint) throw ArgumentError("isPoint == false");
    return fromPrice;
  }

  @override
  String toString() => isPoint ? "$fromPrice" : "[$fromPrice..$toPrice]";
}

class PriceAndValue {
  final PriceRange price;
  final double value;

  PriceAndValue(this.price, this.value);

  static List<PriceAndValue> _mergeAdjacents(Iterable<PriceAndValue> pnvs) =>
      pnvs.fold(
          [],
          (List<PriceAndValue> previous, PriceAndValue next) =>
              switch (previous) {
                [] => [next],
                [...List<PriceAndValue> rest, PriceAndValue last] =>
                  last.price.toPrice >= next.price.fromPrice
                      ? [
                          ...rest,
                          PriceAndValue(
                              PriceRange(
                                  last.price.fromPrice, next.price.toPrice),
                              next.value)
                        ]
                      : [...rest, last, next],
              });

  @override
  String toString() => "{$value @ $price}";
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
        delta: calcDelta(
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
    for (int i = 0; i < 5; ++i) {
      double nextPrice = (prevPrice + 1.0) * 1.5;
      double nextValue = priceToValue(nextPrice);
      deltas.add(calcDelta(
          x1: prevPrice, x2: nextPrice, y1: prevValue, y2: nextValue));
      prevPrice = nextPrice;
      prevValue = nextValue;
    }
    double delta =
        deltas.every((delta) => delta == deltas[0]) ? deltas[0] : 0.0;

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

  static double calcDelta(
          {required double x1,
          required double x2,
          required double y1,
          required double y2}) =>
      (y2 - y1) / (x2 - x1);

  PriceAndValue get minValue => minOrMaxValue(delta);
  PriceAndValue get maxValue => minOrMaxValue(-delta);
  PriceAndValue minOrMaxValue(double delta) => switch (delta.sign) {
        -1.0 => PriceAndValue(PriceRange.point(maxPrice), valueAtMaxPrice),
        1.0 => PriceAndValue(PriceRange.point(minPrice), valueAtMinPrice),
        _ => PriceAndValue(PriceRange(minPrice, maxPrice), valueAtMinPrice),
      };

  PriceRange? get breakeven => switch (delta) {
        0.0 => valueAtMinPrice == 0.0 ? PriceRange(minPrice, maxPrice) : null,
        _ => valueAtMinPrice.sign != valueAtMaxPrice.sign
            ? PriceRange.point(minPrice - valueAtMinPrice / delta)
            : null,
      };

  double? valueAt(double price) => minPrice <= price && price <= maxPrice
      ? valueAtMinPrice + (price - minPrice) * delta
      : null;

  @override
  String toString() => "[($minPrice..$maxPrice), "
      "minValue=$minValue, maxValue=$maxValue, breakeven=$breakeven, "
      "delta=$delta]";
}
