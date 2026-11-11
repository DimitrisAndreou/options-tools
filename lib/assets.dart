import 'dart:collection';
import 'data_source.dart';

export 'data_source.dart';

sealed class Asset {
  final String name;
  final DataSource? source;

  const Asset(this.name, {this.source});

  Line ofSize(double size, [Line? costBasis]) => Line(this, size, costBasis);
  Line get unit => Line(this, 1.0);
  Line atCost(Line costBasis, [double size = 1.0]) =>
      Line(this, size, costBasis);
  Line ofTotalCost(double size, Position? totalCostBasis) =>
      Line.fromCostBasis(this, size, totalCostBasis);

  bool get isCommodity => this is Commodity;
  Commodity get asCommodity => this as Commodity;
  bool get isExpirable => this is Expirable;
  Expirable get toExpirable => this as Expirable;
  bool get isDatedFuture => this is DatedFuture;
  DatedFuture get toDatedFuture => this as DatedFuture;
  bool get isOption => this is Option;
  Option get toOption => this as Option;

  String? get url => source?.assetUrl(this);

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Asset && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

sealed class Position {
  Position operator -() => this * -1.0;
  Position operator *(double size) =>
      size == 1.0 ? this : _ScaledPosition(this, size);

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

  // Returns the Position as a single Line, or null if it contains multiple
  // or zero lines, or if expectedAsset does not match.
  Line? singletonOrNull([Asset? expectedAsset]) {
    final lines = decompose();
    final single = lines.singleOrNull;
    if (single == null) return null;
    if (expectedAsset != null && expectedAsset != single.asset) return null;
    return single;
  }

  // Total cost basis (could be heterogeneous).
  Position? get costBasis;

  // Returns the cost basis as a single Line, optionally asserting that
  // it is in [expectedAsset] (e.g. USD).
  Line? costBasisSingle([Asset? expectedAsset]) =>
      costBasis?.singleton(expectedAsset);

  // Parameterizes or overrides the *unit* cost basis for matching assets.
  Position withCostBasis(Map<Asset, Line> bases) =>
      Position.mergeAll(decompose().map((line) => bases.containsKey(line.asset)
          ? line.withUnitCostBasis(bases[line.asset])
          : line));

  @override
  String toString();
}

// A line in a portfolio. That is, a raw, directly tradeable instrument,
// with a size and an optional unit cost basis.
class Line extends Position {
  final Asset asset;
  final double size;
  final Line? unitCostBasis;

  Line(this.asset, this.size, [this.unitCostBasis]);

  // Creates a Line initialized from a total [costBasis], deriving the unitCostBasis.
  factory Line.fromCostBasis(Asset asset, double size, Position? costBasis) {
    final costLine = costBasis?.singletonOrNull();
    final unitCost = (costLine != null && size != 0.0)
        ? Line(costLine.asset, (costLine.size / size).abs())
        : null;
    return Line(asset, size, unitCost);
  }

  // The total cost basis for this line (unitCostBasis * size).
  @override
  Line? get costBasis => unitCostBasis == null ? null : unitCostBasis! * size;

  Line withUnitCostBasis(Line? unitCostBasis) =>
      Line(asset, size, unitCostBasis);

  // Similar to the superclass implementation, except it returns Line,
  // not Position.
  @override
  Line operator *(double size) => Line(asset, this.size * size, unitCostBasis);
  @override
  Line operator -() => Line(asset, -this.size, unitCostBasis);

  @override
  Iterable<Line> decompose() => [this];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Line &&
          asset == other.asset &&
          size == other.size &&
          unitCostBasis == other.unitCostBasis;

  @override
  int get hashCode => Object.hash(asset, size, unitCostBasis);

  @override
  String toString() => unitCostBasis == null
      ? '$size X $asset'
      : '$size X $asset @ $unitCostBasis';
}

class _ScaledPosition extends Position {
  final Position position;
  final double scale;
  _ScaledPosition(this.position, this.scale);

  @override
  Position? get costBasis =>
      position.costBasis == null ? null : position.costBasis! * scale;

  @override
  Iterable<Line> decompose() =>
      position.decompose().map((line) => line * scale);

  @override
  String toString() => '($scale X $position)';
}

class _MergedPosition extends Position {
  final Map<Asset, double> _assetPositions = HashMap();
  final Map<Asset, Position> _assetCostBases = HashMap();

  _MergedPosition(Iterable<Position> positions) {
    for (final line in positions.expand((pos) => pos.decompose())) {
      _assetPositions.update(
          line.asset, (previousSize) => previousSize + line.size,
          ifAbsent: () => line.size);
      if (line.costBasis != null) {
        _assetCostBases.update(
          line.asset,
          (previousBasis) => previousBasis + line.costBasis!,
          ifAbsent: () => line.costBasis!,
        );
      }
    }
  }

  @override
  Position? get costBasis => _assetCostBases.isEmpty
      ? null
      : Position.mergeAll(_assetCostBases.values);

  @override
  Iterable<Line> decompose() sync* {
    for (final entry in _assetPositions.entries) {
      yield Line.fromCostBasis(
          entry.key, entry.value, _assetCostBases[entry.key]);
    }
  }

  @override
  Line operator [](Asset asset) =>
      decompose().firstWhere((line) => line.asset == asset);

  @override
  String toString() => '($_assetPositions)';
}

// USDC, BTC etc.
class Commodity extends Asset implements Comparable<Commodity> {
  static final Map<(String, DataSource?), Commodity> _cache = {};
  const Commodity(super.name, {super.source});
  factory Commodity.fromName(String name, {DataSource? source}) =>
      _cache.putIfAbsent((name, source), () => Commodity(name, source: source));

  @override
  int compareTo(Commodity that) {
    return name.compareTo(that.name);
  }
}

abstract class Expirable extends Asset {
  final Commodity underlying;
  // One derivative contract would refer to how many units of the underlying?
  final double contractLot;
  final double minSize;
  final DateTime expiration;

  Expirable(super.name,
      {required this.underlying,
      required this.expiration,
      this.contractLot = 1,
      this.minSize = 1,
      super.source});
}

class DatedFuture extends Expirable {
  DatedFuture(super.name,
      {required super.underlying,
      required super.expiration,
      super.contractLot,
      super.minSize,
      super.source});
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
      super.contractLot,
      super.minSize,
      super.source}) {
    if (isPut == isCall) {
      throw ArgumentError("Exactly one of these should be true: "
          "isPut: $isPut, isCall: $isCall");
    }
  }

  /// Human-readable Deribit-style option code (e.g., `SNDK-16JUL27-1180-C`),
  /// replacing opaque 21-char OCC symbols from YFinance while preserving
  /// `name` for exchange URLs.
  String get readableName {
    if (source != DataSource.yfinance) {
      return name;
    }
    const monthNames = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    final day = expiration.day;
    final month = monthNames[expiration.month];
    final year = (expiration.year % 100).toString().padLeft(2, '0');
    final strikeStr = strike == strike.toInt()
        ? strike.toInt().toString()
        : strike.toString().replaceAll(RegExp(r'\.?0+$'), '');
    final typeChar = isCall ? 'C' : 'P';
    return '${underlying.name}-$day$month$year-$strikeStr-$typeChar';
  }

  @override
  String toString() => '$name[strike=$money]';
}
