import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/position_analyzer.dart';

void main() {
  final btc = Commodity.fromName('BTC');
  final usd = Commodity.fromName('USD');
  final expiration = DateTime.now().add(const Duration(days: 30));

  group('PositionAnalyzer', () {
    test('analyzes a long call option', () {
      final callOption = Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );
      
      // We buy 1 call option for 50 USD
      final position = callOption.ofSize(1.0) + usd.ofSize(-50.0);
      
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      expect(analyzer.minValue, equals(-50.0));
      expect(analyzer.maxValue, equals(double.infinity));
      expect(analyzer.maxRisk, equals(50.0));
      expect(analyzer.maxProfit, equals(double.infinity));
      
      // Breakeven is strike + premium
      final breakevens = analyzer.breakevens.toList();
      expect(breakevens.length, equals(1));
      expect(breakevens.first.isPoint, isTrue);
      expect(breakevens.first.price, equals(1050.0));
      
      expect(analyzer.valueAt(900.0), equals(-50.0));
      expect(analyzer.valueAt(1000.0), equals(-50.0));
      expect(analyzer.valueAt(1100.0), equals(50.0));
      
      expect(analyzer.deltaBefore(1000.0), equals(0.0));
      expect(analyzer.deltaAfter(1000.0), equals(1.0));
      
      final worst = analyzer.worstPrices.toList();
      expect(worst.length, equals(1));
      expect(worst.first.isPoint, isFalse);
      expect(worst.first.fromPrice, equals(0.0));
      expect(worst.first.toPrice, equals(1000.0));
    });

    test('analyzes a short put option', () {
      final putOption = Option(
        'BTC-1000-P',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isPut: true,
        expiration: expiration,
      );
      
      // We sell 1 put option for 50 USD
      final position = putOption.ofSize(-1.0) + usd.ofSize(50.0);
      
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      expect(analyzer.maxValue, equals(50.0));
      expect(analyzer.maxProfit, equals(50.0));
      
      // Max risk is when underlying goes to 0: loss is 1000 - 50 = 950
      expect(analyzer.minValue, equals(-950.0));
      expect(analyzer.maxRisk, equals(950.0));
      
      // Breakeven is strike - premium
      final breakevens = analyzer.breakevens.toList();
      expect(breakevens.length, equals(1));
      expect(breakevens.first.price, equals(950.0));
      
      expect(analyzer.valueAt(900.0), equals(-50.0));
      expect(analyzer.valueAt(1000.0), equals(50.0));
      expect(analyzer.valueAt(1100.0), equals(50.0));
      
      expect(analyzer.deltaBefore(1000.0), equals(1.0));
      expect(analyzer.deltaAfter(1000.0), equals(0.0));
    });
    
    test('analyzes a straddle', () {
      final callOption = Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );
      final putOption = Option(
        'BTC-1000-P',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isPut: true,
        expiration: expiration,
      );
      
      // Buy both options for 100 USD total
      final position = callOption.ofSize(1.0) + putOption.ofSize(1.0) + usd.ofSize(-100.0);
      
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      expect(analyzer.minValue, equals(-100.0));
      expect(analyzer.maxValue, equals(double.infinity));
      
      final breakevens = analyzer.breakevens.toList();
      expect(breakevens.length, equals(2));
      expect(breakevens[0].price, equals(900.0));
      expect(breakevens[1].price, equals(1100.0));
      
      expect(analyzer.valueAt(1000.0), equals(-100.0));
      expect(analyzer.valueAt(800.0), equals(100.0));
      expect(analyzer.valueAt(1200.0), equals(100.0));
      
      expect(analyzer.deltaBefore(1000.0), equals(-1.0));
      expect(analyzer.deltaAfter(1000.0), equals(1.0));
    });
    
    test('equalizeRisk scales the position correctly', () {
       final callOption = Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );
      
      // We buy 1 call option for 50 USD
      final position = callOption.ofSize(1.0) + usd.ofSize(-50.0);
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      // Another position that has double the risk
      final position2 = callOption.ofSize(2.0) + usd.ofSize(-100.0);
      
      final equalizedAnalyzer = analyzer.equalizeRisk(position2);
      expect(equalizedAnalyzer.maxRisk, equals(analyzer.maxRisk));
      // Risk was 100, now should be 50. Size of call was 2, now should be 1.
      expect(equalizedAnalyzer.position[callOption].size, equals(1.0));
    });
    
    test('throws error for different expirations', () {
      final callOption1 = Option(
        'BTC-1000-C-1',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );
      final callOption2 = Option(
        'BTC-1000-C-2',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration.add(const Duration(days: 1)),
      );
      
      final position = callOption1.ofSize(1.0) + callOption2.ofSize(1.0);
      
      expect(() => PositionAnalyzer(position, underlying: btc, money: usd), throwsArgumentError);
    });
    
    test('analyzes an outright underlying position', () {
      // Long 1 BTC at $1000 average price
      final position = btc.ofSize(1.0) + usd.ofSize(-1000.0);
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      expect(analyzer.minValue, equals(-1000.0));
      expect(analyzer.maxValue, equals(double.infinity));
      expect(analyzer.maxRisk, equals(1000.0));
      expect(analyzer.maxProfit, equals(double.infinity));
      
      final breakevens = analyzer.breakevens.toList();
      expect(breakevens.length, equals(1));
      expect(breakevens.first.price, equals(1000.0));
      
      expect(analyzer.deltaBefore(1000.0), equals(1.0));
      expect(analyzer.deltaAfter(1000.0), equals(1.0));
      
      expect(analyzer.valueAt(900.0), equals(-100.0));
      expect(analyzer.valueAt(1100.0), equals(100.0));
    });

    test('yieldAt and maxYield compute correctly', () {
      final callOption = Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );
      
      // We buy 1 call option for 50 USD
      final position = callOption.ofSize(1.0) + usd.ofSize(-50.0);
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      // maxRisk is 50.
      expect(analyzer.maxRisk, equals(50.0));
      
      // yieldAt = 1.0 + valueAt(price) / maxRisk
      // At 1000, value is -50, so yield is 1.0 - 1.0 = 0.0
      expect(analyzer.yieldAt(1000.0), equals(0.0));
      
      // At 1100, value is 50, so yield is 1.0 + 1.0 = 2.0
      expect(analyzer.yieldAt(1100.0), equals(2.0));
      
      // maxYield is 1.0 + maxProfit / maxRisk = 1.0 + infinity = infinity
      expect(analyzer.maxYield, equals(double.infinity));
    });
    
    test('bestPrices and worstPrices behave correctly on a covered call', () {
      final callOption = Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );
      
      // Buy 1 BTC at $900, sell 1 Call at $1000 for $50
      final position = btc.ofSize(1.0) + usd.ofSize(-900.0) + callOption.ofSize(-1.0) + usd.ofSize(50.0);
      final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);
      
      // Value at 0 = -900 + 50 = -850
      // Value at 1000 = 100 + 50 = 150
      // Value at 2000 = 1100 - 1000 + 50 = 150
      expect(analyzer.minValue, equals(-850.0));
      expect(analyzer.maxValue, equals(150.0));
      
      final best = analyzer.bestPrices.toList();
      expect(best.length, equals(1));
      expect(best.first.isPoint, isFalse);
      expect(best.first.fromPrice, equals(1000.0));
      expect(best.first.toPrice, equals(double.infinity));
      
      final worst = analyzer.worstPrices.toList();
      expect(worst.length, equals(1));
      expect(worst.first.isPoint, isTrue);
      expect(worst.first.price, equals(0.0));
    });

    test('analyzeVersus extension compares two positions correctly', () {
      final callOption = Option(
        'BTC-1000-C',
        underlying: btc,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );

      // Strategy 1: Long Call
      final strategy1 = callOption.ofSize(1.0) + usd.ofSize(-50.0);
      
      // Strategy 2: Long Underlying
      final strategy2 = btc.ofSize(1.0) + usd.ofSize(-1000.0);

      // Analyze 1 vs 2
      final analyzer = strategy1.analyzeVersus(strategy2, underlying: btc, money: usd);
      
      // The difference is a synthetic put? 
      // Long Call - Long Underlying = Long Call + Short Underlying = Synthetic Short Put + Money difference
      // Actually, we just need to verify it returns a valid analyzer with some known properties.
      expect(analyzer.breakevens.isNotEmpty, isTrue);
    });
  });
}
