import 'dart:collection';

sealed class Asset {
  @override
  String toString() => name;

  String get name;

  // Decompose this asset into a list of SimpleAsset positions.
  Iterable<Position> decompose();

  Position position(double size) => Position(this, size);

  Commodity? get underlying;

  bool get isExpirable => this is Expirable;
  bool get isDatedFuture => this is DatedFuture;
  bool get isOption => this is Option;
}

class Position {
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

  bool get isZero => size == 0.0;

  @override
  String toString() => '($size $asset)';
}

// NamedAsset is an asset that can be traded directly;
// it doesn't consist of a combination of other assets.
abstract class NamedAsset extends Asset {
  final String _name;
  NamedAsset(String name) : _name = name;

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
  Commodity._internal(super.name);
  factory Commodity(String name) =>
      _cache.putIfAbsent(name, () => Commodity._internal(name));

  @override
  int compareTo(Commodity that) {
    return name.compareTo(that.name);
  }

  @override
  Commodity get underlying => this;
}

// A SyntheticAsset is an Asset that is a combination of other assets
// (simple or synthetic) of particular proportions.
// Usually it cannot be traded directly or atomically.
// Moreover, an entire portfolio can be represented as a single
// synthetic asset.
class SyntheticAsset extends Asset {
  final Map<Asset, Position> _assetPositions = HashMap();

  SyntheticAsset(Iterable<Position> positions) {
    for (final position in positions) {
      _assetPositions.update(
          position.asset, (existing) => existing + position.size,
          ifAbsent: () => position);
    }
  }

  // Given a strategy, you trade() each leg, get a synthetic asset
  // for each leg, then you just merge them all via this constructor,
  // and you end up with a position of the strategy, including a
  // single (merged) money position (the cost basis).
  SyntheticAsset.mergeAssets(Iterable<Asset> assets)
      : this(assets.expand((a) => a.decompose()));

  @override
  Iterable<Position> decompose() sync* {
    for (final position in _assetPositions.values) {
      for (final innerPosition in position.asset.decompose()) {
        yield innerPosition.asset.position(position.size);
      }
    }
  }

  @override
  String get name => "SyntheticAsset: ${_assetPositions.entries}";

  @override
  Commodity? get underlying => null;

  @override
  bool operator ==(Object other) =>
      other is SyntheticAsset && _assetPositions == other._assetPositions;
  @override
  int get hashCode => _assetPositions.hashCode;
}

abstract class Expirable extends NamedAsset {
  @override
  final Commodity underlying;
  final Commodity money;
  // price at which the exchange is exercised. Quoted in money.
  final double strike;
  // One derivative contract would refer to how many units of the underlying?
  final double contractLot;
  final DateTime expiration;
  // Does this contract refer to a "buy" exchange? This is true
  // for futures & call options, but not for puts (those are sells).
  final bool _isBuy;

  Expirable(
    super.name, {
    required this.underlying,
    required this.money,
    required this.strike,
    required this.expiration,
    required bool isBuy,
    this.contractLot = 1,
  }) : _isBuy = isBuy;

  Asset exercise() => SyntheticAsset([
        underlying.position(contractLot * (_isBuy ? 1 : -1)),
        money.position(strike * (_isBuy ? -1 : 1))
      ]);

  @override
  bool operator ==(Object that) {
    if (identical(this, that)) return true;
    if (that is! Expirable) return false;
    return name == that.name &&
        underlying == that.underlying &&
        money == that.money &&
        strike == that.strike &&
        contractLot == that.contractLot &&
        expiration == that.expiration &&
        _isBuy == that._isBuy;
  }

  @override
  int get hashCode => Object.hash(
      name, underlying, money, strike, contractLot, expiration, _isBuy);
}

class DatedFuture extends Expirable {
  DatedFuture(super.name,
      {required super.underlying,
      required super.money,
      required super.strike,
      required super.expiration,
      super.contractLot})
      : super(isBuy: true);

  // TODO: replace with ReversedFuture wrapper implementation
  // TODO: unused
  DatedFuture get reverse => DatedFuture('Reverse of [$name]',
      underlying: money,
      money: underlying,
      contractLot: 1.0 / contractLot,
      strike: 1.0 / strike,
      expiration: expiration);

  @override
  String toString() =>
      'Future($name,money=$money,underlying=$underlying,strike=$strike)';
}

class Option extends Expirable {
  final bool isPut;
  final bool isCall;

  Option(super.name,
      {required super.underlying,
      required super.money,
      required super.strike,
      this.isPut = false,
      this.isCall = false,
      required super.expiration,
      super.contractLot})
      : super(isBuy: isCall) {
    if (isPut == isCall) {
      throw ArgumentError("Exactly one of these should be true: " +
          "isPut: $isPut, isCall: $isCall");
    }
  }

  // TODO: replace with ReversedOption wrapper implementation
  // TODO: unused
  Option get reverse => Option('Reverse of [$name]',
      underlying: money,
      money: underlying,
      contractLot: 1.0 / contractLot,
      strike: 1.0 / strike,
      isPut: !isPut,
      isCall: !isCall,
      expiration: expiration);

  @override
  String toString() => '$name[strike=$money]';
}
