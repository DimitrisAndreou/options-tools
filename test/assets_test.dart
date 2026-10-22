import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/oracle.dart';

void main() {
  group('Asset', () {
    test('Asset venues are stored and read correctly', () {
      final comm = Commodity('BTC', venues: {Venue.Deribit});
      expect(comm.venues, equals({Venue.Deribit}));

      final opt = Option('BTC-1000-C',
          underlying: comm,
          money: Commodity('USD'),
          strike: 1000.0,
          isCall: true,
          expiration: DateTime.now(),
          venues: {Venue.OptionStrat});
      expect(opt.venues, equals({Venue.OptionStrat}));
    });
  });

  group('Line', () {
    test('line creation and decomposition', () {
      final btc = Commodity.fromName('BTC');
      final line = btc.ofSize(1.5);
      
      expect(line.asset, equals(btc));
      expect(line.size, equals(1.5));
      expect(line.decompose().length, equals(1));
      expect(line.decompose().first, equals(line));
    });

    test('line operator * modifies size', () {
      final btc = Commodity.fromName('BTC');
      final line = btc.ofSize(2.0);
      final scaled = line * 3.0;

      expect(scaled.size, equals(6.0));
      expect(scaled.asset, equals(btc));
    });

    test('line operator - creates negative position', () {
      final btc = Commodity.fromName('BTC');
      final negated = -btc.ofSize(2.0);

      expect(negated.size, equals(-2.0));
    });
    
    test('singleton method returns the line', () {
      final btc = Commodity.fromName('BTC');
      final line = btc.ofSize(2.0);
      
      expect(line.singleton(), equals(line));
      expect(line.singleton(btc), equals(line));
      expect(() => line.singleton(Commodity.fromName('ETH')), throwsStateError);
    });
  });

  group('Position', () {
    test('addition of identical assets merges them', () {
      final btc = Commodity.fromName('BTC');
      final pos1 = btc.ofSize(1.0);
      final pos2 = btc.ofSize(2.0);
      
      final sum = pos1 + pos2;
      final lines = sum.decompose().toList();
      
      expect(lines.length, equals(1));
      expect(lines.first.asset, equals(btc));
      expect(lines.first.size, equals(3.0));
      
      // using the index operator
      expect(sum[btc].size, equals(3.0));
    });

    test('addition of different assets keeps them separate', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      final pos1 = btc.ofSize(1.0);
      final pos2 = eth.ofSize(2.0);
      
      final sum = pos1 + pos2;
      final lines = sum.decompose().toList();
      
      expect(lines.length, equals(2));
      expect(sum[btc].size, equals(1.0));
      expect(sum[eth].size, equals(2.0));
    });

    test('subtraction of assets works correctly', () {
      final btc = Commodity.fromName('BTC');
      final pos1 = btc.ofSize(5.0);
      final pos2 = btc.ofSize(2.0);
      
      final diff = pos1 - pos2;
      expect(diff[btc].size, equals(3.0));
    });
    
    test('operator * applied to a MergedPosition scales all constituents', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      final pos = btc.ofSize(1.0) + eth.ofSize(2.0);
      
      final scaled = pos * 2.0;
      
      // Indexer acts on decomposed elements
      expect(scaled[btc].size, equals(2.0));
      expect(scaled[eth].size, equals(4.0));
    });

    test('mergeAll dynamically merges multiple positions', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      
      final merged = Position.mergeAll([
        btc.ofSize(2.0),
        eth.ofSize(3.0),
        btc.ofSize(-1.0),
      ]);
      
      expect(merged[btc].size, equals(1.0));
      expect(merged[eth].size, equals(3.0));
    });
    
    test('singleton method throws for complex position with multiple lines', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      final pos = btc.ofSize(1.0) + eth.ofSize(2.0);
      
      expect(() => pos.singleton(), throwsStateError);
    });

    test('singleton method succeeds for merged position wrapping one line', () {
      final btc = Commodity.fromName('BTC');
      final pos = btc.ofSize(1.0) + btc.ofSize(2.0); // merges to 3.0 BTC
      
      final single = pos.singleton();
      expect(single.asset, equals(btc));
      expect(single.size, equals(3.0));
    });
  });

  group('Commodity', () {
    test('Commodity.fromName caches instances', () {
      final btc1 = Commodity.fromName('BTC');
      final btc2 = Commodity.fromName('BTC');
      
      expect(identical(btc1, btc2), isTrue);
    });
  });

  group('Option', () {
    test('Constructor validates isPut and isCall mutually exclusive', () {
      final usd = Commodity.fromName('USD');
      final btc = Commodity.fromName('BTC');
      
      expect(() => Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isPut: true,
        isCall: true,
        expiration: DateTime.now()
      ), throwsArgumentError);
      
      expect(() => Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isPut: false,
        isCall: false,
        expiration: DateTime.now()
      ), throwsArgumentError);
    });
  });

  group('CostBasis', () {
    test('Line costBasis and unitCostBasis calculation', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final eur = Commodity.fromName('EUR');

      final lineWithoutCost = btc.ofSize(2.0);
      expect(lineWithoutCost.unitCostBasis, isNull);
      expect(lineWithoutCost.costBasis, isNull);
      expect(lineWithoutCost.costBasisSingle(), isNull);

      final lineWithCost = btc.ofSize(2.0, usd.ofSize(60000.0));
      expect(lineWithCost.unitCostBasis, equals(usd.ofSize(60000.0)));
      expect(lineWithCost.costBasis, equals(usd.ofSize(120000.0)));
      expect(lineWithCost.costBasisSingle(), equals(usd.ofSize(120000.0)));
      expect(lineWithCost.costBasisSingle(usd), equals(usd.ofSize(120000.0)));
      expect(() => lineWithCost.costBasisSingle(eur), throwsStateError);
    });

    test('Line scaling and negation preserve unitCostBasis and scale costBasis', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final line = btc.ofSize(2.0, usd.ofSize(50000.0));

      final scaled = line * 3.0;
      expect(scaled.size, equals(6.0));
      expect(scaled.unitCostBasis, equals(usd.ofSize(50000.0)));
      expect(scaled.costBasis, equals(usd.ofSize(300000.0)));

      final negated = -line;
      expect(negated.size, equals(-2.0));
      expect(negated.unitCostBasis, equals(usd.ofSize(50000.0)));
      expect(negated.costBasis, equals(usd.ofSize(-100000.0)));
    });

    test('Short position has negative cost basis and reduces net outlay in covered call', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final call = Option('BTC-Call',
          underlying: btc,
          money: usd,
          strike: 70000.0,
          isCall: true,
          expiration: DateTime.now());

      // Long 1 BTC @ 60,000 USD (outlay = +$60,000)
      final longStock = btc.ofSize(1.0, usd.ofSize(60000.0));
      // Short 1 Call @ 5,000 USD (proceeds = -$5,000)
      final shortCall = -call.ofSize(1.0, usd.ofSize(5000.0));

      expect(shortCall.size, equals(-1.0));
      expect(shortCall.costBasis, equals(usd.ofSize(-5000.0)));

      // Net outlay for covered call = 60,000 - 5,000 = $55,000
      final coveredCall = longStock + shortCall;
      expect(coveredCall.costBasisSingle(usd), equals(usd.ofSize(55000.0)));
    });

    test('MergedPosition calculates weighted average cost basis for same asset', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');

      // 2 BTC @ $50,000 + 3 BTC @ $60,000 = 5 BTC @ $56,000
      final pos1 = btc.ofSize(2.0, usd.ofSize(50000.0));
      final pos2 = btc.ofSize(3.0, usd.ofSize(60000.0));
      final merged = pos1 + pos2;

      expect(merged[btc].size, equals(5.0));
      expect(merged[btc].unitCostBasis?.asset, equals(usd));
      expect(merged[btc].unitCostBasis?.size, closeTo(56000.0, 1e-6));
      expect(merged[btc].costBasis?.size, closeTo(280000.0, 1e-6));
      expect(merged.costBasisSingle(usd)?.size, closeTo(280000.0, 1e-6));
    });

    test('MergedPosition aggregates cost basis across multiple distinct assets', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      final usd = Commodity.fromName('USD');

      // 1 BTC @ $60,000 + 10 ETH @ $3,000 = $90,000 total cost basis
      final pos = btc.ofSize(1.0, usd.ofSize(60000.0)) + eth.ofSize(10.0, usd.ofSize(3000.0));

      expect(pos[btc].costBasis, equals(usd.ofSize(60000.0)));
      expect(pos[eth].costBasis, equals(usd.ofSize(30000.0)));
      expect(pos.costBasisSingle(usd), equals(usd.ofSize(90000.0)));
    });

    test('Multi-currency cost basis throws on single asset assertion but decomposes correctly', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      final usd = Commodity.fromName('USD');
      final eur = Commodity.fromName('EUR');

      final pos = btc.ofSize(1.0, usd.ofSize(60000.0)) + eth.ofSize(10.0, eur.ofSize(2500.0));

      // Cannot extract as a single asset without conversion
      expect(() => pos.costBasisSingle(), throwsStateError);
      expect(() => pos.costBasisSingle(usd), throwsStateError);

      final decomposedBases = pos.costBasis!.decompose().toList();
      expect(decomposedBases.length, equals(2));
      expect(pos.costBasis![usd], equals(usd.ofSize(60000.0)));
      expect(pos.costBasis![eur], equals(eur.ofSize(25000.0)));
    });

    test('costBasisIn converts multi-currency cost basis via Oracle', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');
      final usd = Commodity.fromName('USD');
      final eur = Commodity.fromName('EUR');

      final pos = btc.ofSize(1.0, usd.ofSize(60000.0)) + eth.ofSize(10.0, eur.ofSize(2500.0));

      final oracle = SimulatedOracle();
      // EUR/USD = 1.10 (1 EUR = 1.10 USD)
      oracle.setPrice(asset: eur, money: usd, price: 1.10);

      // 60,000 USD + (25,000 EUR * 1.10 = 27,500 USD) = 87,500 USD
      final convertedCost = pos.costBasisIn(oracle, usd);
      expect(convertedCost.asset, equals(usd));
      expect(convertedCost.size, closeTo(87500.0, 1e-6));
    });

    test('withCostBasis parameterizes cost basis on existing positions', () {
      final aapl = Commodity.fromName('AAPL');
      final usd = Commodity.fromName('USD');

      // Portfolio originally holding stock without cost basis
      final pos = aapl.ofSize(100.0);
      expect(pos.costBasis, isNull);

      // Parameterize with $150/share cost basis
      final parameterized = pos.withCostBasis({aapl: usd.ofSize(150.0)});
      expect(parameterized[aapl].unitCostBasis, equals(usd.ofSize(150.0)));
      expect(parameterized[aapl].costBasis, equals(usd.ofSize(15000.0)));
      expect(parameterized.costBasisSingle(usd), equals(usd.ofSize(15000.0)));
    });

    test('Line.fromCostBasis and Asset.ofTotalCost derive unitCostBasis correctly', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');

      // 2 BTC with total cost basis $120,000 -> unitCostBasis $60,000
      final line = Line.fromCostBasis(btc, 2.0, usd.ofSize(120000.0));
      expect(line.unitCostBasis, equals(usd.ofSize(60000.0)));
      expect(line.costBasis, equals(usd.ofSize(120000.0)));

      // -2 BTC with total credit -$120,000 -> unitCostBasis $60,000
      final shortLine = Line.fromCostBasis(btc, -2.0, usd.ofSize(-120000.0));
      expect(shortLine.unitCostBasis, equals(usd.ofSize(60000.0)));
      expect(shortLine.costBasis, equals(usd.ofSize(-120000.0)));

      // Via Asset helper
      final fromAsset = btc.ofTotalCost(0.5, usd.ofSize(30000.0));
      expect(fromAsset.unitCostBasis, equals(usd.ofSize(60000.0)));
      expect(fromAsset.costBasis, equals(usd.ofSize(30000.0)));
    });

    test('Position.singletonOrNull returns single line or null on multi/zero/mismatch', () {
      final btc = Commodity.fromName('BTC');
      final eth = Commodity.fromName('ETH');

      expect(btc.ofSize(1.0).singletonOrNull(), equals(btc.ofSize(1.0)));
      expect(btc.ofSize(1.0).singletonOrNull(btc), equals(btc.ofSize(1.0)));
      expect(btc.ofSize(1.0).singletonOrNull(eth), isNull);

      final complex = btc.ofSize(1.0) + eth.ofSize(1.0);
      expect(complex.singletonOrNull(), isNull);
    });
  });
}
