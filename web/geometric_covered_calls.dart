import 'contracts.dart';

class GeometricCoveredCall {
  final Contract contract;
  late final double minimumContract;
  late final double initialHeld;
  late final double premium;
  late final double strikeAsChange;
  late final double breakEven;
  late final double breakEvenAsYield;
  late final double maxYield;
  late final double equivalentSellPrice;

  GeometricCoveredCall(this.contract, this.minimumContract) {
    final spot = contract.spotPrice;
    final bid = contract.bidPrice;
    final strike = contract.strike;
    final callsToSell = minimumContract;
    premium = callsToSell * bid;
    initialHeld = minimumContract - premium;

    breakEven = spot * (1.0 - bid);
    breakEvenAsYield = breakEven / spot;
    maxYield = strike / spot / (1.0 - bid);
    equivalentSellPrice = spot * maxYield;
  }

  double get totalHeld => initialHeld + premium;

  Map<String, dynamic> toJson() => {
        'callContract': contract,
        'initialHeld': initialHeld,
        'premium': premium,
        'breakEven': breakEven,
        'breakEvenAsYield': breakEvenAsYield,
        'maxYield': maxYield,
        'maxYieldAt': contract.strike,
        'maxYieldAtAsYield': contract.strikeAsYield,
        'equivalentSpotSellPrice': equivalentSellPrice,
        'minimumContractSize': minimumContract,
      };
}
