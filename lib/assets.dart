import 'dart:collection';
import 'package:collection/collection.dart';

abstract class Decomposable {
  const Decomposable();

  // Decompose this asset into a list of SimpleAsset positions.
  // Iterable of Positions instead of Assets because it's important
  // to capture the *sign* and the *proportion* of the composed assets.
  Iterable<Position> decompose();
  // TODO: if you use decomposeAsSingle(), or decompose().single
  // then you can replace Position.merge(Iterable<Position>).

  // Returns the position of decompose() where the asset is the specified one
  // (or an empty position if it is not found).
  Position innerPositionOf(Asset asset) =>
      decompose().firstWhereOrNull((p) => p.asset == asset) ?? asset.empty;
}

sealed class Asset extends Decomposable {
  const Asset();

  @override
  String toString() => name;

  String get name;

  Position get unit => Position(this, 1.0);
  Position get empty => Position(this, 0.0);
  Position withSize(double size) => Position(this, size);

  bool get isExpirable => this is Expirable;
  Expirable get toExpirable => this as Expirable;
  bool get isDatedFuture => this is DatedFuture;
  DatedFuture get toDatedFuture => this as DatedFuture;
  bool get isOption => this is Option;
  Option get toOption => this as Option;
}

class Position extends Decomposable {
  final Asset asset;
  final double size;

  Position(this.asset, [this.size = 0.0]);

  factory Position.merge(Iterable<Position> positions) {
    final first = positions.firstOrNull;
    if (first == null) {
      throw ArgumentError("At least one position must be specified");
    }
    if (!positions.every((p) => p.asset == first.asset)) {
      throw ArgumentError("Only positions of the same asset can be merged: "
          "$positions");
    }
    return first.withSize(positions.map((p) => p.size).sum);
  }

  Position operator +(double size) => Position(asset, this.size + size);
  Position operator -(double size) => Position(asset, this.size - size);
  Position operator -() => Position(asset, -size);
  Position operator *(double size) => Position(asset, this.size * size);

  // This returns a rate.
  double operator /(Position that) {
    if (asset != that.asset) {
      throw ArgumentError("Incompatible positions: $this, $that");
    }
    return size / that.size;
  }

  Position withSize(double size) => Position(asset, size);
  Position empty() => Position(asset);

  bool get isZero => size == 0.0;

  @override
  Iterable<Position> decompose() =>
      asset.decompose().map((innerPosition) => innerPosition * size);

  @override
  String toString() => '($size $asset)';
}

// NamedAsset is an asset that can be traded directly;
// it doesn't consist of a combination of other assets.
// TODO: this can be something richer; e.g. an object that also has a url
// to the tradeable instrument.
abstract class NamedAsset extends Asset {
  final String _name;
  const NamedAsset(String name) : _name = name;

  @override
  String get name => _name;

  @override
  Iterable<Position> decompose() sync* {
    yield unit;
  }

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
  Position innerPositionOf(Asset asset) =>
      _assetPositions[asset] ?? asset.empty;

  @override
  String get name => "SyntheticAsset: ${_assetPositions.values}";

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
  String toString() => '$name[strike=$money]';
}
