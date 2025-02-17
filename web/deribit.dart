import 'contracts.dart';
import 'dart:convert';
import 'dart:html';
import 'package:http/http.dart' as http;

const int minutesToCache = 15;  // TODO: 15

class DeribitResponse {
  final String json;
  final DateTime timestamp;
  final List<Contract> contracts;

  DeribitResponse(this.json, this.timestamp, this.contracts);

  factory DeribitResponse.createFromHttp(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch data, got error: ${response.statusCode}');
    }
    return DeribitResponse.createFromJson(response.body);
  }

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

  static Future<DeribitResponse> fetchLiveOrCachedData(String uri) async {
    String? cachedJson = window.localStorage[uri];
    if (cachedJson != null) {
      DeribitResponse cachedResponse = DeribitResponse.createFromJson(cachedJson);
      if (cachedResponse.timestamp
          .isAfter(DateTime.now().subtract(Duration(minutes: minutesToCache)))) {
        print("Using cache for: $uri");
        return cachedResponse;
      }
    }
    print("Fetching: $uri");
    DeribitResponse response = DeribitResponse.createFromHttp(
      await http.get(Uri.parse(uri)));
    window.localStorage[uri] = response.json;
    return response;
  }
}

String deribitUriForOptionChain(String ticker) =>
  "https://www.deribit.com/api/v2/public/get_book_summary_by_currency?kind=option&currency=$ticker";

double getMinimumContract(String ticker) {
  switch (ticker) {
    case "BTC": return 0.1;
    case "ETH": return 1.0;
    default: throw ArgumentError("Unknown ticker: $ticker");
  }
}