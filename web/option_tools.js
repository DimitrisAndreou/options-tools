const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
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
  position: 'top',
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

/**
 * Prepares and formats the raw data for display.
 */
function prepareCCData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    underlying,
    money,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeAbsolute / value.spotPrice - 1.0),
    callName: value.call,
    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.underlyingToBuy)} ${underlying}`,

    // Yields
    moneyYield: percentFmt.format(value.moneyYield - 1.0),
    moneyProfit: `${dollarFmt.format(value.moneyProfit)}`,
    underlyingYield: percentFmt.format(value.underlyingYield - 1.0),
    underlyingProfit: `${underlyingFmt.format(value.premiumToReceive)} ${underlying}`,

    // Breakeven / Caps
    beAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyAbsolute),
    beRelative: percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0),
    capAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute),
    capRelative: percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0),

    // Instructions
    buyAmount: `${underlyingFmt.format(value.underlyingToBuy)} ${underlying}`,
    buyCost: dollarFmt.format(-value.moneySize),
    sellAmount: `${-value.callSize} call(s)`,
    sellPremium: `${underlyingFmt.format(value.premiumToReceive)} ${underlying}`
  };
}

// Semantic color helpers for a premium look
const fmtStyle = {
  label: (str) => `<span class="text-label">${str}</span>`,
  neutral: (str) => `<span class="text-neutral">${str}</span>`,
  good: (str) => `<span class="text-good">${str}</span>`,
  bad: (str) => `<span class="text-bad">${str}</span>`,
  header: (str) => `<div class="strategy-header"><i class="fas fa-cube me-2"></i> ${str}</div>`
};

function renderDetailedCC(d) {
  return `
    ${fmtStyle.header(`Strategy: Covered Call on&nbsp;${fmtStyle.neutral(d.underlying)}`)}
    
    <table class="strategy-table">
      <tr><td>${fmtStyle.label('Expiration')}</td><td class="text-end">${fmtStyle.neutral(d.formattedDate)} <small>${fmtStyle.bad('(' + d.DTE + 'd)')}</small></td></tr>
      <tr><td>${fmtStyle.label('Strike Price')}</td><td class="text-end">${fmtStyle.neutral(d.strikeAbsolute)}</td></tr>
      <tr><td>${fmtStyle.label('Contract')}</td><td class="text-end contract-name">${fmtStyle.neutral(d.callName)}</td></tr>
      <tr><td>${fmtStyle.label('Capital Required')}</td><td class="text-end">${fmtStyle.neutral(d.capitalRequired)} <small class="text-muted-alt">(${fmtStyle.neutral(d.capitalRequiredUnderlying)})</small></td></tr>
    </table>

    <div class="outcomes-panel">
      <div class="outcomes-header">Outcomes at Expiration:</div>
      <div class="outcome-row">
        <span>If Price &ge; ${d.strikeAbsolute}:</span>
        <span>${fmtStyle.good(d.moneyYield)} ${fmtStyle.good(d.money)} <small class="text-good-alt">(+${d.moneyProfit})</small></span>
      </div>
      <div class="outcome-row mb-0">
        <span>If Price &lt; ${d.strikeAbsolute}:</span>
        <span>${fmtStyle.good(d.underlyingYield)} ${fmtStyle.good(d.underlying)} <small class="text-good-alt">(+${d.underlyingProfit})</small></span>
      </div>
    </div>

    <div class="warnings-panel">
      <div class="warning-row">
        <i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i> 
        If ${d.underlying} falls below ${fmtStyle.bad(d.beAbsolute)} (${fmtStyle.bad(d.beRelative)}), 
        you will have ${fmtStyle.bad('less')} ${d.money} than starting with a 100% ${d.money} allocation.
      </div>
      <div class="warning-row">
        <i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i> 
        If ${d.underlying} surpasses ${fmtStyle.good(d.capAbsolute)} (${fmtStyle.good(d.capRelative)}), 
        you will have ${fmtStyle.bad('less')} ${d.underlying} than starting with a 100% ${d.underlying} allocation.
      </div>
    </div>

    <div class="instructions-panel">
      <div class="instructions-header">Execution Instructions</div>
      <div class="instructions-content">
        &bull; <b>Buy</b> ${fmtStyle.good(d.buyAmount)} for ${fmtStyle.bad(d.buyCost)}<br/>
        &bull; <b>Sell</b> ${fmtStyle.bad(d.sellAmount)} for ${fmtStyle.good(d.sellPremium)}
      </div>
    </div>
  `;
}

function renderTooltipCC(d) {
  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="tooltip-yield-good">${d.moneyYield} ${d.money} ⬆</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-yield-good">${d.underlyingYield} ${d.underlying} ⬇</div>
      </div>

      <div class="tooltip-breakeven">
        <span class="text-label">Even vs full ${d.money}:</span> 
        <span class="text-neutral">${d.beAbsolute}</span>
        <span class="text-bad ms-1">(${d.beRelative})</span>
        <br/>
        <span class="text-label">Even vs full ${d.underlying}:</span> 
        <span class="text-neutral">${d.capAbsolute}</span>
        <span class="text-good ms-1">(${d.capRelative})</span>
      </div>
      
      <div class="tooltip-footer">
        Minimum position: <span class="text-light-alt">${d.capitalRequired}</span> (${d.capitalRequiredUnderlying})
      </div>
    </div>
  `;
}

function ccFormatterTemplate(params, isDetailed) {
  if (!params || !params.value) return '';
  const data = prepareCCData(params.value);
  return isDetailed ? renderDetailedCC(data) : renderTooltipCC(data);
}


const ccTooltipFormatter = function (params) {
  return ccFormatterTemplate(params, false);
};

const ccDetailsFormatter = function (params) {
  return ccFormatterTemplate(params, true);
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
}

function extractSpotPrice(data) {
  return data.at(0)?.spotPrice;
}

function populateStrategyDetails(dataObj) {
  const panel = document.getElementById('coveredCallDetailsPanel');
  if (panel && dataObj) {
    // ECharts formatter expects an object with 'value' property
    panel.innerHTML = ccDetailsFormatter({ value: dataObj });
  }
}

function coveredCallToBreakEvenChart(data, divId) {
  {
    let chartDom = document.getElementById(divId);
    let existingChart = echarts.getInstanceByDom(chartDom);
    if (existingChart) existingChart.dispose();
  }

  const spotPrice = extractSpotPrice(data);
  const money = data.at(0)?.money || '';
  const underlying = data.at(0)?.underlying || '';
  // TODO: share this code across charts.
  const dataset = {
    id: "original",
    dimensions: ["moneyYield", "underlyingYield", "DTE"],
    source: data
  };
  const uniqueDTEs = [...new Set(dataset.source.map(item => item.DTE))];
  const datasetPerDTE = uniqueDTEs.map(dte => ({
    id: `dte_${dte}`,
    fromDatasetId: 'original',
    label: `${dte}`,
    transform: {
      type: 'filter',
      config: {
        dimension: 'DTE',
        '=': dte
      }
    }
  }));

  const chart = echarts.init(document.getElementById(divId));
  window.addEventListener('resize', function () {
    console.log("Before resize");
    chart.resize();
    console.log("After resize");
  });

  chart.setOption({
    dataset: [dataset, ...datasetPerDTE],
    xAxis: {
      type: 'value',
      name: `${money}➡`,
      nameLocation: 'end',
      nameGap: 0,
      nameTextStyle: {
        ...axisTitleNameTextStyle,
        align: 'right',
        verticalAlign: 'top',
        padding: [30, 0, 0, 0]
      },
      axisLabel: {
        ...axisXValuesNameTextStyle,
        formatter: function (value) {
          return `${percentFmt.format(value - 1.0)}`;
        },
      },
      axisLine,
      scale: true,
      position: 'bottom',
    },
    grid,
    yAxis: {
      type: 'value',
      name: `⬆${underlying}`,
      nameLocation: 'end',
      nameTextStyle: yAxisTitleNameTextStyle,
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return `${percentFmt.format(value - 1.0)}`;
        },
      },
      axisLine,
      scale: true
    },
    tooltip: {
      ...tooltipStyle,
      formatter: ccTooltipFormatter,
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'moneyYield',
        y: 'underlyingYield'
      },
      symbolSize: function (data) {
        return 8;
      },
      emphasis: {
        symbolSize: function (data) {
          return 10;
        },
        itemStyle: {
          color: 'red',
          borderColor: 'white',
          borderWidth: 2
        },
        scale: true,
        focus: 'series',
      },
      label: {
        show: false
      }
    }))],
    legend: legend,
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        startValue: 1.0,
        endValue: 2.0,
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        startValue: 1.0,
        endValue: 2.0,
      }
    ],
  });

  chart.on('click', function (params) {
    if (params.componentType === 'series' && params.data) {
      populateStrategyDetails(params.data);
    }
  });

  return chart;
}
