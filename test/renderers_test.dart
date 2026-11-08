import 'package:test/test.dart';
import 'package:options_tools/assets.dart';
import 'package:options_tools/renderers.dart';

void main() {
  group('AssetRenderer.deribit', () {
    final renderer = AssetRenderer.deribit();

    test('renders Future correctly', () {
      final underlying = Commodity('BTC');
      final future = DatedFuture(
        'BTC-26JUN26',
        underlying: underlying,
        expiration: DateTime(2026, 6, 26),
        source: DataSource.deribit,
      );
      expect(renderer.render(future),
          equals('https://www.deribit.com/futures/BTC-26JUN26'));
    });

    test('renders Option correctly', () {
      final underlying = Commodity('BTC');
      final money = Commodity('USD');
      final option = Option(
        'BTC-24APR26-61000-C',
        underlying: underlying,
        money: money,
        strike: 61000.0,
        isCall: true,
        expiration: DateTime(2026, 4, 24),
        source: DataSource.deribit,
      );
      expect(
          renderer.render(option),
          equals(
              'https://www.deribit.com/options/BTC/BTC-24APR26/BTC-24APR26-61000-C'));
    });

    test('fails if not Deribit source', () {
      final underlying = Commodity('BTC');
      final future = DatedFuture(
        'BTC-26JUN26',
        underlying: underlying,
        expiration: DateTime(2026, 6, 26),
        source: DataSource.yfinance,
      );
      expect(() => renderer.render(future), throwsArgumentError);
    });

    test('renders Commodity correctly', () {
      final comm = Commodity('BTC', source: DataSource.deribit);
      expect(renderer.render(comm), equals('https://www.deribit.com/spot/BTC_USDT'));
    });
  });

  group('AssetRenderer.yfinance', () {
    final renderer = AssetRenderer.yfinance();

    test('renders Commodity correctly', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      expect(renderer.render(iren), equals('https://finance.yahoo.com/quote/IREN/'));
    });

    test('renders Option correctly', () {
      final iren = Commodity('IREN');
      final option = Option(
        'IREN280121C00018000',
        underlying: iren,
        money: Commodity('USD'),
        strike: 18.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        source: DataSource.yfinance,
      );
      expect(renderer.render(option), equals('https://finance.yahoo.com/quote/IREN280121C00018000/'));
    });

    test('fails if not YFinance source', () {
      final iren = Commodity('IREN', source: DataSource.deribit);
      expect(() => renderer.render(iren), throwsArgumentError);
    });
  });

  group('PositionRenderer.optionStrat', () {
    final renderer = PositionRenderer.optionStrat();

    test('renders covered call correctly', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      final option = Option(
        'IREN280121C37',
        underlying: iren,
        money: Commodity('USD'),
        strike: 37.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        source: DataSource.yfinance,
      );
      
      final position = iren.ofSize(100.0) + option.ofSize(-1.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/covered-call/IREN/IRENx100,-.IREN280121C37'));
    });

    test('renders covered call with unitCostBasis correctly', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      final option = Option(
        'IREN280121C37',
        underlying: iren,
        money: Commodity('USD'),
        strike: 37.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        source: DataSource.yfinance,
      );
      
      final position = iren.ofSize(100.0, Commodity('USD').ofSize(35.0)) +
          option.ofSize(-1.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/covered-call/IREN/IRENx100@35,-.IREN280121C37'));
    });

    test('renders covered call with unitCostBasis on stock and option leg', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      final option = Option(
        'IREN280121C37',
        underlying: iren,
        money: Commodity('USD'),
        strike: 37.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        contractLot: 100.0,
        source: DataSource.yfinance,
      );
      
      final position = iren.ofSize(100.0, Commodity('USD').ofSize(35.0)) +
          option.ofSize(-1.0, Commodity('USD').ofSize(250.0));
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/covered-call/IREN/IRENx100@35,-.IREN280121C37@2.5'));
    });

    test('renders covered call correctly with 8-digit padded option names', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      final option = Option(
        'IREN280121C00018000',
        underlying: iren,
        money: Commodity('USD'),
        strike: 18.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        source: DataSource.yfinance,
      );
      
      final position = iren.ofSize(100.0) + option.ofSize(-1.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/covered-call/IREN/IRENx100,-.IREN280121C18'));
    });

    test('skips non-OptionStrat assets', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      final other = Commodity('BTC', source: DataSource.deribit);
      
      final position = iren.ofSize(100.0) + other.ofSize(2.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/custom/IREN/IRENx100'));
    });

    test('fails if multiple underlyings', () {
      final iren = Commodity('IREN', source: DataSource.yfinance);
      final aapl = Commodity('AAPL', source: DataSource.yfinance);
      
      final position = iren.ofSize(100.0) + aapl.ofSize(100.0);
      expect(() => renderer.render(position), throwsArgumentError);
    });
    
    test('fails if no valid OptionStrat assets', () {
      final other = Commodity('BTC', source: DataSource.deribit);
      
      final position = other.ofSize(2.0);
      expect(() => renderer.render(position), throwsArgumentError);
    });
  });
}
