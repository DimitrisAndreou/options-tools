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
        venues: {Venue.Deribit},
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
        venues: {Venue.Deribit},
      );
      expect(
          renderer.render(option),
          equals(
              'https://www.deribit.com/options/BTC/BTC-24APR26/BTC-24APR26-61000-C'));
    });

    test('fails if not Venue.Deribit', () {
      final underlying = Commodity('BTC');
      final future = DatedFuture(
        'BTC-26JUN26',
        underlying: underlying,
        expiration: DateTime(2026, 6, 26),
        venues: {Venue.OptionStrat},
      );
      expect(() => renderer.render(future), throwsArgumentError);
    });

    test('fails if not Future or Option', () {
      final comm = Commodity('BTC', venues: {Venue.Deribit});
      expect(() => renderer.render(comm), throwsArgumentError);
    });
  });

  group('AssetRenderer.optionStrat', () {
    final renderer = AssetRenderer.optionStrat();

    test('renders Commodity correctly', () {
      final iren = Commodity('IREN', venues: {Venue.OptionStrat});
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
        venues: {Venue.OptionStrat},
      );
      expect(renderer.render(option), equals('https://finance.yahoo.com/quote/IREN280121C00018000/'));
    });

    test('fails if not Venue.OptionStrat', () {
      final iren = Commodity('IREN', venues: {Venue.Deribit});
      expect(() => renderer.render(iren), throwsArgumentError);
    });
  });

  group('PositionRenderer.optionStrat', () {
    final renderer = PositionRenderer.optionStrat();

    test('renders covered call correctly', () {
      final iren = Commodity('IREN', venues: {Venue.OptionStrat});
      final option = Option(
        'IREN280121C37',
        underlying: iren,
        money: Commodity('USD'),
        strike: 37.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        venues: {Venue.OptionStrat},
      );
      
      final position = iren.ofSize(100.0) + option.ofSize(-1.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/custom/IREN/IRENx100,.IREN280121C37x-1'));
    });

    test('renders covered call correctly with 8-digit padded option names', () {
      final iren = Commodity('IREN', venues: {Venue.OptionStrat});
      final option = Option(
        'IREN280121C00018000',
        underlying: iren,
        money: Commodity('USD'),
        strike: 18.0,
        isCall: true,
        expiration: DateTime(2028, 1, 21),
        venues: {Venue.OptionStrat},
      );
      
      final position = iren.ofSize(100.0) + option.ofSize(-1.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/custom/IREN/IRENx100,.IREN280121C18x-1'));
    });

    test('skips non-OptionStrat assets', () {
      final iren = Commodity('IREN', venues: {Venue.OptionStrat});
      final other = Commodity('BTC', venues: {Venue.Deribit});
      
      final position = iren.ofSize(100.0) + other.ofSize(2.0);
      expect(renderer.render(position), 
          equals('https://optionstrat.com/build/custom/IREN/IRENx100'));
    });

    test('fails if multiple underlyings', () {
      final iren = Commodity('IREN', venues: {Venue.OptionStrat});
      final aapl = Commodity('AAPL', venues: {Venue.OptionStrat});
      
      final position = iren.ofSize(100.0) + aapl.ofSize(100.0);
      expect(() => renderer.render(position), throwsArgumentError);
    });
    
    test('fails if no valid OptionStrat assets', () {
      final other = Commodity('BTC', venues: {Venue.Deribit});
      
      final position = other.ofSize(2.0);
      expect(() => renderer.render(position), throwsArgumentError);
    });
  });
}
