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

function formatSignedDollar(val) {
  const v = val === 0 ? 0 : val;
  return `${v >= 0 ? '+' : ''}${dollarFmt.format(v)}`;
}

function formatExistingDollarHtml(amount) {
  if (amount == null || !Number.isFinite(Number(amount))) return '—';
  return `<span class="text-neutral text-nowrap">${dollarFmt.format(Number(amount))}</span>`;
}

function formatExistingUnrealizedPnlHtml(pnl, totalYield) {
  const pnlVal = Number(pnl);
  const yieldVal = Number(totalYield);
  if (!Number.isFinite(pnlVal) || !Number.isFinite(yieldVal)) return '—';
  if (pnlVal === 0) {
    return '<span class="text-neutral-alt text-nowrap">0.0%</span> <small class="text-neutral-alt text-nowrap">($0.00)</small>';
  }
  const pctStr = percentFmt.format(yieldVal - 1.0);
  const pnlStr = formatSignedDollar(pnlVal);
  const cls = pnlVal > 0 ? 'text-good' : 'text-bad';
  const altCls = pnlVal > 0 ? 'text-good-alt' : 'text-bad';
  return `<span class="${cls} text-nowrap">${pctStr}</span> <small class="${altCls} text-nowrap">(${pnlStr})</small>`;
}

function formatExistingTaxImpactHtml(preTax, postTax) {
  if (!preTax || !postTax) return null;
  const prePnl = Number(preTax.pnl);
  const preYield = Number(preTax.yield);
  const postPnl = Number(postTax.pnl);
  const postYield = Number(postTax.yield);
  if (
    !Number.isFinite(prePnl) || !Number.isFinite(preYield) ||
    !Number.isFinite(postPnl) || !Number.isFinite(postYield)
  ) {
    return null;
  }
  const absImpact = postPnl - prePnl;
  const impactCls = absImpact > 0 ? 'text-good' : (absImpact < 0 ? 'text-bad' : 'text-muted-alt');
  if (preYield > 0) {
    const relImpact = postYield / preYield - 1.0;
    return `<span class="${impactCls} text-nowrap">${percentFmt.format(relImpact)}</span> <small class="${impactCls} text-nowrap">(${formatSignedDollar(absImpact)})</small>`;
  }
  return `<span class="${impactCls} text-nowrap">${formatSignedDollar(absImpact)}</span>`;
}

const _OCC_OPTION_REGEX = /^([A-Za-z0-9.^_-]+?)(\d{2})(\d{2})(\d{2})([CP])(\d{8})$/;
const _OCC_MONTH_NAMES = [
  '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
];

function formatOptionName(name) {
  if (!name || typeof name !== 'string') return name;
  const m = _OCC_OPTION_REGEX.exec(name.trim());
  if (!m) return name;
  const ticker = m[1];
  const yy = m[2];
  const mm = parseInt(m[3], 10);
  const dd = parseInt(m[4], 10);
  const cp = m[5];
  const strikeVal = parseInt(m[6], 10) / 1000.0;
  const monthStr = _OCC_MONTH_NAMES[mm] || m[3];
  const strikeStr = Number.isInteger(strikeVal)
    ? String(strikeVal)
    : String(strikeVal);
  return `${ticker}-${dd}${monthStr}${yy}-${strikeStr}-${cp}`;
}
