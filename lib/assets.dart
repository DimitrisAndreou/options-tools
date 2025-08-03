import 'dart:collection';

// TODO: this can be something richer; e.g. an object that also has a url
// to the tradeable instrument.
sealed class Asset {
  final String name;
  const Asset(this.name);

  Line pos(double size) => Line(this, size);
  Line get unit => Line(this, 1.0);

  bool get isCommodity => this is Commodity;
  Commodity get asCommodity => this as Commodity;
  bool get isExpirable => this is Expirable;
  Expirable get toExpirable => this as Expirable;
  bool get isDatedFuture => this is DatedFuture;
  DatedFuture get toDatedFuture => this as DatedFuture;
  bool get isOption => this is Option;
  Option get toOption => this as Option;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Asset && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

sealed class Position {
  Position operator -() => this * -1.0;
  Position operator *(double size) => _ScaledPosition(this, size);

  Position operator +(Position that) => _MergedPosition([this, that]);
  Position operator -(Position that) => _MergedPosition([this, -that]);

  static Position mergeAll(Iterable<Position> positions) =>
      _MergedPosition(positions);

  Iterable<Line> decompose();
  Line operator [](Asset asset) =>
      decompose().firstWhere((line) => line.asset == asset);

  // Returns the Position as a single Line, or throws an exception if it's
  // more complicated.
  // If a expectedAsset is specified, then it is also asserted that the
  // Line's asset is the expected one.
  Line singleton([Asset? expectedAsset]) {
    Iterable<Line> lines = decompose();
    if (lines.singleOrNull == null) {
      throw StateError("Unexpected lines, expected $expectedAsset, was $lines");
    }
    Line single = lines.single;
    if (expectedAsset != null && expectedAsset != single.asset) {
      throw StateError(
          "Expected single asset: $expectedAsset, got ${single.asset}");
    }
    return single;
  }

  @override
  String toString();
}

// A line in a portfolio. That is, a raw, directly tradeable instrument,
// with a size.
class Line extends Position {
  final Asset asset;
  final double size;
  Line(this.asset, this.size);

  // Similar to the superclass implementation, except it returns Line,
  // not Position.
  @override
  Line operator *(double size) => Line(asset, this.size * size);
  @override
  Line operator -() => this * -1.0;

  @override
  Iterable<Line> decompose() => [this];

  @override
  String toString() => '$size X $asset';
}

class _ScaledPosition extends Position {
  final Position position;
  final double scale;
  _ScaledPosition(this.position, this.scale);

  @override
  Iterable<Line> decompose() =>
      position.decompose().map((line) => line * scale);

  @override
  String toString() => '($scale X $position)';
}

class _MergedPosition extends Position {
  final Iterable<Position> positions;
  final Map<Asset, double> _assetPositions = HashMap();
  _MergedPosition(this.positions) {
    for (final line in positions.expand((pos) => pos.decompose())) {
      _assetPositions.update(
          line.asset, (previousSize) => previousSize + line.size,
          ifAbsent: () => line.size);
    }
  }

  @override
  Iterable<Line> decompose() sync* {
    for (final entry in _assetPositions.entries) {
      yield Line(entry.key, entry.value);
    }
  }

  // Overriden as an optimization.
  @override
  Line operator [](Asset asset) => asset.pos(_assetPositions[asset]!);

  @override
  String toString() => 'Sum($positions)';
}

// USDC, BTC etc.
class Commodity extends Asset implements Comparable<Commodity> {
  static final Map<String, Commodity> _cache = {};
  const Commodity(super.name);
  factory Commodity.fromName(String name) =>
      _cache.putIfAbsent(name, () => Commodity(name));

  @override
  int compareTo(Commodity that) {
    return name.compareTo(that.name);
  }
}

abstract class Expirable extends Asset {
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
