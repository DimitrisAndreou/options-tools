// Return the properties of a previously opened position on this strategy,
// from Alpine store's openPosition, if found.
function getOpenParams() {
  const store = getAppStore();
  if (!store || !store.openPosition) return null;
  const p = store.openPosition;
  const openMoneyYield = p.moneyYield !== undefined && p.moneyYield !== null ? parseFloat(p.moneyYield) : NaN;
  const openUnderlyingYield = p.underlyingYield !== undefined && p.underlyingYield !== null ? parseFloat(p.underlyingYield) : NaN;
  const openDTE = p.DTE !== undefined && p.DTE !== null ? parseInt(p.DTE, 10) : NaN;
  const openMoney = p.money !== undefined && p.money !== null ? parseFloat(p.money) : null;
  const openUnderlying = p.underlying !== undefined && p.underlying !== null ? parseFloat(p.underlying) : null;

  if (isNaN(openMoneyYield) || isNaN(openUnderlyingYield) || isNaN(openDTE)) {
    return null;
  }

  return {
    openMoneyYield,
    openUnderlyingYield,
    openDTE,
    openMoney: openMoney === null || isNaN(openMoney) ? null : openMoney,
    openUnderlying: openUnderlying === null || isNaN(openUnderlying) ? null : openUnderlying
  };
}

function prepareCCData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Covered Call',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeAbsolute / value.spotPrice - 1.0),
    callName: value.call,
    callURL: value.callURL,
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

StrategyRegistry['coveredCall'] = new class extends BaseStrategyConfig {
  prepareData = prepareCCData;
  renderTooltip = renderTooltipCC;
  createOpenPosition(dataObj) {
    if (dataObj.moneyYield === undefined || dataObj.underlyingYield === undefined ||
      dataObj.moneySize === undefined || dataObj.underlyingToBuy === undefined ||
      dataObj.DTE === undefined) {
      console.log("Not creating an open position from", dataObj);
      return null;
    }
    return {
      moneyYield: Number(dataObj.moneyYield),
      underlyingYield: Number(dataObj.underlyingYield),
      money: Number(-dataObj.moneySize),
      underlying: Number(dataObj.underlyingToBuy),
      DTE: Number(dataObj.DTE)
    };
  }
  prepareUnrealizedData(dataObj) {
    const openParams = getOpenParams();
    if (!openParams) {
      return null;
    }
    const openMoneyYield = openParams.openMoneyYield;
    const openUnderlyingYield = openParams.openUnderlyingYield;
    const openDTE = openParams.openDTE;
    const openMoney = openParams.openMoney;
    const openUnderlying = openParams.openUnderlying;

    const moneyRatio = !isNaN(openMoneyYield) && dataObj.moneyYield ? openMoneyYield / dataObj.moneyYield : null;
    const underlyingRatio = !isNaN(openUnderlyingYield) && dataObj.underlyingYield ? openUnderlyingYield / dataObj.underlyingYield : null;

    const res = {};
    if (moneyRatio !== null) {
      const val = (moneyRatio - 1.0) * 100;
      const sign = val >= 0 ? '+' : '';
      res.unrealizedMoneyYield = sign + val.toFixed(2) + '%';
      res.moneyYieldClass = moneyRatio >= 1.0 ? 'text-good' : 'text-bad';
    } else {
      res.unrealizedMoneyYield = 'N/A';
      res.moneyYieldClass = 'text-muted-alt';
    }

    if (underlyingRatio !== null) {
      const val = (underlyingRatio - 1.0) * 100;
      const sign = val >= 0 ? '+' : '';
      res.unrealizedUnderlyingYield = sign + val.toFixed(2) + '%';
      res.underlyingYieldClass = underlyingRatio >= 1.0 ? 'text-good' : 'text-bad';
    } else {
      res.unrealizedUnderlyingYield = 'N/A';
      res.underlyingYieldClass = 'text-muted-alt';
    }

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
  updateSelection(idToSelect) {
    const store = getAppStore();
    const chartDom = document.getElementById("strategyChartContainer");
    const chart = echarts.getInstanceByDom(chartDom);
    if (!chart || !store || !store.chartData) return;

    const targetItem = store.chartData.find(item => item.id === idToSelect);
    const overlay = calculateOverlay(targetItem);

    chart.setOption({
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect || '' } }
      }],
      series: [{
        id: 'openOverlay',
        markPoint: {
          data: overlay ? [{ coord: overlay.open }] : []
        },
        markLine: {
          data: overlay ? [[{ coord: overlay.open }, { coord: overlay.current }]] : []
        }
      }]
    });
  }
};

function calculateOverlay(target) {
  const openParams = getOpenParams();
  if (!openParams || !target) return null;

  const { openMoneyYield, openUnderlyingYield } = openParams;
  const moneyRatio = target.moneyYield ? openMoneyYield / target.moneyYield : null;
  const underlyingRatio = target.underlyingYield ? openUnderlyingYield / target.underlyingYield : null;
  const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
  const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

  if (moneyDiffers || underlyingDiffers) {
    return {
      open: [openMoneyYield, openUnderlyingYield],
      current: [target.moneyYield, target.underlyingYield]
    };
  }
  return null;
}


function renderCoveredCallsChart(data, chartDom, idToSelect) {
  const money = data.at(0)?.money || '';
  const underlying = data.at(0)?.underlying || '';

  const targetItem = data.find(item => item.id === idToSelect);
  const overlay = calculateOverlay(targetItem);

  const dataset = {
    id: "original",
    dimensions: ["moneyYield", "underlyingYield", "DTE", "id"],
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
      min: function (value) { return Math.max(1.0, value.min - 0.5); },
      max: function (value) { return value.max + 0.5; },
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
      min: function (value) { return Math.max(1.0, value.min - 0.5); },
      max: function (value) { return value.max + 0.5; }
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
          x: 'moneyYield',
          y: 'underlyingYield'
        },
        symbolSize: function (data) {
          return 6;
        },
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
        encode: { x: 'moneyYield', y: 'underlyingYield' }
      },
      {
        id: 'openOverlay',
        type: 'scatter',
        silent: true,
        data: [],
        markPoint: {
          symbol: 'circle',
          symbolSize: 80,
          itemStyle: {
            color: 'transparent',
            borderColor: '#ff5c5c',
            borderWidth: 4,
            borderType: 'dashed'
          },
          data: overlay ? [{ coord: overlay.open }] : []
        },
        markLine: {
          symbol: ['none', 'arrow'],
          symbolSize: 18,
          lineStyle: {
            color: '#e1e355ff',
            width: 3,
            type: 'solid'
          },
          data: overlay ? [[{ coord: overlay.open }, { coord: overlay.current }]] : []
        }
      },
      {
        type: 'line',
        name: '45°',
        data: [[1, 1], [5, 5]],
        symbol: 'none',
        silent: true,
        animation: false,
        lineStyle: {
          color: '#fcd34d',
          type: 'dashed',
          width: 2.0,
          opacity: 0.75
        },
        emphasis: {
          focus: 'series',
          lineStyle: {
            width: 3.0,
            opacity: 1,
            type: 'solid'
          }
        },
        showSymbol: false
      }
    ],
    legend: legend,
    animationDurationUpdate: 800,
    animationEasingUpdate: 'quinticOut',
    dataZoom: [
      {
        type: 'inside',
        maxValueSpan: 1.0,
        throttle: 50,
        xAxisIndex: 0,
        filterMode: 'none',
        startValue: 1.0,
        endValue: 1.5
      },
      {
        type: 'inside',
        maxValueSpan: 1.0,
        throttle: 50,
        yAxisIndex: 0,
        filterMode: 'none',
        startValue: 1.0,
        endValue: 1.5
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
