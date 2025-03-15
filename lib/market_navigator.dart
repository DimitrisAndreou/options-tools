import 'dart:collection';

import 'assets.dart';
import 'markets.dart';
export 'expirations.dart';

class MarketsNavigator {
  final Iterable<Market> allMarkets;

  // asset -> money -> corresponding spot Market
  final Map<Asset, Map<Asset, Market>> _markets = HashMap();

  MarketsNavigator(this.allMarkets) {
    for (final market in allMarkets) {
      // TODO: if we're indexing reverse markets, why not call-put parity too?
      // I.e. add synthetic calls or puts if they are missing.
      for (final m in [market, market.reverse]) {
        (_markets[m.asset] ??= HashMap())[m.money] = m;
      }
    }
  }

  Market findBestMarket({required Asset asset, required Commodity money}) {
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

  Position markToMarket(
          {required Asset asset,
          required Commodity money,
          double slippage = 0.5}) =>
      Position.merge(asset.decompose().map((subposition) =>
          findBestMarket(asset: subposition.asset, money: money)
              .sell(size: subposition.size, slippage: slippage)));

  // TODO: implement
  // findFuture(asset, money, date) --> Market (either future or synthetic?)

  // TODO: expose interest rate somehow, per future (absolute & APR)
}
