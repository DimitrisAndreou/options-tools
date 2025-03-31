import 'assets.dart';

import 'dart:math';
import 'dart:collection';

import 'package:collection/collection.dart';

export 'expirations.dart';

abstract class Market {
  Asset get asset;
  Asset get money;
  double get bidPrice;
  double get bidSize;
  double get askPrice;
  double get askSize;

  Market();

  factory Market.create({
    required Asset asset,
    required Asset money,
    required double bidPrice,
    required double askPrice,
    double bidSize = double.infinity,
    double askSize = double.infinity,
  }) =>
      _DirectMarket(
          asset: asset,
          money: money,
          bidPrice: bidPrice,
          askPrice: askPrice,
          bidSize: bidSize,
          askSize: askSize);
  factory Market.createIdentity(Asset asset) => _IdentityMarket(asset);

  // Given a strategy, you trade() each leg, get a synthetic asset
  // for each leg, then you just merge them all,
  // and you end up with a position of the strategy, including a
  // single (merged) money position (the cost basis).
  Asset long([double slippage = 0.5]) => SyntheticAsset(
      [asset.position(1.0), money.position(-buyPrice(slippage))]);
  Asset short([double slippage = 0.5]) => SyntheticAsset(
      [asset.position(-1.0), money.position(sellPrice(slippage))]);

  double buyPrice([double slippageRatio = 0.5]) =>
      bidPrice + _slippage(slippageRatio);
  double sellPrice([double slippageRatio = 0.5]) =>
      askPrice - _slippage(slippageRatio);

  double _slippage(double slippageRatio) {
    if (!(slippageRatio >= 0.0 && slippageRatio <= 1.0)) {
      throw ArgumentError(
          'Slippage ratio must be in [0, 1], was: $slippageRatio');
    }
    return (askPrice - bidPrice) * slippageRatio;
  }

  double get midPrice => (bidPrice + askPrice) / 2.0;
  // The spread size (ask - bid) compared to midPrice.
  double get relativeSpread => (askPrice - bidPrice) / midPrice;

  Market get reverse {
    if (this is _InverseMarket) {
      return (this as _InverseMarket)._market;
    }
    return _InverseMarket(this);
  }

  // Given a market A-B, and a B-C, create a market A-C.
  Market concatenate(Market that) {
    return _SyntheticMarket(this, that);
  }

  // In case this market is a synthetic one, this would return all the intermediate markets
  // that are required to be combined in order for this market to be offered.
  Iterable<Market> decompose() => [this];

  @override
  String toString() =>
      '$asset, bid: $bidPrice $money, ask: $askPrice $money [${[
        asset
      ].followedBy(decompose().map((m) => m.money)).map((a) => a.toString()).join("->")}]';
}

class _DirectMarket extends Market {
  @override
  final Asset asset;
  @override
  final Asset money;
  @override
  final double bidPrice;
  @override
  final double bidSize;
  @override
  final double askPrice;
  @override
  final double askSize;

  _DirectMarket({
    required this.asset,
    required this.money,
    required this.bidPrice,
    required this.askPrice,
    this.bidSize = double.infinity,
    this.askSize = double.infinity,
  }) {
    if (bidPrice > askPrice) {
      throw ArgumentError("Bid price cannot be greater than ask price! $this");
    }
  }
}

class _IdentityMarket extends _DirectMarket {
  _IdentityMarket(Asset asset)
      : super(
            asset: asset,
            money: asset,
            bidPrice: 1.0,
            askPrice: 1.0,
            bidSize: double.infinity,
            askSize: double.infinity);

  @override
  Iterable<Market> decompose() => [];
}

class _InverseMarket extends Market {
  final Market _market;
  _InverseMarket(this._market);

  @override
  Asset get asset => _market.money;
  @override
  Asset get money => _market.asset;
  @override
  double get bidPrice => 1.0 / _market.askPrice;
  @override
  double get bidSize => _market.askSize / _market.askPrice;
  @override
  double get askPrice => 1.0 / _market.bidPrice;
  @override
  double get askSize => _market.bidSize / _market.bidPrice;
}

class _SyntheticMarket extends Market {
  final Market _a2bMarket;
  final Market _b2cMarket;
  _SyntheticMarket(Market a2bMarket, Market b2cMarket)
      : _a2bMarket = a2bMarket,
        _b2cMarket = b2cMarket {
    if (_a2bMarket.money != _b2cMarket.asset) {
      throw ArgumentError("The <money> of the first market: $_a2bMarket, "
          "must be the <asset> of the second market: $_b2cMarket");
    }
    if (_a2bMarket.asset == _b2cMarket.money) {
      throw ArgumentError("The <asset> of the first market: $_a2bMarket, "
          "cannot also be the <money> of the second market: $_b2cMarket");
    }
  }

  @override
  Asset get asset => _a2bMarket.asset;
  @override
  Asset get money => _b2cMarket.money;

  @override
  double get bidPrice => _a2bMarket.bidPrice * _b2cMarket.bidPrice;
  @override
  double get bidSize =>
      min(_a2bMarket.bidSize * _a2bMarket.bidPrice, _b2cMarket.bidSize);
  @override
  double get askPrice => _a2bMarket.askPrice * _b2cMarket.askPrice;
  @override
  double get askSize =>
      min(_a2bMarket.askSize * _a2bMarket.askPrice, _b2cMarket.askSize);

  @override
  Iterable<Market> decompose() =>
      _a2bMarket.decompose().followedBy(_b2cMarket.decompose());
}

enum Order {
  asc,
  desc;

  int compare<T extends Comparable<T>>(T t1, T t2) {
    int comparison = t1.compareTo(t2);
    if (this == desc) comparison = -comparison;
    return comparison;
  }
}

extension MarketListExtension on Iterable<Market> {
  Iterable<Market> whereUnderlyingIs(Commodity underlying) => where((market) {
        final asset = market.asset;
        return asset is OfIntrinsicValue &&
            (asset as OfIntrinsicValue).underlying == underlying;
      });

  Iterable<Market> withMoney(Commodity money, MarketsNavigator helper) =>
      map((market) => helper.findBestMarket(asset: market.asset, money: money));

  Iterable<Market> get futures => where((market) => market.asset.isDatedFuture);
  Iterable<Market> get options => where((market) => market.asset.isOption);
  Iterable<Market> get calls =>
      where((market) => market.asset.isOption && market.asset.toOption.isCall);
  Iterable<Market> get puts =>
      where((market) => market.asset.isOption && market.asset.toOption.isPut);

  Iterable<Market> sortByExpiration(Order order) =>
      _sort((Expirable expirable) => expirable.expiration, order);
  Iterable<Market> sortByStrike(Order order) =>
      _sort<num>((Expirable expirable) => expirable.strike, order);

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
          ._groupBy((Expirable expirable) => expirable.strike);

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

/*
.over(), under(), probability(), 

θα εχω και τετοια για να ζευγαρωνω συμβολαια (ειτε με καποια αποσταση 
στα strikes, ειτε με καποια αποσταση στα dates)
οποτε απο κει που εχω χυμα τα calls, με λιγα keystrokes πιο περα, 
να εχω ολα τα spreads που με ενδιαφερουν, και με ένα map() ακόμα --> 
over/under στοιχηματα

Ολα τα box spreads!
*/

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
      Position.merge(asset.decompose().map((innerPosition) =>
          findBestMarket(asset: innerPosition.asset, money: money)
              .short(slippage)
              .position(innerPosition.size)));

  // TODO: implement
  // findFuture(asset, money, date) --> Market (either future or synthetic?)

  // TODO: expose interest rate somehow, per future (absolute & APR)
}
