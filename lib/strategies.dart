// GCC: what's the bare minimum needed?
// just a call, and a spot market.
// Give it the market navigator, the commodity, and the markets.
// Then you can group by Expiration -> Strike -> Call
// and via an inner mapValues(), map to GCC.
// How to map to JSON? Maybe keep it flat?

// Call -> SyntheticAsset (spot - call).
// max risk: value at $0
// max yield: value at $strike / value at $spot
// breakEven: solve Analytically

// Engine that can compute interesting points automatically.
// Who owns "markToMarket"? With a hypothetical spot market.
// Can such an engine find interesting points?
// What about a simple short put, paid in BTC?

class GeometricCoveredCall {
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
