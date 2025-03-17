import 'assets.dart';

import 'dart:math';
import 'package:collection/collection.dart';

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

  Asset trade({required double size, double slippage = 0.5}) {
    final price = size > 0.0 ? buyPrice(slippage) : sellPrice(slippage);
    return SyntheticAsset(
        [asset.position(size), money.position(-size * price)]);
  }

  double buyPrice([double slippageRatio = 0.5]) =>
      bidPrice + _slippage(slippageRatio);
  double sellPrice([double slippageRatio = 0.5]) =>
      askPrice - _slippage(slippageRatio);
  Position buy({required double size, double slippage = 0.5}) =>
      money.position(-size * buyPrice(slippage));
  Position sell({required double size, double slippage = 0.5}) =>
      money.position(size * sellPrice(slippage));

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

extension ListOfMarketOperations on Iterable<Market> {
  Iterable<Market> whereUnderlyingIs(Commodity underlying) =>
      where((market) => market.asset.underlying == underlying);

  Iterable<Market> get futures => where((market) => market.asset.isDatedFuture);

  Iterable<Market> options(
          {bool callsOnly = false,
          bool putsOnly = false,
          double minStrike = 0.0,
          double maxStrike = double.infinity,
          DateTime? earliestExpiration,
          DateTime? latestExpiration}) =>
      where((market) {
        if (!market.asset.isOption) return false;
        final option = market.asset as Option;
        return (callsOnly ? option.isCall : true) &&
            (putsOnly ? option.isPut : true) &&
            option.strike >= minStrike &&
            option.strike <= maxStrike &&
            (earliestExpiration == null ||
                earliestExpiration == option.expiration ||
                earliestExpiration.isBefore(option.expiration)) &&
            (latestExpiration == null ||
                latestExpiration == option.expiration ||
                latestExpiration.isAfter(option.expiration));
      });

  Iterable<Market> get sortByExpirationAsc =>
      _sort((Expirable expirable) => expirable.expiration, ascending: true);
  Iterable<Market> get sortByExpirationDesc =>
      _sort((Expirable expirable) => expirable.expiration, ascending: false);
  Iterable<Market> get sortByStrikeAsc =>
      _sort<num>((Expirable expirable) => expirable.strike, ascending: true);
  Iterable<Market> get sortByStrikeDesc =>
      _sort<num>((Expirable expirable) => expirable.strike, ascending: false);

  // Stable sort!
  Iterable<Market> _sort<T extends Comparable<T>>(
          T Function(Expirable) keyExtractor,
          {required bool ascending}) =>
      where((market) => market.asset.isExpirable)
          .indexed
          .toList()
          .sorted(((int, Market) a, (int, Market) b) {
        final (marketIndexA, marketA) = a;
        final (marketIndexB, marketB) = b;

        final keyA = keyExtractor(marketA.asset as Expirable);
        final keyB = keyExtractor(marketB.asset as Expirable);
        int comparison = keyA.compareTo(keyB);
        if (!ascending) comparison = -comparison;
        if (comparison != 0) return comparison;
        return marketIndexA.compareTo(marketIndexB);
      }).map((indexedMarket) => indexedMarket.$2);

  Map<DateTime, List<Market>> get groupByExpiration =>
      _groupBy((Expirable expirable) => expirable.expiration);

  Map<double, List<Market>> get groupByStrike =>
      _groupBy((Expirable expirable) => expirable.strike);

  Map<T, List<Market>> _groupBy<T>(T Function(Expirable) keyExtractor) =>
      where((market) => market.asset.isExpirable)
          .groupListsBy((market) => keyExtractor(market.asset as Expirable));
}

/*
How do I organize by Expiration & Strike?
I.e. Map<(DateTime, double), (Put, Call)>


.over(), under(), probability(), 

θα εχω και τετοια για να ζευγαρωνω συμβολαια (ειτε με καποια αποσταση 
στα strikes, ειτε με καποια αποσταση στα dates)
οποτε απο κει που εχω χυμα τα calls, με λιγα keystrokes πιο περα, 
να εχω ολα τα spreads που με ενδιαφερουν, και με ένα map() ακόμα --> 
over/under στοιχηματα

Ολα τα box spreads!
*/
