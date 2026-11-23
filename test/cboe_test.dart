import 'dart:convert';

import 'package:options_tools/assets.dart';
import 'package:options_tools/data/cboe.dart';
import 'package:options_tools/markets.dart';
import 'package:options_tools/strategies.dart';
import 'package:test/test.dart';

void main() {
  group('Cboe.parseOcc', () {
    test('parses standard equity call and put OCC symbols', () {
      final call = Cboe.parseOcc('ANT261218C00050000');
      expect(call, isNotNull);
      expect(call!.root, equals('ANT'));
      expect(call.expiration, equals(DateTime.utc(2026, 12, 18)));
      expect(call.isCall, isTrue);
      expect(call.strike, equals(50.0));

      final put = Cboe.parseOcc('SPY260619P00525500');
      expect(put, isNotNull);
      expect(put!.root, equals('SPY'));
      expect(put.expiration, equals(DateTime.utc(2026, 6, 19)));
      expect(put.isCall, isFalse);
      expect(put.strike, equals(525.5));
    });

    test('parses weekly letter-suffix and adjusted digit-suffix roots', () {
      final weekly = Cboe.parseOcc('SPXW261218C06000000');
      expect(weekly, isNotNull);
      expect(weekly!.root, equals('SPXW'));
      expect(weekly.strike, equals(6000.0));

      final adjusted = Cboe.parseOcc('BITO1261204P00014000');
      expect(adjusted, isNotNull);
      expect(adjusted!.root, equals('BITO1'));
      expect(adjusted.strike, equals(14.0));
    });

    test('returns null for invalid symbols', () {
      expect(Cboe.parseOcc(''), isNull);
      expect(Cboe.parseOcc('NOT_AN_OCC'), isNull);
    });
  });

  group('Cboe.parseMarketsFromJson', () {
    test('parses spot, calls, puts, filters adjusted & zero-bid contracts, and generates covered calls', () {
      final sampleJson = jsonEncode({
        'data': {
          'current_price': 48.5,
          'close': 48.0,
          'options': [
            // Valid call
            {
              'option': 'ANT261218C00050000',
              'bid': 2.1,
              'ask': 2.3,
              'bid_size': 15,
              'ask_size': 10,
            },
            // Valid put
            {
              'option': 'ANT261218P00045000',
              'bid': 1.4,
              'ask': 1.6,
              'bid_size': 5,
              'ask_size': 8,
            },
            // Adjusted deliverable -> should be skipped
            {
              'option': 'ANT1261218C00050000',
              'bid': 2.0,
              'ask': 2.5,
              'bid_size': 5,
              'ask_size': 5,
            },
            // Weekly letter suffix -> should be kept
            {
              'option': 'ANTW261224C00055000',
              'bid': 1.0,
              'ask': 1.2,
              'bid_size': 3,
              'ask_size': 4,
            },
            // bid_size == 0 -> bid treated as 0.0 -> skipped
            {
              'option': 'ANT261218C00060000',
              'bid': 0.5,
              'ask': 0.7,
              'bid_size': 0,
              'ask_size': 10,
            },
          ],
        },
      });

      final now = DateTime.utc(2026, 11, 23);
      final markets = Cboe.parseMarketsFromJson(
        sampleJson,
        ticker: 'ANT',
        now: now,
      );

      // 2 calls + 1 put + 1 spot = 4 markets
      expect(markets.length, equals(4));
      expect(markets.calls.length, equals(2));
      expect(markets.puts.length, equals(1));

      final calls = markets.calls.toList();
      expect(calls[0].asset.name, equals('ANT261218C00050000'));
      expect((calls[0].asset as Option).readableName, equals('ANT-18DEC26-50-C'));
      expect((calls[0].asset as Option).contractLot, equals(100.0));
      expect(calls[0].bidPrice, closeTo(210.0, 1e-6));
      expect(calls[0].askPrice, closeTo(230.0, 1e-6));

      // Weekly root is preserved in readableName (ANTW stays ANTW)
      expect(calls[1].asset.name, equals('ANTW261224C00055000'));
      expect((calls[1].asset as Option).readableName, equals('ANTW-24DEC26-55-C'));

      final underlying = Commodity('ANT', source: DataSource.cboe);
      final ccs = CoveredCall.generateAll(
        markets,
        underlying: underlying,
        money: Commodity('USD'),
      ).toList();
      expect(ccs.length, equals(2));
      expect(ccs.first.strategyURL, contains('optionstrat.com/build/covered-call/ANT/'));
    });

    test('respects minDTE and maxDTE filters', () {
      final sampleJson = jsonEncode({
        'data': {
          'current_price': 50.0,
          'options': [
            {
              'option': 'ANT261127C00050000', // 4 DTE
              'bid': 1.0,
              'ask': 1.2,
              'bid_size': 5,
            },
            {
              'option': 'ANT261218C00050000', // 25 DTE
              'bid': 2.0,
              'ask': 2.2,
              'bid_size': 5,
            },
            {
              'option': 'ANT270618C00050000', // 207 DTE
              'bid': 5.0,
              'ask': 5.5,
              'bid_size': 5,
            },
          ],
        },
      });

      final markets = Cboe.parseMarketsFromJson(
        sampleJson,
        ticker: 'ANT',
        minDTE: 10,
        maxDTE: 60,
        now: DateTime.utc(2026, 11, 23),
      );

      expect(markets.calls.length, equals(1));
      expect(markets.calls.single.asset.name, equals('ANT261218C00050000'));
    });
  });
}
