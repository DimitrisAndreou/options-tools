import 'dart:math';
import '../position_analyzer.dart';

class PayoffSvgRenderer {
  /// Renders a PositionAnalyzer's PnL curve to a standalone SVG string.
  static String render(
    PositionAnalyzer analyzer, {
    double? minPrice,
    double? maxPrice,
    String title = 'Position PnL at Expiration',
    int width = 750,
    int height = 420,
    bool darkMode = true,
  }) {
    // 1. Determine Price Range
    final breakevens = analyzer.breakevens.toList();
    final strikes = <double>[];
    for (final line in analyzer.position.decompose()) {
      if (line.asset.isOption) {
        strikes.add(line.asset.toOption.strike);
      }
    }

    double lowP = minPrice ??
        (strikes.isNotEmpty
            ? strikes.reduce(min) * 0.8
            : (breakevens.isNotEmpty ? breakevens.first.fromPrice * 0.8 : 80.0));
    double highP = maxPrice ??
        (strikes.isNotEmpty
            ? strikes.reduce(max) * 1.2
            : (breakevens.isNotEmpty ? breakevens.last.toPrice * 1.2 : 120.0));

    if (lowP >= highP) {
      lowP = 0.0;
      highP = 200.0;
    }

    // 2. Sample Points
    final int sampleCount = 200;
    final List<Point<double>> points = [];
    final double step = (highP - lowP) / sampleCount;

    // Collect all interesting points to ensure exact sharp corners
    final Set<double> xVals = {};
    for (int i = 0; i <= sampleCount; i++) {
      xVals.add(lowP + step * i);
    }
    xVals.addAll(strikes);
    for (final be in breakevens) {
      xVals.add(be.fromPrice);
      xVals.add(be.toPrice);
    }

    final sortedXVals = xVals.where((x) => x >= lowP && x <= highP).toList()..sort();

    double minPnl = 0.0;
    double maxPnl = 0.0;

    for (final x in sortedXVals) {
      final y = analyzer.valueAt(x);
      points.add(Point(x, y));
      if (y < minPnl) minPnl = y;
      if (y > maxPnl) maxPnl = y;
    }

    // Give Y axis some breathing margin
    double pnlRange = maxPnl - minPnl;
    if (pnlRange == 0) pnlRange = 100;
    final double yMin = minPnl - pnlRange * 0.15;
    final double yMax = maxPnl + pnlRange * 0.15;

    // Margins inside SVG canvas
    final double marginLeft = 70;
    final double marginRight = 30;
    final double marginTop = 50;
    final double marginBottom = 50;

    final double graphWidth = width - marginLeft - marginRight;
    final double graphHeight = height - marginTop - marginBottom;

    // Coordinate mapping functions
    double mapX(double price) =>
        marginLeft + ((price - lowP) / (highP - lowP)) * graphWidth;

    double mapY(double pnl) =>
        marginTop + graphHeight - ((pnl - yMin) / (yMax - yMin)) * graphHeight;

    final zeroY = mapY(0.0);

    // Color Palette
    final bgFill = darkMode ? '#181825' : '#ffffff';
    final cardBg = darkMode ? '#1e1e2e' : '#f8f9fa';
    final textMain = darkMode ? '#cdd6f4' : '#1e1e2e';
    final textMuted = darkMode ? '#a6adc8' : '#6c757d';
    final gridColor = darkMode ? '#313244' : '#e9ecef';
    final lineZero = darkMode ? '#585b70' : '#adb5bd';
    final pnlStroke = darkMode ? '#89b4fa' : '#0d6efd';
    final profitFill = darkMode ? 'rgba(166, 227, 161, 0.25)' : 'rgba(40, 167, 69, 0.2)';
    final lossFill = darkMode ? 'rgba(243, 139, 168, 0.25)' : 'rgba(220, 53, 69, 0.2)';
    final breakevenLine = darkMode ? '#f9e2af' : '#fd7e14';

    final svg = StringBuffer();

    svg.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" width="100%" height="100%" style="background:$bgFill; font-family: system-ui, -apple-system, sans-serif;">');
    
    // Background rect
    svg.writeln('  <rect width="$width" height="$height" fill="$bgFill" rx="12" />');
    svg.writeln('  <rect x="${marginLeft - 10}" y="${marginTop - 10}" width="${graphWidth + 20}" height="${graphHeight + 20}" fill="$cardBg" rx="8" />');

    // Grid lines (X & Y)
    // Horizontal Zero line
    svg.writeln('  <!-- Zero line -->');
    svg.writeln('  <line x1="$marginLeft" y1="$zeroY" x2="${marginLeft + graphWidth}" y2="$zeroY" stroke="$lineZero" stroke-width="1.5" stroke-dasharray="4,4" />');

    // Horizontal Y Ticks
    final yTickCount = 5;
    for (int i = 0; i <= yTickCount; i++) {
      final pnlVal = yMin + (yMax - yMin) * (i / yTickCount);
      final yPos = mapY(pnlVal);
      if ((yPos - zeroY).abs() > 10) {
        svg.writeln('  <line x1="$marginLeft" y1="$yPos" x2="${marginLeft + graphWidth}" y2="$yPos" stroke="$gridColor" stroke-width="1" />');
      }
      final pnlLabel = '\$${pnlVal.toStringAsFixed(0)}';
      svg.writeln('  <text x="${marginLeft - 8}" y="${yPos + 4}" fill="$textMuted" font-size="11" text-anchor="end">$pnlLabel</text>');
    }

    // Vertical X Ticks
    final xTickCount = 6;
    for (int i = 0; i <= xTickCount; i++) {
      final priceVal = lowP + (highP - lowP) * (i / xTickCount);
      final xPos = mapX(priceVal);
      svg.writeln('  <line x1="$xPos" y1="$marginTop" x2="$xPos" y2="${marginTop + graphHeight}" stroke="$gridColor" stroke-width="1" />');
      svg.writeln('  <text x="$xPos" y="${marginTop + graphHeight + 20}" fill="$textMuted" font-size="11" text-anchor="middle">\$${priceVal.toStringAsFixed(0)}</text>');
    }

    // Profit & Loss Shading Polygons
    // Split points into segments above zero and below zero for distinct fill colors
    svg.writeln('  <!-- Shading -->');
    final pathPoints = points.map((p) => '${mapX(p.x).toStringAsFixed(1)},${mapY(p.y).toStringAsFixed(1)}').join(' ');
    
    // Profit polygon (clipped to zeroY and above)
    final profitPath = StringBuffer();
    profitPath.write('M ${mapX(points.first.x).toStringAsFixed(1)} $zeroY ');
    for (final p in points) {
      final x = mapX(p.x).toStringAsFixed(1);
      final y = mapY(max(p.y, 0.0)).toStringAsFixed(1);
      profitPath.write('L $x $y ');
    }
    profitPath.write('L ${mapX(points.last.x).toStringAsFixed(1)} $zeroY Z');
    svg.writeln('  <path d="${profitPath.toString()}" fill="$profitFill" />');

    // Loss polygon (clipped to zeroY and below)
    final lossPath = StringBuffer();
    lossPath.write('M ${mapX(points.first.x).toStringAsFixed(1)} $zeroY ');
    for (final p in points) {
      final x = mapX(p.x).toStringAsFixed(1);
      final y = mapY(min(p.y, 0.0)).toStringAsFixed(1);
      lossPath.write('L $x $y ');
    }
    lossPath.write('L ${mapX(points.last.x).toStringAsFixed(1)} $zeroY Z');
    svg.writeln('  <path d="${lossPath.toString()}" fill="$lossFill" />');

    // Main PnL Line
    svg.writeln('  <!-- Main PnL Line -->');
    svg.writeln('  <polyline points="$pathPoints" fill="none" stroke="$pnlStroke" stroke-width="3" stroke-linejoin="round" />');

    // Strike lines
    for (final strike in strikes) {
      if (strike >= lowP && strike <= highP) {
        final sx = mapX(strike);
        svg.writeln('  <line x1="$sx" y1="$marginTop" x2="$sx" y2="${marginTop + graphHeight}" stroke="$textMuted" stroke-width="1" stroke-dasharray="2,2" />');
        svg.writeln('  <text x="$sx" y="${marginTop - 6}" fill="$textMuted" font-size="10" text-anchor="middle">K=\$${strike.toStringAsFixed(0)}</text>');
      }
    }

    // Breakeven Markers
    for (final be in breakevens) {
      if (!be.isPoint) continue;
      final bx = mapX(be.fromPrice);
      if (bx >= marginLeft && bx <= marginLeft + graphWidth) {
        svg.writeln('  <!-- Breakeven $be -->');
        svg.writeln('  <line x1="$bx" y1="$marginTop" x2="$bx" y2="${marginTop + graphHeight}" stroke="$breakevenLine" stroke-width="2" stroke-dasharray="4,2" />');
        svg.writeln('  <circle cx="$bx" cy="$zeroY" r="4" fill="$breakevenLine" />');
        svg.writeln('  <rect x="${bx - 35}" y="${zeroY - 22}" width="70" height="16" fill="$bgFill" rx="3" stroke="$breakevenLine" stroke-width="1" />');
        svg.writeln('  <text x="$bx" y="${zeroY - 10}" fill="$breakevenLine" font-size="10" font-weight="bold" text-anchor="middle">BE: \$${be.fromPrice.toStringAsFixed(1)}</text>');
      }
    }

    // Title & Axis Labels
    svg.writeln('  <!-- Title & Axis Labels -->');
    svg.writeln('  <text x="${marginLeft}" y="28" fill="$textMain" font-size="16" font-weight="bold">$title</text>');
    svg.writeln('  <text x="${width / 2}" y="${height - 10}" fill="$textMuted" font-size="12" text-anchor="middle">Underlying Price (\$) at Expiration</text>');
    svg.writeln('  <text x="18" y="${height / 2}" fill="$textMuted" font-size="12" text-anchor="middle" transform="rotate(-90 18 ${height / 2})">PnL (\$)</text>');

    svg.writeln('</svg>');
    return svg.toString();
  }
}
