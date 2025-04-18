import 'dart:collection';

import 'package:collection/collection.dart';

abstract class Decomposable {
  // Decompose this asset into a list of SimpleAsset positions.
  // Iterable of Positions instead of Assets because it's important
  // to capture the *sign* and the *proportion* of the composed assets.
  Iterable<Position> decompose();
}

abstract class WithIntrinsicValue {
  double intrinsicValue(
      {required Commodity commodity,
      required Commodity money,
      required double price});
}

sealed class Asset implements Decomposable, WithIntrinsicValue {
  const Asset();

  @override
  String toString() => name;

  String get name;

  Position unit() => Position(this, 1.0);
  Position position(double size) => Position(this, size);

  bool get isExpirable => this is Expirable;
  Expirable get toExpirable => this as Expirable;
  bool get isDatedFuture => this is DatedFuture;
  DatedFuture get toDatedFuture => this as DatedFuture;
  bool get isOption => this is Option;
  Option get toOption => this as Option;
}

class Position implements Decomposable, WithIntrinsicValue {
  final Asset asset;
  // TODO: double is not a great type for money.
  final double size;

  Position(this.asset, [this.size = 0.0]);

  factory Position.merge(Iterable<Position> positions) {
    Position first = positions.first;
    double size = first.size;
    for (Position next in positions.skip(1)) {
      if (next.asset != first.asset) {
        throw ArgumentError("Can't merge positions due to differing " +
            "assets, ${first.asset} != ${next.asset}");
      }
      size += next.size;
    }
    return first.withSize(size);
  }

  Position operator +(double size) => Position(asset, this.size + size);
  Position operator *(double size) => Position(asset, this.size * size);

  Position withSize(double size) => Position(asset, size);
  Position empty() => Position(asset);

  bool get isZero => size == 0.0;

  @override
  Iterable<Position> decompose() =>
      asset.decompose().map((innerPosition) => innerPosition * size);

  @override
  double intrinsicValue(
          {required Commodity commodity,
          required Commodity money,
          required double price}) =>
      asset.intrinsicValue(commodity: commodity, money: money, price: price) *
      size;

  @override
  String toString() => '($size $asset)';
}

// NamedAsset is an asset that can be traded directly;
// it doesn't consist of a combination of other assets.
abstract class NamedAsset extends Asset {
  final String _name;
  const NamedAsset(String name) : _name = name;

  @override
  String get name => _name;

  @override
  Iterable<Position> decompose() => [position(1.0)];

  @override
  bool operator ==(Object other) => other is NamedAsset && name == other.name;

  @override
  int get hashCode => _name.hashCode;
}

// USDC, BTC etc.
class Commodity extends NamedAsset implements Comparable<Commodity> {
  static final Map<String, Commodity> _cache = {};
  const Commodity(super.name);
  factory Commodity.fromName(String name) =>
      _cache.putIfAbsent(name, () => Commodity(name));

  @override
  double intrinsicValue(
      {required Commodity commodity,
      required Commodity money,
      required double price}) {
    if (this == commodity) return price;
    if (this == money) return 1.0;
    throw ArgumentError("Can only calculate intrinsicValue of commodity "
        "$this if given the price of that commodity, or if it is considered "
        "the money. Was given the price of "
        "commodity: $commodity, and the specifed money was $money");
  }

  @override
  int compareTo(Commodity that) {
    return name.compareTo(that.name);
  }
}

// A SyntheticAsset is an Asset that is a combination of other assets
// (simple or synthetic) of particular proportions.
// Usually it cannot be traded directly or atomically.
// Moreover, an entire portfolio can be represented as a single
// synthetic asset.
class SyntheticAsset extends Asset {
  final Map<Asset, Position> _assetPositions = HashMap();

  SyntheticAsset(Iterable<Position> positions) {
    for (final inner in positions.expand((p) => p.decompose())) {
      _assetPositions[inner.asset] =
          (_assetPositions[inner.asset] ?? inner.empty()) + inner.size;
    }
  }

  @override
  Iterable<Position> decompose() => _assetPositions.values;

  @override
  String get name => "SyntheticAsset: ${_assetPositions.values}";

  @override
  double intrinsicValue(
          {required Commodity commodity,
          required Commodity money,
          required double price}) =>
      decompose()
          .map((p) =>
              p.size *
              p.asset.intrinsicValue(
                  commodity: commodity, money: money, price: price))
          .sum;

  @override
  bool operator ==(Object that) =>
      that is SyntheticAsset && _assetPositions == that._assetPositions;
  @override
  int get hashCode => _assetPositions.hashCode;
}

abstract class Expirable extends NamedAsset {
  final Commodity underlying;
  // One derivative contract would refer to how many units of the underlying?
  final double contractLot;
  final DateTime expiration;

  Expirable(
    super.name, {
    required this.underlying,
    required this.expiration,
    this.contractLot = 1,
  });
}

class DatedFuture extends Expirable {
  DatedFuture(super.name,
      {required super.underlying,
      required super.expiration,
      super.contractLot});

  @override
  double intrinsicValue(
          {required Commodity commodity,
          required Commodity money,
          required double price}) =>
      underlying.intrinsicValue(
          commodity: commodity, money: money, price: price);

  @override
  String toString() => 'Future($name,underlying=$underlying)';
}

class Option extends Expirable {
  final Commodity money;
  // price at which the exchange is exercised. Quoted in money.
  final double strike;
  final bool isPut;
  final bool isCall;

  Option(super.name,
      {required super.underlying,
      required this.money,
      required this.strike,
      this.isPut = false,
      this.isCall = false,
      required super.expiration,
      super.contractLot}) {
    if (isPut == isCall) {
      throw ArgumentError("Exactly one of these should be true: " +
          "isPut: $isPut, isCall: $isCall");
    }
  }

  @override
  double intrinsicValue(
      {required Commodity commodity,
      required Commodity money,
      required double price}) {
    if (underlying != commodity || this.money != money) {
      throw ArgumentError("An option's intrinsic value can only be "
          "evaluated if given the price of the underlying, at the same "
          "money as the strike of the option. Option's underlying=and money");
    }
    if (price < strike) {
      if (isPut) {
        return (strike - price) * contractLot;
      }
    } else {
      if (isCall) {
        return (price - strike) * contractLot;
      }
    }
    return 0.0;
  }

  @override
  String toString() => '$name[strike=$money]';
}
