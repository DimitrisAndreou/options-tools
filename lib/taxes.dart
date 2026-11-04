import 'dart:math';

class TaxProfile {
  final double underlyingTaxRate;
  final double derivativeTaxRate;
  final bool includeTaxBenefits;

  const TaxProfile({
    this.underlyingTaxRate = 0.0,
    this.derivativeTaxRate = 0.0,
    this.includeTaxBenefits = true,
  });

  static const TaxProfile none = TaxProfile();

  bool get isTaxFree =>
      underlyingTaxRate == 0.0 && derivativeTaxRate == 0.0;

  double computeTax({
    required double realizedUnderlyingPnL,
    required double realizedDerivativePnL,
  }) =>
      _taxFor(realizedUnderlyingPnL, underlyingTaxRate) +
      _taxFor(realizedDerivativePnL, derivativeTaxRate);

  double _taxFor(double pnl, double rate) =>
      (includeTaxBenefits ? pnl : max(0.0, pnl)) * rate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxProfile &&
          underlyingTaxRate == other.underlyingTaxRate &&
          derivativeTaxRate == other.derivativeTaxRate &&
          includeTaxBenefits == other.includeTaxBenefits;

  @override
  int get hashCode =>
      Object.hash(underlyingTaxRate, derivativeTaxRate, includeTaxBenefits);

  @override
  String toString() =>
      'TaxProfile(underlying: $underlyingTaxRate, derivative: $derivativeTaxRate, '
      'includeTaxBenefits: $includeTaxBenefits)';
}

