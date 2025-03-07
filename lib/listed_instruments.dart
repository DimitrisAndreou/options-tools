class ListedInstrument {
  final String instrument_name;
  final String base_currency;
  final String quote_currency;
  final double mark_price;
  final double? estimated_delivery_price;
  final double? last;
  final double? low;
  final double? bid_price;
  final double? mid_price;
  final double? ask_price;
  final double? high;
  final String? underlying_index;
  final double? underlying_price;
  final double? price_change;

  ListedInstrument(
      {required this.instrument_name,
      required this.base_currency,
      required this.quote_currency,
      required this.mark_price,
      this.estimated_delivery_price,
      this.last,
      this.low,
      this.bid_price,
      this.mid_price,
      this.ask_price,
      this.high,
      this.underlying_index,
      this.underlying_price,
      this.price_change});

  static ListedInstrument? fromJson(Map<String, dynamic> data) =>
      ListedInstrument(
          instrument_name: data['instrument_name'] as String,
          base_currency: data['base_currency'] as String,
          quote_currency: data['quote_currency'] as String,
          mark_price: data['mark_price'] as double,
          estimated_delivery_price: data['estimated_delivery_price'] as double?,
          last: data['last'] as double?,
          low: data['low'] as double?,
          bid_price: data['bid_price'] as double?,
          mid_price: data['mid_price'] as double?,
          ask_price: data['ask_price'] as double?,
          high: data['high'] as double?,
          underlying_index: data['underlying_index'] as String?,
          underlying_price: data['underlying_price'] as double?,
          price_change: data['price_change'] as double?);

  @override
  String toString() =>
      'instrument_name: $instrument_name,' 'base_currency: $base_currency,' +
      'quote_currency: $quote_currency,' +
      'mark_price: $mark_price,' +
      'estimated_delivery_price: $estimated_delivery_price,' +
      'last: $last,' +
      'low: $low,' +
      'bid_price: $bid_price,' +
      'mid_price: $mid_price,' +
      'ask_price: $ask_price,' +
      'high: $high,' +
      'underlying_index: $underlying_index,' +
      'underlying_price: $underlying_price,' +
      'price_change: $price_change,';
}
