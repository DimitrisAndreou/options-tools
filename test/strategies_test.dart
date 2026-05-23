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
          'maxLeverage': 20.0,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'costInUnderlying': 0.05,
          'costInMoney': 50.0,
          'money': 'USD',
          'spotPrice': 1000.0,
          'call': 'BTC-1000-C',
          'callURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'callSize': 1.0,
          'formattedDate': '31 December 2026',
          'strikeAbsolute': 1000.0,
          'strikeRelative': 1.0,
          'breakEvenVsFullUnderlyingAbsolute': 1052.6315789473683,
          'breakEvenVsFullUnderlyingRelative': 1.0526315789473684,
          'breakEvenVsFullMoneyAbsolute': 1050.0,
          'breakEvenVsFullMoneyRelative': 1.05
        }));
  });

  test('LongPut JSON generation golden test', () {
    final btc = Commodity.fromName('BTC', venues: {Venue.Deribit});
    final usd = Commodity.fromName('USD', venues: {Venue.Deribit});
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final putOption = Option(
      'BTC-1000-P',
      underlying: btc,
      money: usd,
      strike: 1000.0,
      isPut: true,
      expiration: expiration,
      venues: {Venue.Deribit},
    );

    final putMarket = Market.create(
      asset: putOption,
      money: usd,
      bidPrice: 50.0,
      askPrice: 50.0,
    );

    final longPuts = LongPut.generateAll(
      [spotMarket, putMarket],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    expect(longPuts.length, equals(1));
    final lp = longPuts.first;

    final json = lp.toJson();
    final dte = json.remove('DTE');
    expect(dte, isNotNull);

    expect(
        json,
        equals({
          'strategyType': 'longPut',
          'strategyURL': null,
          'maxLeverage': 20.0,
          'maxMoneyYield': 20.0,
          'maxMoneyProfit': 950.0,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'costInUnderlying': 0.05,
          'costInMoney': 50.0,
          'money': 'USD',
          'spotPrice': 1000.0,
          'put': 'BTC-1000-P',
          'putURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-P',
          'putSize': 1.0,
          'formattedDate': '31 December 2026',
          'strikeAbsolute': 1000.0,
          'strikeRelative': 1.0,
          // Since it's a put with 1000 strike and costs 50, break even vs full money is 950
          'breakEvenVsFullUnderlyingAbsolute': 952.3809523809523,
          'breakEvenVsFullUnderlyingRelative': 0.9523809523809523,
          'breakEvenVsFullMoneyAbsolute': 950.0,
          'breakEvenVsFullMoneyRelative': 0.95
        }));
  });
}
