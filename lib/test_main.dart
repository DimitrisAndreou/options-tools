import 'package:options_tools/url_fetcher.dart';
import 'assets.dart';
import 'markets.dart';
import 'market_navigator.dart';
import 'deribit.dart';

String percentify(double x, {int decimals = 1}) =>
    "${(100.0 * x).toStringAsFixed(decimals)}%";
String dollarify(double x) => "\$${x.toStringAsFixed(0)}";

void main() async {
  List<Market> markets = await Deribit.fetchMarkets(
      DeribitCoin.BTC, UrlFetcher(Duration(minutes: 15)));
  final usd = Commodity("USD");
  final btc = Commodity("BTC");
  final spotMarket =
      MarketsNavigator(markets).findBestMarket(asset: btc, money: usd);
  final spotPrice = spotMarket.midPrice;
  List<(DateTime, List<Market>)> callsByExpiration = markets
      .whereUnderlyingIs(btc)
      .options(
          callsOnly: true,
          minStrike: 80000,
          maxStrike: 85000,
          earliestExpiration: 1.DTE,
          latestExpiration: 7.DTE)
      // TODO: really need stable sort!!!
      .sortByStrikeDesc
      .sortByExpirationDesc
      .groupByExpiration;
  print("SPOT PRICE: $spotPrice");
  for (final (expiration, marketsOfExpiration) in callsByExpiration) {
    print("Expiration: $expiration");
    for (final market in marketsOfExpiration) {
      print("   $market");
    }
  }
  // final slippage = 0.5 + 0.14;
  // final spotBuyPrice = spotMarket.buyPrice(slippage);
  // for (final market in markets
  //     .whereUnderlyingIs(btc)
  //     .options(
  //         callsOnly: true,
  //         minStrike: 70000,
  //         maxStrike: 90000,
  //         earliestExpiration: 7.DTE)
  //     .sortByStrikeDesc
  //     .sortByExpirationDesc
  //     .groupByExpiration) {
  //   final option = market.asset as Option;

  //   // riskFreeYield =
  //   //     1.0 + max(0.0, contract.futurePrice / contract.spotPrice - 1);

  //   final premiumPerContract = market.sellPrice(slippage);
  //   final strike = option.strike;
  //   final minimumContracts = Deribit.getMinimumContract(option.underlying.name);
  //   final callsToSell = minimumContracts;
  //   final premium = callsToSell * premiumPerContract;
  //   final initialHeld = minimumContracts - premium;

  //   // final strikeAsChange = option.strike / spot - 1.0;
  //   final breakEven = spotBuyPrice * (1.0 - premiumPerContract);
  //   final breakEvenAsChange = breakEven / spotBuyPrice - 1.0;
  //   final maxYield = strike / spotPrice / (1.0 - premiumPerContract);
  //   final equivalentSellPrice = spotPrice * maxYield;
  //   // print("$market:\n   ${option.name.toString().padLeft(21)}: " +
  //   //     "breakeven ${percentify(breakEvenAsChange).padLeft(6)} " +
  //   //     "(${dollarify(breakEven).padLeft(7)}), " +
  //   //     "max yield ${percentify(maxYield - 1.0).padLeft(6)} " +
  //   //     "(like selling at: ${dollarify(equivalentSellPrice).padLeft(7)})" +
  //   //     ", achieved at >= ${dollarify(option.strike).padLeft(7)}). " +
  //   //     "Buy ${initialHeld.toStringAsFixed(5)} ${option.underlying} (${dollarify(initialHeld * spot)})");
  //   print(
  //       "### $market\n  market.money=${market.money}, option.underlying=${option.underlying}, "
  //       "option.money=${option.money}, "
  //       "spot=$spotPrice, slippage=$slippage, premium=$premium, "
  //       "strike=$strike, minimumContracts=$minimumContracts, premium=$premium, "
  //       "initialHeld=$initialHeld, breakEven=$breakEven, "
  //       "breakEvenAsChange=$breakEvenAsChange, maxYield=$maxYield, "
  //       "equivalentSellPrice=$equivalentSellPrice\n\n");
  // }

  // Iterable<(DateTime, Iterable<MarketsWithStrike>)> s = markets
  //     .whereUnderlyingIs(btc)
  //     .calls
  //     .byExpiration
  //     .map((marketsWithExpiration) =>
  //         (marketsWithExpiration.expiration, marketsWithExpiration.byStrike));

  // final btc = Commodity("BTC");
  // final marketsNavigator = MarketsNavigator.from(markets);
  // final btcMarkets = marketsNavigator.withMoney(btc).withAsset(btc);
  // print(btcMarkets.spot);

//   print("SPOT MARKETS");
//   for (final byAsset in allMarkets._markets.entries) {
//     if (byAsset.key is! Commodity) continue;
//     for (final spotMarket in byAsset.value.values) {
//       if (spotMarket.money is! Commodity) continue;
//       print(spotMarket);
//       if (spotMarket.asset == money) continue;
//       print("   ==> ${spotMarket.asset} " +
//           allMarkets
//               .withMoney(money)
//               .markToMarket(spotMarket.asset, slippage: 0.5)
//               .toString());
//     }
//   }
//   print("EXPIRABLES");
//   for (final e1 in allMarkets._expirables.entries) {
//     print("  DATE: ${e1.key}");
//     for (final e2 in e1.value.entries) {
//       final asset = e2.key;
//       for (final e3 in e2.value.entries) {
//         final money = e3.key;
//         print("    markets for: asset: $asset, money: $money");
//         final futureAndOptions = e3.value;
//         print(
//             "      future: ${futureAndOptions.future} with money: ${futureAndOptions.future?.asset}");
//         print("      options:");
//         for (final strike in futureAndOptions.options.entries) {
//           print(
//               "        strike: ${strike.key}, put: ${strike.value.put}, call: ${strike.value.call}");
//           for (Market m in strike.value.markets) {
//             Option o = m.asset as Option;
//             final type = o.isPut ? "put" : "call";
//             print("Exercise $type: ${o.exercise()}");
// //             print("   ==> " + allMarkets.withMoney(money).markToMarket(o, slippage: 0.5).toString());
//           }
//         }
//       }
//     }
//   }

//   print("======================");
//   print(allMarkets._markets[Commodity("ETH")]![Commodity("BTC")]!);
//   print(allMarkets._markets[Commodity("BTC")]![Commodity("ETH")]!);
//   print(
//       allMarkets.withMoney(Commodity("ETH")).withAsset(Commodity("BTC")).spot);
//   print(
//       allMarkets.withMoney(Commodity("USDT")).withAsset(Commodity("BTC")).spot);

//   print(
//       allMarkets.withMoney(Commodity("USDC")).withAsset(Commodity("ETH")).spot);
//   print(
//       allMarkets.withMoney(Commodity("ETH")).withAsset(Commodity("USDC")).spot);
}
