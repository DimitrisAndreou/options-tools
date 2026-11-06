const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const unsignedPercentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'never',
});

const dollarFmt = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 2
});

// TODO: Digits of rounding should depend on the underlying.
const underlyingFmt = new Intl.NumberFormat('en-US', {
  style: 'decimal',
  minimumFractionDigits: 3,
  maximumFractionDigits: 3
});

const priceFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const tooltipStyle = {
  confine: true,
  enterable: true,
  textStyle: {
    color: '#f8fafc',
    fontFamily: 'Inter, sans-serif'
  },
  backgroundColor: '#1e293b',
  borderColor: '#fcd34d',
  borderWidth: 1,
  padding: 0, // Template handles padding
  shadowBlur: 10,
  shadowColor: 'rgba(0,0,0,0.5)'
};

const selectionHighlightSeries = {
  id: 'selectionHighlight',
  type: 'scatter',
  datasetId: 'highlightDataset',
  symbol: 'circle',
  symbolSize: 80,
  itemStyle: {
    color: 'transparent',
    borderColor: 'rgba(255, 255, 255, 1.0)',
    borderWidth: 4,
    borderType: 'dashed'
  },
  silent: true,
  z: 10
};

const axisTitleNameTextStyle = {
  color: '#fcd34d',
  fontFamily: 'Inter',
  fontWeight: 'bold',
  fontSize: 15
};

const yAxisTitleNameTextStyle = {
  ...axisTitleNameTextStyle,
  align: 'left',
};

const axisXValuesNameTextStyle = {
  color: '#94a3b8',
  fontFamily: 'Roboto Mono',
  fontSize: 12,
};

const axisYValuesNameTextStyle = {
  color: '#94a3b8',
  fontFamily: 'Roboto Mono',
  fontSize: 12,
};

const axisLine = {
  lineStyle: {
    color: '#334155'
  }
};

const grid = {
  left: '5%',
  right: '10%',
  top: '10%',
  bottom: '15%',
  containLabel: true
};

const legend = {
  show: true,
  type: 'scroll',        // Keeps it scrollable if too long
  orient: 'horizontal',
  top: 'bottom',
  textStyle: {
    color: 'yellow',
    fontFamily: 'monospace',
    fontSize: 12
  },
  pageIconColor: 'yellow',
  pageTextStyle: {
    color: 'yellow'
  },
  width: '75%',
};

function formatYieldAsPercent(theYield) {
  const val = (theYield - 1.0) * 100;
  return (val >= 0 ? '+' : '') + val.toFixed(2) + '%';
}
function formatYieldAsClass(theYield) {
  return theYield >= 1.0 ? 'text-good' : 'text-bad';
}

function formatPnL(current, entry, formatter, pctSuffix = '', absSuffix = '') {
  const diff = current - entry;
  const pct = entry > 0 ? (diff / entry) * 100 : 0;
  const sign = diff >= 0 ? '+' : '';
  const pctSuffixStr = pctSuffix ? ' ' + pctSuffix : '';
  const absSuffixStr = absSuffix ? ' ' + absSuffix : '';
  return {
    pct: sign + pct.toFixed(1) + '%' + pctSuffixStr,
    abs: sign + formatter(diff) + absSuffixStr,
    className: diff >= 0 ? 'text-good' : 'text-bad'
  };
}

function formatDaysDiff(entryDTE, currentDTE) {
  const diffDte = entryDTE - currentDTE;
  const pctDte = entryDTE > 0 ? (diffDte / entryDTE) * 100 : 0;
  const sign = diffDte >= 0 ? '+' : '';
  const pctSign = pctDte >= 0 ? '+' : '';
  return `${sign}${diffDte} days (${pctSign}${pctDte.toFixed(2)}%)`;
}

function formatExistingCostBasisHtml(costBasis, avgPrice, spotPrice) {
  if (costBasis == null || avgPrice == null || !(avgPrice > 0)) return '—';
  const costBasisStr = dollarFmt.format(costBasis);
  if (!Number.isFinite(spotPrice)) {
    return `<span class="text-neutral text-nowrap">${costBasisStr}</span>`;
  }
  const spotValue = costBasis * (spotPrice / avgPrice);
  const diff = spotValue - costBasis;
  const pct = diff / costBasis;
  const pctStr = percentFmt.format(pct);
  if (diff < 0) {
    const lossAmt = dollarFmt.format(Math.abs(diff));
    return `<span class="text-neutral text-nowrap">${costBasisStr}</span><br/><small class="text-bad text-nowrap">${lossAmt} (${pctStr}) loss</small>`;
  } else if (diff > 0) {
    const profitAmt = dollarFmt.format(diff);
    return `<span class="text-neutral text-nowrap">${costBasisStr}</span><br/><small class="text-good text-nowrap">${profitAmt} (${pctStr}) profit</small>`;
  } else {
    return `<span class="text-neutral text-nowrap">${costBasisStr}</span><br/><small class="text-neutral-alt text-nowrap">$0.00 (0.0%)</small>`;
  }
}
