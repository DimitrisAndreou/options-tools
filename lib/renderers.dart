import 'assets.dart';

abstract class AssetRenderer {
  String render(Asset asset);

  factory AssetRenderer.deribit() = _DeribitAssetRenderer;
  factory AssetRenderer.optionStrat() = _OptionStratAssetRenderer;

  static AssetRenderer? forVenue(Venue venue) {
    switch (venue) {
      case Venue.Deribit:
        return AssetRenderer.deribit();
      case Venue.OptionStrat:
        return AssetRenderer.optionStrat();
    }
  }

  static String? tryRenderFirst(Asset asset) {
    for (final venue in asset.venues) {
      final renderer = forVenue(venue);
      if (renderer != null) {
        try {
          return renderer.render(asset);
        } catch (_) {
          // Ignore and try next venue if render fails
        }
      }
    }
    return null;
  }
}

class _OptionStratAssetRenderer implements AssetRenderer {
  @override
  String render(Asset asset) {
    if (!asset.venues.contains(Venue.OptionStrat)) {
      throw ArgumentError('Asset does not support OptionStrat venue: $asset');
    }

    if (asset is Commodity || asset is Option) {
      return 'https://finance.yahoo.com/quote/${asset.name}/';
    }
    throw ArgumentError('Asset must be a Commodity or an Option: $asset');
  }
}

class _DeribitAssetRenderer implements AssetRenderer {
  @override
  String render(Asset asset) {
    if (!asset.venues.contains(Venue.Deribit)) {
      throw ArgumentError('Asset does not support Deribit venue: $asset');
    }

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
    throw ArgumentError(
        'Asset must be a Commodity, DatedFuture or an Option: $asset');
  }
}

abstract class PositionRenderer {
  String render(Position position);

  factory PositionRenderer.optionStrat() = _OptionStratPositionRenderer;

  static PositionRenderer? forVenue(Venue venue) {
    switch (venue) {
      case Venue.OptionStrat:
        return PositionRenderer.optionStrat();
      case Venue.Deribit:
        return null;
    }
  }

  static String? tryRenderFirst(Position position) {
    final venues = position.decompose().expand((l) => l.asset.venues).toSet();
    for (final venue in venues) {
      final renderer = forVenue(venue);
      if (renderer != null) {
        try {
          return renderer.render(position);
        } catch (_) {
          // Ignore and try next venue if render fails
        }
      }
    }
    return null;
  }
}

class _OptionStratPositionRenderer implements PositionRenderer {
  String _formatOptionStratName(String name) {
    final match = RegExp(r'^(.*[CP])(\d{8})$').firstMatch(name);
    if (match != null) {
      final prefix = match.group(1)!;
      final strikeInt = int.parse(match.group(2)!);
      final strike = strikeInt / 1000.0;
      final strikeStr = strike == strike.truncate()
          ? strike.toInt().toString()
          : strike.toString();
      return '$prefix$strikeStr';
    }
    return name;
  }

  static String _formatPrice(double val) {
    if ((val - val.roundToDouble()).abs() < 1e-6) {
      return val.round().toString();
    }
    final str = val.toStringAsFixed(4);
    return str.replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  String render(Position position) {
    final validLines = <Line>[];
    String? underlyingName;

    for (final line in position.decompose()) {
      if (!line.asset.venues.contains(Venue.OptionStrat)) {
        continue;
      }

      String currentUnderlying;
      if (line.asset is Commodity) {
        currentUnderlying = line.asset.name;
      } else if (line.asset is Option) {
        currentUnderlying = (line.asset as Option).underlying.name;
      } else {
        throw ArgumentError(
            'Asset must be a Commodity or Option: ${line.asset}');
      }

      if (underlyingName == null) {
        underlyingName = currentUnderlying;
      } else if (underlyingName != currentUnderlying) {
        throw ArgumentError(
            'Position contains multiple underlyings: $underlyingName and $currentUnderlying');
      }

      validLines.add(line);
    }

    if (underlyingName == null || validLines.isEmpty) {
      throw ArgumentError('No valid OptionStrat assets found in position.');
    }

    final commodityLines =
        validLines.where((l) => l.asset is Commodity).toList();
    final optionLines = validLines.where((l) => l.asset is Option).toList();

    final isCoveredCall = validLines.length == 2 &&
        commodityLines.length == 1 &&
        commodityLines.single.size > 0 &&
        optionLines.length == 1 &&
        (optionLines.single.asset as Option).isCall &&
        optionLines.single.size < 0;

    if (isCoveredCall) {
      final c = commodityLines.single;
      final o = optionLines.single;
      final option = o.asset as Option;
      final shares = c.size.round();
      final price = c.unitCostBasis?.size;
      final priceSuffix = price != null ? '@${_formatPrice(price)}' : '';
      final stockLeg = '${c.asset.name}x$shares$priceSuffix';

      final optionName = _formatOptionStratName(o.asset.name);
      final oSize = o.size.round();
      final oPrefix = switch (oSize) {
        1 => '.',
        -1 => '-.',
        _ => '$oSize.'
      };
      final oPrice = o.unitCostBasis?.size;
      final lot = option.contractLot > 0 ? option.contractLot : 1.0;
      final oPricePerShare = oPrice != null ? oPrice / lot : null;
      final oPriceSuffix =
          oPricePerShare != null ? '@${_formatPrice(oPricePerShare)}' : '';
      final optionLeg = '$oPrefix$optionName$oPriceSuffix';

      return 'https://optionstrat.com/build/covered-call/$underlyingName/$stockLeg,$optionLeg';
    }

    final parts = <String>[];
    for (final line in validLines) {
      final sizeStr = line.size.round().toString();
      if (line.asset is Commodity) {
        final costBasis = line.unitCostBasis?.size;
        final costBasisStr =
            costBasis != null ? '@${_formatPrice(costBasis)}' : '';
        parts.add('${line.asset.name}x$sizeStr$costBasisStr');
      } else if (line.asset is Option) {
        final option = line.asset as Option;
        final optionName = _formatOptionStratName(line.asset.name);
        final size = line.size.round();
        final prefix = switch (size) {
          1 => '.',
          -1 => '-.',
          _ => '$size.'
        };
        final costBasis = line.unitCostBasis?.size;
        final lot = option.contractLot > 0 ? option.contractLot : 1.0;
        final costBasisPerShare =
            costBasis != null ? costBasis / lot : null;
        final costBasisStr =
            costBasisPerShare != null ? '@${_formatPrice(costBasisPerShare)}' : '';
        parts.add('$prefix$optionName$costBasisStr');
      }
    }

    return 'https://optionstrat.com/build/custom/$underlyingName/${parts.join(',')}';
  }
}
