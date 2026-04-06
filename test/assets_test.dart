import 'package:test/test.dart';
import 'package:options_tools/assets.dart';

void main() {
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
}
