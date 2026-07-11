function prepareLongCallData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Long Call',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    callName: value.call,
    callURL: value.callURL,
    callSize: value.callSize,

    costInMoney: dollarFmt.format(-value.moneySize),
    costInUnderlying: underlyingFmt.format(value.costInUnderlying),
    maxLeverage: value.maxLeverage.toFixed(2) + 'x',

    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeRelative - 1.0),

    // Breakeven / Caps
    beAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyAbsolute),
    beRelative: percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0),
    capAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute),
    capRelative: percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0),

    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.costInUnderlying)} ${underlying}`
  };
}

function renderTooltipLongCall(d) {
  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="tooltip-yield-good">${d.maxLeverage} Leverage ⬆</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-yield-bad">-100% ⬇</div>
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

function prepareLongPutData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Long Put',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    putName: value.put,
    putURL: value.putURL,
    putSize: value.putSize,

    costInMoney: dollarFmt.format(-value.moneySize),
    costInUnderlying: underlyingFmt.format(value.costInUnderlying),
    maxLeverage: value.maxLeverage.toFixed(2) + 'x',
    maxMoneyYield: percentFmt.format(value.maxMoneyYield - 1.0) + ' (+' + dollarFmt.format(value.maxMoneyProfit) + ')',

    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeRelative - 1.0),

    // Breakeven / Caps
    beAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyAbsolute),
    beRelative: percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0),
    capAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute),
    capRelative: percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0),

    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.costInUnderlying)} ${underlying}`
  };
}

function renderTooltipLongPut(d) {
  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="tooltip-yield-bad">-100% ⬆</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-yield-good">${d.maxLeverage} Leverage ⬇</div>
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

function prepareLongOptionsUnrealizedData(dataObj) {
  const store = getAppStore();
  if (!store || !store.openPosition) return null;
  const p = store.openPosition;
  const openDTE = p.DTE !== undefined && p.DTE !== null ? parseInt(p.DTE, 10) : NaN;
  const openMoney = p.money !== undefined && p.money !== null ? parseFloat(p.money) : null;
  const openUnderlying = p.underlying !== undefined && p.underlying !== null ? parseFloat(p.underlying) : null;

  if (isNaN(openDTE) && openMoney === null && openUnderlying === null) {
    return null;
  }

  const res = {};

  let timePassed = 'N/A';
  if (!isNaN(openDTE) && dataObj.DTE !== undefined) {
    const diff = openDTE - dataObj.DTE;
    const pct = openDTE > 0 ? (diff / openDTE) * 100 : 0;
    timePassed = `${diff} days (${pct.toFixed(2)}%)`;
  }
  res.timePassed = timePassed;

  if (openMoney !== null && !isNaN(openMoney)) {
    res.openMoney = dollarFmt.format(openMoney);
  }
  if (openUnderlying !== null && !isNaN(openUnderlying)) {
    res.openUnderlying = `${underlyingFmt.format(openUnderlying)} ${dataObj.underlying}`;
  }

  return res;
}

StrategyRegistry['longCall'] = new class extends BaseStrategyConfig {
  prepareData = prepareLongCallData;
  renderTooltip = renderTooltipLongCall;

  createOpenPosition(dataObj) {
    if (dataObj.moneySize === undefined || dataObj.costInUnderlying === undefined || dataObj.DTE === undefined) {
      throw new Error("Missing required properties in dataObj for longCall open position");
    }
    return {
      money: Number(-dataObj.moneySize),
      underlying: Number(dataObj.costInUnderlying),
      DTE: Number(dataObj.DTE)
    };
  }

  prepareUnrealizedData(dataObj) {
    return prepareLongOptionsUnrealizedData(dataObj);
  }

  updateSelection(idToSelect) {
    const chartDom = document.getElementById("strategyChartContainer");
    const chart = echarts.getInstanceByDom(chartDom);
    if (!chart) return;

    chart.setOption({
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect || '' } }
      }]
    });
  }
};

StrategyRegistry['longPut'] = new class extends BaseStrategyConfig {
  prepareData = prepareLongPutData;
  renderTooltip = renderTooltipLongPut;

  createOpenPosition(dataObj) {
    if (dataObj.moneySize === undefined || dataObj.costInUnderlying === undefined || dataObj.DTE === undefined) {
      throw new Error("Missing required properties in dataObj for longPut open position");
    }
    return {
      money: Number(-dataObj.moneySize),
      underlying: Number(dataObj.costInUnderlying),
      DTE: Number(dataObj.DTE)
    };
  }

  prepareUnrealizedData(dataObj) {
    return prepareLongOptionsUnrealizedData(dataObj);
  }

  updateSelection(idToSelect) {
    const chartDom = document.getElementById("strategyChartContainer");
    const chart = echarts.getInstanceByDom(chartDom);
    if (!chart) return;

    chart.setOption({
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect || '' } }
      }]
    });
  }
};

function renderLongOptionsChart(data, chartDom, idToSelect) {
  const underlying = data.at(0)?.underlying || '';
  const dataset = {
    id: "original",
    dimensions: ["maxLeverage", "breakEvenVsFullUnderlyingRelative", "DTE", "id"],
    source: data
  };
  const highlightDataset = {
    id: 'highlightDataset',
    fromDatasetId: 'original',
    transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect || '' } }
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

  const chart = echarts.init(chartDom);
  window.addEventListener('resize', function () {
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, highlightDataset, ...datasetPerDTE],
    xAxis: {
      type: 'value',
      name: `Achieved Leverage➡`,
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
          return `${value.toFixed(1)}x`;
        },
      },
      axisLine,
      min: function (value) { return Math.max(0, value.min - 1.0); },
      max: function (value) { return value.max + 1.0; },
      position: 'bottom',
    },
    grid,
    yAxis: {
      type: 'value',
      name: `⇳ Required Price Change`,
      nameLocation: 'end',
      nameTextStyle: yAxisTitleNameTextStyle,
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return `${percentFmt.format(value - 1.0)}`;
        },
      },
      axisLine,
      min: function (value) { return Math.max(0.0, value.min - 0.05); },
      max: function (value) { return value.max + 0.05; }
    },
    tooltip: {
      ...tooltipStyle,
      formatter: strategyTooltipFormatter,
    },
    series: [
      ...datasetPerDTE.map(ds => ({
        type: 'line',
        name: ds.label,
        datasetId: ds.id,
        encode: {
          x: 'maxLeverage',
          y: 'breakEvenVsFullUnderlyingRelative'
        },
        symbol: 'triangle',
        symbolRotate: function (value, params) {
          if (params && params.data && params.data.strategyType === 'longPut') {
            return 180;
          }
          return 0;
        },
        symbolSize: 8,
        emphasis: {
          scale: 2,
          itemStyle: {
            color: 'red',
            borderColor: 'white',
            borderWidth: 2
          },
          focus: 'series',
        },
        label: {
          show: false
        }
      })),
      {
        ...selectionHighlightSeries,
        encode: { x: 'maxLeverage', y: 'breakEvenVsFullUnderlyingRelative' }
      }
    ],
    legend: legend,
    animationDurationUpdate: 800,
    animationEasingUpdate: 'quinticOut',
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        filterMode: 'none',
        startValue: 0.0,
        endValue: 10.0
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        filterMode: 'none',
        startValue: 0.8,
        endValue: 1.2
      }
    ],
  });

  chart.on('click', function (params) {
    if (params.componentType === 'series' && params.data) {
      selectStrategyById(params.data.id);
    }
  });
  chart.on('datazoom', function () {
    chart.dispatchAction({
      type: 'hideTip'
    });
  });

  selectStrategyById(idToSelect);
  return chart;
}
