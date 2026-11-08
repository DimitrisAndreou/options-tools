import 'assets.dart';

abstract class AssetRenderer {
  String render(Asset asset);

  factory AssetRenderer.deribit() = _DeribitAssetRenderer;
  factory AssetRenderer.optionStrat() = _YFinanceAssetRenderer;
  factory AssetRenderer.yfinance() = _YFinanceAssetRenderer;

  static AssetRenderer? forSource(DataSource source) {
    if (source == DataSource.deribit) {
      return AssetRenderer.deribit();
    } else if (source == DataSource.yfinance) {
      return AssetRenderer.yfinance();
    }
    return null;
  }

  static String? tryRenderFirst(Asset asset) => asset.url;
}

class _YFinanceAssetRenderer implements AssetRenderer {
  @override
  String render(Asset asset) {
    if (asset.source != DataSource.yfinance) {
      throw ArgumentError('Asset does not support YFinance/OptionStrat source: $asset');
    }

    final url = DataSource.yfinance.assetUrl(asset);
    if (url != null) {
      return url;
    }
    throw ArgumentError('Asset must be a Commodity or an Option: $asset');
  }
}

class _DeribitAssetRenderer implements AssetRenderer {
  @override
  String render(Asset asset) {
    if (asset.source != DataSource.deribit) {
      throw ArgumentError('Asset does not support Deribit source: $asset');
    }

    final url = DataSource.deribit.assetUrl(asset);
    if (url != null) {
      return url;
    }
    throw ArgumentError(
        'Asset must be a Commodity, DatedFuture or an Option: $asset');
  }
}

abstract class PositionRenderer {
  String render(Position position);

  factory PositionRenderer.optionStrat() = _OptionStratPositionRenderer;

  static PositionRenderer? forSource(DataSource source) {
    if (source == DataSource.yfinance) {
      return PositionRenderer.optionStrat();
    }
    return null;
  }

  static String? tryRenderFirst(Position position) {
    for (final line in position.decompose()) {
      final source = line.asset.source;
      if (source != null) {
        final url = source.strategyUrl(position);
        if (url != null) return url;
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
      if (line.asset.source != DataSource.yfinance) {
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
