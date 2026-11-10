import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/strategies.dart';

void main() {
  test('CoveredCall JSON generation golden test', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
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
      source: DataSource.deribit,
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
          'id': '2026-12-31~1000',
          'strategyType': 'coveredCall',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'underlyingToBuy': 0.95,
          'money': 'USD',
          'moneySize': -950.0,
          'spotPrice': 1000.0,
          'call': 'BTC-1000-C',
          'callURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'callSize': -1.0,
          'callPrice': 50.0,
          'callContractPrice': 50.0,
          'contractLot': 1.0,
          'minSize': 1.0,
          'formattedDate': '31 December 2026',
          'strikeAbsolute': 1000.0,
          'strikeRelative': 1.0,
          'moneyProbability': null,
          'underlyingProbability': null,
          'unitCostBasis': 1000.0,
          'costBasis': 1000.0,
          'underlyingTaxRate': 0.0,
          'derivativeTaxRate': 0.0,
          'instructions': [
            {
              'action': 'Buy',
              'size': 0.95,
              'unit': 'BTC',
              'price': 950.0,
              'priceUnit': 'USD',
            },
            {
              'action': 'Sell',
              'size': 1.0,
              'unit': 'call(s)',
              'price': 0.05,
              'priceUnit': 'BTC',
            },
          ],
          'preTax': {
            'moneyYield': 1.0526315789473684,
            'underlyingYield': 1.0526315789473684,
            'moneyProfit': 50.0,
            'premiumToReceive': 0.05,
            'breakEvenVsFullUnderlying': {
              'absolute': 1052.6315789473686,
              'relative': 1.0526315789473686,
            },
            'breakEvenVsFullMoney': {
              'absolute': 950.0,
              'relative': 0.95,
            },
          },
        }));
  });

  test('CoveredCall with custom avgPrice and TaxProfile', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final callOption = Option(
      'BTC-1100-C',
      underlying: btc,
      money: usd,
      strike: 1100.0,
      isCall: true,
      expiration: expiration,
      source: DataSource.deribit,
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 50.0,
      askPrice: 50.0,
    );

    const taxes = TaxProfile(
      underlyingTaxRate: 0.05,
      derivativeTaxRate: 0.30,
    );

    final coveredCalls = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: btc,
      money: usd,
      slippage: 0.0,
      avgPrice: 500.0,
      taxes: taxes,
    ).toList();

    expect(coveredCalls.length, equals(1));
    final cc = coveredCalls.first;
    expect(cc.toJson()['underlyingHeld'], equals(1.0));

    // Pre-tax metrics (reflecting avgPrice = 500, maxRisk = 500):
    expect(cc.unitCostBasis, equals(500.0));
    expect(cc.costBasis, equals(500.0));
    expect(cc.preTax.moneyProfit, equals(650.0)); // 1100 + 50 - 500 = 650
    expect(cc.preTax.moneyYield, closeTo(1.0 + 650.0 / 500.0, 1e-12));
    expect(cc.preTax.premiumToReceive.size, closeTo(0.05, 1e-12));
    expect(cc.preTax.underlyingYield, closeTo(1.0 + 0.05 / 0.95, 1e-12));
    expect(cc.preTax.breakEvenVsFullMoney!.absolute, closeTo(450.0, 1e-12));
    expect(cc.preTax.breakEvenVsFullUnderlying!.absolute,
        closeTo(1100.0 / 0.95, 1e-9));

    // Post-tax metrics:
    // Below strike: +50 derivative PnL taxed at 30% -> 15 USD unassignedTax
    // Above strike: +650 underlying PnL taxed at 5% -> 32.5 tax -> postTax.moneyProfit = 650 - 32.5 = 617.5
    final postTax = cc.postTax!;
    expect(postTax.moneyProfit, closeTo(617.5, 1e-12));
    expect(postTax.moneyYield, closeTo(1.0 + 617.5 / 500.0, 1e-12));
    expect(postTax.premiumToReceive.size, closeTo(0.035, 1e-12));
    expect(postTax.underlyingYield, closeTo(1.0 + 0.035 / 0.95, 1e-12));
    expect(postTax.unassignedTax, closeTo(15.0, 1e-12));
    expect(postTax.breakEvenVsFullMoney!.absolute, closeTo(465.0, 1e-12));
    expect(postTax.breakEvenVsFullUnderlying!.absolute,
        closeTo((617.5 + 450.0) / 0.95, 1e-9));

    final json = cc.toJson();
    expect(json['underlyingTaxRate'], equals(0.05));
    expect(json['derivativeTaxRate'], equals(0.30));
    expect(json['postTax'], isNotNull);
    expect(json['postTax']['moneyProfit'], closeTo(617.5, 1e-12));
    expect(json['postTax']['unassignedTax'], closeTo(15.0, 1e-12));
    expect(json['postTax']['breakEvenVsFullMoney']['absolute'],
        closeTo(465.0, 1e-12));

    // Existing position PnL & yields (1 BTC @ $500 basis, $1000 spot, 5% underlying tax):
    expect(cc.existingPosition, isNotNull);
    expect(cc.existingPosition!.unitsHeld, equals(1.0));
    expect(cc.existingPosition!.costBasis, closeTo(500.0, 1e-12));
    expect(cc.existingPosition!.currentValue, closeTo(1000.0, 1e-12));
    expect(cc.existingPosition!.preTax.pnl, closeTo(500.0, 1e-12));
    expect(cc.existingPosition!.preTax.yield, closeTo(2.0, 1e-12));
    expect(cc.existingPosition!.postTax!.pnl, closeTo(475.0, 1e-12));
    expect(
        cc.existingPosition!.postTax!.yield, closeTo(1.0 + 475.0 / 500.0, 1e-12));
    expect(
      json['existingPosition'],
      equals({
        'unitsHeld': 1.0,
        'costBasis': 500.0,
        'currentValue': 1000.0,
        'preTax': {
          'pnl': 500.0,
          'yield': 2.0,
        },
        'postTax': {
          'pnl': 475.0,
          'yield': 1.95,
        },
      }),
    );
  });

  test('CoveredCall existingPosition matches PositionAnalyzer for multi-lot stock with tax',
      () {
    final goog = Commodity.fromName('GOOG', source: DataSource.yfinance);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2029, 1, 19);

    final spotMarket = Market.create(
      asset: goog,
      money: usd,
      bidPrice: 285.70,
      askPrice: 285.70,
    );

    final callOption = Option(
      'GOOG290119C00340000',
      underlying: goog,
      money: usd,
      strike: 340.0,
      isCall: true,
      expiration: expiration,
      source: DataSource.yfinance,
      contractLot: 100.0,
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 5180.0,
      askPrice: 5180.0,
    );

    final cc = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: goog,
      money: usd,
      slippage: 0.0,
      avgPrice: 88.0,
      size: 53,
      taxes: const TaxProfile(
        underlyingTaxRate: 0.31,
        derivativeTaxRate: 0.31,
      ),
    ).single;

    final existing = cc.toJson()['existingPosition'];
    expect(existing['unitsHeld'], equals(5300.0));
    expect(existing['costBasis'], closeTo(466400.0, 1e-9));
    expect(existing['currentValue'], closeTo(5300.0 * 285.70, 1e-6));
    expect(existing['preTax']['pnl'], closeTo(1047810.0, 1e-6));
    expect(existing['preTax']['yield'],
        closeTo(1.0 + 1047810.0 / 466400.0, 1e-12));
    expect(existing['postTax']['pnl'], closeTo(722988.90, 1e-6));
    expect(existing['postTax']['yield'],
        closeTo(1.0 + 722988.90 / 466400.0, 1e-12));
  });

  test('CoveredCall existingPosition applies tax credit on negative unrealized PnL',
      () {
    final goog = Commodity.fromName('GOOG', source: DataSource.yfinance);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2029, 1, 19);

    final spotMarket = Market.create(
      asset: goog,
      money: usd,
      bidPrice: 285.70,
      askPrice: 285.70,
    );

    final callOption = Option(
      'GOOG290119C00340000',
      underlying: goog,
      money: usd,
      strike: 340.0,
      isCall: true,
      expiration: expiration,
      source: DataSource.yfinance,
      contractLot: 100.0,
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 5180.0,
      askPrice: 5180.0,
    );

    final cc = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: goog,
      money: usd,
      slippage: 0.0,
      avgPrice: 400.0,
      size: 53,
      taxes: const TaxProfile(
        underlyingTaxRate: 0.31,
        derivativeTaxRate: 0.31,
      ),
    ).single;

    final existing = cc.toJson()['existingPosition'];
    expect(existing['unitsHeld'], equals(5300.0));
    expect(existing['costBasis'], closeTo(2120000.0, 1e-9));
    expect(existing['currentValue'], closeTo(1514210.0, 1e-6));
    expect(existing['preTax']['pnl'], closeTo(-605790.0, 1e-6));
    expect(existing['preTax']['yield'],
        closeTo(1.0 - 605790.0 / 2120000.0, 1e-12));
    // 31% tax credit on $605,790 loss = +$187,794.90 -> post-tax loss = -$417,995.10
    expect(existing['postTax']['pnl'], closeTo(-417995.10, 1e-6));
    expect(existing['postTax']['yield'],
        closeTo(1.0 - 417995.10 / 2120000.0, 1e-12));
    expect(existing['postTax']['pnl'], greaterThan(existing['preTax']['pnl']));
  });

  test('CoveredCall with high avgPrice (negative moneyYield) is not filtered',
      () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final callOption = Option(
      'BTC-1100-C',
      underlying: btc,
      money: usd,
      strike: 1100.0,
      isCall: true,
      expiration: expiration,
      source: DataSource.deribit,
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
      avgPrice: 1500.0,
    ).toList();

    expect(coveredCalls.length, equals(1));
    final cc = coveredCalls.first;
    expect(cc.toJson()['underlyingHeld'], equals(1.0));
    expect(cc.existingPosition!.preTax.pnl, closeTo(-500.0, 1e-12));
    expect(cc.existingPosition!.preTax.yield,
        closeTo(1.0 - 500.0 / 1500.0, 1e-12));
    expect(cc.existingPosition!.postTax, isNull);

    // Max value at expiration is 1100 + 50 - 1500 = -350 (< 0)
    expect(cc.preTax.moneyProfit, closeTo(-350.0, 1e-12));
    expect(cc.preTax.moneyYield, closeTo(1.0 - 350.0 / 1500.0, 1e-12));
    expect(cc.preTax.breakEvenVsFullMoney, isNull);
    expect(cc.preTax.breakEvenVsFullUnderlying!.absolute,
        closeTo(1100.0 / 0.95, 1e-9));
  });

  test('CoveredCall strategyURL renders OptionStrat URL with avgPrice or spotPrice', () {
    final crwv = Commodity.fromName('CRWV', source: DataSource.yfinance);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2029, 1, 19);

    final spotMarket = Market.create(
      asset: crwv,
      money: usd,
      bidPrice: 75.5,
      askPrice: 75.5,
    );

    final callOption = Option(
      'CRWV290119C00065000',
      underlying: crwv,
      money: usd,
      strike: 65.0,
      isCall: true,
      expiration: expiration,
      source: DataSource.yfinance,
      contractLot: 100.0,
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 1746.0,
      askPrice: 1746.0,
    );

    // With explicit avgPrice
    final ccWithAvg = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: crwv,
      money: usd,
      slippage: 0.0,
      avgPrice: 100.0,
    ).single;

    expect(
      ccWithAvg.strategyURL,
      equals(
          'https://optionstrat.com/build/covered-call/CRWV/CRWVx100@100,-.CRWV290119C65@17.46'),
    );
    expect(ccWithAvg.callPrice, closeTo(17.46, 1e-12));
    expect(ccWithAvg.callContractPrice, closeTo(1746.0, 1e-12));
    expect(ccWithAvg.contractLot, equals(100.0));
    expect(ccWithAvg.minSize, equals(1.0));
    final jsonWithAvg = ccWithAvg.toJson();
    expect(jsonWithAvg['callPrice'], closeTo(17.46, 1e-12));
    expect(jsonWithAvg['callContractPrice'], closeTo(1746.0, 1e-12));
    expect(jsonWithAvg['contractLot'], equals(100.0));
    expect(jsonWithAvg['minSize'], equals(1.0));

    // Without avgPrice, defaults to spotPrice (75.5)
    final ccWithoutAvg = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: crwv,
      money: usd,
      slippage: 0.0,
      avgPrice: null,
    ).single;

    expect(
      ccWithoutAvg.strategyURL,
      equals(
          'https://optionstrat.com/build/covered-call/CRWV/CRWVx100@75.5,-.CRWV290119C65@17.46'),
    );
    expect(
      jsonWithAvg['instructions'],
      equals([
        {
          'action': 'Sell',
          'size': 1.0,
          'unit': 'call(s)',
          'price': 1746.0,
          'priceUnit': 'USD',
        },
      ]),
    );

    // With size = 3 and avgPrice = 100.0
    final ccSize3 = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: crwv,
      money: usd,
      slippage: 0.0,
      avgPrice: 100.0,
      size: 3,
    ).single;

    expect(
      ccSize3.strategyURL,
      equals(
          'https://optionstrat.com/build/covered-call/CRWV/CRWVx300@100,-3.CRWV290119C65@17.46'),
    );
    final jsonSize3 = ccSize3.toJson();
    expect(jsonSize3['costBasis'], closeTo(30000.0, 1e-9));
    expect(jsonSize3['underlyingHeld'], equals(300.0));
    expect(jsonSize3['moneySize'], closeTo(-(30000.0 - 3 * 1746.0), 1e-9));
    expect(jsonSize3['callSize'], equals(-3.0));
    expect(jsonSize3['preTax']['moneyProfit'], closeTo(3 * (6500.0 + 1746.0 - 10000.0), 1e-9));
    expect(
      jsonSize3['instructions'],
      equals([
        {
          'action': 'Sell',
          'size': 3.0,
          'unit': 'call(s)',
          'price': 3 * 1746.0,
          'priceUnit': 'USD',
        },
      ]),
    );
  });

  test('CoveredCall with fractional minSize (e.g. BTC 0.1) computes correct callContractPrice', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 75000.0,
      askPrice: 75000.0,
    );

    final callOption = Option(
      'BTC-94000-C',
      underlying: btc,
      money: usd,
      strike: 94000.0,
      isCall: true,
      expiration: expiration,
      contractLot: 1.0,
      minSize: 0.1,
      source: DataSource.deribit,
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 6421.75,
      askPrice: 6421.75,
    );

    final cc = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).single;

    expect(cc.callPrice, closeTo(6421.75, 1e-12));
    expect(cc.callContractPrice, closeTo(642.175, 1e-12));
    expect(cc.minSize, equals(0.1));
    expect(cc.contractLot, equals(1.0));
    final json = cc.toJson();
    expect(json['callPrice'], closeTo(6421.75, 1e-12));
    expect(json['callContractPrice'], closeTo(642.175, 1e-12));
    expect(json['minSize'], equals(0.1));
  });

  test('CoveredCall strategyURL returns null for non-YFinance data source', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    final callOption = Option(
      'BTC-1100-C',
      underlying: btc,
      money: usd,
      strike: 1100.0,
      isCall: true,
      expiration: expiration,
      source: DataSource.deribit,
    );

    final callMarket = Market.create(
      asset: callOption,
      money: usd,
      bidPrice: 50.0,
      askPrice: 50.0,
    );

    final cc = CoveredCall.generateAll(
      [spotMarket, callMarket],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).single;

    expect(cc.strategyURL, isNull);
  });

  test('LongCall JSON generation golden test', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
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
      source: DataSource.deribit,
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
          'id': '2026-12-31~1000~C',
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
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
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
      source: DataSource.deribit,
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
          'id': '2026-12-31~1000~P',
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
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
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
      source: DataSource.deribit,
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
      source: DataSource.deribit,
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
    final overVs =
        spreads.firstWhere((vs) => vs.type == VerticalSpreadType.over);
    final underVs =
        spreads.firstWhere((vs) => vs.type == VerticalSpreadType.under);

    final overJson = overVs.toJson();
    final overDte = overJson.remove('DTE');
    expect(overDte, isNotNull);

    expect(
        overJson,
        equals({
          'id': '2026-12-31~1100~1000~call',
          'strategyType': 'verticalSpread',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'money': 'USD',
          'moneySize': -30.0,
          'spotPrice': 1000.0,
          'shortLeg': 'BTC-1100-C',
          'shortLegURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1100-C',
          'longLeg': 'BTC-1000-C',
          'longLegURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'type': 'over',
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
          'maxRiskAtRelative': 1.0,
          'maxProbBelow': 1.0,
          'maxProbAbove': closeTo(0.3, 1e-9)
        }));

    final underJson = underVs.toJson();
    final underDte = underJson.remove('DTE');
    expect(underDte, isNotNull);

    expect(
        underJson,
        equals({
          'id': '2026-12-31~1000~1100~call',
          'strategyType': 'verticalSpread',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'money': 'USD',
          'moneySize': 30.0,
          'spotPrice': 1000.0,
          'shortLeg': 'BTC-1000-C',
          'shortLegURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'longLeg': 'BTC-1100-C',
          'longLegURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1100-C',
          'type': 'under',
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
          'maxRiskAtRelative': 1.1,
          'maxProbBelow': closeTo(0.7, 1e-9),
          'maxProbAbove': 1.0
        }));
  });

  test('Straddle JSON generation and centered selection test', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    // Strike 900 options (cheaper but less centered) - total cost 120
    final call900 = Option('BTC-900-C',
        underlying: btc,
        money: usd,
        strike: 900.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket900 = Market.create(
        asset: call900, money: usd, bidPrice: 60.0, askPrice: 60.0);
    final put900 = Option('BTC-900-P',
        underlying: btc,
        money: usd,
        strike: 900.0,
        isPut: true,
        expiration: expiration,
        source: DataSource.deribit);
    final putMarket900 = Market.create(
        asset: put900, money: usd, bidPrice: 60.0, askPrice: 60.0);

    // Strike 1000 options (ATM - more expensive but perfectly centered) - total cost 140
    final call1000 = Option('BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1000 = Market.create(
        asset: call1000, money: usd, bidPrice: 70.0, askPrice: 70.0);
    final put1000 = Option('BTC-1000-P',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isPut: true,
        expiration: expiration,
        source: DataSource.deribit);
    final putMarket1000 = Market.create(
        asset: put1000, money: usd, bidPrice: 70.0, askPrice: 70.0);

    // Strike 1100 options (cheaper but less centered) - total cost 120
    final call1100 = Option('BTC-1100-C',
        underlying: btc,
        money: usd,
        strike: 1100.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1100 = Market.create(
        asset: call1100, money: usd, bidPrice: 60.0, askPrice: 60.0);
    final put1100 = Option('BTC-1100-P',
        underlying: btc,
        money: usd,
        strike: 1100.0,
        isPut: true,
        expiration: expiration,
        source: DataSource.deribit);
    final putMarket1100 = Market.create(
        asset: put1100, money: usd, bidPrice: 60.0, askPrice: 60.0);

    final straddles = Straddle.generateAll(
      [
        spotMarket,
        callMarket900,
        putMarket900,
        callMarket1000,
        putMarket1000,
        callMarket1100,
        putMarket1100
      ],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    expect(straddles.length, equals(1));
    final straddle = straddles.first;

    expect(straddle.strikePrice.absolute, equals(1000.0));
    expect(straddle.moneyLeg.size, equals(-140.0)); // cost of 70 call + 70 put

    final json = straddle.toJson();
    final dte = json.remove('DTE');
    expect(dte, isNotNull);

    expect(
        json,
        equals({
          'id': '2026-12-31~1000',
          'strategyType': 'straddle',
          'strategyURL': null,
          'underlying': 'BTC',
          'underlyingURL': 'https://www.deribit.com/spot/BTC_USDT',
          'costInUnderlying': 0.14,
          'moneySize': -140.0,
          'money': 'USD',
          'spotPrice': 1000.0,
          'call': 'BTC-1000-C',
          'callURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-C',
          'callSize': 1.0,
          'callCostInMoney': 70.0,
          'callCostInUnderlying': 0.07,
          'put': 'BTC-1000-P',
          'putURL':
              'https://www.deribit.com/options/BTC/BTC-31DEC26/BTC-1000-P',
          'putSize': 1.0,
          'putCostInMoney': 70.0,
          'putCostInUnderlying': 0.07,
          'formattedDate': '31 December 2026',
          'strikeAbsolute': 1000.0,
          'strikeRelative': 1.0,
          'distanceBetweenBreakEvensAbsolute': 280.0,
          'distanceBetweenBreakEvensRelative': 0.28,

          // Breakevens vs full money
          'breakEvenVsFullMoneyDownAbsolute': 860.0,
          'breakEvenVsFullMoneyDownRelative': 0.86,
          'breakEvenVsFullMoneyUpAbsolute': 1140.0,
          'breakEvenVsFullMoneyUpRelative': 1.14,

          // Breakevens vs full underlying
          'breakEvenVsFullUnderlyingDownAbsolute': 877.1929824561404,
          'breakEvenVsFullUnderlyingDownRelative': 0.8771929824561404,
          'breakEvenVsFullUnderlyingUpAbsolute': 1162.7906976744186,
          'breakEvenVsFullUnderlyingUpRelative': 1.1627906976744186,
        }));
  });

  test('Probabilities class test', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    // Create leg options and markets
    final call1000 = Option('BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1000 = Market.create(
        asset: call1000, money: usd, bidPrice: 100.0, askPrice: 100.0);

    final call1100 = Option('BTC-1100-C',
        underlying: btc,
        money: usd,
        strike: 1100.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1100 = Market.create(
        asset: call1100, money: usd, bidPrice: 30.0, askPrice: 30.0);

    final call1200 = Option('BTC-1200-C',
        underlying: btc,
        money: usd,
        strike: 1200.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1200 = Market.create(
        asset: call1200, money: usd, bidPrice: 10.0, askPrice: 10.0);

    // Let's generate vertical spreads from these
    final spreads = VerticalSpread.generateAll(
      [spotMarket, callMarket1000, callMarket1100, callMarket1200],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    // Now construct Probabilities
    final probs = Probabilities(spreads, underlying: btc, money: usd);

    // The midpoints generated are 1050 (from 1000-1100 pair, p=0.70)
    // and 1150 (from 1100-1200 pair, p=0.20).
    final p1050 = probs.getProbabilityExpiringAbove(expiration, 1050.0);
    expect(p1050, closeTo(0.70, 1e-9));
    final p1150 = probs.getProbabilityExpiringAbove(expiration, 1150.0);
    expect(p1150, closeTo(0.20, 1e-9));
    // Exact interior strike 1100 is linearly interpolated between 1050 and 1150:
    final p1100 = probs.getProbabilityExpiringAbove(expiration, 1100.0);
    expect(p1100, closeTo(0.45, 1e-9));

    // Verify extrapolation outside [1050, 1150] throws ArgumentError
    expect(() => probs.getProbabilityExpiringAbove(expiration, 900.0),
        throwsArgumentError);
    expect(() => probs.getProbabilityExpiringAbove(expiration, 1000.0),
        throwsArgumentError);
    expect(() => probs.getProbabilityExpiringAbove(expiration, 1200.0),
        throwsArgumentError);
    expect(() => probs.getProbabilityExpiringAbove(expiration, 1300.0),
        throwsArgumentError);
  });

  test('CoveredCall attaches probabilities test', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2026, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    // Create leg options and markets
    final call1000 = Option('BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1000 = Market.create(
        asset: call1000, money: usd, bidPrice: 100.0, askPrice: 100.0);

    final call1100 = Option('BTC-1100-C',
        underlying: btc,
        money: usd,
        strike: 1100.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1100 = Market.create(
        asset: call1100, money: usd, bidPrice: 30.0, askPrice: 30.0);

    final call1200 = Option('BTC-1200-C',
        underlying: btc,
        money: usd,
        strike: 1200.0,
        isCall: true,
        expiration: expiration,
        source: DataSource.deribit);
    final callMarket1200 = Market.create(
        asset: call1200, money: usd, bidPrice: 10.0, askPrice: 10.0);

    final coveredCalls = CoveredCall.generateAll(
      [spotMarket, callMarket1000, callMarket1100, callMarket1200],
      underlying: btc,
      money: usd,
      slippage: 0.0,
    ).toList();

    // BTC-1100-C sits between midpoints 1050 (p=0.70) and 1150 (p=0.20),
    // so its interpolated probability is 0.45.
    final cc1100 = coveredCalls.firstWhere((cc) => cc.option.strike == 1100.0);
    expect(cc1100.moneyProbability, closeTo(0.45, 1e-9));
    expect(cc1100.underlyingProbability, closeTo(0.55, 1e-9));
    expect(cc1100.moneyProbability! + cc1100.underlyingProbability!,
        closeTo(1.0, 1e-9));

    // Boundary strikes 1000 and 1200 lie outside [1050, 1150] (would require extrapolation)
    final cc1000 = coveredCalls.firstWhere((cc) => cc.option.strike == 1000.0);
    expect(cc1000.moneyProbability, isNull);
    expect(cc1000.underlyingProbability, isNull);

    final cc1200 = coveredCalls.firstWhere((cc) => cc.option.strike == 1200.0);
    expect(cc1200.moneyProbability, isNull);
    expect(cc1200.underlyingProbability, isNull);
  });

  test('Probabilities un-discounts long-term options via box spread and uses PAVA', () {
    final btc = Commodity.fromName('BTC', source: DataSource.deribit);
    final usd = Commodity.fromName('USD');
    final expiration = DateTime.utc(2028, 12, 31, 8, 0, 0);

    final spotMarket = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 1000.0,
      askPrice: 1000.0,
    );

    // Suppose 2-year interest rate gives discount factor D = 1 / 1.20 = 5/6 (~0.833333).
    // On [1000, 1100] (width = 100, midpoint = 1050):
    // True P(S_T > 1050) = 0.60, P(S_T <= 1050) = 0.40.
    // Present value of bull call spread = D * 60 = 50.0 (e.g. C(1000)=110, C(1100)=60).
    // Present value of bear put spread  = D * 40 = 33.333333 (e.g. P(1000)=20, P(1100)=53.333333).
    // Box spread PV = 50 + 33.333333 = 83.333333 -> D = 83.333333 / 100 = 5/6.
    const d = 5.0 / 6.0;
    final c1000 = Option('BTC-1000-C',
        underlying: btc, money: usd, strike: 1000.0, isCall: true, expiration: expiration);
    final c1100 = Option('BTC-1100-C',
        underlying: btc, money: usd, strike: 1100.0, isCall: true, expiration: expiration);
    final p1000 = Option('BTC-1000-P',
        underlying: btc, money: usd, strike: 1000.0, isPut: true, expiration: expiration);
    final p1100 = Option('BTC-1100-P',
        underlying: btc, money: usd, strike: 1100.0, isPut: true, expiration: expiration);

    final mC1000 = Market.create(asset: c1000, money: usd, bidPrice: 110.0, askPrice: 110.0);
    final mC1100 = Market.create(asset: c1100, money: usd, bidPrice: 60.0, askPrice: 60.0);
    final mP1000 = Market.create(asset: p1000, money: usd, bidPrice: 20.0, askPrice: 20.0);
    final mP1100 = Market.create(
        asset: p1100, money: usd, bidPrice: 20.0 + d * 40.0, askPrice: 20.0 + d * 40.0);

    final spreads = VerticalSpread.generateAll(
      [spotMarket, mC1000, mC1100, mP1000, mP1100],
      underlying: btc,
      money: usd,
      slippage: 0.5,
    ).toList();

    final probs = Probabilities(spreads, underlying: btc, money: usd);
    expect(probs.discountFactors[expiration], closeTo(d, 1e-9));
    // Instead of raw 50/100 = 0.50, un-discounting by D = 5/6 yields the true 0.60 probability!
    expect(probs.getProbabilityExpiringAbove(expiration, 1050.0), closeTo(0.60, 1e-9));

    // ATM crossover where C(K) == P(K):
    // At K=1000, C - P = 110 - 20 = +90.
    // At K=1100, C - P = 60 - 53.333333 = +6.666667 (still > 0).
    // Let's also verify PAVA pooling when a noisy interval violates monotonicity:
    // Suppose we have 3 intervals:
    // [900, 1000] (midpoint 950): C(900)=180, C(1000)=100 -> p = 0.80 (tight spread)
    // [1000, 1100] (midpoint 1050): C(1000)=100, C(1100)=60 -> p = 0.40 (tight spread)
    // [1100, 1200] (midpoint 1150): C(1100)=60, C(1200)=10 -> p = 0.50 (inversion! p(1150) > p(1050))
    final c900 = Option('BTC-900-C',
        underlying: btc, money: usd, strike: 900.0, isCall: true, expiration: expiration);
    final c1200 = Option('BTC-1200-C',
        underlying: btc, money: usd, strike: 1200.0, isCall: true, expiration: expiration);
    final mC900 = Market.create(asset: c900, money: usd, bidPrice: 180.0, askPrice: 180.0);
    final mC1000Pava = Market.create(asset: c1000, money: usd, bidPrice: 100.0, askPrice: 100.0);
    final mC1100Pava = Market.create(asset: c1100, money: usd, bidPrice: 60.0, askPrice: 60.0);
    final mC1200Pava = Market.create(asset: c1200, money: usd, bidPrice: 10.0, askPrice: 10.0);

    final pavaSpreads = VerticalSpread.generateAll(
      [spotMarket, mC900, mC1000Pava, mC1100Pava, mC1200Pava],
      underlying: btc,
      money: usd,
      slippage: 0.5,
    ).toList();

    final pavaProbs = Probabilities(pavaSpreads, underlying: btc, money: usd);
    // Midpoint 950 is unaffected (0.80), while midpoints 1050 (0.40) and 1150 (0.50)
    // have equal weight and are pooled by PAVA into (0.40 + 0.50) / 2 = 0.45:
    expect(pavaProbs.getProbabilityExpiringAbove(expiration, 950.0), closeTo(0.80, 1e-9));
    expect(pavaProbs.getProbabilityExpiringAbove(expiration, 1050.0), closeTo(0.45, 1e-9));
    expect(pavaProbs.getProbabilityExpiringAbove(expiration, 1150.0), closeTo(0.45, 1e-9));
  });
}
