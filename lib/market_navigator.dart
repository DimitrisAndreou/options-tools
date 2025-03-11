import 'dart:collection';

import 'assets.dart';
import 'markets.dart';

class _FutureAndOptions {
  Market? future;
  // strike --> put/call markets
  final Map<double, _PutAndCall> options = SplayTreeMap();
}

class _PutAndCall {
  Market? put;
  Market? call;
  Iterable<Market> get markets sync* {
    if (put != null) yield put!;
    if (call != null) yield call!;
  }
}

class MarketsNavigator {
  // asset -> money -> corresponding spot Market
  final Map<Asset, Map<Asset, Market>> _markets = HashMap();
  // expiration -> asset -> money --> corresponding future Market
  final Map<DateTime, Map<Commodity, Map<Commodity, _FutureAndOptions>>>
      _expirables = SplayTreeMap();

  MarketsNavigator.from(Iterable<Market> allAvailableMarkets) {
    for (final market in allAvailableMarkets) {
      // TODO: if we're indexing reverse markets, why not do call-put parity too?
      // I.e. add synthetic calls or puts if they are missing.
      for (final m in [market, market.reverse]) {
        (_markets[m.asset] ??= HashMap())[m.money] = m;
        switch ((m.asset, m.money)) {
          case (DatedFuture future, Commodity money):
            (((_expirables[future.expiration] ??=
                        SplayTreeMap())[future.underlying] ??=
                    SplayTreeMap())[money] ??= _FutureAndOptions())
                .future = m;
            break;
          case (Option option, Commodity money):
            final putAndCall = (((_expirables[option.expiration] ??=
                        SplayTreeMap())[option.underlying] ??=
                    SplayTreeMap())[money] ??= _FutureAndOptions())
                .options[option.strike] ??= _PutAndCall();
            if (option.isCall) {
              putAndCall.call = m;
            } else {
              putAndCall.put = m;
            }
            break;
          default:
          // skip
        }
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

// markets.withMoney("USD")
//   .markToMarket(position)
//   .withAsset("BTC")
//     .spot  --> Market
//     .dates[]
//       .future    // --> also compute implied interest
//       .strikes[]
//         .strike
//         .put()
//         .call()
  MarketsWithMoney withMoney(Commodity money) => MarketsWithMoney(this, money);
}

class MarketsWithMoney {
  final MarketsNavigator allMarkets;
  final Commodity money;

  MarketsWithMoney(this.allMarkets, this.money);

  Position markToMarket(Asset asset, {double slippage = 0.5}) =>
      Position.merge(asset.decompose().map((position) => allMarkets
          .findBestMarket(asset: position.asset, money: money)
          .sell(size: position.size, slippage: slippage)));

  MarketsWithMoneyAndAsset withAsset(Commodity asset) =>
      MarketsWithMoneyAndAsset(allMarkets, asset: asset, money: money);
}

class MarketsWithMoneyAndAsset {
  final MarketsNavigator allMarkets;
  final Commodity asset;
  final Commodity money;
  final Market spot;

  MarketsWithMoneyAndAsset(this.allMarkets,
      {required this.asset, required this.money})
      : spot = allMarkets.findBestMarket(asset: asset, money: money);

  // TODO: add methods to this list?
  // UnmodifiableListView
  List<ExpirationsAccessor> get dates => throw ArgumentError("implement");
}

abstract class ExpirationsAccessor {
  Market get future;
  // TODO: add methods to this list? E.g. atm()?
  // UnmodifiableListView
  List<StrikeAccessor> get strikes;
}

abstract class StrikeAccessor {
  double get strike;
  Market get put;
  Market get call;
}

/*

BTC-26SEP25-140000-C
strike is in USD
market is in BTC
underlying is in BTC

for all markets
keep btc options, calls
order by date
order by strike

IDEA:
Create all markets in a "context" (or universe).
Each market then is able to change its money.

Via extension methods:

Primitives:
findBestMarket(asset, money) -> Market
findFuture(asset, money, date) -> Market
.over(), under(), probability(), 

markets.
.expirations( < 30 days)
.calls()
.atm()   // or .at(+30%)
.where(...)
.withMoney(usd)
.sortByDate()
.sortByStrike()

.groupByDate?
.groupByStrike?
.scatterPlot?

// Each expiration could reference its future (synthetic or not), and interest rate.
// Each option/future references its expiration.
*/
