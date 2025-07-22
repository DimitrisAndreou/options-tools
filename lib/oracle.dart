import 'dart:collection';
import 'dart:math';

import 'assets.dart';
import 'markets.dart';

sealed class Oracle {
  Market marketFor({required Asset asset, required Commodity money});

  Line markToMarket(
          {required Position position,
          required Commodity money,
          double slippage = 0.5}) =>
      Position.mergeAll(position.decompose().map((line) =>
          marketFor(asset: line.asset, money: money).sell(slippage) *
          line.size)).singleton(money);

  Line intrinsicValue({required Position position, required Commodity money}) =>
      Position.mergeAll(position
              .decompose()
              .map((line) => switch (line) {
                    Line(asset: Commodity()) => line,
                    Line(
                      asset: DatedFuture(underlying: final underlying),
                      size: final size
                    ) =>
                      underlying.pos(size),
                    Line(
                      asset: Option(
                        underlying: final underlying,
                        strike: final strike,
                        money: final strikeMoney,
                        isPut: final isPut,
                        contractLot: final lot
                      ),
                      size: final size
                    ) =>
                      strikeMoney.pos(size *
                          lot *
                          max(
                              0,
                              (isPut ? 1 : -1) *
                                  (strike -
                                      marketFor(
                                              asset: underlying,
                                              money: strikeMoney)
                                          .midPrice))),
                    _ => throw AssertionError(
                        "Unexpected asset from decompose(): ${line.asset}"),
                  })
              .map((line) => markToMarket(position: line, money: money)))
          .singleton(money);

  Line extrinsicValue({required Position position, required Commodity money}) =>
      (markToMarket(position: position, money: money) -
              intrinsicValue(position: position, money: money))
          .singleton(money);

  static Oracle fromMarkets(Iterable<Market> markets) =>
      _RealMarketsOracle(markets);
}

class _RealMarketsOracle extends Oracle {
  final Iterable<Market> allMarkets;

  // asset -> money -> corresponding spot Market
  final Map<Asset, Map<Asset, Market>> _markets = HashMap();
  final Map<(Asset, Asset), Market> _cache = HashMap();

  _RealMarketsOracle(this.allMarkets) {
    for (final market in allMarkets) {
      // TODO: if we're indexing reverse markets, why not call-put parity too?
      // I.e. add synthetic calls or puts if they are missing.
      for (final m in [market, market.reverse]) {
        (_markets[m.asset] ??= HashMap())[m.money] = m;
      }
    }
  }

  @override
  Market marketFor({required Asset asset, required Commodity money}) {
    final cachedResult = _cache[(asset, money)];
    if (cachedResult != null) {
      return cachedResult;
    }
    Set<Asset> visitedAssets = HashSet();
    SplayTreeSet<Market> candidateMarkets = SplayTreeSet((Market a, Market b) {
      int comparison = a.relativeSpread.compareTo(b.relativeSpread);
      if (comparison != 0) return comparison;
      comparison = a.asset.name.compareTo(b.asset.name);
      if (comparison != 0) return comparison;
      return a.money.name.compareTo(b.money.name);
    });
    candidateMarkets.add(Market.createIdentity(asset));
    while (candidateMarkets.isNotEmpty) {
      final visitingMarket = candidateMarkets.first;
      candidateMarkets.remove(visitingMarket);
      if (visitingMarket.money == money) {
        _cache[(asset, money)] = visitingMarket;
        return visitingMarket;
      }
      visitedAssets.add(visitingMarket.money);

      final Map<Asset, Market>? nextMarkets = _markets[visitingMarket.money];
      if (nextMarkets != null) {
        for (final entry in nextMarkets.entries) {
          final maybeCandidateMarket = entry.value;
          if (!visitedAssets.contains(maybeCandidateMarket.money)) {
            candidateMarkets.add(visitingMarket.concatenate(entry.value));
          }
        }
      }
    }
    throw ArgumentError("Can't create a market from $asset to $money");
  }

  // TODO: implement
  // findFuture(asset, money, date) --> Market (either future or synthetic?)

  // final futurePrice = future.midPrice;
  // final riskFreeYield = 1.0 + max(0.0, futurePrice / spotPrice - 1);
  // final riskFreeAPR = (riskFreeYield - 1.0) *
  //     Duration(days: 365).inMinutes /
  //     expiration.minutesLeft;

  // TODO: expose interest rate somehow, per future (absolute & APR)
}

class SimulatedOracle extends Oracle {
  final Map<(Asset, Commodity), double> _prices = HashMap();

  @override
  Market marketFor({required Asset asset, required Commodity money}) {
    if (asset == money) {
      return Market.createIdentity(asset);
    }
    final price = _prices[(asset, money)];
    if (price == null) {
      throw StateError("Price was requested for asset $asset and "
          "money $money but no such price was configured via setPrice(). "
          "Known prices: $_prices");
    }
    return Market.create(
        asset: asset, money: money, bidPrice: price, askPrice: price);
  }

  void setPrice(
      {required Asset asset, required Commodity money, required double price}) {
    _prices[(asset, money)] = price;
  }
}
