import 'dart:io';
import 'package:options_tools/assets.dart';
import 'package:options_tools/graphics/payoff_svg.dart';
import 'package:options_tools/position_analyzer.dart';

void main() {
  final underlying = Commodity.fromName('XYZ');
  final money = Commodity.fromName('USD');
  final exp = DateTime(2026, 12, 18);

  // Define a Bull Call Spread:
  // Buy 1 Call at Strike 100 ($5 cost)
  // Sell 1 Call at Strike 110 ($2 credit) -> Net cost = $3 ($300 total for 100 multiplier)
  final longCall = Option('XYZ-100C', underlying: underlying, expiration: exp, money: money, strike: 100, isCall: true, isPut: false);
  final shortCall = Option('XYZ-110C', underlying: underlying, expiration: exp, money: money, strike: 110, isCall: true, isPut: false);

  // Position: 1 long call - 1 short call - 3 USD
  final position = longCall.unit - shortCall.unit - money.ofSize(3.0);

  final analyzer = PositionAnalyzer(position, underlying: underlying, money: money);

  print('Analyzing position: $position');
  print('Breakevens: ${analyzer.breakevens}');
  print('Max Profit: \$${analyzer.maxProfit}');
  print('Max Risk: \$${analyzer.maxRisk}');

  final svgString = PayoffSvgRenderer.render(
    analyzer,
    title: 'Bull Call Spread (Buy 100 Call, Sell 110 Call @ \$3 Net Debit)',
    darkMode: true,
  );

  final outputDir = Directory('book/assets/figures');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final outputFile = File('book/assets/figures/sample_payoff.svg');
  outputFile.writeAsStringSync(svgString);
  print('Saved PnL SVG diagram to: ${outputFile.path}');
}
