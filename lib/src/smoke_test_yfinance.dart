import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../assets.dart';
import '../data/url_fetcher.dart';
import '../data/yfinance.dart';
import '../markets.dart';
import '../strategies.dart';

const List<String> defaultSmokeTickers = ['GOOG', 'F'];

const int _exitOk = 0;
const int _exitUsage = 64;
const int _exitSoftware = 70;

bool get _useAnsi =>
    stdout.hasTerminal &&
    stdout.supportsAnsiEscapes &&
    !Platform.environment.containsKey('NO_COLOR');

String _green(String text) => _useAnsi ? '\x1B[32m$text\x1B[0m' : text;
String _red(String text) => _useAnsi ? '\x1B[31m$text\x1B[0m' : text;
String _cyan(String text) => _useAnsi ? '\x1B[36m$text\x1B[0m' : text;

const String _usageText = '''
Usage: ./bin/smoke_test_yfinance.sh [options] [TICKER...]

Runs an end-to-end live Yahoo Finance smoke test (handshake, option chains,
CoveredCalls, LongOptions, Straddles, and JSON serialization).

If no ticker is provided, defaults to: GOOG, F

Options:
  -t, --ticker <SYMBOL>     Ticker to test (can also be passed positionally).
      --min-dte <DAYS>      Minimum DTE filter (default: 7).
      --max-dte <DAYS>      Maximum DTE filter (default: 1092).
      --slippage <RATIO>    Slippage ratio in [0, 1] (default: 0.5).
  -v, --verbose             Show verbose internal fetch and skip logs.
  -h, --help                Show this usage information.
''';

class _CliOptions {
  final List<String> tickers;
  final int minDte;
  final int maxDte;
  final double slippage;
  final bool verbose;
  final bool showHelp;

  _CliOptions({
    required this.tickers,
    required this.minDte,
    required this.maxDte,
    required this.slippage,
    required this.verbose,
    required this.showHelp,
  });
}

_CliOptions _parseArgs(List<String> args) {
  final tickers = <String>[];
  int minDte = 7;
  int maxDte = 1092;
  double slippage = 0.5;
  bool verbose = false;
  bool showHelp = false;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-h' || arg == '--help') {
      showHelp = true;
    } else if (arg == '-v' || arg == '--verbose') {
      verbose = true;
    } else if (arg == '-t' || arg == '--ticker') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      tickers.add(args[++i].trim().toUpperCase());
    } else if (arg.startsWith('--ticker=')) {
      tickers.add(arg.substring('--ticker='.length).trim().toUpperCase());
    } else if (arg == '--min-dte') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      minDte = int.parse(args[++i]);
    } else if (arg.startsWith('--min-dte=')) {
      minDte = int.parse(arg.substring('--min-dte='.length));
    } else if (arg == '--max-dte') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      maxDte = int.parse(args[++i]);
    } else if (arg.startsWith('--max-dte=')) {
      maxDte = int.parse(arg.substring('--max-dte='.length));
    } else if (arg == '--slippage') {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      slippage = double.parse(args[++i]);
    } else if (arg.startsWith('--slippage=')) {
      slippage = double.parse(arg.substring('--slippage='.length));
    } else if (arg.startsWith('-')) {
      throw FormatException('Unknown option: $arg');
    } else {
      final symbol = arg.trim().toUpperCase();
      if (symbol.isNotEmpty) {
        tickers.add(symbol);
      }
    }
  }

  return _CliOptions(
    tickers: tickers.isEmpty ? defaultSmokeTickers : tickers,
    minDte: minDte,
    maxDte: maxDte,
    slippage: slippage,
    verbose: verbose,
    showHelp: showHelp,
  );
}

Future<T> _runCapturingPrint<T>(
  Future<T> Function() action, {
  required bool verbose,
  required List<String> logBuffer,
}) {
  return runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        logBuffer.add(line);
        if (verbose) {
          parent.print(zone, line);
        }
      },
    ),
  );
}

Future<int> runSmokeTestCli(List<String> args) async {
  final _CliOptions options;
  try {
    options = _parseArgs(args);
  } on FormatException catch (e) {
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln()
      ..write(_usageText);
    return _exitUsage;
  }

  if (options.showHelp) {
    stdout.write(_usageText);
    return _exitOk;
  }

  final urlFetcher = UrlFetcher(const Duration(minutes: 5));
  bool allPassed = true;

  for (final ticker in options.tickers) {
    stdout.writeln(
      _cyan(
        '==> Smoke-testing YFinance for $ticker '
        '(DTE: ${options.minDte}..${options.maxDte}, slippage: ${options.slippage})...',
      ),
    );
    final logBuffer = <String>[];
    final stopwatch = Stopwatch()..start();

    try {
      await _runCapturingPrint(
        () async {
          final yf = await YFinance.openConnection(urlFetcher);
          final List<Market> markets = await yf.fetchMarkets(
            ticker,
            urlFetcher,
            minDTE: options.minDte,
            maxDTE: options.maxDte,
          );

          final underlying =
              Commodity(ticker, source: DataSource.yfinance);
          final money = const Commodity('USD');
          final spotMarket = markets.spotMarkets.firstOrNull;
          final spotStr = spotMarket != null
              ? '\$${spotMarket.midPrice.toStringAsFixed(2)}'
              : 'unknown';

          stdout.writeln(
            '  ${_green("✓")} Markets fetched: ${markets.length} '
            '(spot: $spotStr)',
          );

          // 1. Covered Calls
          final ccList = CoveredCall.generateAll(
            markets,
            underlying: underlying,
            money: money,
            slippage: options.slippage,
          ).toList();
          final ccJson = jsonEncode(ccList);
          final ccDecoded = jsonDecode(ccJson) as List;
          stdout.writeln(
            '  ${_green("✓")} CoveredCalls:    ${ccDecoded.length} strategies encoded cleanly',
          );

          // 2. Long Options (Calls + Puts)
          final longCalls = LongCall.generateAll(
            markets,
            underlying: underlying,
            money: money,
            slippage: options.slippage,
          ).map((e) => e.toJson()).toList();
          final longPuts = LongPut.generateAll(
            markets,
            underlying: underlying,
            money: money,
            slippage: options.slippage,
          ).map((e) => e.toJson()).toList();
          final loJson = jsonEncode([...longCalls, ...longPuts]);
          final loDecoded = jsonDecode(loJson) as List;
          stdout.writeln(
            '  ${_green("✓")} LongOptions:     ${loDecoded.length} strategies '
            '(${longCalls.length} calls, ${longPuts.length} puts) encoded cleanly',
          );

          // 3. Straddles
          final straddleList = Straddle.generateAll(
            markets,
            underlying: underlying,
            money: money,
            slippage: options.slippage,
          ).toList();
          final stJson = jsonEncode(straddleList);
          final stDecoded = jsonDecode(stJson) as List;
          stdout.writeln(
            '  ${_green("✓")} Straddles:       ${stDecoded.length} strategies encoded cleanly',
          );
        },
        verbose: options.verbose,
        logBuffer: logBuffer,
      );

      stopwatch.stop();
      stdout.writeln(
        '  ${_green("PASS")} $ticker completed in '
        '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s\n',
      );
    } catch (e, st) {
      stopwatch.stop();
      allPassed = false;
      if (!options.verbose && logBuffer.isNotEmpty) {
        stderr.writeln('--- Last internal logs before failure ($ticker) ---');
        final tail = logBuffer.length > 15
            ? logBuffer.sublist(logBuffer.length - 15)
            : logBuffer;
        for (final line in tail) {
          stderr.writeln('  $line');
        }
        stderr.writeln('---------------------------------------------------');
      }
      stderr.writeln('${_red("FAIL")} $ticker failed: $e');
      if (e is JsonUnsupportedObjectError) {
        if (e.cause != null) {
          stderr.writeln('  Cause: ${e.cause}');
        }
        if (e.unsupportedObject != null) {
          stderr.writeln('  Unsupported object: ${e.unsupportedObject}');
        }
      }
      stderr.writeln(st);
    }
  }

  return allPassed ? _exitOk : _exitSoftware;
}
