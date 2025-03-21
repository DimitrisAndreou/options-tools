import 'package:options_tools/url_fetcher.dart';
import 'assets.dart';
import 'markets.dart';
import 'market_navigator.dart';
import 'deribit.dart';
import 'dart:math';

String percentify(double x, {int decimals = 1}) =>
    "${(100.0 * x).toStringAsFixed(decimals)}%";
String dollarify(double x) => "\$${x.toStringAsFixed(0)}";

void main() async {
  // TODO: make it simpler to fetch BTC and ETH together (and merge the markets).
  List<Market> markets = await Deribit.fetchMarkets(
      DeribitCoin.BTC, UrlFetcher(Duration(minutes: 15)));
  final usd = Commodity("USD");
  final btc = Commodity("BTC");
  final spotMarket =
      MarketsNavigator(markets).findBestMarket(asset: btc, money: usd);
  final spotPrice = spotMarket.midPrice;

  final slippage = 0.5 + 0.14;
  final spotBuyPrice = spotMarket.buyPrice(slippage);
  final Map<DateTime, Market> futures = markets
      .whereUnderlyingIs(btc)
      .futures
      .groupByExpiration()
      .mapValues((ms) => ms.single);

  for (final optionsByExpiration in markets
      .whereUnderlyingIs(btc)
      .calls
      .groupByExpiration(Order.desc)
      .mapValues((ms) => ms.sortByStrike(Order.asc))
      .entries) {
    final expiration = optionsByExpiration.key;
    final options = optionsByExpiration.value;
    final future = futures[expiration];
    if (future == null) continue;
    final futurePrice = future.midPrice;
    final riskFreeYield = 1.0 + max(0.0, futurePrice / spotPrice - 1);
    final riskFreeAPR = (riskFreeYield - 1.0) *
        Duration(days: 365).inMinutes /
        expiration.minutesLeft;

    print("\n\n=========== Expiration: ${expiration.daysLeft} days and "
        "${expiration.hoursModuloDaysLeft} hours, "
        "risk-free yield: ${percentify(riskFreeYield - 1.0)} "
        "(APR: ${percentify(riskFreeAPR).padLeft(5)}) "
        "===========\n");

    for (final market in options) {
      final option = market.asset as Option;

      final premiumPerContract = market.sellPrice(slippage);
      final soldCalls = Deribit.getMinimumContract(option.underlying.name);
      final premium = soldCalls * premiumPerContract;
      final initialHeld = soldCalls - premium;

      // final strikeAsChange = option.strike / spot - 1.0;
      final breakEven = spotBuyPrice * (1.0 - premiumPerContract);
      final breakEvenAsChange = breakEven / spotBuyPrice - 1.0;
      final maxYield = option.strike / spotPrice / (1.0 - premiumPerContract);

      if (maxYield <= riskFreeYield) continue;

      final equivalentSellPrice = spotPrice * maxYield;
      print("${option.name.toString().padLeft(21)}: " +
          "breakeven ${percentify(breakEvenAsChange).padLeft(6)} " +
          "(${dollarify(breakEven).padLeft(7)}), " +
          "max yield ${percentify(maxYield - 1.0).padLeft(6)} " +
          "(like selling at: ${dollarify(equivalentSellPrice).padLeft(7)})" +
          ", achieved at >= ${dollarify(option.strike).padLeft(7)}). " +
          "Buy ${initialHeld.toStringAsFixed(5)} ${option.underlying} (${dollarify(initialHeld * spotPrice)})");
    }
  }

  print("========================");
  print("========================");
  print("========================");
  for (final MapEntry<DateTime,
          Map<double, ({Market? call, Market? put})>> expirationToStrike
      in markets
          .whereUnderlyingIs(btc)
          .options
          .sortByExpiration(Order.desc)
          .groupByExpiration()
          .mapValues((ms) => ms.groupByStrike(Order.desc).mapValues(
              (ms) => (call: ms.calls.singleOrNull, put: ms.puts.singleOrNull)))
          .entries) {
    print("Date: ${expirationToStrike.key}");
    for (final strikeToOptions in expirationToStrike.value.entries) {
      final options = strikeToOptions.value;
      print(
          "  Strike: ${strikeToOptions.key} Call: ${options.call},  put: ${options.put}");
    }
  }
}
