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
