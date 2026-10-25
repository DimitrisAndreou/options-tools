import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/oracle.dart';

void main() {
  group('_RealMarketsOracle', () {
    final btc = Commodity.fromName('BTC');
    final usd = Commodity.fromName('USD');
    final eur = Commodity.fromName('EUR');

    final wideBtcUsd = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 90.0,
      askPrice: 110.0, // spread = 20, mid = 100, relSpread = 0.20
    );

    final tightBtcUsd = Market.create(
      asset: btc,
      money: usd,
      bidPrice: 99.0,
      askPrice: 101.0, // spread = 2, mid = 100, relSpread = 0.02
    );

    test('prefers market with tighter spread regardless of input order', () {
      final oracle1 = Oracle.fromMarkets([wideBtcUsd, tightBtcUsd]);
      final chosen1 = oracle1.marketFor(asset: btc, money: usd);
      expect(chosen1.relativeSpread, equals(tightBtcUsd.relativeSpread));
      expect(chosen1.bidPrice, equals(99.0));

      final oracle2 = Oracle.fromMarkets([tightBtcUsd, wideBtcUsd]);
      final chosen2 = oracle2.marketFor(asset: btc, money: usd);
      expect(chosen2.relativeSpread, equals(tightBtcUsd.relativeSpread));
      expect(chosen2.bidPrice, equals(99.0));
    });

    test('prefers tighter direct or reversed market regardless of order', () {
      // Direct market BTC -> USD has wide spread (20%)
      final directWide = Market.create(
        asset: btc,
        money: usd,
        bidPrice: 90.0,
        askPrice: 110.0, // relSpread = 0.20
      );

      // Market USD -> BTC with tighter spread (2%)
      // mid ~ 0.01 BTC/USD, spread = 0.0002
      final usdToBtcTight = Market.create(
        asset: usd,
        money: btc,
        bidPrice: 0.0099,
        askPrice: 0.0101, // relSpread = 0.0002 / 0.0100 = 0.02
      );

      final oracle1 = Oracle.fromMarkets([directWide, usdToBtcTight]);
      final chosen1 = oracle1.marketFor(asset: btc, money: usd);
      expect(chosen1.relativeSpread, closeTo(0.02, 1e-6));

      final oracle2 = Oracle.fromMarkets([usdToBtcTight, directWide]);
      final chosen2 = oracle2.marketFor(asset: btc, money: usd);
      expect(chosen2.relativeSpread, closeTo(0.02, 1e-6));
    });

    test('multi-hop market navigation uses the tighter market', () {
      final usdEur = Market.create(
        asset: usd,
        money: eur,
        bidPrice: 0.90,
        askPrice: 0.92,
      );

      final oracle = Oracle.fromMarkets([wideBtcUsd, tightBtcUsd, usdEur]);
      final btcToEur = oracle.marketFor(asset: btc, money: eur);
      // Path must be tightBtcUsd concatenated with usdEur
      expect(btcToEur.asset, equals(btc));
      expect(btcToEur.money, equals(eur));
      expect(btcToEur.decompose().first.relativeSpread,
          equals(tightBtcUsd.relativeSpread));
    });

    test('marketFor returns identity for same asset and money', () {
      final oracle = Oracle.fromMarkets([tightBtcUsd]);
      final identity = oracle.marketFor(asset: btc, money: btc);
      expect(identity.asset, equals(btc));
      expect(identity.money, equals(btc));
      expect(identity.bidPrice, equals(1.0));
      expect(identity.askPrice, equals(1.0));
    });

    test('marketFor throws ArgumentError if no path exists', () {
      final eth = Commodity.fromName('ETH');
      final oracle = Oracle.fromMarkets([tightBtcUsd]);
      expect(() => oracle.marketFor(asset: eth, money: usd),
          throwsArgumentError);
    });
  });
}
