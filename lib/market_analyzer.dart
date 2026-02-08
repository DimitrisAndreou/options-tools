// All markets about an underlying:
// spot, futures, options.
// Commodity underlying, Commodity money.
// Organize all strategies.
// Maybe offer option to use markPrice too, as a fallback?
//   (this requires deep refactoring in Market)
// Probabilities.
// Vertical spreads.
// Covered calls built on this.
//

import 'assets.dart';
import 'markets.dart';
import 'oracle.dart';

class MarketNavigator {
  final ArchOracle oracle;
  final Commodity underlying;
  final Commodity money;
  final Market spot;

  late final Map<DateTime, Market> futuresByDate;

  MarketNavigator._(
      {required this.oracle,
      required this.underlying,
      required this.money,
      required this.spot,
      required Iterable<Market> futures,
      required Iterable<Market> options}) {
    // If .single fails, it means that there are multiple futures
    // of the same underlying (but different money). Instead of failing,
    // we should keep the best available market.
    // Hang on. The Oracle should tell you the available expirations
    // and contracts per underlying (,money, for options).
    Map<DateTime, Market> futuresByDate = futures
        .groupByExpiration(Order.asc)
        .mapValues((ms) => ms.tighestMarket);

    Map<DateTime, Map<double, ({Market? call, Market? put})>>
        optionsByExpirationAndStrike = options
            .groupByExpiration(Order.asc)
            .mapValues((ms) => ms.groupByStrike(Order.asc).mapValues((ms) => (
                  call: ms.calls.tighestMarketOrNull,
                  put: ms.puts.tighestMarketOrNull
                )));

    // We only use the intersection of future expirations and
    // option expirations to avoid making up the index price
    // at expirations lacking an actual traded future contract.
    // We can still use other expirations when we don't need the future price.
    final Set<DateTime> expirations = futuresByDate.keys
        .toSet()
        .intersection(optionsByExpirationAndStrike.keys.toSet());

    // index price at every expiration.
    // option chain at every expiration
    // probabilities at every expiration
  }

  factory MarketNavigator.create(ArchOracle oracle,
      {required Commodity underlying, required Commodity money}) {
    return MarketNavigator._(
        oracle: oracle,
        underlying: underlying,
        money: money,
        spot: oracle.marketFor(asset: underlying, money: money),
        futures: oracle.allMarkets.futures
            .whereUnderlyingIs(underlying)
            .coercedToMoney(money, oracle),
        options: oracle.allMarkets
            .whereUnderlyingIs(underlying)
            .optionsWithStrikeInMoney(money)
            .coercedToMoney(money, oracle));
  }
}
