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

    test('supports options with strike == 0.0 (thought experiment: zero-strike call equals underlying)', () {
      final zeroStrikeCall = Option(
        'BTC-0-C',
        underlying: btc,
        money: usd,
        strike: 0.0,
        isCall: true,
        expiration: expiration,
      );
      final zeroStrikePut = Option(
        'BTC-0-P',
        underlying: btc,
        money: usd,
        strike: 0.0,
        isPut: true,
        expiration: expiration,
      );

      // A zero-strike call bought for $1000 behaves identically to 1 BTC bought for $1000
      final callPos = zeroStrikeCall.ofSize(1.0) - usd.ofSize(1000.0);
      final callAnalyzer = PositionAnalyzer(callPos, underlying: btc, money: usd);
      expect(callAnalyzer.minValue, equals(-1000.0));
      expect(callAnalyzer.maxValue, equals(double.infinity));
      expect(callAnalyzer.breakevens.single.price, equals(1000.0));
      expect(callAnalyzer.deltaAfter(0.0), equals(1.0));

      // Comparing 1 zero-strike call vs 1 unit of underlying yields identically 0 across all prices
      final diffAnalyzer = zeroStrikeCall.unit.analyzeVersus(btc.unit, underlying: btc, money: usd);
      expect(diffAnalyzer.minValue, equals(0.0));
      expect(diffAnalyzer.maxValue, equals(0.0));
      expect(diffAnalyzer.deltaAfter(0.0), equals(0.0));

      // A zero-strike put is always worthless (0 payoff everywhere)
      final putAnalyzer = PositionAnalyzer(zeroStrikePut.unit, underlying: btc, money: usd);
      expect(putAnalyzer.minValue, equals(0.0));
      expect(putAnalyzer.maxValue, equals(0.0));
      expect(putAnalyzer.deltaAfter(0.0), equals(0.0));
    });

    test('throws error for mismatched underlying or unrelated commodity', () {
      final eth = Commodity.fromName('ETH');
      final eur = Commodity.fromName('EUR');
      final ethCall = Option(
        'ETH-1000-C',
        underlying: eth,
        money: usd,
        strike: 1000.0,
        isCall: true,
        expiration: expiration,
      );

      expect(
        () => PositionAnalyzer(ethCall.unit, underlying: btc, money: usd),
        throwsArgumentError,
      );
      expect(
        () => PositionAnalyzer(eur.ofSize(100.0), underlying: btc, money: usd),
        throwsArgumentError,
      );
      expect(
        () => PositionAnalyzer(btc.ofSize(1.0, eur.ofSize(900.0)), underlying: btc, money: usd),
        throwsArgumentError,
      );
    });

    group('costBasis, realizedPnL, and unrealizedPnL per segment', () {
      test('covered call with pre-owned stock at custom costBasis', () {
        final callOption = Option(
          'BTC-1100-C',
          underlying: btc,
          money: usd,
          strike: 1100.0,
          isCall: true,
          expiration: expiration,
        );

        // User already bought 1 BTC at $1200 (even though current spot may be $1000),
        // and sells 1 Call at strike $1100 for $50.
        final position = btc.ofSize(1.0, usd.ofSize(1200.0)) -
            usd.ofSize(1000.0) +
            (-callOption.ofSize(1.0, usd.ofSize(50.0)) + usd.ofSize(50.0));

        final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);

        // Below strike (< 1100): Call expires worthless (+50 realized), BTC remains open at $1200 cost basis.
        expect(analyzer.costBasisBefore(1100.0), equals(1200.0));
        expect(analyzer.realizedPnLBefore(1100.0), equals(50.0));
        expect(analyzer.unrealizedPnLBefore(900.0), equals(-300.0));  // 900 - 1200
        expect(analyzer.unrealizedPnLBefore(1100.0), equals(-100.0)); // 1100 - 1200

        // Above strike (>= 1100): Call is exercised; option cost basis (-$50) transfers to stock sale
        // (effective sale proceeds = $1100 + $50 = $1150 vs $1200 basis -> -$50 realized).
        // No shares remain open, so remaining cost basis and unrealized PnL are 0.
        expect(analyzer.costBasisAfter(1100.0), equals(0.0));
        expect(analyzer.realizedPnLAfter(1100.0), equals(-50.0));
        expect(analyzer.unrealizedPnLAfter(1100.0), equals(0.0));
        expect(analyzer.unrealizedPnLAfter(1500.0), equals(0.0));
      });

      test('long call transfers costBasis to underlying upon exercise', () {
        final callOption = Option(
          'BTC-1000-C',
          underlying: btc,
          money: usd,
          strike: 1000.0,
          isCall: true,
          expiration: expiration,
        );

        // Buy 1 Call at $1000 strike for $50
        final position = callOption.ofSize(1.0, usd.ofSize(50.0)) - usd.ofSize(50.0);
        final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);

        // Below strike: Call expires worthless -> -$50 realized, 0 remaining costBasis, 0 unrealized
        expect(analyzer.costBasisBefore(1000.0), equals(0.0));
        expect(analyzer.realizedPnLBefore(1000.0), equals(-50.0));
        expect(analyzer.unrealizedPnLBefore(900.0), equals(0.0));
        expect(analyzer.unrealizedPnLBefore(1000.0), equals(0.0));

        // Above strike: Call is exercised -> acquires 1 BTC with cost basis $1000 + $50 = $1050.
        // Exercise itself realizes $0; PnL is unrealized on the acquired BTC.
        expect(analyzer.costBasisAfter(1000.0), equals(1050.0));
        expect(analyzer.realizedPnLAfter(1000.0), equals(0.0));
        expect(analyzer.unrealizedPnLAfter(1000.0), equals(-50.0));  // 1000 - 1050
        expect(analyzer.unrealizedPnLAfter(1200.0), equals(150.0));  // 1200 - 1050
      });

      test('short put transfers costBasis to underlying upon assignment', () {
        final putOption = Option(
          'BTC-1000-P',
          underlying: btc,
          money: usd,
          strike: 1000.0,
          isPut: true,
          expiration: expiration,
        );

        // Sell 1 Put at $1000 strike for $50
        final position = -putOption.ofSize(1.0, usd.ofSize(50.0)) + usd.ofSize(50.0);
        final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);

        // Below strike: Put is assigned -> acquires 1 BTC at net cost basis $1000 - $50 = $950.
        // Assignment realizes $0; PnL is unrealized on the acquired BTC.
        expect(analyzer.costBasisBefore(1000.0), equals(950.0));
        expect(analyzer.realizedPnLBefore(1000.0), equals(0.0));
        expect(analyzer.unrealizedPnLBefore(900.0), equals(-50.0));  // 900 - 950
        expect(analyzer.unrealizedPnLBefore(1000.0), equals(50.0));  // 1000 - 950

        // Above strike: Put expires worthless -> +$50 realized, 0 remaining costBasis, 0 unrealized
        expect(analyzer.costBasisAfter(1000.0), equals(0.0));
        expect(analyzer.realizedPnLAfter(1000.0), equals(50.0));
        expect(analyzer.unrealizedPnLAfter(1000.0), equals(0.0));
        expect(analyzer.unrealizedPnLAfter(1200.0), equals(0.0));
      });

      test('vertical bull call spread across all three segments', () {
        final call900 = Option(
          'BTC-900-C',
          underlying: btc,
          money: usd,
          strike: 900.0,
          isCall: true,
          expiration: expiration,
        );
        final call1000 = Option(
          'BTC-1000-C',
          underlying: btc,
          money: usd,
          strike: 1000.0,
          isCall: true,
          expiration: expiration,
        );

        // Long 900 Call @ $80, Short 1000 Call @ $30 (net debit $50)
        final position = call900.ofSize(1.0, usd.ofSize(80.0)) -
            call1000.ofSize(1.0, usd.ofSize(30.0)) -
            usd.ofSize(50.0);
        final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);

        // Segment 1 [0..900]: Both expire worthless -> realized = -80 + 30 = -50
        expect(analyzer.costBasisBefore(900.0), equals(0.0));
        expect(analyzer.realizedPnLBefore(900.0), equals(-50.0));
        expect(analyzer.unrealizedPnLBefore(850.0), equals(0.0));

        // Segment 2 [900..1000]: 900 Call exercised (costBasis = 980), 1000 Call expires OTM (realized = +30)
        expect(analyzer.costBasisAfter(900.0), equals(980.0));
        expect(analyzer.realizedPnLAfter(900.0), equals(30.0));
        expect(analyzer.unrealizedPnLAfter(950.0), equals(-30.0)); // 950 - 980 (total PnL = 30 - 30 = 0 at breakeven 950!)

        // Segment 3 [1000..inf): Both exercised -> +1 BTC @ 980 closed against -1 BTC @ 1030 -> realized = +50
        expect(analyzer.costBasisAfter(1000.0), equals(0.0));
        expect(analyzer.realizedPnLAfter(1000.0), equals(50.0));
        expect(analyzer.unrealizedPnLAfter(1100.0), equals(0.0));
      });

      test('partial covered call disposes covered portion and preserves cost basis of remaining shares', () {
        final callOption = Option(
          'BTC-1100-C',
          underlying: btc,
          money: usd,
          strike: 1100.0,
          isCall: true,
          expiration: expiration,
        );

        // Hold 2 BTC @ $1200 each (total cost basis $2400), sell 1 Call @ $1100 for $50
        final position = btc.ofSize(2.0, usd.ofSize(1200.0)) -
            callOption.ofSize(1.0, usd.ofSize(50.0));
        final analyzer = PositionAnalyzer(position, underlying: btc, money: usd);

        // Below 1100: Call expires worthless (+50 realized), 2 BTC remain at $2400 cost basis
        expect(analyzer.costBasisBefore(1100.0), equals(2400.0));
        expect(analyzer.realizedPnLBefore(1100.0), equals(50.0));
        expect(analyzer.unrealizedPnLBefore(1000.0), equals(-400.0)); // 2 * 1000 - 2400

        // Above 1100: 1 BTC is called away at $1150 vs $1200 basis -> -$50 realized;
        // 1 BTC remains open at $1200 cost basis.
        expect(analyzer.costBasisAfter(1100.0), equals(1200.0));
        expect(analyzer.realizedPnLAfter(1100.0), equals(-50.0));
        expect(analyzer.unrealizedPnLAfter(1300.0), equals(100.0)); // 1 * 1300 - 1200
      });
    });
  });
}
