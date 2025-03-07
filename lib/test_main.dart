import 'dart:collection';

import 'dart:convert';
import 'package:http/http.dart';
import 'package:options_tools/url_fetcher.dart';
import 'assets.dart';
import 'markets.dart';
import 'market_navigator.dart';
import 'deribit_io.dart';

void main() async {
  List<Market> markets = await DeribitIO.fetchMarkets(DeribitCoin.BTC, UrlFetcher(Duration(minutes: 15));

  final money = Commodity("BTC");
  final allMarkets = AllMarkets.from(markets);
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

  print("======================");
  print(allMarkets._markets[Commodity("ETH")]![Commodity("BTC")]!);
  print(allMarkets._markets[Commodity("BTC")]![Commodity("ETH")]!);
  print(
      allMarkets.withMoney(Commodity("ETH")).withAsset(Commodity("BTC")).spot);
  print(
      allMarkets.withMoney(Commodity("USDT")).withAsset(Commodity("BTC")).spot);

  print(
      allMarkets.withMoney(Commodity("USDC")).withAsset(Commodity("ETH")).spot);
  print(
      allMarkets.withMoney(Commodity("ETH")).withAsset(Commodity("USDC")).spot);
}
