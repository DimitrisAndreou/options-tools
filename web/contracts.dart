import 'dart:math';
import 'rates.dart';

class Contract {
  static final _now = DateTime.now();
  
  final String instrumentName;
  final String asset;
  final int strike;
  final DateTime expirationDate;
  final String expirationDateStr;
  final String type;

  late final Duration durationTillExpiration;

  final double bidPrice;
  final double midPrice;
  final double markPrice;
  final double askPrice;

  final String quoteCurrency;
  final double spotPrice;
  final double futurePrice;

  late final double strikeAsYield;
  late final double riskFreeYield;

  Contract(
      {required this.instrumentName,
      required this.asset,
      required this.strike,
      required this.expirationDate,
      required this.expirationDateStr,
      required this.type,
      required this.bidPrice,
      required this.midPrice,
      required this.markPrice,
      required this.askPrice,
      required this.quoteCurrency,
      required this.spotPrice,
      required this.futurePrice}) {
    durationTillExpiration = expirationDate.difference(_now);
    strikeAsYield = strike / spotPrice;
    riskFreeYield = max(1.0, futurePrice / spotPrice);
  }

  bool isPut() => type == 'P';
  bool isCall() => type == 'C';

  Map<String, dynamic> toJson() => {
        'instrumentName': instrumentName,
        'spotPrice': spotPrice,
        'futurePrice': futurePrice,
        'bidPrice': bidPrice,
        'midPrice': midPrice,
        'markPrice': markPrice,
        'askPrice': askPrice,
        'strike': strike,
        'strikeAsYield': strikeAsYield,
        'asset': asset,
        'quoteCurrency': quoteCurrency,
        'expirationDate': expirationDate.toIso8601String(),
        'expirationDateStr': expirationDateStr,
        'daysTillExpiration': durationTillExpiration.inDays,
        'type': type,
        'riskFreeYield': riskFreeYield,
        'riskFreeYieldAnnualized':
            annualizedYield(riskFreeYield, durationTillExpiration),
      };

  @override
  String toString() => '$instrumentName: $bidPrice..$markPrice..$askPrice';

  // Example name: BTC-31MAY24-59000-P
  static final RegExp _instrumentNameRegex =
      RegExp(r"^(\w+)-(.*?)-(\d+)-(P|C)$");
  static final RegExp _dateRegex = RegExp(r"^(\d+)(\w*?)(\d+)$");

  static final Map<String, int> _monthToNum = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, //
    'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8, //
    'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12, //
  };

  static Contract? fromDeribitJson(Map<String, dynamic> data) {
    if (data case {
      'instrument_name': String instrumentName,
      'mark_price': double markPrice,
      'quote_currency': String quoteCurrency,
      'estimated_delivery_price': double spotPrice,
      'underlying_price': double futurePrice,
      'mid_price': double midPrice,
      'bid_price': double bidPrice,
      'ask_price': double askPrice
      }) {
        Match match = _instrumentNameRegex.firstMatch(instrumentName)!;
        final asset = match.group(1)!;
        final dateStr = match.group(2)!;
        final strike = int.parse(match.group(3)!);
        final type = match.group(4)!;

        Match dateMatch = _dateRegex.firstMatch(dateStr)!;
        final dd = int.parse(dateMatch.group(1)!);
        final mmm = dateMatch.group(2)!;
        final yy = int.parse(dateMatch.group(3)!);
        final date = DateTime.utc(2000 + yy, _monthToNum[mmm]!, dd);
        return Contract(
            instrumentName: instrumentName,
            markPrice: markPrice,
            quoteCurrency: quoteCurrency,
            spotPrice: spotPrice,
            futurePrice: futurePrice,
            midPrice: midPrice,
            askPrice: askPrice,
            bidPrice: bidPrice,
            asset: asset,
            expirationDate: date,
            expirationDateStr: dateStr,
            strike: strike,
            type: type);
    }
    // print("Invalid contract: $data");
    return null;
  }
}
