const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const percentNoSignFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
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
  label: (str) => `<span style="color: #94a3b8; font-weight: bold;">${str}</span>`,
  neutral: (str) => `<span style="color: #38bdf8; font-weight: bold;">${str}</span>`,
  good: (str) => `<span style="color: #00ffa3; font-weight: bold;">${str}</span>`,
  bad: (str) => `<span style="color: #ff5c5c; font-weight: bold;">${str}</span>`,
  header: (str) => `<div style="color: #fcd34d; font-size: 1.2em; font-weight: bold; border-bottom: 1px solid #334155; margin-bottom: 12px; padding-bottom: 6px; display: flex; align-items: center;"><i class="fas fa-cube me-2"></i> ${str}</div>`
};

function renderDetailedCC(d) {
  return `
    ${fmtStyle.header(`Strategy: Covered Call on&nbsp;${fmtStyle.neutral(d.underlying)}`)}
    
    <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px; font-size: 0.95em;">
      <tr><td style="padding: 4px 0;">${fmtStyle.label('Expiration')}</td><td style="text-align: right;">${fmtStyle.neutral(d.formattedDate)} <small>${fmtStyle.bad('(' + d.DTE + 'd)')}</small></td></tr>
      <tr><td style="padding: 4px 0;">${fmtStyle.label('Strike Price')}</td><td style="text-align: right;">${fmtStyle.neutral(d.strikeAbsolute)}</td></tr>
      <tr><td style="padding: 4px 0;">${fmtStyle.label('Contract')}</td><td style="text-align: right; font-family: monospace;">${fmtStyle.neutral(d.callName)}</td></tr>
      <tr><td style="padding: 4px 0;">${fmtStyle.label('Capital Required')}</td><td style="text-align: right;">${fmtStyle.neutral(d.capitalRequired)} <small style="color: #64748b">(${fmtStyle.neutral(d.capitalRequiredUnderlying)})</small></td></tr>
    </table>

    <div style="background: rgba(30, 41, 59, 0.5); padding: 12px; border-radius: 8px; border: 1px solid #334155; margin-bottom: 16px;">
      <div style="margin-bottom: 8px; font-weight: bold; color: #cbd5e1;">Outcomes at Expiration:</div>
      <div style="display: flex; justify-content: space-between; margin-bottom: 6px;">
        <span>If Price &ge; ${d.strikeAbsolute}:</span>
        <span>${fmtStyle.good(d.moneyYield)} ${fmtStyle.good(d.money)} <small style="color: #00ffa3">(+${d.moneyProfit})</small></span>
      </div>
      <div style="display: flex; justify-content: space-between;">
        <span>If Price &lt; ${d.strikeAbsolute}:</span>
        <span>${fmtStyle.good(d.underlyingYield)} ${fmtStyle.good(d.underlying)} <small style="color: #00ffa3">(+${d.underlyingProfit})</small></span>
      </div>
    </div>

    <div style="font-size: 0.9em; margin-bottom: 16px; line-height: 1.5; color: #94a3b8;">
      <div style="border-top: 1px dashed #334155; margin: 8px 0; padding-top: 8px;">
        <i class="fas fa-exclamation-triangle me-1" style="color: #fcd34d"></i> 
        If ${d.underlying} falls below ${fmtStyle.bad(d.beAbsolute)} (${fmtStyle.bad(d.beRelative)}), 
        you will have ${fmtStyle.bad('less')} ${d.money} than starting with a 100% ${d.money} allocation.
      </div>
      <div style="border-top: 1px dashed #334155; margin: 8px 0; padding-top: 8px;">
        <i class="fas fa-exclamation-triangle me-1" style="color: #fcd34d"></i> 
        If ${d.underlying} surpasses ${fmtStyle.good(d.capAbsolute)} (${fmtStyle.good(d.capRelative)}), 
        you will have ${fmtStyle.bad('less')} ${d.underlying} than starting with a 100% ${d.underlying} allocation.
      </div>
    </div>

    <div style="background: rgba(15, 23, 42, 0.3); padding: 10px; border-left: 3px solid #38bdf8; border-radius: 0 4px 4px 0;">
      <div style="font-weight: bold; margin-bottom: 6px; font-size: 0.9em; text-transform: uppercase; letter-spacing: 0.05em;">Execution Instructions</div>
      <div style="font-size: 0.9em;">
        &bull; <b>Buy</b> ${fmtStyle.good(d.buyAmount)} for ${fmtStyle.bad(d.buyCost)}<br/>
        &bull; <b>Sell</b> ${fmtStyle.bad(d.sellAmount)} for ${fmtStyle.good(d.sellPremium)}
      </div>
    </div>
  `;
}

function renderTooltipCC(d) {
  return `
    <div style="padding: 10px; min-width: 220px; font-family: 'Inter', sans-serif; background: #1e293b;">
      <div style="display: flex; justify-content: space-between; border-bottom: 1px solid #334155; margin-bottom: 12px; padding-bottom: 6px;">
        <span style="font-weight: bold; color: #cbd5e1;">${d.formattedDate}</span>
        <span style="color: #ff5c5c; font-weight: bold;">${d.DTE}d</span>
      </div>
      
      <div style="display: flex; flex-direction: column; align-items: center; gap: 2px;">
        <div style="color: #00ffa3; font-weight: bold; font-size: 1.1em;">${d.moneyYield} ${d.money} ⬆</div>
        <div style="height: 10px; border-left: 2px dashed #475569;"></div>
        <div style="background: #334155; padding: 2px 12px; border-radius: 12px; color: #fcd34d; font-weight: bold; font-size: 0.9em; border: 1px solid #475569;">
          ${d.strikeAbsolute}
        </div>
        <div style="height: 10px; border-left: 2px dashed #475569;"></div>
        <div style="color: #00ffa3; font-weight: bold; font-size: 1.1em;">${d.underlyingYield} ${d.underlying} ⬇</div>
      </div>

      <div style="margin-top: 12px; padding-top: 8px; border-top: 1px solid #334155; text-align: center; font-size: 0.85em;">
        <span style="color: #94a3b8;">Even vs full ${d.money}:</span> 
        <span style="color: #38bdf8; font-weight: bold;">${d.beAbsolute}</span>
        <span style="color: #ff5c5c; margin-left: 4px;">(${d.beRelative})</span>
        <br/>
        <span style="color: #94a3b8;">Even vs full ${d.underlying}:</span> 
        <span style="color: #38bdf8; font-weight: bold;">${d.capAbsolute}</span>
        <span style="color: #00ffa3; margin-left: 4px;">(${d.capRelative})</span>
      </div>
    </div>
  `;
}
// capAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute),
// capRelative: percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0),

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
    chart.resize();
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

function highlightEChartPoint(chartInstance, clickedCallValue) {
  const option = chartInstance.getOption();
  const allSeries = option.series;
  const originalDatasetSource = option.dataset[0].source;
  const clickedItem = originalDatasetSource.find(item => item.call === clickedCallValue);

  if (!clickedItem) {
    console.warn(`No data found in original dataset for call: "${clickedCallValue}"`);
    return;
  }

  const clickedDTE = clickedItem.DTE;
  const targetSeriesIndex = allSeries.findIndex(s => s.name === String(clickedDTE));

  if (targetSeriesIndex === -1) {
    console.warn(`[ECharts Highlight] ECharts series not found for DTE: ${clickedDTE}`);
    return;
  }

  const dataForTargetSeries = originalDatasetSource.filter(item => item.DTE === clickedDTE);
  const targetDataIndex = dataForTargetSeries.findIndex(item => item.call === clickedCallValue);

  if (targetDataIndex === -1) {
    console.warn(`[ECharts Highlight] Internal error: Data point index not found within DTE series for Call: "${clickedCallValue}", DTE: ${clickedDTE}`);
    return;
  }

  chartInstance.dispatchAction({
    type: 'downplay',
    seriesIndex: allSeries.map((_, i) => i) // Downplay all series
  });

  chartInstance.dispatchAction({
    type: 'highlight',
    seriesIndex: targetSeriesIndex,
    dataIndex: targetDataIndex
  });

  chartInstance.dispatchAction({
    type: 'showTip',
    seriesIndex: targetSeriesIndex,
    dataIndex: targetDataIndex
  });
}

function coveredCallToBreakEvenTable(data, divId, chart) {
  const gridDiv = document.getElementById(divId);
  if (!gridDiv) {
    console.error(`AG Grid target div not found: #${divId}`);
    return;
  }

  const columnDefs = [
    {
      headerName: 'Call',
      field: 'call',
      sortable: false,
      filter: true,
      cellRenderer: (params) => `<strong>${params.data.call}</strong>`,
      minWidth: 200,
      headerTooltip: 'The call option via which to build a covered call strategy',
    },
    {
      headerName: 'Strike',
      field: 'strikeAbsolute',
      sortable: true,
      filter: true,
      cellRenderer: (params) => `<strong>${params.data.strikeAbsolute}</strong>`,
      minWidth: 100,
      headerTooltip: 'The strike (also the price where max yield is achieved)',
    },
    {
      headerName: 'DTE',
      field: 'DTE',
      sortable: true,
      filter: 'agNumberColumnFilter',
      headerTooltip: 'Days till expiration',
      minWidth: 50,
      sort: 'desc',
    },
    {
      headerName: 'B.E.',
      field: 'breakEvenVsFullMoneyAbsolute',
      sortable: true,
      filter: 'agNumberColumnFilter',
      valueFormatter: (params) => dollarFmt.format(params.value),
      minWidth: 100,
      headerTooltip: 'Underlying price which (at expiration) would give you your money back',
    },
    {
      headerName: 'B.E. %',
      field: 'breakEvenVsFullMoneyRelative',
      sortable: true,
      filter: 'agNumberColumnFilter',
      valueFormatter: (params) => percentFmt.format(params.value - 1.0),
      minWidth: 90,
      headerTooltip: 'The breakeven price, as a change (%) of the current spot price',
    },
    {
      headerName: 'M.Y. %',
      field: 'moneyYield',
      sortable: true,
      filter: 'agNumberColumnFilter',
      valueFormatter: (params) => percentFmt.format(params.value - 1.0),
      minWidth: 90,
      headerTooltip: 'The max yield (maximum profitability) of this strategy',
    },
    {
      headerName: 'M.Y. At %',
      field: 'strikeRelative',
      sortable: true,
      filter: 'agNumberColumnFilter',
      valueFormatter: (params) => percentFmt.format(params.value - 1.0),
      minWidth: 90,
      headerTooltip: 'The minimum spot price change (%) you need at expiration to get the max yield',
    },
  ];

  const gridOptions = {
    columnDefs: columnDefs,
    rowData: data,

    pagination: false,
    defaultColDef: {
      sortable: true,
      resizable: true,
      filter: true,
      floatingFilter: true,
    },
    onRowClicked: (event) => {
      highlightEChartPoint(chart, event.data.call);
      populateStrategyDetails(event.data);
    }
  };
  gridApi = agGrid.createGrid(gridDiv, gridOptions);
  gridApi.sizeColumnsToFit();
  window.addEventListener('resize', function () {
    gridApi.sizeColumnsToFit();
  });
  return gridApi;
}

function coveredCallToBreakEvenLockup(data, chartDivId, tableDivId) {
  let chartDom = document.getElementById(chartDivId);
  let existingChart = echarts.getInstanceByDom(chartDom);
  if (existingChart) existingChart.dispose();

  let tableDom = document.getElementById(tableDivId);
  if (tableDom) tableDom.innerHTML = '';

  chart = coveredCallToBreakEvenChart(data, chartDivId);
  coveredCallToBreakEvenTable(data, tableDivId, chart);
}

function verticalSpreadsChart(data, divId) {
  const spotPrice = extractSpotPrice(data);
  const dataset = {
    id: "original",
    dimensions: ["type", "DTE", "moneyYield", "strikeAbsolute", "shortLeg", "longLeg",
      "credit", "maxRisk", "breakEven"
    ],
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
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, ...datasetPerDTE],
    xAxis: {
      type: 'value',
      name: 'Strike',
      nameLocation: 'center',
      nameGap: 25,
      nameTextStyle: {
        color: 'green',
        fontFamily: 'monospace',
        fontSize: 16
      },
      axisLabel: {
        color: 'green',
        fontFamily: 'monospace',
        fontSize: 12
      },
      axisLine,
      scale: true
    },
    grid,
    yAxis: {
      type: 'value',
      name: 'Time Value (%)',
      nameTextStyle: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 16
      },
      axisLabel: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 12,
        formatter: function (value) {
          return percentFmt.format(value);
        }
      },
      axisLine,
      scale: true
    },
    tooltip: {
      ...tooltipStyle,
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Profit At: $${value.strikeAbsolute}<br/>
          Break Even: ${dollarFmt.format(value.breakEvenVsFullMoneyAbsolute)} (${percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0)})<br/>
          Max Profit: ${percentFmt.format(value.moneyYield - 1.0)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}<br/>
          DTE: ${value.DTE}
        `;
      },
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'maxYieldAt',
        y: 'timeValue'
      },
      symbolSize: function (data) {
        // TODO: function of maxYield? Or of time value?
        return 4;
      },
      label: {
        show: false
      }
    }))],
    legend,
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        startValue: spotPrice * 0.5,
        endValue: spotPrice * 1.5
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        startValue: 0,
        endValue: spotPrice
      }
    ],
  });
}
