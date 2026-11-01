import 'dart:io';

import 'package:options_tools/src/smoke_test_yfinance.dart';

Future<void> main(List<String> args) async {
  exitCode = await runSmokeTestCli(args);
}

