import 'dart:convert';
import 'package:xml/xml.dart';

double getAttrDouble(XmlNode node, String name, [double def = 0.0]) {
  if (node is XmlElement) {
    final val = node.getAttribute(name);
    if (val != null && val.trim().isNotEmpty) {
      return double.tryParse(val) ?? def;
    }
  }
  return def;
}

String detectBaseCurrency(XmlDocument document) {
  final possibleTags = [
    'ChangeInNAV',
    'EquitySummaryByReportDateInBase',
    'EquitySummaryInBase',
    'EquitySummary',
    'FlexStatement'
  ];
  for (final tag in possibleTags) {
    for (final el in document.findAllElements(tag)) {
      final currency = el.getAttribute('currency');
      if (currency != null && currency.trim().isNotEmpty) {
        return currency.trim().toUpperCase();
      }
    }
  }
  return 'USD';
}

Map<String, dynamic>? parseAccountNavSummary(XmlDocument document) {
  final navNode = document.findAllElements('ChangeInNAV').firstOrNull ??
                  document.findAllElements('ChangeInNAVByPeriod').firstOrNull ??
                  document.findAllElements('ChangeInNAVStatement').firstOrNull;

  final mtmNodes = document.findAllElements('MTMPerformanceSummaryInBase').toList()
    ..addAll(document.findAllElements('MTMPerformanceSummaryUnderlying'))
    ..addAll(document.findAllElements('MTMPerformanceSummary'))
    ..addAll(document.findAllElements('RealizedUnrealizedPerformanceSummaryAtNAV'))
    ..addAll(document.findAllElements('RealizedUnrealizedPerformanceSummary'));

  final equityNodes = document.findAllElements('EquitySummaryByReportDateInBase').toList()
    ..addAll(document.findAllElements('EquitySummaryInBase'))
    ..addAll(document.findAllElements('EquitySummary'))
    ..addAll(document.findAllElements('NavSummaryInBase'))
    ..addAll(document.findAllElements('NavSummary'))
    ..addAll(document.findAllElements('EquitySummaryByReportDate'));

  double? startingNAV;
  double? endingNAV;
  double realizedPNL = 0.0;
  double unrealizedPNL = 0.0;
  double mtmPNL = 0.0;
  double depositsWithdrawals = 0.0;
  double dividends = 0.0;
  double interest = 0.0;
  bool hasChangeInNavSection = false;

  if (navNode != null) {
    startingNAV = getAttrDouble(navNode, 'startingValue', getAttrDouble(navNode, 'startingNAV', -1.0));
    if (startingNAV == -1.0) startingNAV = null;

    endingNAV = getAttrDouble(navNode, 'endingValue', getAttrDouble(navNode, 'endingNAV', -1.0));
    if (endingNAV == -1.0) endingNAV = null;

    realizedPNL = getAttrDouble(navNode, 'realizedPNL', getAttrDouble(navNode, 'realizedPnl', getAttrDouble(navNode, 'realizedTotal')));
    unrealizedPNL = getAttrDouble(navNode, 'unrealizedPNL', getAttrDouble(navNode, 'unrealizedPnl', getAttrDouble(navNode, 'unrealizedTotal', getAttrDouble(navNode, 'changeInUnrealized'))));
    mtmPNL = getAttrDouble(navNode, 'mtmPNL', getAttrDouble(navNode, 'mtmPnl', getAttrDouble(navNode, 'mtmTotal', getAttrDouble(navNode, 'markToMarket'))));
    depositsWithdrawals = getAttrDouble(navNode, 'depositsWithdrawals', getAttrDouble(navNode, 'depositsAndWithdrawals', getAttrDouble(navNode, 'capitalMovements')));
    dividends = getAttrDouble(navNode, 'dividends');
    interest = getAttrDouble(navNode, 'interest');
    hasChangeInNavSection = true;
  } else if (equityNodes.isNotEmpty) {
    equityNodes.sort((a, b) => (a.getAttribute('reportDate') ?? '').compareTo(b.getAttribute('reportDate') ?? ''));
    final first = equityNodes.first;
    final last = equityNodes.last;
    startingNAV = getAttrDouble(first, 'total', getAttrDouble(first, 'startingAccountValue', -1.0));
    if (startingNAV == -1.0) startingNAV = null;

    endingNAV = getAttrDouble(last, 'total', getAttrDouble(last, 'endingAccountValue', -1.0));
    if (endingNAV == -1.0) endingNAV = null;

    dividends = getAttrDouble(last, 'dividendAccruals');
    interest = getAttrDouble(last, 'interestAccruals');
  }

  if (mtmNodes.isNotEmpty && realizedPNL == 0.0 && unrealizedPNL == 0.0) {
    for (final node in mtmNodes) {
      realizedPNL += getAttrDouble(node, 'realizedTotal', getAttrDouble(node, 'realizedPnl', getAttrDouble(node, 'realizedSTK')));
      unrealizedPNL += getAttrDouble(node, 'unrealizedTotal', getAttrDouble(node, 'unrealizedPnl', getAttrDouble(node, 'unrealizedSTK')));
    }
  }

  // Fallbacks
  if (unrealizedPNL == 0.0) {
    final openPosNodes = document.findAllElements('OpenPosition');
    if (openPosNodes.isNotEmpty) {
      unrealizedPNL = openPosNodes.fold(0.0, (acc, node) {
        final fx = getAttrDouble(node, 'fxRateToBase', 1.0);
        final val = getAttrDouble(node, 'fifoPnlUnrealized', getAttrDouble(node, 'unrealizedPNL'));
        return acc + val * fx;
      });
    }
  }

  if (realizedPNL == 0.0) {
    final tradeNodes = document.findAllElements('Trade');
    if (tradeNodes.isNotEmpty) {
      realizedPNL = tradeNodes.fold(0.0, (acc, node) {
        final fx = getAttrDouble(node, 'fxRateToBase', 1.0);
        final val = getAttrDouble(node, 'fifoPnlRealized', getAttrDouble(node, 'realizedPNL'));
        return acc + val * fx;
      });
    }
  }

  if (mtmPNL == 0.0) {
    final tradeNodes = document.findAllElements('Trade');
    final mtmFromTrades = tradeNodes.fold(0.0, (acc, node) {
      final fx = getAttrDouble(node, 'fxRateToBase', 1.0);
      final val = getAttrDouble(node, 'mtmPnl');
      return acc + val * fx;
    });
    mtmPNL = mtmFromTrades + unrealizedPNL;
  }

  realizedPNL += dividends;

  if (startingNAV == null && endingNAV == null) {
    return null;
  }

  final netChange = (endingNAV ?? 0.0) - (startingNAV ?? 0.0);

  return {
    'hasData': true,
    'startingNAV': startingNAV ?? 0.0,
    'endingNAV': endingNAV ?? 0.0,
    'netChange': netChange,
    'realizedPNL': realizedPNL,
    'unrealizedPNL': unrealizedPNL,
    'mtmPNL': mtmPNL,
    'depositsWithdrawals': depositsWithdrawals,
    'dividends': dividends,
    'interest': interest,
    'hasChangeInNavSection': hasChangeInNavSection,
  };
}

String extractSymbolRoot(XmlElement node) {
  final underlying = node.getAttribute('underlyingSymbol') ?? node.getAttribute('underlyingCategory');
  if (underlying != null && underlying.trim().isNotEmpty) {
    return underlying.trim().toUpperCase();
  }
  final rawSymbol = node.getAttribute('symbol') ?? '';
  if (rawSymbol.trim().isNotEmpty) {
    return rawSymbol.trim().split(RegExp(r'\s+')).first.toUpperCase();
  }
  return 'UNKNOWN';
}

class InstrumentSummary {
  final String symbol;
  final String assetCategory;
  int tradesCount = 0;
  int openPositionsCount = 0;
  double realized = 0.0;
  double dividends = 0.0;
  double unrealized = 0.0;
  double total = 0.0;

  InstrumentSummary(this.symbol, this.assetCategory);

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'assetCategory': assetCategory,
      'tradesCount': tradesCount,
      'openPositionsCount': openPositionsCount,
      'realized': realized,
      'dividends': dividends,
      'unrealized': unrealized,
      'total': total,
    };
  }
}

class SymbolSummary {
  final String symbol;
  double realized = 0.0;
  double dividends = 0.0;
  double unrealized = 0.0;
  double total = 0.0;
  int tradesCount = 0;
  int openPositionsCount = 0;
  final Map<String, InstrumentSummary> instrumentsMap = {};
  final List<Map<String, String>> trades = [];
  final List<Map<String, String>> openPositions = [];
  final List<Map<String, String>> priorPositions = [];

  SymbolSummary(this.symbol);

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'realized': realized,
      'dividends': dividends,
      'unrealized': unrealized,
      'total': total,
      'tradesCount': tradesCount,
      'openPositionsCount': openPositionsCount,
      'instruments': instrumentsMap.values.map((i) => i.toJson()).toList(),
      'trades': trades,
      'openPositions': openPositions,
      'priorPositions': priorPositions,
    };
  }
}

List<Map<String, dynamic>> aggregateBySymbol(XmlDocument document) {
  final symbolMap = <String, SymbolSummary>{};

  SymbolSummary getOrInitSymbol(String sym) {
    return symbolMap.putIfAbsent(sym, () => SymbolSummary(sym));
  }

  InstrumentSummary getOrInitInstrument(SymbolSummary parentAggr, String rawInstSymbol, String assetCategory) {
    final key = rawInstSymbol.isNotEmpty ? rawInstSymbol : parentAggr.symbol;
    return parentAggr.instrumentsMap.putIfAbsent(key, () => InstrumentSummary(key, assetCategory));
  }

  Map<String, String> nodeToMap(XmlElement node) {
    final map = <String, String>{};
    for (final attr in node.attributes) {
      map[attr.name.local] = attr.value;
    }
    return map;
  }

  // 1. Process Executed Trades
  for (final node in document.findAllElements('Trade')) {
    final sym = extractSymbolRoot(node);
    final aggr = getOrInitSymbol(sym);
    aggr.trades.add(nodeToMap(node));
    aggr.tradesCount++;

    final rawInstSymbol = node.getAttribute('symbol') ?? sym;
    final assetCategory = node.getAttribute('assetCategory') ?? '';
    final inst = getOrInitInstrument(aggr, rawInstSymbol, assetCategory);
    inst.tradesCount++;

    final fx = getAttrDouble(node, 'fxRateToBase', 1.0);
    final fifoRealized = getAttrDouble(node, 'fifoPnlRealized', getAttrDouble(node, 'realizedPNL')) * fx;
    aggr.realized += fifoRealized;
    inst.realized += fifoRealized;
  }

  // 2. Process Current Open Positions
  for (final node in document.findAllElements('OpenPosition')) {
    final sym = extractSymbolRoot(node);
    final aggr = getOrInitSymbol(sym);
    aggr.openPositions.add(nodeToMap(node));
    aggr.openPositionsCount++;

    final rawInstSymbol = node.getAttribute('symbol') ?? sym;
    final assetCategory = node.getAttribute('assetCategory') ?? '';
    final inst = getOrInitInstrument(aggr, rawInstSymbol, assetCategory);
    inst.openPositionsCount++;

    final fx = getAttrDouble(node, 'fxRateToBase', 1.0);
    final fifoUnrealized = getAttrDouble(node, 'fifoPnlUnrealized', getAttrDouble(node, 'unrealizedPNL')) * fx;
    aggr.unrealized += fifoUnrealized;
    inst.unrealized += fifoUnrealized;
  }

  // 3. Process Prior Period Positions
  for (final node in document.findAllElements('PriorPeriodPosition')) {
    final sym = extractSymbolRoot(node);
    final aggr = getOrInitSymbol(sym);
    aggr.priorPositions.add(nodeToMap(node));

    final rawInstSymbol = node.getAttribute('symbol') ?? sym;
    final assetCategory = node.getAttribute('assetCategory') ?? '';
    getOrInitInstrument(aggr, rawInstSymbol, assetCategory);
  }

  // 4. Process Performance Summary Items if detailed trades/positions are omitted
  for (final node in document.findAllElements('RealizedUnrealizedPerformanceSummaryItem')) {
    final sym = extractSymbolRoot(node);
    final aggr = getOrInitSymbol(sym);
    final realizedTotal = getAttrDouble(node, 'realizedTotal', getAttrDouble(node, 'realizedPnl'));
    final unrealizedTotal = getAttrDouble(node, 'unrealizedTotal', getAttrDouble(node, 'unrealizedPnl'));

    if (aggr.trades.isEmpty && aggr.openPositions.isEmpty) {
      aggr.realized = realizedTotal;
      aggr.unrealized = unrealizedTotal;

      final rawInstSymbol = node.getAttribute('symbol') ?? sym;
      final assetCategory = node.getAttribute('assetCategory') ?? '';
      final inst = getOrInitInstrument(aggr, rawInstSymbol, assetCategory);
      inst.realized = realizedTotal;
      inst.unrealized = unrealizedTotal;
    }
  }

  // 5. Parse dividends from MTMPerformanceSummaryUnderlying 'other' attribute
  for (final node in document.findAllElements('MTMPerformanceSummaryUnderlying')) {
    final sym = extractSymbolRoot(node);
    final assetCategory = node.getAttribute('assetCategory') ?? '';
    final otherVal = getAttrDouble(node, 'other');

    if (assetCategory.isNotEmpty && assetCategory != 'CASH' && otherVal != 0.0) {
      final aggr = getOrInitSymbol(sym);
      aggr.dividends += otherVal;

      final rawInstSymbol = node.getAttribute('symbol') ?? sym;
      final inst = getOrInitInstrument(aggr, rawInstSymbol, assetCategory);
      inst.dividends += otherVal;
    }
  }

  // Calculate totals and convert to Map representation
  final results = <SymbolSummary>[];
  for (final aggr in symbolMap.values) {
    aggr.total = aggr.realized + aggr.unrealized + aggr.dividends;
    for (final inst in aggr.instrumentsMap.values) {
      inst.total = inst.realized + inst.unrealized + inst.dividends;
    }
    results.add(aggr);
  }

  // Sort top-level symbols:
  // 1) Prefer symbols with open positions, to symbols that only have closed positions
  // 2) Then compare with absolute total PnL descending
  results.sort((a, b) {
    final aHasOpen = a.openPositionsCount > 0;
    final bHasOpen = b.openPositionsCount > 0;
    if (aHasOpen != bHasOpen) {
      return aHasOpen ? -1 : 1;
    }
    return b.total.abs().compareTo(a.total.abs());
  });

  return results.map((r) => r.toJson()).toList();
}

String parseIbkrXml(String xmlText) {
  try {
    final document = XmlDocument.parse(xmlText);

    final flexResponse = document.findAllElements('FlexStatementResponse').firstOrNull;
    if (flexResponse != null) {
      final status = flexResponse.getAttribute('Status');
      final errorCode = flexResponse.getAttribute('errorCode') ??
                        flexResponse.findElements('ErrorCode').firstOrNull?.innerText;
      final errorMsg = flexResponse.getAttribute('errorMessage') ??
                       flexResponse.findElements('ErrorMessage').firstOrNull?.innerText;

      if (status == 'Fail' || (errorCode != null && errorCode != '0')) {
        if (errorCode == '1001') {
          return jsonEncode({
            'error': 'IBKR Error (Code 1001): Newly created Flex Queries take 2–5 minutes to initialize across IBKR servers. Please wait a couple minutes and try fetching again.'
          });
        }
        return jsonEncode({
          'error': 'IBKR Error (Code $errorCode): ${errorMsg ?? 'Unknown error'}'
        });
      }
    }

    final baseCurrency = detectBaseCurrency(document);
    final navSummary = parseAccountNavSummary(document);
    final symbolSummaries = aggregateBySymbol(document);

    // Count totals of all trades/positions parsed
    int totalTrades = 0;
    int totalOpenPositions = 0;
    int totalPriorPositions = 0;

    for (final s in symbolSummaries) {
      totalTrades += (s['trades'] as List).length;
      totalOpenPositions += (s['openPositions'] as List).length;
      totalPriorPositions += (s['priorPositions'] as List).length;
    }

    final flexStmt = document.findAllElements('FlexStatement').firstOrNull;
    final queryResponse = document.findAllElements('FlexQueryResponse').firstOrNull;
    final queryName = queryResponse?.getAttribute('queryName') ?? '';
    final fromDate = flexStmt?.getAttribute('fromDate') ?? flexStmt?.getAttribute('startDateTime') ?? '';
    final toDate = flexStmt?.getAttribute('toDate') ?? flexStmt?.getAttribute('endDateTime') ?? '';
    final flexPeriod = flexStmt?.getAttribute('period') ?? '';

    final result = {
      'queryName': queryName,
      'fromDate': fromDate,
      'toDate': toDate,
      'flexPeriod': flexPeriod,
      'baseCurrency': baseCurrency,
      'accountNavSummary': navSummary,
      'symbolsCount': symbolSummaries.length,
      'tradesCount': totalTrades,
      'openPositionsCount': totalOpenPositions,
      'priorPositionsCount': totalPriorPositions,
      'perSymbolPnL': symbolSummaries,
    };

    return jsonEncode(result);
  } catch (e) {
    return jsonEncode({'error': e.toString()});
  }
}
