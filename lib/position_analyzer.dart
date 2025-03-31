import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'assets.dart';

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
      if (innerAsset == money) continue;
      if (innerAsset is! OfIntrinsicValue) {
        throw AssertionError("decompose() for position $position returned asset"
            " which is not OfIntrinsicValue: $innerAsset");
      }
      Commodity underlying = (innerAsset as OfIntrinsicValue).underlying;
      if (underlying == money) {
        // Can't handle derivatives that depend on the "price of money",
        // because the price of money would be in terms of what?
        // Another money?
        throw ArgumentError("Cannot analyze asset: ${inner.asset}, which "
            "appears to be a derivative of money ($money)");
      }
      if (underlying != this.underlying) {
        throw ArgumentError("Unexpected underlying asset: $underlying, expected"
            ": ${this.underlying} (in position to be analyzed: $position)");
      }
      if (innerAsset.isExpirable) {
        expirations.add(innerAsset.toExpirable.expiration);
        if (expirations.length >= 2) {
          throw ArgumentError("At least 2 different option expirations "
              "involved in position: $position, impossible to analyze");
        }
      }
      if (innerAsset.isOption) {
        interestingPoints.add(innerAsset.toOption.strike);
      }
    }

    double evaluateAtPrice(double price) => position.decompose().map((inner) {
          final innerAsset = inner.asset as OfIntrinsicValue;
          final priceOfInnerAsset = innerAsset == money ? 1.0 : price;
          return inner.size * innerAsset.intrinsicValue(priceOfInnerAsset);
        }).sum;

    double prevPrice = 0.0;
    double prevValue = evaluateAtPrice(prevPrice);
    for (final nextPrice in interestingPoints) {
      double nextValue = evaluateAtPrice(nextPrice);
      _segments.add(_PnLSegment(
          minPrice: prevPrice,
          valueAtMinPrice: prevValue,
          nextPrice: nextPrice,
          valueAtNextPrice: nextValue,
          maxPrice: nextPrice));
      prevPrice = nextPrice;
      prevValue = nextValue;
    }
    // To handle the remaining space from the last interesting point to infinity
    _segments.add(_PnLSegment(
        minPrice: prevPrice,
        valueAtMinPrice: prevValue,
        nextPrice: prevPrice * 1.5,
        valueAtNextPrice: evaluateAtPrice(prevPrice * 1.5),
        maxPrice: double.infinity));
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

  double get maxYield => -maxValue.first.value / minValue.first.value;

  double valueAt(double price) =>
      _segments.map((segment) => segment.valueAt(price)).nonNulls.first;

  @override
  String toString() =>
      "PositionAnalyzer(position: $position, underlying: $underlying, money: $money, "
      "minValue: $minValue, maxValue: $maxValue, breakevens: $breakevens)";
}

// Inclusive range.
class PriceRange {
  final double fromPrice;
  final double toPrice;

  PriceRange(this.fromPrice, this.toPrice);
  PriceRange.point(final double price) : this(price, price);

  bool get isPoint => fromPrice == toPrice;

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
  final double valueAtMinPrice;
  final double nextPrice;
  final double valueAtNextPrice;
  final double maxPrice;
  // value change for a unit of price change
  late final double delta;
  late final double valueAtMaxPrice;

  _PnLSegment(
      {required this.minPrice,
      required this.valueAtMinPrice,
      required this.nextPrice,
      required this.valueAtNextPrice,
      required this.maxPrice}) {
    if (!minPrice.isFinite ||
        !valueAtMinPrice.isFinite ||
        !nextPrice.isFinite ||
        !valueAtNextPrice.isFinite) {
      throw ArgumentError("All these numbers were assumed to be finited: "
          "minPrice: $minPrice, valueAtMinPrice: $valueAtMinPrice, "
          "nextPrice: $nextPrice, valueAtNextPrice: $valueAtNextPrice");
    }
    if (nextPrice <= minPrice) {
      throw ArgumentError(
          "Next price ($nextPrice) must be > min price ($minPrice)");
    }
    // Not using maxPrice for delta computation because that might be +oo.
    delta = (valueAtNextPrice - valueAtMinPrice) / (nextPrice - minPrice);

    if (nextPrice == maxPrice) {
      valueAtMaxPrice = valueAtNextPrice;
    } else if (maxPrice.isInfinite) {
      valueAtMaxPrice = switch (delta.sign) {
        1.0 => double.infinity,
        -1.0 => double.negativeInfinity,
        _ => valueAtMinPrice
      };
    } else {
      valueAtMaxPrice = valueAtMinPrice + delta * (maxPrice - minPrice);
    }
  }

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
      "minValue=$minValue, maxValue=$maxValue, breakeven=$breakeven]";
}
