import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/markets.dart';

void main() {
  group('Market basic creation and properties', () {
    test('Market.create stores basic properties correctly', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 60000.0,
        askPrice: 61000.0,
      );
      
      expect(market.asset, equals(btc));
      expect(market.money, equals(usd));
      expect(market.bidPrice, equals(60000.0));
      expect(market.askPrice, equals(61000.0));
      expect(market.midPrice, equals(60500.0));
      expect(market.relativeSpread, equals(1000.0 / 60500.0));
      expect(market.buyPrice(0.0), equals(60000.0));
      expect(market.buyPrice(1.0), equals(61000.0));
      expect(market.sellPrice(0.0), equals(61000.0));
      expect(market.sellPrice(1.0), equals(60000.0));
    });

    test('Market.create throws on invalid bid/ask', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      
      expect(() => Market.create(
        asset: btc,
        money: usd,
        bidPrice: 61000.0,
        askPrice: 60000.0,
      ), throwsArgumentError);
    });

    test('Market.createIdentity', () {
      final btc = Commodity.fromName('BTC');
      final identity = Market.createIdentity(btc);
      
      expect(identity.asset, equals(btc));
      expect(identity.money, equals(btc));
      expect(identity.bidPrice, equals(1.0));
      expect(identity.askPrice, equals(1.0));
      expect(identity.decompose().isEmpty, isTrue);
    });
  });

  group('Market long/short positions', () {
    test('Market.long creates unit asset and subtracts money', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 50000.0,
        askPrice: 52000.0,
      );
      
      final Position longPos = market.long(0.5); // mid slippage imply buy price = 51000
      
      expect(longPos[btc].size, equals(1.0));
      expect(longPos[usd].size, equals(-51000.0));
    });

    test('Market.short subtracts unit asset and adds money', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 50000.0,
        askPrice: 52000.0,
      );
      
      final Position shortPos = market.short(0.5); // mid slippage => sell price = 51000
      
      expect(shortPos[btc].size, equals(-1.0));
      expect(shortPos[usd].size, equals(51000.0));
    });
  });

  group('Market conversion methods', () {
    test('Market.toAsset converts money to asset', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 100.0,
        askPrice: 110.0,
      );
      
      final moneyLine = usd.ofSize(1050.0);
      final assetLine = market.toAsset(moneyLine, 0.5); // buy price = 105
      
      expect(assetLine.asset, equals(btc));
      expect(assetLine.size, closeTo(10.0, 1e-6));
    });

    test('Market.toAsset throws if given non-money asset', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 100.0,
        askPrice: 110.0,
      );
      
      expect(() => market.toAsset(btc.ofSize(10.0)), throwsArgumentError);
    });

    test('Market.toMoney converts asset to money', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 100.0,
        askPrice: 110.0,
      );
      
      final assetLine = btc.ofSize(10.0);
      final moneyLine = market.toMoney(assetLine, 0.5); // sell price = 105
      
      expect(moneyLine.asset, equals(usd));
      expect(moneyLine.size, closeTo(1050.0, 1e-6));
    });
    
    test('Market.swap trades an asset line and gives negative opposite side', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 100.0,
        askPrice: 110.0,
      );
      
      // Swap asset
      final assetSwapped = market.swap(btc.ofSize(10.0), 0.5);
      expect(assetSwapped.asset, equals(usd));
      expect(assetSwapped.size, closeTo(-1050.0, 1e-6));
      
      // Swap money
      final moneySwapped = market.swap(usd.ofSize(1050.0), 0.5);
      expect(moneySwapped.asset, equals(btc));
      expect(moneySwapped.size, closeTo(-10.0, 1e-6));
      
      // Unknown swap throws
      final eth = Commodity.fromName('ETH');
      expect(() => market.swap(eth.ofSize(5.0)), throwsArgumentError);
    });
  });

  group('Market modifications', () {
    test('Market.reverse creates inverse market', () {
      final btc = Commodity.fromName('BTC');
      final usd = Commodity.fromName('USD');
      final market = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 10.0,
        askPrice: 20.0,
        bidSize: 100.0,
        askSize: 50.0,
      );
      
      final reverse = market.reverse;
      expect(reverse.asset, equals(usd));
      expect(reverse.money, equals(btc));
      expect(reverse.bidPrice, closeTo(1.0 / 20.0, 1e-6));
      expect(reverse.askPrice, closeTo(1.0 / 10.0, 1e-6));
      expect(reverse.bidSize, closeTo(50.0 / 20.0, 1e-6));
      expect(reverse.askSize, closeTo(100.0 / 10.0, 1e-6));
      
      // reversing again yields equivalent
      expect(reverse.reverse.asset, equals(btc));
    });

    test('Market.concatenate creates synthetic market across two steps', () {
      final a = Commodity.fromName('A');
      final b = Commodity.fromName('B');
      final c = Commodity.fromName('C');
      
      final m1 = Market.create(asset: a, money: b, bidPrice: 2.0, askPrice: 3.0, bidSize: 5.0, askSize: 10.0);
      final m2 = Market.create(asset: b, money: c, bidPrice: 10.0, askPrice: 15.0, bidSize: 100.0, askSize: 50.0);
      
      final synthetic = m1.concatenate(m2);
      expect(synthetic.asset, equals(a));
      expect(synthetic.money, equals(c));
      
      expect(synthetic.bidPrice, closeTo(20.0, 1e-6));
      expect(synthetic.askPrice, closeTo(45.0, 1e-6));
      
      expect(synthetic.bidSize, closeTo(10.0, 1e-6));
      expect(synthetic.askSize, closeTo(30.0, 1e-6));
      expect(synthetic.decompose().length, equals(2));
    });

    test('Market.concatenate throws if currency mismatched', () {
      final a = Commodity.fromName('A');
      final b = Commodity.fromName('B');
      final c = Commodity.fromName('C');
      
      final m1 = Market.create(asset: a, money: b, bidPrice: 2.0, askPrice: 3.0);
      final m2 = Market.create(asset: c, money: b, bidPrice: 10.0, askPrice: 15.0);
      
      expect(() => m1.concatenate(m2), throwsArgumentError);
    });
  });
}
