import 'dart:collection';

import 'package:collection/collection.dart';

import 'assets.dart';
import 'markets.dart';

class PositionAnalyzer {
  // map each underlying to interesting price point (where the PNL chart bends).
  final Map<Commodity, SplayTreeSet<double>> _underlyingsToInterestingPoints =
      {};

  PositionAnalyzer(Position p, Commodity money) {
    _underlyingsToInterestingPoints[money] = SplayTreeSet.from([1.0]);
    Set<DateTime> expirations = {};
    for (final inner in p.decompose()) {
      final innerAsset = inner.asset;
      if (innerAsset == money) continue;
      if (innerAsset is! OfIntrinsicValue) {
        throw AssertionError("decompose() for position $p returned asset "
            "which is not OfIntrinsicValue: $innerAsset");
      }
      Commodity underlying = (innerAsset as OfIntrinsicValue).underlying;
      if (underlying == money) {
        // Can't handle derivatives that depend on the "price of money",
        // because the price of money would be in terms of what?
        // Another money?
        throw ArgumentError("Cannot analyze asset: ${inner.asset}, which "
            "appears to be a derivative of money ($money)");
      }
      final interestingPoints = _underlyingsToInterestingPoints.putIfAbsent(
          underlying, () => SplayTreeSet<double>());
      if (innerAsset.isExpirable) {
        expirations.add(innerAsset.toExpirable.expiration);
        if (expirations.length >= 2) {
          throw ArgumentError("At least 2 different option expirations "
              "involved in position: $p, impossible to analyze");
        }
      }
      // TODO: TMP
      interestingPoints.add(0.0);
      if (innerAsset.isOption) {
        final o = innerAsset.toOption;
        interestingPoints.add(o.strike);
        // TODO: TMP
        // interestingPoints.add(o.strike * 2);
      }
    }

    print("Position: $p");
    for (final Map<Commodity, double> prices
        in _cartesianProduct(_underlyingsToInterestingPoints)) {
      final double value = p.decompose().map((inner) {
        final innerAsset = inner.asset as OfIntrinsicValue;
        return inner.size *
            innerAsset.intrinsicValue(prices[innerAsset.underlying]!);
      }).sum;
      print("  with prices: $prices --> value: $value ($money)");
    }
  }

  static Iterable<Map<K, V>> _cartesianProduct<K, V>(
      Map<K, Iterable<V>> choicesPerKey) {
    return _cartesianProductRecursion(choicesPerKey.entries.toList())
        .map((entries) => Map.fromEntries(entries));
  }

  static Iterable<Iterable<MapEntry<K, V>>> _cartesianProductRecursion<K, V>(
      List<MapEntry<K, Iterable<V>>> choicesPerKey,
      [int depth = 0]) sync* {
    if (choicesPerKey.isEmpty || depth == choicesPerKey.length) {
      yield [];
      return;
    }
    final entryToIterate = choicesPerKey[depth]!;
    for (final choice in entryToIterate.value) {
      final chosen = MapEntry(entryToIterate.key, choice);
      for (Iterable<MapEntry<K, V>> restCombinations
          in _cartesianProductRecursion(choicesPerKey, depth + 1)) {
        yield [chosen, ...restCombinations];
      }
    }
  }

  @override
  String toString() => "PositionAnalyzer($_underlyingsToInterestingPoints)";
}

  // find underlyings (ignoring money).
  // If one, easy. If more?

  // Find expirations. If one, easy. If more?

  // if both are single, then:
  // find all interesting points:
  // $0 and all strikes.
  // Mark to market the position forEach (spotPrice: interesting)
  // max gain / max loss
  //
  // after last strike (interesting point): what then?
  // maybe just double price (or price++), and see what's the effect on the
  // position. flat? Up? Down? Value = price * a + b;
  // This is enough. 
  // 
  // Then you have the valuation for all the range of price: [0.0 ... +oo]
  // Then you can find max gain, max loss etc, for all of it,
  // or for *some* of it!

  // If you have two underlyings? It's a 2d space. You can still support it!
  // No need to provide price via an entire Market. Just pass the price
