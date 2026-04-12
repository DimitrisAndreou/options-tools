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
    color: '#fcd34d',
    fontFamily: 'monospace'
  },
  backgroundColor: '#1e1e2f',
  borderColor: '#fcd34d',
};

function ccFormatterTemplate(params, isDetailed) {
  function label(str) {
    return `<strong style="color: #ffffff;">${str}</strong>`;
  }
  function neutral(str) {
    return `<strong style="color: #38bdf8;">${str}</strong>`;
  }
  function good(str) {
    return `<strong style="color: #00ffa3;">${str}</strong>`;
  }
  function bad(str) {
    return `<strong style="color: #ff5c5c;">${str}</strong>`;
  }
  const value = params.value;
  // console.log({ value });
  const DTE = `${value.DTE}`;
  const money = value.money;
  const underlying = value.underlying;
  const breakEvenVsFullMoneyRelative = `${percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0)}`;
  const breakEvenVsFullMoneyAbsolute = `${dollarFmt.format(value.breakEvenVsFullMoneyAbsolute)}`;
  const breakEvenVsFullUnderlyingRelative = `${percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0)}`;
  const breakEvenVsFullUnderlyingAbsolute = `${dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute)}`;
  const moneyYieldPercent = `${percentFmt.format(value.moneyYield - 1.0)}`;
  const underlyingYieldPercent = `${percentFmt.format(value.underlyingYield - 1.0)}`;
  const moneyProfit = `+${dollarFmt.format(value.moneyProfit)}`;
  const underlyingProfit = `+${underlyingFmt.format(value.premiumToReceive)} ${underlying}`;
  const whatToBuy = `${underlyingFmt.format(value.underlyingToBuy)}`;
  const whatToBuyFor = `${dollarFmt.format(-value.moneySize)}`;
  const whatToSell = `${-value.callSize}`;
  const whatToSellFor = `${underlyingFmt.format(value.premiumToReceive)} ${underlying}`;

  let html = ``;
  if (isDetailed) {
    html += `${label('Covered Call')} on ${neutral(underlying)}`;
  }

  html += `<br/>${label('Expiration')}: ${neutral(value.formattedDate)}`;
  if (isDetailed) {
    html += `<br/>${label('Strike')}: ${neutral(dollarFmt.format(value.strikeAbsolute))}`;
    html += `<br/>${label('Contract Name')}: ${neutral(value.call)}`;
  }

  html += `
    <br/>${label('Capital required: ')} <!-- ${neutral(value.money)} --> ${neutral(whatToBuyFor)}`;

  if (isDetailed) {
    html += ` = ${neutral(whatToBuy)} ${neutral(underlying)}`;
  }
  html += `
    <br/>
    <br/>In ${bad(DTE)} days, you get one of:
    <br/>
    <br/>${good(moneyYieldPercent)} ${good(money)} (${good(moneyProfit)})
    <br/>⬆⬆⬆ if above ⬆⬆⬆
    <br/>${neutral(underlying)} = ${neutral(dollarFmt.format(value.strikeAbsolute))}
    <br/>⬇⬇⬇ if below ⬇⬇⬇
    <br/>${good(underlyingYieldPercent)} ${good(underlying)} (${good(underlyingProfit)})
    <br/>`;
  if (!isDetailed) {
    html += `
    <br/>${label('Breakeven')}: ${neutral(breakEvenVsFullMoneyRelative)}
      (at ${neutral(breakEvenVsFullMoneyAbsolute)})<br/>
    `;
  }

  if (isDetailed) {
    html += `
      <br/>${label('Is there no downside?')}
      <br/>
      <br/>If ${neutral(underlying)} > ${good(breakEvenVsFullUnderlyingAbsolute)} (${good(breakEvenVsFullUnderlyingRelative)}):
      <br/>You will have ${bad('less')} in terms of ${neutral(underlying)} vs ${neutral('being 100% in')} ${neutral(underlying)}.
      <br/>
      <br/>If ${neutral(underlying)} < ${bad(breakEvenVsFullMoneyAbsolute)} (${bad(breakEvenVsFullMoneyRelative)})
      <br/>${bad('less')} in terms of ${neutral(money)} vs ${neutral('being 100% in')} ${neutral(money)}.
      `;

    html += `
      ${label('Instructions')}:
      <ul style="margin: 0">
      <li>Buy ${good(whatToBuy)} ${neutral(underlying)}, for ${bad(whatToBuyFor)}</li>
      <li>Sell ${bad(whatToSell)} call(s), for ${good(whatToSellFor)}</li>
      </ul>
      `;
  }

  return html;
}

const ccTooltipFormatter = function (params) {
  return ccFormatterTemplate(params, false);
};

const ccDetailsFormatter = function (params) {
  return ccFormatterTemplate(params, true);
};

const axisTitleNameTextStyle = {
  color: 'yellow',
  fontFamily: 'monospace',
  fontSize: 18
};
const yAxisTitleNameTextStyle = {
  ...axisTitleNameTextStyle,
  align: 'left',
};
const axisXValuesNameTextStyle = {
  color: 'lightgreen',
  fontFamily: 'monospace',
  fontSize: 16,
};
const axisYValuesNameTextStyle = {
  color: 'orange',
  fontFamily: 'monospace',
  fontSize: 16,
};
const axisLine = {
  lineStyle: {
    color: 'yellow'
  }
};
const grid = {
  left: 60,
  right: 50,
  top: 50,
  bottom: 100,
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
      nameGap: 15,
      nameTextStyle: axisTitleNameTextStyle,
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
