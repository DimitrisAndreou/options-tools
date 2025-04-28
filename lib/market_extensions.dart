import 'dart:collection';
import 'package:collection/collection.dart';

import 'assets.dart';
import 'markets.dart';
import 'oracle.dart';

extension MarketListExtension on Iterable<Market> {
  Iterable<Market> whereUnderlyingIs(Commodity underlying) => where((market) {
        final asset = market.asset;
        return asset == underlying ||
            asset.isExpirable && asset.toExpirable.underlying == underlying;
      });

  Iterable<Market> withMoney(Commodity money, Oracle helper) =>
      map((market) => helper.marketFor(asset: market.asset, money: money));

  Iterable<Market> get spotMarkets =>
      where((market) => market.asset is Commodity);
  Iterable<Market> get futures => where((market) => market.asset.isDatedFuture);
  Iterable<Market> get options => where((market) => market.asset.isOption);
  Iterable<Market> get calls =>
      where((market) => market.asset.isOption && market.asset.toOption.isCall);
  Iterable<Market> get puts =>
      where((market) => market.asset.isOption && market.asset.toOption.isPut);

  Iterable<Market> sortByExpiration(Order order) =>
      _sort((Expirable expirable) => expirable.expiration, order);
  Iterable<Market> sortByStrike(Order order) =>
      _sort<num>((Expirable expirable) => expirable.toOption.strike, order);

  // Stable sort!
  Iterable<Market> _sort<T extends Comparable<T>>(
          T Function(Expirable) keyExtractor, Order order) =>
      where((market) => market.asset.isExpirable)
          .indexed
          .toList()
          .sorted(((int, Market) a, (int, Market) b) {
        final (marketIndexA, marketA) = a;
        final (marketIndexB, marketB) = b;

        int comparison = order.compare(keyExtractor(marketA.asset as Expirable),
            keyExtractor(marketB.asset as Expirable));
        if (comparison != 0) return comparison;
        return marketIndexA.compareTo(marketIndexB);
      }).map((indexedMarket) => indexedMarket.$2);

  Map<DateTime, Iterable<Market>> groupByExpiration([Order? order]) =>
      (order == null ? this : sortByExpiration(order))
          ._groupBy((Expirable expirable) => expirable.expiration);

  Map<double, Iterable<Market>> groupByStrike([Order? order]) =>
      (order == null ? this : sortByStrike(order))
          ._groupBy((Expirable expirable) => expirable.toOption.strike);

  // Remember that the keys of the returned Map are in insertion order;
  // thus the ordering of markets is respected.
  Map<T, Iterable<Market>> _groupBy<T>(T Function(Expirable) keyExtractor) =>
      where((market) => market.asset.isExpirable)
          .groupListsBy((market) => keyExtractor(market.asset as Expirable));
}

extension MarketsMapExtension<T> on Map<T, Iterable<Market>> {
  Map<T, R> mapValues<R>(R Function(Iterable<Market>) fn) =>
      map((key, markets) => MapEntry(key, fn(markets)));
}
