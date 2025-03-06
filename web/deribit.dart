import 'contracts.dart';
import 'dart:convert';

class DeribitResponse {
  final String json;
  final DateTime timestamp;
  final List<Contract> contracts;

  DeribitResponse(this.json, this.timestamp, this.contracts);

  factory DeribitResponse.createFromJson(String json) {
    Map<String, dynamic> jsonData = jsonDecode(json);
    final rawContracts = jsonData['result'] as List<dynamic>?;
    final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
        rawContracts?.first?['creation_timestamp'] as int? ?? -1);
    final contracts = rawContracts!
        .map((rawContract) => Contract.fromDeribitJson(rawContract))
        .where((contract) => contract != null)
        .cast<Contract>()
        .toList();

    return DeribitResponse(json, timestamp, contracts);
  }
}

String deribitUriForOptionChain(String ticker) =>
    "https://www.deribit.com/api/v2/public/get_book_summary_by_currency?kind=option&currency=$ticker";

double getMinimumContract(String ticker) {
  switch (ticker) {
    case "BTC":
      return 0.1;
    case "ETH":
      return 1.0;
    default:
      throw ArgumentError("Unknown ticker: $ticker");
  }
}
