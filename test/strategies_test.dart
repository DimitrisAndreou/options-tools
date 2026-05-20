import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/strategies.dart';

void main() {
  test('CoveredCall JSON generation golden test', () {
    final btc = Commodity.fromName('BTC', venues: {Venue.Deribit});
    final usd = Commodity.fromName('USD', venues: {Venue.Deribit});
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final callOption = Option(
      'BTC-1000-C',
      underlying: btc,
      money: usd,
      strike: 1000.0,
      isCall: true,
      expiration: expiration,
      venues: {Venue.Deribit},
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 50.0,
      askPrice: 50.0,
    );

    final coveredCalls = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    expect(coveredCalls.length, equals(1));
    final cc = coveredCalls.first;

    final json = cc.toJson();
    final dte = json.remove('DTE');
    expect(dte, isNotNull);

    expect(
        json,
        equals({
          'strategyType': 'coveredCall',
          'strategyURL': null,
          'moneyYield': 1.0526315789473684,
          'underlyingYield': 1.0526315789473686,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'underlyingToBuy': 0.95,
          'premiumToReceive': 0.050000000000000044,
          'money': 'USD',
          'moneySize': -950.0,
          'moneyProfit': 50.0,
          'spotPrice': 1000.0,
          'call': 'BTC-1000-C',
          'callURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'callSize': -1.0,
          'formattedDate': '31 December 2026',
          'strikeAbsolute': 1000.0,
          'strikeRelative': 1.0,
          'breakEvenVsFullUnderlyingAbsolute': 1052.6315789473686,
          'breakEvenVsFullUnderlyingRelative': 1.0526315789473686,
          'breakEvenVsFullMoneyAbsolute': 950.0,
          'breakEvenVsFullMoneyRelative': 0.95,
        }));
  });

  test('LongCall JSON generation golden test', () {
    final btc = Commodity.fromName('BTC', venues: {Venue.Deribit});
    final usd = Commodity.fromName('USD', venues: {Venue.Deribit});
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final callOption = Option(
      'BTC-1000-C',
      underlying: btc,
      money: usd,
      strike: 1000.0,
      isCall: true,
      expiration: expiration,
      venues: {Venue.Deribit},
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 50.0,
      askPrice: 50.0,
    );

    final longCalls = LongCall.generateAll(
      [spotMarket, callMarket],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    expect(longCalls.length, equals(1));
    final lc = longCalls.first;

    final json = lc.toJson();
    final dte = json.remove('DTE');
    expect(dte, isNotNull);

    expect(
        json,
        equals({
          'strategyType': 'longCall',
          'strategyURL': null,
          'maxLeverage': 1.0,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'costInUnderlying': 0.05,
          'costInMoney': -50.0,
          'money': 'USD',
          'moneySize': -50.0,
          'spotPrice': 1000.0,
          'call': 'BTC-1000-C',
          'callURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'callSize': 1.0,
          'formattedDate': '31 December 2026',
          'breakEvenVsFullUnderlyingAbsolute': 1052.6315789473683,
          'breakEvenVsFullUnderlyingRelative': 1.0526315789473684,
          'breakEvenVsFullMoneyAbsolute': 1050.0,
          'breakEvenVsFullMoneyRelative': 1.05
        }));
  });
}
