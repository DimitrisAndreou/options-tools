import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'assets.dart';

class PositionAnalyzer {
  final Position position;
  final Commodity underlying;
  final Commodity money;
  late final List<StrategySegment> segments;

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

    final List<StrategySegment> segments = [];
    double prevPrice = 0.0;
    double prevValue = evaluateAtPrice(prevPrice);
    for (final nextPrice in interestingPoints) {
      double nextValue = evaluateAtPrice(nextPrice);
      segments.add(_ClosedSegment(
          minPrice: prevPrice,
          valueAtMinPrice: prevValue,
          maxPrice: nextPrice,
          valueAtMaxPrice: nextValue));
      prevPrice = nextPrice;
      prevValue = nextValue;
    }
    segments.add(_SemiSegment(
        minPrice: prevPrice,
        valueAtMinPrice: prevValue,
        nextPrice: prevPrice + 1.0,
        valueAtNextPrice: evaluateAtPrice(prevPrice + 1.0)));
    this.segments = List.unmodifiable(segments);
  }

  @override
  String toString() =>
      "PositionAnalyzer(position: $position, underlying: $underlying, money: $money, "
      "segments: $segments)";
}

abstract class StrategySegment {
  // Price of the underlying (in money).
  final double minPrice;
  final double valueAtMinPrice;
  double get maxPrice;
  double get valueAtMaxPrice;

  StrategySegment({required this.minPrice, required this.valueAtMinPrice});

  // Value of position (in money).
  double get minValue => min(valueAtMinPrice, valueAtMaxPrice);
  double get maxValue => max(valueAtMinPrice, valueAtMaxPrice);

  List<double> get breakevenPrices;

  @override
  String toString() => "$minPrice ($valueAtMinPrice)-->";
}

class _ClosedSegment extends StrategySegment {
  @override
  final double maxPrice;
  @override
  final double valueAtMaxPrice;

  _ClosedSegment(
      {required super.minPrice,
      required super.valueAtMinPrice,
      required this.maxPrice,
      required this.valueAtMaxPrice}) {
    if (maxPrice <= minPrice) {
      throw ArgumentError(
          "Max price ($maxPrice) must be > min price ($minPrice)");
    }
  }

  @override
  List<double> get breakevenPrices => [
        if (valueAtMinPrice == 0.0) minPrice,
        if (valueAtMinPrice.sign != valueAtMaxPrice.sign)
          minPrice -
              (valueAtMinPrice * (maxPrice - minPrice)) /
                  (valueAtMaxPrice - valueAtMinPrice),
        if (valueAtMaxPrice == 0.0) maxPrice,
      ];
}

class _SemiSegment extends StrategySegment {
  final double _nextPrice;
  final double _valueAtNextPrice;
  // value change for a unit of price change
  late final double _delta;

  _SemiSegment(
      {required super.minPrice,
      required super.valueAtMinPrice,
      required double nextPrice,
      required double valueAtNextPrice})
      : _nextPrice = nextPrice,
        _valueAtNextPrice = valueAtMinPrice {
    if (nextPrice <= minPrice) {
      throw ArgumentError(
          "Next price ($nextPrice) must be > min price ($minPrice)");
    }
    _delta = (_valueAtNextPrice - valueAtMinPrice) / (_nextPrice - minPrice);
  }

  @override
  double get maxPrice => double.infinity;
  @override
  double get valueAtMaxPrice => switch (_delta.sign) {
        1.0 => double.infinity,
        -1.0 => double.negativeInfinity,
        _ => valueAtMinPrice
      };

  // TODO: simplify with _ClosedSegment.breakevenPrices
  @override
  List<double> get breakevenPrices => [
        if (valueAtMinPrice == 0.0) minPrice,
        if (valueAtMinPrice.sign != valueAtMaxPrice.sign)
          minPrice - valueAtMinPrice / _delta,
        if (valueAtMaxPrice == 0.0) maxPrice,
      ];
}
