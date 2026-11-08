import 'assets.dart';
import 'data/deribit.dart';
import 'data/url_fetcher.dart';
import 'data/yfinance.dart';
import 'markets.dart';
import 'renderers.dart';

abstract class DataSource {
  String get name;

  String? assetUrl(Asset asset);

  String? strategyUrl(Position position);

  Future<List<Market>> fetchMarkets(
    String ticker,
    UrlFetcher urlFetcher, {
    int? minDTE,
    int? maxDTE,
  });

  static final DataSource deribit = DeribitDataSource();
  static final DataSource yfinance = YFinanceDataSource();

  static DataSource? fromName(String name) => switch (name.toLowerCase()) {
        'deribit' => deribit,
        'yfinance' => yfinance,
        _ => null,
      };

  @override
  String toString() => name;
}

class DeribitDataSource extends DataSource {
  @override
  String get name => 'Deribit';

  @override
  String? assetUrl(Asset asset) {
    if (asset is Commodity) {
      return 'https://www.deribit.com/spot/${asset.name}_USDT';
    }
    if (asset is DatedFuture) {
      return 'https://www.deribit.com/futures/${asset.name}';
    }
    if (asset is Option) {
      final underlying = asset.underlying.name;
      const monthNames = [
        '',
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      final day = asset.expiration.day;
      final month = monthNames[asset.expiration.month];
      final year = (asset.expiration.year % 100).toString().padLeft(2, '0');
      final date = '$day$month$year';
      return 'https://www.deribit.com/options/$underlying/$underlying-$date/${asset.name}';
    }
    return null;
  }

  @override
  String? strategyUrl(Position position) => null;

  @override
  Future<List<Market>> fetchMarkets(
    String ticker,
    UrlFetcher urlFetcher, {
    int? minDTE,
    int? maxDTE,
  }) async {
    final tickerToFetch = switch (ticker.toUpperCase()) {
      'BTC' || 'ETH' => ticker.toUpperCase(),
      'SOL' || 'AVAX' || 'XRP' || 'TRX' => 'USDC',
      _ => throw ArgumentError('Unknown Deribit ticker: $ticker'),
    };
    return await Deribit.fetchMarkets(
      [tickerToFetch],
      urlFetcher,
      errorListener: (instr, error) {},
      minDTE: minDTE,
      maxDTE: maxDTE,
    );
  }
}

class YFinanceDataSource extends DataSource {
  @override
  String get name => 'YFinance';

  @override
  String? assetUrl(Asset asset) {
    if (asset is Commodity || asset is Option) {
      return 'https://finance.yahoo.com/quote/${asset.name}/';
    }
    return null;
  }

  @override
  String? strategyUrl(Position position) {
    try {
      return PositionRenderer.optionStrat().render(position);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Market>> fetchMarkets(
    String ticker,
    UrlFetcher urlFetcher, {
    int? minDTE,
    int? maxDTE,
  }) async {
    final yf = await YFinance.openConnection(urlFetcher);
    return await yf.fetchMarkets(
      ticker.toUpperCase(),
      urlFetcher,
      minDTE: minDTE,
      maxDTE: maxDTE,
    );
  }
}

