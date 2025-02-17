import 'dart:collection';
import 'dart:math';

import 'dart:convert';
import 'package:http/http.dart';

abstract class Asset {
  @override
  String toString() => name;

  String get name;

  // Decompose this asset into a list of SimpleAsset positions.
  Iterable<Position> decompose();

  Position position(double size) => Position(this, size);
}

class Position {
  final Asset asset;
  // TODO: double is not a great type for money.
  final double size;

  Position(this.asset, [this.size = 0.0]);

  factory Position.merge(Iterable<Position> positions) {
    Position first = positions.first;
    double size = first.size;
    for (Position next in positions.skip(1)) {
      if (next.asset != first.asset) {
        throw ArgumentError("Can't merge positions due to differing " +
            "assets, ${first.asset} != ${next.asset}");
      }
      size += next.size;
    }
    return first.withSize(size);
  }

  Position operator +(double size) => Position(asset, this.size + size);
  Position operator *(double size) => Position(asset, this.size * size);

  Position withSize(double size) => Position(this.asset, size);

  bool get isZero => this.size == 0.0;

  @override
  String toString() => '($size $asset)';
}

// NamedAsset is an asset that can be traded directly;
// it doesn't consist of a combination of other assets.
class NamedAsset extends Asset {
  final String _name;
  NamedAsset(String name) : _name = name;

  @override
  String get name => _name;

  @override
  Iterable<Position> decompose() => [this.position(1.0)];

  @override
  bool operator ==(Object other) =>
      other is NamedAsset && this.name == other.name;

  @override
  int get hashCode => _name.hashCode;
}

// USDC, BTC etc.
class Commodity extends NamedAsset implements Comparable<Commodity> {
  static final Map<String, Commodity> _cache = {};
  Commodity._internal(super.name);
  factory Commodity(String name) =>
      _cache.putIfAbsent(name, () => Commodity._internal(name));

  @override
  int compareTo(Commodity that) {
    return this.name.compareTo(that.name);
  }
}

// A SyntheticAsset is an Asset that is a combination of other assets
// (simple or synthetic) of particular proportions.
// Usually it cannot be traded directly or atomically.
// Moreover, an entire portfolio can be represented as a single
// synthetic asset.
class SyntheticAsset extends Asset {
  final Map<Asset, Position> _assetPositions = HashMap();

  SyntheticAsset(Iterable<Position> positions) {
    for (final position in positions) {
      _assetPositions.update(
          position.asset, (existing) => existing + position.size,
          ifAbsent: () => position);
    }
  }

  // Given a strategy, you trade() each leg, get a synthetic asset
  // for each leg, then you just merge them all via this constructor,
  // and you end up with a position of the strategy, including a
  // single (merged) money position (the cost basis).
  SyntheticAsset.mergeAssets(Iterable<Asset> assets)
      : this(assets.expand((a) => a.decompose()));

  @override
  Iterable<Position> decompose() sync* {
    for (final position in _assetPositions.values) {
      for (final innerPosition in position.asset.decompose()) {
        yield innerPosition.asset.position(position.size);
      }
    }
  }

  @override
  String get name => "SyntheticAsset: ${_assetPositions.entries}";

  @override
  bool operator ==(Object other) =>
      other is SyntheticAsset && this._assetPositions == other._assetPositions;
  int get hashCode => _assetPositions.hashCode;
}

abstract class ExpirableContract extends NamedAsset {
  final Commodity underlying;
  final Commodity money;
  // price at which the exchange is exercised. Quoted in money.
  final double strike;
  // One derivative contract would refer to how many units of the underlying?
  final double contractLot;
  final DateTime expiration;
  // Does this contract refer to a "buy" exchange? This is true
  // for futures & call options, but not for puts (those are sells).
  final bool _isBuy;

  ExpirableContract(
    String name, {
    required this.underlying,
    required this.money,
    required this.strike,
    required this.expiration,
    required bool isBuy,
    this.contractLot = 1,
  })  : _isBuy = isBuy,
        super(name);

  Asset exercise() => SyntheticAsset([
        underlying.position(contractLot * (_isBuy ? 1 : -1)),
        money.position(strike * (_isBuy ? -1 : 1))
      ]);

  @override
  bool operator ==(Object that) {
    if (identical(this, that)) return true;
    if (that is! ExpirableContract) return false;
    return this.name == that.name &&
        this.underlying == that.underlying &&
        this.money == that.money &&
        this.strike == that.strike &&
        this.contractLot == that.contractLot &&
        this.expiration == that.expiration &&
        this._isBuy == that._isBuy;
  }

  @override
  int get hashCode => Object.hash(
      name, underlying, money, strike, contractLot, expiration, _isBuy);
}

class DatedFuture extends ExpirableContract {
  DatedFuture(super.name,
      {required super.underlying,
      required super.money,
      required super.strike,
      required super.expiration,
      super.contractLot})
      : super(isBuy: true);

  // TODO: replace with ReversedFuture wrapper implementation
  // TODO: unused
  DatedFuture get reverse => DatedFuture('Reverse of [$name]',
      underlying: money,
      money: underlying,
      contractLot: 1.0 / contractLot,
      strike: 1.0 / strike,
      expiration: expiration);

  @override
  String toString() =>
      'Future($name,money=$money,underlying=$underlying,strike=$strike)';
}

// Two option types: one with money premium, one with underlying as money?
// Or one type: but helper code to easily model both.
class Option extends ExpirableContract {
  final bool isPut;
  final bool isCall;

  Option(super.name,
      {required super.underlying,
      required super.money,
      required super.strike,
      this.isPut = false,
      this.isCall = false,
      required super.expiration,
      super.contractLot})
      : super(isBuy: isCall) {
    if (isPut == isCall) {
      throw ArgumentError("Exactly one of these should be true: " +
          "isPut: $isPut, isCall: $isCall");
    }
  }

  // TODO: replace with ReversedOption wrapper implementation
  // TODO: unused
  Option get reverse => Option('Reverse of [$name]',
      underlying: money,
      money: underlying,
      contractLot: 1.0 / contractLot,
      strike: 1.0 / strike,
      isPut: !isPut,
      isCall: !isCall,
      expiration: expiration);

  @override
  String toString() => '$name[$money]';
}

// TODO: add enough information to reverse-engineer, i.e. figure out
// exactly where a bid/ask comes from (esp. for SyntheticMarket).
abstract class Market {
  Asset get asset;
  Asset get money;
  double get bidPrice;
  double get bidSize;
  double get askPrice;
  double get askSize;

  Market();

  factory Market.create({
    required Asset asset,
    required Asset money,
    required double bidPrice,
    required double askPrice,
    double bidSize = double.infinity,
    double askSize = double.infinity,
  }) =>
      _DirectMarket(
          asset: asset,
          money: money,
          bidPrice: bidPrice,
          askPrice: askPrice,
          bidSize: bidSize,
          askSize: askSize);
  factory Market.createIdentity(Asset asset) => _IdentityMarket(asset);

  Asset trade({required double size, double slippage = 0.5}) {
    final price = size > 0.0 ? buyPrice(slippage) : sellPrice(slippage);
    return SyntheticAsset(
        [asset.position(size), money.position(-size * price)]);
  }

  double buyPrice([double slippageRatio = 0.5]) =>
      bidPrice + _slippage(slippageRatio);
  double sellPrice([double slippageRatio = 0.5]) =>
      askPrice - _slippage(slippageRatio);
  Position buy({required double size, double slippage = 0.5}) =>
      money.position(-size * buyPrice(slippage));
  Position sell({required double size, double slippage = 0.5}) =>
      money.position(size * sellPrice(slippage));

  double _slippage(double slippageRatio) {
    if (!(slippageRatio >= 0.0 && slippageRatio <= 1.0)) {
      throw ArgumentError(
          'Slippage ratio must be in [0, 1], was: $slippageRatio');
    }
    return (askPrice - bidPrice) * slippageRatio;
  }

  double get midPrice => (bidPrice + askPrice) / 2.0;
  // The spread size (ask - bid) compared to midPrice.
  double get relativeSpread => (askPrice - bidPrice) / midPrice;

  Market get reverse {
    if (this is _InverseMarket) {
      return (this as _InverseMarket)._market;
    }
    return _InverseMarket(this);
  }

  // Given a market A-B, and a B-C, create a market A-C.
  // TODO: maybe a helper to concatenate A-B + A-C
  //       (by first reversing "this"), and also A-B + C-A
  //       (by reverse reversing "that", making them compatible).
  Market concatenate(Market that) {
    return _SyntheticMarket(this, that);
  }
  
  // In case this market is a synthetic one, this would return all the intermediate markets
  // that are required to be combined in order for this market to be offered.
  Iterable<Market> decompose() => [this];

  @override
  String toString() =>
    '$asset/$money, bid: $bidPrice($money), ask: $askPrice($money) ['
      + [asset].followedBy(decompose().map((m) => m.money))
         .map((a) => a.toString()).join("->") + ']';
}

class _DirectMarket extends Market {
  final Asset asset;
  final Asset money;
  final double bidPrice;
  final double bidSize;
  final double askPrice;
  final double askSize;

  _DirectMarket({
    required this.asset,
    required this.money,
    required this.bidPrice,
    required this.askPrice,
    this.bidSize = double.infinity,
    this.askSize = double.infinity,
  }) {
    if (bidPrice > askPrice) {
      throw ArgumentError("Bid price cannot be greater than ask price! $this");
    }
  }
}

class _IdentityMarket extends _DirectMarket {
  _IdentityMarket(Asset asset) : super(
      asset: asset,
      money: asset,
      bidPrice: 1.0,
      askPrice: 1.0,
      bidSize: double.infinity,
      askSize: double.infinity);

  @override
  Iterable<Market> decompose() => [];
}

class _InverseMarket extends Market {
  final Market _market;
  _InverseMarket(this._market);

  @override
  Asset get asset => _market.money;
  Asset get money => _market.asset;
  double get bidPrice => 1.0 / _market.askPrice;
  double get bidSize => _market.askSize / _market.askPrice;
  double get askPrice => 1.0 / _market.bidPrice;
  double get askSize => _market.bidSize / _market.bidPrice;
}

class _SyntheticMarket extends Market {
  final Market _a2bMarket;
  final Market _b2cMarket;
  _SyntheticMarket(Market a2bMarket, Market b2cMarket)
      : _a2bMarket = a2bMarket,
        _b2cMarket = b2cMarket {
    if (_a2bMarket.money != _b2cMarket.asset) {
      throw ArgumentError("The <money> of the first market: $_a2bMarket, " +
          "must be the <asset> of the second market: $_b2cMarket");
    }
    if (_a2bMarket.asset == _b2cMarket.money) {
      throw ArgumentError("The <asset> of the first market: $_a2bMarket, " +
          "cannot also be the <money> of the second market: $_b2cMarket");
    }
  }

  @override
  Asset get asset => _a2bMarket.asset;
  @override
  Asset get money => _b2cMarket.money;

  double get bidPrice => _a2bMarket.bidPrice * _b2cMarket.bidPrice;
  double get bidSize =>
      min(_a2bMarket.bidSize * _a2bMarket.bidPrice, _b2cMarket.bidSize);
  double get askPrice => _a2bMarket.askPrice * _b2cMarket.askPrice;
  double get askSize =>
      min(_a2bMarket.askSize * _a2bMarket.askPrice, _b2cMarket.askSize);
  
  @override
  Iterable<Market> decompose() => _a2bMarket.decompose().followedBy(_b2cMarket.decompose());  
}

class _FutureAndOptions {
  Market? future;
  // strike --> put/call markets
  final Map<double, _PutAndCall> options = SplayTreeMap();
}

class _PutAndCall {
  Market? put;
  Market? call;
  Iterable<Market> get markets sync* {
    if (put != null) yield put!;
    if (call != null) yield call!;
  }
}

class AllMarkets {
  // asset -> money -> corresponding spot Market
  final Map<Asset, Map<Asset, Market>> _markets = HashMap();
  // expiration -> asset -> money --> corresponding future Market
  final Map<DateTime, Map<Commodity, Map<Commodity, _FutureAndOptions>>>
      _expirables = SplayTreeMap();

  AllMarkets.from(Iterable<Market> allAvailableMarkets) {
    for (final market in allAvailableMarkets) {
      // TODO: if we're indexing reverse markets, why not do call-put parity too?
      // I.e. add synthetic calls or puts if they are missing.
      for (final m in [market, market.reverse]) {
        (_markets[m.asset] ??= HashMap())[m.money] = m;
        switch ((m.asset, m.money)) {
          case (DatedFuture future, Commodity money):
            (((_expirables[future.expiration] ??=
                        SplayTreeMap())[future.underlying] ??=
                    SplayTreeMap())[money] ??= _FutureAndOptions())
                .future = m;
            break;
          case (Option option, Commodity money):
            final putAndCall = (((_expirables[option.expiration] ??=
                        SplayTreeMap())[option.underlying] ??=
                    SplayTreeMap())[money] ??= _FutureAndOptions())
                .options[option.strike] ??= _PutAndCall();
            if (option.isCall) {
              putAndCall.call = m;
            } else {
              putAndCall.put = m;
            }
            break;
          default:
          // skip
        }
      }
    }
  }

  Market findBestMarket({required Asset asset, required Commodity money}) {
    Set<Asset> visitedAssets = HashSet();
    SplayTreeSet<Market> candidateMarkets = SplayTreeSet((Market a, Market b) {
      int comparison = a.relativeSpread.compareTo(b.relativeSpread);
      if (comparison != 0) return comparison;
      comparison = a.asset.name.compareTo(b.asset.name);
      if (comparison != 0) return comparison;
      return a.money.name.compareTo(b.money.name);
    });
    candidateMarkets.add(Market.createIdentity(asset));
    while (candidateMarkets.isNotEmpty) {
      final visitingMarket = candidateMarkets.first;
      candidateMarkets.remove(visitingMarket);
      if (visitingMarket.money == money) {
        return visitingMarket;
      }
      visitedAssets.add(visitingMarket.money);

      final Map<Asset, Market>? nextMarkets = _markets[visitingMarket.money];
      if (nextMarkets != null) {
        for (final entry in nextMarkets.entries) {
          final maybeCandidateMarket = entry.value;
          if (!visitedAssets.contains(maybeCandidateMarket.money)) {
            candidateMarkets.add(visitingMarket.concatenate(entry.value));
          }
        }
      }
    }
    throw ArgumentError("Can't create a market from $asset to $money");
  }

// markets.withMoney("USD")
//   .markToMarket(position)
//   .withAsset("BTC")
//     .spot  --> Market
//     .dates[]
//       .future
//       .strikes[]
//         .strike
//         .put()
//         .call()
  MarketsWithMoney withMoney(Commodity money) => MarketsWithMoney(this, money);
}

class MarketsWithMoney {
  final AllMarkets allMarkets;
  final Commodity money;

  MarketsWithMoney(this.allMarkets, this.money);

  Position markToMarket(Asset asset, {double slippage = 0.5}) =>
      Position.merge(asset.decompose().map((position) => allMarkets
          .findBestMarket(asset: position.asset, money: money)
          .sell(size: position.size, slippage: slippage)));

  MarketsWithMoneyAndAsset withAsset(Commodity asset) =>
      MarketsWithMoneyAndAsset(allMarkets, asset: asset, money: money);
}

class MarketsWithMoneyAndAsset {
  final AllMarkets allMarkets;
  final Commodity asset;
  final Commodity money;
  final Market spot;

  MarketsWithMoneyAndAsset(this.allMarkets,
      {required this.asset, required this.money})
      : spot = allMarkets.findBestMarket(asset: asset, money: money);

  // TODO: add methods to this list?
  // UnmodifiableListView
  List<ExpirationsAccessor> get dates => throw ArgumentError("implement");
}

abstract class ExpirationsAccessor {
  Market get future;
  // TODO: add methods to this list? E.g. atm()?
  // UnmodifiableListView
  List<StrikeAccessor> get strikes;
}

abstract class StrikeAccessor {
  double get strike;
  Market get put;
  Market get call;
}

void main() async {
  final instruments =
      parseDeribitInstruments(await fetchDeribitInstruments("BTC"));

  List<Market> markets = instruments.map((i) => i.toMarket()).nonNulls.toList();

  final money = Commodity("BTC");
  final allMarkets = AllMarkets.from(markets);
//   print("SPOT MARKETS");
//   for (final byAsset in allMarkets._markets.entries) {
//     if (byAsset.key is! Commodity) continue;
//     for (final spotMarket in byAsset.value.values) {
//       if (spotMarket.money is! Commodity) continue;
//       print(spotMarket);
//       if (spotMarket.asset == money) continue;
//       print("   ==> ${spotMarket.asset} " +
//           allMarkets
//               .withMoney(money)
//               .markToMarket(spotMarket.asset, slippage: 0.5)
//               .toString());
//     }
//   }
//   print("EXPIRABLES");
//   for (final e1 in allMarkets._expirables.entries) {
//     print("  DATE: ${e1.key}");
//     for (final e2 in e1.value.entries) {
//       final asset = e2.key;
//       for (final e3 in e2.value.entries) {
//         final money = e3.key;
//         print("    markets for: asset: $asset, money: $money");
//         final futureAndOptions = e3.value;
//         print(
//             "      future: ${futureAndOptions.future} with money: ${futureAndOptions.future?.asset}");
//         print("      options:");
//         for (final strike in futureAndOptions.options.entries) {
//           print(
//               "        strike: ${strike.key}, put: ${strike.value.put}, call: ${strike.value.call}");
//           for (Market m in strike.value.markets) {
//             Option o = m.asset as Option;
//             final type = o.isPut ? "put" : "call";
//             print("Exercise $type: ${o.exercise()}");
// //             print("   ==> " + allMarkets.withMoney(money).markToMarket(o, slippage: 0.5).toString());
//           }
//         }
//       }
//     }
//   }

  print("======================");
  print(allMarkets._markets[Commodity("ETH")]![Commodity("BTC")]!);
  print(allMarkets._markets[Commodity("BTC")]![Commodity("ETH")]!);
  print(allMarkets.withMoney(Commodity("ETH")).withAsset(Commodity("BTC")).spot);
  print(allMarkets.withMoney(Commodity("USDT")).withAsset(Commodity("BTC")).spot);

  print(allMarkets.withMoney(Commodity("USDC")).withAsset(Commodity("ETH")).spot);
  print(allMarkets.withMoney(Commodity("ETH")).withAsset(Commodity("USDC")).spot);
}

class DeribitInstrument {
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

  DeribitInstrument(
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

  static Iterable<DeribitInstrument> implicitUsdInstruments(
      List<String> stableCoins) sync* {
    for (String stableCoin in stableCoins) {
      yield DeribitInstrument(
          instrument_name: "$stableCoin\_USD",
          base_currency: stableCoin,
          quote_currency: "USD",
          mark_price: 1.0,
          bid_price: 1.0,
          ask_price: 1.0);
    }
  }

  static DeribitInstrument? fromJson(Map<String, dynamic> data) =>
      DeribitInstrument(
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
      'instrument_name: $instrument_name,' +
      'base_currency: $base_currency,' +
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

  // BTC-22NOV24-85000-P
  static final RegExp _instrumentRegex =
      // ASSET[-STRAT][-DATES][-STRIKES][-P|C]
      RegExp(
          r"^([\w_]+)(?:-([\w_]+))??(?:-((?:\d+[A-Z]+\d+)|_)+)?(?:-([\d_]+))?(?:-(P|C))?$");

  // 29NOV2024
  static final RegExp _dateRegex = RegExp(r"^(\d+)(\w*?)(\d+)$");

  static final Map<String, int> _monthToNum = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  DateTime _parseDate(String dateStr) {
    Match dateMatch = _dateRegex.firstMatch(dateStr)!;
    final dd = int.parse(dateMatch.group(1)!);
    final mmm = dateMatch.group(2)!;
    final yy = int.parse(dateMatch.group(3)!);
    return DateTime.utc(2000 + yy, _monthToNum[mmm]!, dd);
  }

  Market? toMarket({void Function(String)? errorListener}) {
    final errorsSink = errorListener ?? (error) {};
    // TODO: produced assets might want a reference to this DeribitInstrument
    if (bid_price == null || ask_price == null) {
      errorsSink("No bid or no ask");
      // TODO: can use markPrice +- defaultSlippage
      return null;
    }
    // Only the underlying & the money are registered in the registry.
    final underlying = Commodity(base_currency);
    final money = Commodity(quote_currency);
    final makeMarket = (Asset asset) => Market.create(
        asset: asset, money: money, bidPrice: bid_price!, askPrice: ask_price!);

    Match? match = _instrumentRegex.firstMatch(instrument_name);
    if (match == null) {
      errorsSink("UNPROCESSED: $instrument_name");
      return null;
    }
    final String? strat = match.group(2);
    if (strat != null) {
      // A custom strategy or a perpetual; ignore.
      errorsSink("Ignoring strat: $instrument_name");
      return null;
    }
    final String? dates = match.group(3);
    if (dates == null) {
      // Spot market.
      return makeMarket(underlying);
    }
    final String assetNames = match.group(1)!;
    final assetsList = assetNames.split('_');
    if (assetsList.length != 1) {
      errorsSink("Multiple assets: $assetsList");
      return null;
    }
    final datesList = dates.split('_');
    if (datesList.length != 1) {
      errorsSink("Multiple dates: $datesList");
      return null;
    }
    final expirationDate = _parseDate(datesList.first);

    final String? strikes = match.group(4);
    final String? optionType = match.group(5);
    if (strikes == null) {
      // A dated future.
      if (optionType != null) {
        errorsSink("A dated future with an option type?!");
        return null;
      }
      return makeMarket(DatedFuture(instrument_name,
          underlying: underlying,
          money: money,
          strike: mark_price,
          expiration: expirationDate,
          contractLot: 1.0));
    }
    final strikesList = strikes.split('_');
    if (strikesList.length != 1) {
      errorsSink("An option with multiple strikes");
      return null;
    }
    final strike = double.parse(strikesList.first);

    if (optionType == null) {
      errorsSink("An option without a type");
      return null;
    }
    final bool isPut = optionType == "P";
    final bool isCall = optionType == "C";
    return makeMarket(Option(instrument_name,
        underlying: underlying,
        // All deribit strikes refer to USD!
        money: Commodity("USD"),
        strike: strike,
        isPut: isPut,
        isCall: isCall,
        expiration: expirationDate,
        contractLot: 1.0));
  }
}

List<DeribitInstrument> parseDeribitInstruments(String deribitInstrumentsJson) {
//   String url = 'https://www.deribit.com/api/v2/public/get_instrument?instrument_name=BTC-31MAY24-92000-C';
  // Access data using key-value pairs
  final data = json.decode(deribitInstrumentsJson) as Map<String, dynamic>;
  final rawInstruments = (data["result"] as List<dynamic>);
  return rawInstruments
      .map((rawInstrument) => DeribitInstrument.fromJson(rawInstrument))
      .where((instrument) => instrument != null)
      .cast<DeribitInstrument>()
      .followedBy(DeribitInstrument.implicitUsdInstruments(["USDC", "USDT"]))
      .toList();
}

Future<String> fetchDeribitInstruments(String underlying) async {
  String url =
      'https://www.deribit.com/api/v2/public/get_book_summary_by_currency?currency=$underlying';
  // Fetch data from server if not cached or cache is stale
  final response = await get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response.body;
  } else {
    // Handle error
    throw Exception('Failed to load data from $url');
  }
}
