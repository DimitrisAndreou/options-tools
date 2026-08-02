/// Playground for analyzing post-tax PnL using surrogate market data and tax-optimal heuristics.
///
/// ============================================================================
/// SURROGATE MARKET SETUP
/// ============================================================================
/// Underlying: ACME stock, Spot price = $100.00
/// Interest rate: 0%
/// Expiration: 30 days
/// Strikes: $0 to $200 in intervals of $10
///
/// Option pricing uses round extrinsic values (decaying linearly from ATM peak of $5.00):
///   - ATM (K=100): Extrinsic = $5.00
///   - K=90, 110: Extrinsic = $4.00
///   - K=80, 120: Extrinsic = $3.00, etc.
///
/// Put-Call Parity (at zero interest rate):
///   C(K) - P(K) = S0 - K = 100 - K  =>  P(K) = C(K) + K - 100
///
/// ============================================================================
/// TAX REGIME RULES & DYNAMIC TAX-OPTIMAL HEURISTIC (TaxStrategy Handler)
/// ============================================================================
/// Standard TaxProfile setup:
///   (1) Underlying Stock Capital Gains/Losses: Taxed at underlyingTaxRate (e.g. 0%).
///   (2) Derivatives (Options/Futures) Realized PnL: Taxed at derivativeTaxRate (e.g. 15%).
///
/// DYNAMIC EXPIRATION HEURISTIC:
///   At expiration, for any ITM option, TaxStrategy evaluates the tax debit of both choices:
///     - Path A (Exercise / Assign): Option converts into an underlying trade, rolling option premium
///       into the stock cost basis -> Taxed at underlyingTaxRate.
///     - Path B (Cash Close / Settle): Option is closed as a derivative contract -> Taxed at derivativeTaxRate.
///
///   The handler dynamically selects whichever path minimizes tax debit (maximizes post-tax PnL).
///   This works universally regardless of whether underlyingTaxRate < derivativeTaxRate or > derivativeTaxRate.
///

library;

import 'dart:math';

import 'assets.dart';
import 'markets.dart';

// ============================================================================
// TAX ENGINE & DECISION HANDLERS
// ============================================================================

class TaxProfile {
  final double underlyingTaxRate; // 0.00 = 0%
  final double derivativeTaxRate; // 0.15 = 15%

  const TaxProfile({
    this.underlyingTaxRate = 0.00,
    this.derivativeTaxRate = 0.15,
  });
}

enum LegTaxAction {
  /// Option is exercised (if long) or assigned (if short), converting into an underlying trade.
  exerciseOrAssign,

  /// Option is closed / settled for cash as a derivative contract.
  cashClose,

  /// Option expires OTM worthless.
  expireWorthless,

  /// Underlying spot trade (shares held or sold). Taxed at underlyingTaxRate.
  underlyingSpotTrade,
}

class LegTaxResult {
  final Asset asset;
  final double size;
  final LegTaxAction action;
  final double preTaxPnL;
  final double taxDebit; // Positive = tax owed; Negative = tax credit
  final String explanation;

  LegTaxResult({
    required this.asset,
    required this.size,
    required this.action,
    required this.preTaxPnL,
    required this.taxDebit,
    required this.explanation,
  });

  double get postTaxPnL => preTaxPnL - taxDebit;
}

class PositionTaxResult {
  final Position position;
  final double underlyingPrice;
  final double preTaxPnL;
  final double totalTaxDebit;
  final List<LegTaxResult> legResults;

  PositionTaxResult({
    required this.position,
    required this.underlyingPrice,
    required this.preTaxPnL,
    required this.totalTaxDebit,
    required this.legResults,
  });

  double get postTaxPnL => preTaxPnL - totalTaxDebit;
}

/// Handler responsible for applying tax-optimal expiration heuristics to each leg of a position.
class TaxStrategy {
  final TaxProfile taxProfile;
  final Commodity underlying;
  final Commodity money;

  TaxStrategy({
    this.taxProfile = const TaxProfile(),
    required this.underlying,
    required this.money,
  });

  /// Evaluates a single leg (Line) at expiration price [price].
  /// [entryPrice] is the purchase price for stock or premium paid/received for options.
  LegTaxResult evaluateLeg(Line line, double price, double entryPrice) {
    final asset = line.asset;
    final size = line.size;

    // 1. Stock / Underlying Spot Leg
    if (asset.isCommodity && asset == underlying) {
      final preTaxPnL = (price - entryPrice) * size;
      final taxDebit = preTaxPnL * taxProfile.underlyingTaxRate;
      return LegTaxResult(
        asset: asset,
        size: size,
        action: LegTaxAction.underlyingSpotTrade,
        preTaxPnL: preTaxPnL,
        taxDebit: taxDebit,
        explanation: "Underlying spot trade taxed at ${(taxProfile.underlyingTaxRate * 100).toStringAsFixed(0)}% rate.",
      );
    }

    // 2. Option Leg
    if (asset.isOption) {
      final opt = asset.toOption;
      final isLong = size > 0;
      final absSize = size.abs();
      final strike = opt.strike;
      final isCall = opt.isCall;

      final isITM = isCall ? (price > strike) : (price < strike);
      final intrinsicValue = isCall ? max(0.0, price - strike) : max(0.0, strike - price);

      // Derivative PnL if closed for cash payoff:
      // Long option: payoff - premium
      // Short option: premium - payoff
      final cashClosePnL = isLong
          ? (intrinsicValue - entryPrice) * absSize
          : (entryPrice - intrinsicValue) * absSize;

      if (!isITM) {
        // Option is OTM: Expires Worthless
        final preTaxPnL = isLong ? -entryPrice * absSize : entryPrice * absSize;
        final taxDebit = preTaxPnL * taxProfile.derivativeTaxRate;
        return LegTaxResult(
          asset: asset,
          size: size,
          action: LegTaxAction.expireWorthless,
          preTaxPnL: preTaxPnL,
          taxDebit: taxDebit,
          explanation: "OTM option expired worthless. Derivative PnL taxed at ${(taxProfile.derivativeTaxRate * 100).toStringAsFixed(0)}%.",
        );
      }

      // Option is ITM: Compare Path A (Exercise/Assign) vs Path B (Cash Close) dynamically!
      final taxDebitExercise = cashClosePnL * taxProfile.underlyingTaxRate;
      final taxDebitCashClose = cashClosePnL * taxProfile.derivativeTaxRate;

      // Select tax-optimal path (lower tax debit = higher post-tax PnL)
      if (taxDebitExercise <= taxDebitCashClose) {
        return LegTaxResult(
          asset: asset,
          size: size,
          action: LegTaxAction.exerciseOrAssign,
          preTaxPnL: cashClosePnL,
          taxDebit: taxDebitExercise,
          explanation: "ITM option EXERCISED/ASSIGNED -> Underlying trade regime (${(taxProfile.underlyingTaxRate * 100).toStringAsFixed(0)}% tax). Optimal choice.",
        );
      } else {
        return LegTaxResult(
          asset: asset,
          size: size,
          action: LegTaxAction.cashClose,
          preTaxPnL: cashClosePnL,
          taxDebit: taxDebitCashClose,
          explanation: "ITM option CASH CLOSED -> Derivative regime (${(taxProfile.derivativeTaxRate * 100).toStringAsFixed(0)}% tax). Optimal choice.",
        );
      }
    }

    // Fallback
    return LegTaxResult(
      asset: asset,
      size: size,
      action: LegTaxAction.cashClose,
      preTaxPnL: 0.0,
      taxDebit: 0.0,
      explanation: "Standard asset",
    );
  }

  /// Evaluates an entire composite Position at underlying price [price].
  PositionTaxResult evaluatePosition(Position position, double price, Map<Asset, double> entryPrices) {
    double totalPreTaxPnL = 0.0;
    double totalTaxDebit = 0.0;
    final legResults = <LegTaxResult>[];

    for (final line in position.decompose()) {
      final entryPrice = entryPrices[line.asset] ?? 0.0;
      final legRes = evaluateLeg(line, price, entryPrice);
      totalPreTaxPnL += legRes.preTaxPnL;
      totalTaxDebit += legRes.taxDebit;
      legResults.add(legRes);
    }

    return PositionTaxResult(
      position: position,
      underlyingPrice: price,
      preTaxPnL: totalPreTaxPnL,
      totalTaxDebit: totalTaxDebit,
      legResults: legResults,
    );
  }
}

// ============================================================================
// SURROGATE MARKET DATA GENERATOR
// ============================================================================

class SurrogateMarketData {
  final Commodity acme = Commodity("ACME");
  final Commodity usd = Commodity("USD");
  final double spotPrice = 100.0;
  final DateTime expiration = DateTime(2026, 9, 1);

  final List<Market> markets = [];
  final Map<Asset, double> entryPrices = {};

  SurrogateMarketData() {
    // 1. Spot Market
    final spotMarket = Market.create(
      asset: acme,
      money: usd,
      bidPrice: spotPrice,
      askPrice: spotPrice,
    );
    markets.add(spotMarket);
    entryPrices[acme] = spotPrice;

    // 2. Option Chain: Strikes 0 to 200 in intervals of 10
    // Using clean round extrinsic numbers (ATM peak at $5.00, decaying linearly by $1.00 per $10 strike step)
    for (int strikeInt = 0; strikeInt <= 200; strikeInt += 10) {
      final strike = strikeInt.toDouble();

      final dist = (strike - spotPrice).abs();
      final callExtrinsic = max(0.0, 5.0 - (dist / 10.0));

      final callIntrinsic = max(0.0, spotPrice - strike);
      final callPrice = callIntrinsic + callExtrinsic;

      // Put-Call Parity: P(K) = C(K) + K - S0
      final putPrice = callPrice + strike - spotPrice;

      final callAsset = Option(
        "ACME-${expiration.month}AUG26-$strikeInt-C",
        underlying: acme,
        money: usd,
        strike: strike,
        isCall: true,
        expiration: expiration,
      );
      final callMarket = Market.create(
        asset: callAsset,
        money: usd,
        bidPrice: callPrice,
        askPrice: callPrice,
      );
      markets.add(callMarket);
      entryPrices[callAsset] = callPrice;

      final putAsset = Option(
        "ACME-${expiration.month}AUG26-$strikeInt-P",
        underlying: acme,
        money: usd,
        strike: strike,
        isPut: true,
        expiration: expiration,
      );
      final putMarket = Market.create(
        asset: putAsset,
        money: usd,
        bidPrice: putPrice,
        askPrice: putPrice,
      );
      markets.add(putMarket);
      entryPrices[putAsset] = putPrice;
    }
  }

  Option getCall(double strike) {
    return markets
        .map((m) => m.asset)
        .whereType<Option>()
        .firstWhere((o) => o.isCall && o.strike == strike);
  }

  Option getPut(double strike) {
    return markets
        .map((m) => m.asset)
        .whereType<Option>()
        .firstWhere((o) => o.isPut && o.strike == strike);
  }
}

// ============================================================================
// MAIN PLAYGROUND & COMPARISON RUNNER
// ============================================================================

void main() {
  print("==========================================================================");
  print("         TAX PLAYGROUND: SURROGATE MARKET (ACME Spot = \$100)            ");
  print("==========================================================================");
  print("Tax Profile Setup:");
  print("  • Underlying Stock Tax Rate: 0% Tax");
  print("  • Derivative Realized PnL Tax Rate: 15% Tax");
  print("\nDynamic Tax-Optimal Treatment:");
  print("  • Evaluates leg-by-leg tax debit for Exercise/Assign vs Cash Close.");
  print("  • Dynamically selects the treatment minimizing total tax liability.");
  print("==========================================================================\n");

  final surrogate = SurrogateMarketData();
  final taxStrategy = TaxStrategy(underlying: surrogate.acme, money: surrogate.usd);

  // Validate Put-Call Parity at ATM strike 100
  final call100 = surrogate.getCall(100);
  final put100 = surrogate.getPut(100);
  final c100Price = surrogate.entryPrices[call100]!;
  final p100Price = surrogate.entryPrices[put100]!;
  print("Surrogate Market Pricing Check at ATM Strike \$100:");
  print("  • Call \$100 Price: \$${c100Price.toStringAsFixed(2)}");
  print("  • Put  \$100 Price: \$${p100Price.toStringAsFixed(2)}");
  print("  • Put-Call Parity Check: P(100) - C(100) = \$${(p100Price - c100Price).toStringAsFixed(2)} (Expected \$100 - \$100 = \$0.00)\n");

  // Evaluation Prices: $0 to $200 in intervals of $20
  final testPrices = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0, 120.0, 140.0, 160.0, 180.0, 200.0];

  print("==========================================================================");
  print("   ATM COMPARISON: COVERED CALL \$100 vs SHORT PUT \$100 AT EXPIRATION   ");
  print("==========================================================================");
  _printComparisonTable(
    strat1Name: "CC \$100",
    strat1Pos: surrogate.acme.unit - call100.unit,
    strat2Name: "SP \$100",
    strat2Pos: -put100.unit,
    taxStrategy: taxStrategy,
    entryPrices: surrogate.entryPrices,
    prices: testPrices,
  );

  print("\n==========================================================================");
  print("   BOX SPREAD COMPARISON: BOX(60,80) vs BOX(80,120) vs BOX(120,140)       ");
  print("==========================================================================");
  final box60_80 = _createBoxSpread(surrogate, 60.0, 80.0);
  final box80_120 = _createBoxSpread(surrogate, 80.0, 120.0);
  final box120_140 = _createBoxSpread(surrogate, 120.0, 140.0);

  _printThreeWayBoxSpreadTable(
    taxStrategy: taxStrategy,
    entryPrices: surrogate.entryPrices,
    prices: testPrices,
    box60_80: box60_80,
    box80_120: box80_120,
    box120_140: box120_140,
  );
}

void _printThreeWayBoxSpreadTable({
  required TaxStrategy taxStrategy,
  required Map<Asset, double> entryPrices,
  required List<double> prices,
  required Position box60_80,
  required Position box80_120,
  required Position box120_140,
}) {
  print(
    "${'Price (S)'.padLeft(9)} | "
    "${'Pre-Tax PnL'.padLeft(11)} | "
    "${'B(60,80) Tax'.padLeft(14)} | "
    "${'B(80,120) Tax'.padLeft(14)} | "
    "${'B(120,140) Tax'.padLeft(14)} | "
    "${'B(60,80) Post'.padLeft(14)} | "
    "${'B(80,120) Post'.padLeft(14)} | "
    "${'B(120,140) Post'.padLeft(14)} | "
    "${'Optimal Tax Winner'.padLeft(26)}"
  );
  print("-" * 140);

  for (final price in prices) {
    final res1 = taxStrategy.evaluatePosition(box60_80, price, entryPrices);
    final res2 = taxStrategy.evaluatePosition(box80_120, price, entryPrices);
    final res3 = taxStrategy.evaluatePosition(box120_140, price, entryPrices);

    final taxes = [
      (name: "Box(60,80)", tax: res1.totalTaxDebit, post: res1.postTaxPnL),
      (name: "Box(80,120)", tax: res2.totalTaxDebit, post: res2.postTaxPnL),
      (name: "Box(120,140)", tax: res3.totalTaxDebit, post: res3.postTaxPnL),
    ];

    taxes.sort((a, b) => a.tax.compareTo(b.tax));

    String winner = "TIED";
    final minTax = taxes.first.tax;
    final runnerUpTax = taxes[1].tax;

    if (runnerUpTax - minTax > 0.001) {
      final savings = runnerUpTax - minTax;
      winner = "${taxes.first.name} (Saves \$${savings.toStringAsFixed(2)})";
    }

    final t1Str = _formatTax(res1.totalTaxDebit);
    final t2Str = _formatTax(res2.totalTaxDebit);
    final t3Str = _formatTax(res3.totalTaxDebit);

    final p1Str = "\$${res1.postTaxPnL.toStringAsFixed(2)}";
    final p2Str = "\$${res2.postTaxPnL.toStringAsFixed(2)}";
    final p3Str = "\$${res3.postTaxPnL.toStringAsFixed(2)}";

    print(
      "\$${price.toStringAsFixed(0).padLeft(8)} | "
      "\$${res1.preTaxPnL.toStringAsFixed(2).padLeft(10)} | "
      "${t1Str.padLeft(14)} | "
      "${t2Str.padLeft(14)} | "
      "${t3Str.padLeft(14)} | "
      "${p1Str.padLeft(14)} | "
      "${p2Str.padLeft(14)} | "
      "${p3Str.padLeft(14)} | "
      "${winner.padLeft(26)}"
    );
  }
  print("-" * 140);
}

Position _createBoxSpread(SurrogateMarketData surrogate, double low, double high) {
  final callLow = surrogate.getCall(low);
  final putLow = surrogate.getPut(low);
  final callHigh = surrogate.getCall(high);
  final putHigh = surrogate.getPut(high);
  // -C[low] + P[low] + C[high] - P[high]
  return -callLow.unit + putLow.unit + callHigh.unit - putHigh.unit;
}

void _printComparisonTable({
  required String strat1Name,
  required Position strat1Pos,
  required String strat2Name,
  required Position strat2Pos,
  required TaxStrategy taxStrategy,
  required Map<Asset, double> entryPrices,
  required List<double> prices,
}) {
  final s1TaxCol = "$strat1Name Tax";
  final s2TaxCol = "$strat2Name Tax";
  final s1PostCol = "$strat1Name Post";
  final s2PostCol = "$strat2Name Post";

  print(
    "${'Price (S)'.padLeft(9)} | "
    "${'Pre-Tax PnL'.padLeft(11)} | "
    "${s1TaxCol.padLeft(14)} | "
    "${s2TaxCol.padLeft(14)} | "
    "${s1PostCol.padLeft(15)} | "
    "${s2PostCol.padLeft(15)} | "
    "${'Optimal Tax Winner'.padLeft(26)}"
  );
  print("-" * 117);

  for (final price in prices) {
    final res1 = taxStrategy.evaluatePosition(strat1Pos, price, entryPrices);
    final res2 = taxStrategy.evaluatePosition(strat2Pos, price, entryPrices);

    final taxDiff = res1.totalTaxDebit - res2.totalTaxDebit;
    String winner = "TIED";
    if (taxDiff < -0.001) {
      winner = "$strat1Name (Saves \$${(-taxDiff).toStringAsFixed(2)})";
    } else if (taxDiff > 0.001) {
      winner = "$strat2Name (Saves \$${taxDiff.toStringAsFixed(2)})";
    }

    final s1TaxStr = _formatTax(res1.totalTaxDebit);
    final s2TaxStr = _formatTax(res2.totalTaxDebit);
    final s1PostTaxStr = "\$${res1.postTaxPnL.toStringAsFixed(2)}";
    final s2PostTaxStr = "\$${res2.postTaxPnL.toStringAsFixed(2)}";

    print(
      "\$${price.toStringAsFixed(0).padLeft(8)} | "
      "\$${res1.preTaxPnL.toStringAsFixed(2).padLeft(10)} | "
      "${s1TaxStr.padLeft(14)} | "
      "${s2TaxStr.padLeft(14)} | "
      "${s1PostTaxStr.padLeft(15)} | "
      "${s2PostTaxStr.padLeft(15)} | "
      "${winner.padLeft(26)}"
    );
  }
  print("-" * 117);
}

String _formatTax(double taxDebit) {
  final sign = taxDebit < 0 ? "-" : (taxDebit > 0 ? "+" : " ");
  return "$sign\$${taxDebit.abs().toStringAsFixed(2)}";
}
