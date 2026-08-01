import 'dart:convert';
import 'package:test/test.dart';
import 'package:options_tools/data/ibkr.dart';

void main() {
  group('IBKR Parser Tests', () {
    test('Parse error response XML correctly', () {
      const errorXml = '''
<FlexStatementResponse Status="Fail" errorCode="1001" errorMessage="Query not ready"/>
''';
      final jsonText = parseIbkrXml(errorXml);
      final result = jsonDecode(jsonText);
      expect(result['error'], contains('IBKR Error (Code 1001)'));
    });

    test('Parse valid XML with currency conversion, rollups, and dividends', () {
      const validXml = '''
<FlexQueryResponse queryName="Test Report">
  <FlexStatements>
    <FlexStatement fromDate="20260301" toDate="20260315" period="Custom">
      <ChangeInNAV currency="EUR" startingValue="100000.0" endingValue="110000.0" realizedPNL="2000.0" unrealizedPNL="8000.0" depositsWithdrawals="0.0" dividends="150.0" interest="50.0"/>
      <Trades>
        <Trade symbol="TSLA 260619C00200000" underlyingSymbol="TSLA" assetCategory="OPT" fifoPnlRealized="1000.0" fxRateToBase="1.1"/>
        <Trade symbol="TSLA" underlyingSymbol="TSLA" assetCategory="STK" fifoPnlRealized="500.0" fxRateToBase="1.1"/>
        <Trade symbol="RNO" underlyingSymbol="RNO" assetCategory="STK" fifoPnlRealized="200.0" fxRateToBase="1.0"/>
      </Trades>
      <OpenPositions>
        <OpenPosition symbol="TSLA" underlyingSymbol="TSLA" assetCategory="STK" fifoPnlUnrealized="3000.0" fxRateToBase="1.1"/>
        <OpenPosition symbol="AAPL" underlyingSymbol="AAPL" assetCategory="STK" fifoPnlUnrealized="1000.0" fxRateToBase="1.1"/>
      </OpenPositions>
      <MTMPerformanceSummaryUnderlying symbol="TSLA" assetCategory="STK" other="150.0"/>
    </FlexStatement>
  </FlexStatements>
</FlexQueryResponse>
''';

      final jsonText = parseIbkrXml(validXml);
      final result = jsonDecode(jsonText);

      // Verify basic fields
      expect(result['error'], isNull);
      expect(result['baseCurrency'], equals('EUR'));
      expect(result['queryName'], equals('Test Report'));
      expect(result['fromDate'], equals('20260301'));
      expect(result['toDate'], equals('20260315'));
      expect(result['flexPeriod'], equals('Custom'));

      // Verify Account NAV Summary
      final navSummary = result['accountNavSummary'];
      expect(navSummary, isNotNull);
      expect(navSummary['startingNAV'], equals(100000.0));
      expect(navSummary['endingNAV'], equals(110000.0));
      expect(navSummary['netChange'], equals(10000.0));
      // realizedPNL includes dividends = 2000 + 150 = 2150
      expect(navSummary['realizedPNL'], equals(2150.0));
      expect(navSummary['unrealizedPNL'], equals(8000.0));
      expect(navSummary['dividends'], equals(150.0));
      expect(navSummary['interest'], equals(50.0));

      // Verify totals
      expect(result['symbolsCount'], equals(3));
      expect(result['tradesCount'], equals(3));
      expect(result['openPositionsCount'], equals(2));

      // Verify Symbol summaries
      final symbolList = result['perSymbolPnL'] as List;
      expect(symbolList.length, equals(3));

      // Order should be sorted by absolute total P&L descending: TSLA (5100), AAPL (1100), RNO (200)
      final tsla = symbolList[0];
      final aapl = symbolList[1];
      final rno = symbolList[2];

      // TSLA
      expect(tsla['symbol'], equals('TSLA'));
      // Realized: (1000 * 1.1) + (500 * 1.1) = 1650.0
      expect(tsla['realized'], closeTo(1650.0, 0.001));
      expect(tsla['dividends'], closeTo(150.0, 0.001));
      // Unrealized: 3000 * 1.1 = 3300.0
      expect(tsla['unrealized'], closeTo(3300.0, 0.001));
      expect(tsla['total'], closeTo(5100.0, 0.001));

      // AAPL
      expect(aapl['symbol'], equals('AAPL'));
      expect(aapl['realized'], equals(0.0));
      expect(aapl['dividends'], equals(0.0));
      // Unrealized: 1000 * 1.1 = 1100.0
      expect(aapl['unrealized'], closeTo(1100.0, 0.001));
      expect(aapl['total'], closeTo(1100.0, 0.001));

      // RNO
      expect(rno['symbol'], equals('RNO'));
      // Realized: 200 * 1.0 = 200.0
      expect(rno['realized'], closeTo(200.0, 0.001));
      expect(rno['dividends'], equals(0.0));
      expect(rno['unrealized'], equals(0.0));
      expect(rno['total'], closeTo(200.0, 0.001));
    });

    test('Sort prefers symbols with open positions over closed ones, then absolute total PnL', () {
      const sortingXml = '''
<FlexQueryResponse queryName="Sorting Test">
  <FlexStatements>
    <FlexStatement fromDate="20260301" toDate="20260315" period="Custom">
      <Trades>
        <Trade symbol="CLOSED_LARGE_PNL" underlyingSymbol="CLOSED_LARGE_PNL" assetCategory="STK" fifoPnlRealized="10000.0" fxRateToBase="1.0"/>
        <Trade symbol="OPEN_SMALL_PNL" underlyingSymbol="OPEN_SMALL_PNL" assetCategory="STK" fifoPnlRealized="100.0" fxRateToBase="1.0"/>
        <Trade symbol="CLOSED_SMALL_PNL" underlyingSymbol="CLOSED_SMALL_PNL" assetCategory="STK" fifoPnlRealized="50.0" fxRateToBase="1.0"/>
      </Trades>
      <OpenPositions>
        <OpenPosition symbol="OPEN_SMALL_PNL" underlyingSymbol="OPEN_SMALL_PNL" assetCategory="STK" fifoPnlUnrealized="100.0" fxRateToBase="1.0"/>
        <OpenPosition symbol="OPEN_LARGE_PNL" underlyingSymbol="OPEN_LARGE_PNL" assetCategory="STK" fifoPnlUnrealized="1000.0" fxRateToBase="1.0"/>
      </OpenPositions>
    </FlexStatement>
  </FlexStatements>
</FlexQueryResponse>
''';

      final jsonText = parseIbkrXml(sortingXml);
      final result = jsonDecode(jsonText);
      final symbolList = result['perSymbolPnL'] as List;

      // Symbols expected:
      // 1. OPEN_LARGE_PNL (openPositionsCount = 1, total = 1000)
      // 2. OPEN_SMALL_PNL (openPositionsCount = 1, total = 200)
      // 3. CLOSED_LARGE_PNL (openPositionsCount = 0, total = 10000)
      // 4. CLOSED_SMALL_PNL (openPositionsCount = 0, total = 50)
      expect(symbolList.length, equals(4));
      expect(symbolList[0]['symbol'], equals('OPEN_LARGE_PNL'));
      expect(symbolList[1]['symbol'], equals('OPEN_SMALL_PNL'));
      expect(symbolList[2]['symbol'], equals('CLOSED_LARGE_PNL'));
      expect(symbolList[3]['symbol'], equals('CLOSED_SMALL_PNL'));
    });

    test('Sort sorts instruments within a symbol: open positions first, then absolute total PnL', () {
      const nestedSortingXml = '''
<FlexQueryResponse queryName="Nested Sorting Test">
  <FlexStatements>
    <FlexStatement fromDate="20260301" toDate="20260315" period="Custom">
      <Trades>
        <Trade symbol="TSLA 260619C00200000" underlyingSymbol="TSLA" assetCategory="OPT" fifoPnlRealized="50.0" fxRateToBase="1.0"/>
        <Trade symbol="TSLA 260619P00200000" underlyingSymbol="TSLA" assetCategory="OPT" fifoPnlRealized="5000.0" fxRateToBase="1.0"/>
      </Trades>
      <OpenPositions>
        <OpenPosition symbol="TSLA" underlyingSymbol="TSLA" assetCategory="STK" fifoPnlUnrealized="10.0" fxRateToBase="1.0"/>
      </OpenPositions>
    </FlexStatement>
  </FlexStatements>
</FlexQueryResponse>
''';

      final jsonText = parseIbkrXml(nestedSortingXml);
      final result = jsonDecode(jsonText);
      final symbolList = result['perSymbolPnL'] as List;

      expect(symbolList.length, equals(1));
      final tsla = symbolList[0];
      expect(tsla['symbol'], equals('TSLA'));

      final instruments = tsla['instruments'] as List;
      expect(instruments.length, equals(3));
      // 1. TSLA (has open position)
      expect(instruments[0]['symbol'], equals('TSLA'));
      // 2. TSLA 260619P00200000 (closed, but total.abs() = 5000)
      expect(instruments[1]['symbol'], equals('TSLA 260619P00200000'));
      // 3. TSLA 260619C00200000 (closed, total.abs() = 50)
      expect(instruments[2]['symbol'], equals('TSLA 260619C00200000'));
    });

    test('Position quantity parsing, accumulation, and fallback logic', () {
      const xmlWithOpenPos = '''
<FlexQueryResponse queryName="Position Test">
  <FlexStatements>
    <FlexStatement fromDate="20260301" toDate="20260315" period="Custom">
      <OpenPositions>
        <OpenPosition symbol="IBIT" underlyingSymbol="IBIT" assetCategory="STK" position="1000" positionValue="50000" fxRateToBase="1.1"/>
        <OpenPosition symbol="IBIT" underlyingSymbol="IBIT" assetCategory="STK" position="300" positionValue="15000" fxRateToBase="1.1"/>
        <OpenPosition symbol="IBIT  270115C00035000" underlyingSymbol="IBIT" assetCategory="OPT" position="-3" positionValue="-1200" fxRateToBase="1.1"/>
      </OpenPositions>
      <MTMPerformanceSummaryUnderlying symbol="IBIT" assetCategory="STK" closeQuantity="1300"/>
    </FlexStatement>
  </FlexStatements>
</FlexQueryResponse>
''';

      final jsonText1 = parseIbkrXml(xmlWithOpenPos);
      final result1 = jsonDecode(jsonText1);
      final perSymbolPnL1 = result1['perSymbolPnL'] as List;
      final tslaInstruments1 = perSymbolPnL1[0]['instruments'] as List;

      final ibitStk1 = tslaInstruments1.firstWhere((i) => i['symbol'] == 'IBIT');
      final ibitOpt1 = tslaInstruments1.firstWhere((i) => i['symbol'] == 'IBIT  270115C00035000');

      expect(ibitStk1['position'], equals(1300.0));
      expect(ibitStk1['marketValue'], closeTo(71500.0, 0.001)); // (50000 + 15000) * 1.1
      expect(ibitOpt1['position'], equals(-3.0));
      expect(ibitOpt1['marketValue'], closeTo(-1320.0, 0.001)); // -1200 * 1.1
      expect(perSymbolPnL1[0]['marketValue'], closeTo(70180.0, 0.001)); // 71500 + (-1320)

      const xmlWithMtmFallback = '''
<FlexQueryResponse queryName="Position Test Fallback">
  <FlexStatements>
    <FlexStatement fromDate="20260301" toDate="20260315" period="Custom">
      <MTMPerformanceSummaryUnderlying symbol="IBIT" assetCategory="STK" closeQuantity="1000" closePrice="40" multiplier="1"/>
      <MTMPerformanceSummaryUnderlying symbol="IBIT" assetCategory="STK" closeQuantity="300" closePrice="40" multiplier="1"/>
    </FlexStatement>
  </FlexStatements>
</FlexQueryResponse>
''';

      final jsonText2 = parseIbkrXml(xmlWithMtmFallback);
      final result2 = jsonDecode(jsonText2);
      final perSymbolPnL2 = result2['perSymbolPnL'] as List;
      final tslaInstruments2 = perSymbolPnL2[0]['instruments'] as List;

      final ibitStk2 = tslaInstruments2.firstWhere((i) => i['symbol'] == 'IBIT');
      expect(ibitStk2['position'], equals(1300.0));
      expect(ibitStk2['marketValue'], closeTo(52000.0, 0.001)); // (1000 * 40 * 1) + (300 * 40 * 1)
      expect(ibitStk2['openPositionsCount'], equals(1));
      expect(perSymbolPnL2[0]['marketValue'], closeTo(52000.0, 0.001));
    });
  });
}
