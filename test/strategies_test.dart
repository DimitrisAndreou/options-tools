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
          'moneySize': -50.0,
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
          'moneySize': -50.0,
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

  test('VerticalSpread JSON generation golden test', () {
    final btc = Commodity.fromName('BTC', venues: {Venue.Deribit});
    final usd = Commodity.fromName('USD', venues: {Venue.Deribit});
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final callOption1 = Option(
      'BTC-1000-C',
      underlying: btc,
      money: usd,
      strike: 1000.0,
      isCall: true,
      expiration: expiration,
      venues: {Venue.Deribit},
    );

    final callMarket1 = Market.create(
      asset: callOption1,
      money: usd,
      bidPrice: 50.0,
      askPrice: 50.0,
    );

    final callOption2 = Option(
      'BTC-1100-C',
      underlying: btc,
      money: usd,
      strike: 1100.0,
      isCall: true,
      expiration: expiration,
      venues: {Venue.Deribit},
    );

    final callMarket2 = Market.create(
      asset: callOption2,
      money: usd,
      bidPrice: 20.0,
      askPrice: 20.0,
    );

    final spreads = VerticalSpread.generateAll(
      [spotMarket, callMarket1, callMarket2],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    expect(spreads.length, equals(2));
    final overVs = spreads.firstWhere((vs) => vs.type == VerticalSpreadType.over);
    final underVs = spreads.firstWhere((vs) => vs.type == VerticalSpreadType.under);

    final overJson = overVs.toJson();
    final overDte = overJson.remove('DTE');
    expect(overDte, isNotNull);

    expect(
        overJson,
        equals({
          'strategyType': 'verticalSpread',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'money': 'USD',
          'moneySize': 30.0,
          'spotPrice': 1000.0,
          'shortLeg': 'BTC-1000-C',
          'shortLegURL': 'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'longLeg': 'BTC-1100-C',
          'longLegURL': 'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1100-C',
          'type': 'over',
          'formattedDate': '31 December 2026',
          'breakEvenVsFullMoneyAbsolute': 1030.0,
          'breakEvenVsFullMoneyRelative': 1.03,
          'breakEvenVsFullUnderlyingAbsolute': 1030.9278350515465,
          'breakEvenVsFullUnderlyingRelative': 1.0309278350515465,
          'maxYield': 1.4285714285714286,
          'maxYieldAtAbsolute': 1000.0,
          'maxYieldAtRelative': 1.0,
          'maxRisk': 70.0,
          'maxRiskAtAbsolute': 1100.0,
          'maxRiskAtRelative': 1.1
        }));

    final underJson = underVs.toJson();
    final underDte = underJson.remove('DTE');
    expect(underDte, isNotNull);

    expect(
        underJson,
        equals({
          'strategyType': 'verticalSpread',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'money': 'USD',
          'moneySize': -30.0,
          'spotPrice': 1000.0,
          'shortLeg': 'BTC-1100-C',
          'shortLegURL': 'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1100-C',
          'longLeg': 'BTC-1000-C',
          'longLegURL': 'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'type': 'under',
          'formattedDate': '31 December 2026',
          'breakEvenVsFullMoneyAbsolute': 1030.0,
          'breakEvenVsFullMoneyRelative': 1.03,
          'breakEvenVsFullUnderlyingAbsolute': 1030.9278350515465,
          'breakEvenVsFullUnderlyingRelative': 1.0309278350515465,
          'maxYield': 3.3333333333333335,
          'maxYieldAtAbsolute': 1100.0,
          'maxYieldAtRelative': 1.1,
          'maxRisk': 30.0,
          'maxRiskAtAbsolute': 1000.0,
          'maxRiskAtRelative': 1.0
        }));
  });

  test('Straddle JSON generation and cheapest selection test', () {
    final btc = Commodity.fromName('BTC', venues: {Venue.Deribit});
    final usd = Commodity.fromName('USD', venues: {Venue.Deribit});
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    // Strike 900 options - total cost 120
    final call900 = Option('BTC-900-C', underlying: btc, money: usd, strike: 900.0, isCall: true, expiration: expiration, venues: {Venue.Deribit});
    final callMarket900 = Market.create(asset: call900, money: usd, bidPrice: 110.0, askPrice: 110.0);
    final put900 = Option('BTC-900-P', underlying: btc, money: usd, strike: 900.0, isPut: true, expiration: expiration, venues: {Venue.Deribit});
    final putMarket900 = Market.create(asset: put900, money: usd, bidPrice: 10.0, askPrice: 10.0);

    // Strike 1000 options (ATM - cheapest straddle) - total cost 80
    final call1000 = Option('BTC-1000-C', underlying: btc, money: usd, strike: 1000.0, isCall: true, expiration: expiration, venues: {Venue.Deribit});
    final callMarket1000 = Market.create(asset: call1000, money: usd, bidPrice: 40.0, askPrice: 40.0);
    final put1000 = Option('BTC-1000-P', underlying: btc, money: usd, strike: 1000.0, isPut: true, expiration: expiration, venues: {Venue.Deribit});
    final putMarket1000 = Market.create(asset: put1000, money: usd, bidPrice: 40.0, askPrice: 40.0);

    // Strike 1100 options - total cost 120
    final call1100 = Option('BTC-1100-C', underlying: btc, money: usd, strike: 1100.0, isCall: true, expiration: expiration, venues: {Venue.Deribit});
    final callMarket1100 = Market.create(asset: call1100, money: usd, bidPrice: 10.0, askPrice: 10.0);
    final put1100 = Option('BTC-1100-P', underlying: btc, money: usd, strike: 1100.0, isPut: true, expiration: expiration, venues: {Venue.Deribit});
    final putMarket1100 = Market.create(asset: put1100, money: usd, bidPrice: 110.0, askPrice: 110.0);

    final straddles = Straddle.generateAll(
      [spotMarket, callMarket900, putMarket900, callMarket1000, putMarket1000, callMarket1100, putMarket1100],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    expect(straddles.length, equals(1));
    final straddle = straddles.first;

    expect(straddle.strikePrice.absolute, equals(1000.0));
    expect(straddle.moneyLeg.size, equals(-80.0)); // cost of 40 call + 40 put

    final json = straddle.toJson();
    final dte = json.remove('DTE');
    expect(dte, isNotNull);

    expect(
        json,
        equals({
          'strategyType': 'straddle',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'costInUnderlying': 0.08,
          'moneySize': -80.0,
          'money': 'USD',
          'spotPrice': 1000.0,
          'call': 'BTC-1000-C',
          'callURL': 'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'callSize': 1.0,
          'put': 'BTC-1000-P',
          'putURL': 'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-P',
          'putSize': 1.0,
          'formattedDate': '31 December 2026',
          'strikeAbsolute': 1000.0,
          'strikeRelative': 1.0,
          'distanceBetweenBreakEvensAbsolute': 160.0,
          'distanceBetweenBreakEvensRelative': 0.16,

          // Breakevens vs full money
          'breakEvenVsFullMoneyDownAbsolute': 920.0,
          'breakEvenVsFullMoneyDownRelative': 0.92,
          'breakEvenVsFullMoneyUpAbsolute': 1080.0,
          'breakEvenVsFullMoneyUpRelative': 1.08,

          // Breakevens vs full underlying
          'breakEvenVsFullUnderlyingDownAbsolute': 925.9259259259259,
          'breakEvenVsFullUnderlyingDownRelative': 0.9259259259259258,
          'breakEvenVsFullUnderlyingUpAbsolute': 1086.9565217391305,
          'breakEvenVsFullUnderlyingUpRelative': 1.0869565217391306,
        }));
  });
}

