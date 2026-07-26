

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
    spotPrice: dollarFmt.format(value.spotPrice),
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
    sellPremium: `${underlyingFmt.format(value.premiumToReceive)} ${underlying}`,

    // Probabilities
    moneyProbability: value.moneyProbability,
    underlyingProbability: value.underlyingProbability
  };
}

function renderTooltipCC(d) {
  const moneyProbSuffix = d.moneyProbability != null ? ` <span class="probs">(${Math.round(d.moneyProbability * 100)}% prob)</span>` : '';
  const underlyingProbSuffix = d.underlyingProbability != null ? ` <span class="probs">(${Math.round(d.underlyingProbability * 100)}% prob)</span>` : '';

  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="tooltip-yield-good">${d.moneyYield} ${d.money} ⬆${moneyProbSuffix}</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-yield-good">${d.underlyingYield} ${d.underlying} ⬇${underlyingProbSuffix}</div>
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
  createEntryPosition(pos) {
    if (!pos || pos.id === undefined) {
      console.log("Not creating an entry position from", pos);
      return null;
    }
    return pos;
  }
  prepareUnrealizedOrRollData(currentPos) {
    const store = getAppStore();
    const entryPos = store ? store.entryPosition : null;
    if (!entryPos || !currentPos) return null;

    var entryPosView = {
      moneyYield: entryPos.moneyYield,
      underlyingYield: entryPos.underlyingYield,
      money: -entryPos.moneySize,
      underlying: entryPos.underlyingToBuy,
      DTE: entryPos.DTE
    };
    var currentPosView = {
      moneyYield: currentPos.moneyYield,
      underlyingYield: currentPos.underlyingYield,
      money: -currentPos.moneySize,
      underlying: currentPos.underlyingToBuy,
      DTE: currentPos.DTE
    };

    // Rolls mean replacing the old position with a new one.
    // Their difference does not represent a loss or a gain.
    // If it's not a roll, i.e. we are comparing the same position in two different moments,
    // then the difference is the unrealized loss or gain.
    // In both cases we are showing the diff of the various important aspects,
    // but only the direction of the good/bad changes.
    // E.g. for an unrealized result, going to less capital means a capital loss.
    // But for a roll, it means that we get more premium, thus capital return,
    // thus we retain less risk, which is "good".
    const isRoll = currentPos.id !== entryPos.id;

    const entrySpot = Number(entryPos.spotPrice);
    const currentSpot = Number(currentPos.spotPrice);

    const rows = [];

    // 1. Spot Price
    const spotDiff = currentSpot - entrySpot;
    const spotPct = entrySpot > 0 ? (spotDiff / entrySpot) * 100 : 0;
    const spotDiffText = `${spotDiff >= 0 ? '+' : ''}${dollarFmt.format(spotDiff)}<br/>(${spotDiff >= 0 ? '+' : ''}${spotPct.toFixed(1)}%)`;
    rows.push({
      label: 'Spot Price',
      before: dollarFmt.format(entrySpot),
      after: dollarFmt.format(currentSpot),
      diff: spotDiffText,
      diffClass: spotDiff >= 0 ? 'text-good' : 'text-bad'
    });

    // 2. Days to expiration
    const dteDiff = currentPosView.DTE - entryPosView.DTE;
    const dtePct = entryPosView.DTE > 0 ? (dteDiff / entryPosView.DTE) * 100 : 0;
    const dteDiffText = `${dteDiff >= 0 ? '+' : ''}${dteDiff} days<br/>(${dteDiff >= 0 ? '+' : ''}${dtePct.toFixed(2)}%)`;
    rows.push({
      label: 'Days to expiration',
      before: `${entryPosView.DTE}`,
      after: `${currentPosView.DTE}`,
      diff: dteDiffText,
      diffClass: 'text-neutral-alt'
    });

    // 3. Strike
    const entryStrike = Number(entryPos.strikeAbsolute);
    const currentStrike = Number(currentPos.strikeAbsolute);
    const strikeDiff = currentStrike - entryStrike;
    const strikeDiffPct = entryStrike > 0 ? (strikeDiff / entryStrike) * 100 : 0;
    const strikeDiffText = `${strikeDiff >= 0 ? '+' : ''}${dollarFmt.format(strikeDiff)}<br/>(${strikeDiff >= 0 ? '+' : ''}${strikeDiffPct.toFixed(1)}%)`;
    const entryStrikeRelText = percentFmt.format(entryStrike / entrySpot - 1.0);
    const currentStrikeRelText = percentFmt.format(currentStrike / currentSpot - 1.0);
    rows.push({
      label: 'Strike',
      before: `${dollarFmt.format(entryStrike)}<br/><span class="text-neutral-alt">(${entryStrikeRelText})</span>`,
      after: `${dollarFmt.format(currentStrike)}<br/><span class="text-neutral-alt">(${currentStrikeRelText})</span>`,
      diff: strikeDiffText,
      diffClass: strikeDiff >= 0 ? 'text-good' : 'text-bad',
      separator: true
    });

    // 4. Capital (USD)
    const moneyDiff = currentPosView.money - entryPosView.money;
    const moneyPct = entryPosView.money > 0 ? (moneyDiff / entryPosView.money) * 100 : 0;
    const moneyDiffText = `${moneyDiff >= 0 ? '+' : ''}${dollarFmt.format(moneyDiff)}<br/>(${moneyDiff >= 0 ? '+' : ''}${moneyPct.toFixed(1)}%)`;
    rows.push({
      label: `Capital (${entryPos.money})`,
      before: dollarFmt.format(entryPosView.money),
      after: dollarFmt.format(currentPosView.money),
      diff: moneyDiffText,
      diffClass: isRoll
        ? (moneyDiff <= 0 ? 'text-good' : 'text-bad')
        : (moneyDiff >= 0 ? 'text-good' : 'text-bad')
    });

    // 5. Capital (BTC)
    const undDiff = currentPosView.underlying - entryPosView.underlying;
    const undPct = entryPosView.underlying > 0 ? (undDiff / entryPosView.underlying) * 100 : 0;
    const undDiffText = `${undDiff >= 0 ? '+' : ''}${underlyingFmt.format(undDiff)}<br/>(${undDiff >= 0 ? '+' : ''}${undPct.toFixed(1)}%)`;
    rows.push({
      label: `Capital (${entryPos.underlying})`,
      before: underlyingFmt.format(entryPosView.underlying),
      after: underlyingFmt.format(currentPosView.underlying),
      diff: undDiffText,
      diffClass: isRoll
        ? (undDiff <= 0 ? 'text-good' : 'text-bad')
        : (undDiff >= 0 ? 'text-good' : 'text-bad'),
      separator: true
    });

    // 6. USD Yield
    const entryMoneyYieldValNum = entryPos.moneyYield - 1.0;
    const currentMoneyYieldValNum = currentPos.moneyYield - 1.0;
    const moneyYieldRatioChange = currentPos.moneyYield / entryPos.moneyYield - 1.0;
    const moneyYieldDiffText = percentFmt.format(moneyYieldRatioChange);
    const entryMoneyYieldProbText = entryPos.moneyProbability != null ? `<br/><span class="text-probs">(${Math.round(entryPos.moneyProbability * 100)}% prob)</span>` : '';
    const currentMoneyYieldProbText = currentPos.moneyProbability != null ? `<br/><span class="text-probs">(${Math.round(currentPos.moneyProbability * 100)}% prob)</span>` : '';
    rows.push({
      label: `${entryPos.money} Yield`,
      before: `${percentFmt.format(entryMoneyYieldValNum)}${entryMoneyYieldProbText}`,
      after: `${percentFmt.format(currentMoneyYieldValNum)}${currentMoneyYieldProbText}`,
      diff: moneyYieldDiffText,
      diffClass: moneyYieldRatioChange >= 0 ? 'text-good' : 'text-bad'
    });

    // 7. BTC Yield
    const entryUndYieldValNum = entryPos.underlyingYield - 1.0;
    const currentUndYieldValNum = currentPos.underlyingYield - 1.0;
    const undYieldRatioChange = currentPos.underlyingYield / entryPos.underlyingYield - 1.0;
    const undYieldDiffText = percentFmt.format(undYieldRatioChange);
    const entryUndYieldProbText = entryPos.underlyingProbability != null ? `<br/><span class="text-probs">(${Math.round(entryPos.underlyingProbability * 100)}% prob)</span>` : '';
    const currentUndYieldProbText = currentPos.underlyingProbability != null ? `<br/><span class="text-probs">(${Math.round(currentPos.underlyingProbability * 100)}% prob)</span>` : '';
    rows.push({
      label: `${entryPos.underlying} Yield`,
      before: `${percentFmt.format(entryUndYieldValNum)}${entryUndYieldProbText}`,
      after: `${percentFmt.format(currentUndYieldValNum)}${currentUndYieldProbText}`,
      diff: undYieldDiffText,
      diffClass: undYieldRatioChange >= 0 ? 'text-good' : 'text-bad',
      separator: true
    });

    // 8. Breakeven (vs full USD)
    const entryBeMoneyRelText = percentFmt.format(entryPos.breakEvenVsFullMoneyRelative - 1.0);
    const currentBeMoneyRelText = percentFmt.format(currentPos.breakEvenVsFullMoneyRelative - 1.0);
    const beMoneyDiff = currentPos.breakEvenVsFullMoneyAbsolute - entryPos.breakEvenVsFullMoneyAbsolute;
    const beMoneyDiffPct = entryPos.breakEvenVsFullMoneyAbsolute > 0 ? (beMoneyDiff / entryPos.breakEvenVsFullMoneyAbsolute) * 100 : 0;
    const beMoneyDiffText = `${beMoneyDiff >= 0 ? '+' : ''}${dollarFmt.format(beMoneyDiff)}<br/>(${beMoneyDiff >= 0 ? '+' : ''}${beMoneyDiffPct.toFixed(1)}%)`;
    rows.push({
      label: `Breakeven (vs full ${entryPos.money})`,
      before: `${dollarFmt.format(entryPos.breakEvenVsFullMoneyAbsolute)}<br/><span class="text-bad">(${entryBeMoneyRelText})</span>`,
      after: `${dollarFmt.format(currentPos.breakEvenVsFullMoneyAbsolute)}<br/><span class="text-bad">(${currentBeMoneyRelText})</span>`,
      diff: beMoneyDiffText,
      diffClass: beMoneyDiff <= 0 ? 'text-good' : 'text-bad'
    });

    // 9. Breakeven (vs full BTC)
    const entryBeUndRelText = percentFmt.format(entryPos.breakEvenVsFullUnderlyingRelative - 1.0);
    const currentBeUndRelText = percentFmt.format(currentPos.breakEvenVsFullUnderlyingRelative - 1.0);
    const beUndDiff = currentPos.breakEvenVsFullUnderlyingAbsolute - entryPos.breakEvenVsFullUnderlyingAbsolute;
    const beUndDiffPct = entryPos.breakEvenVsFullUnderlyingAbsolute > 0 ? (beUndDiff / entryPos.breakEvenVsFullUnderlyingAbsolute) * 100 : 0;
    const beUndDiffText = `${beUndDiff >= 0 ? '+' : ''}${dollarFmt.format(beUndDiff)}<br/>(${beUndDiff >= 0 ? '+' : ''}${beUndDiffPct.toFixed(1)}%)`;
    rows.push({
      label: `Breakeven (vs full ${entryPos.underlying})`,
      before: `${dollarFmt.format(entryPos.breakEvenVsFullUnderlyingAbsolute)}<br/><span class="text-good">(${entryBeUndRelText})</span>`,
      after: `${dollarFmt.format(currentPos.breakEvenVsFullUnderlyingAbsolute)}<br/><span class="text-good">(${currentBeUndRelText})</span>`,
      diff: beUndDiffText,
      diffClass: beUndDiff >= 0 ? 'text-good' : 'text-bad'
    });

    return { isRoll, rows };
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
        id: 'entryOverlay',
        markPoint: {
          data: overlay ? [{ coord: overlay.entry }] : []
        },
        markLine: {
          data: overlay ? [[{ coord: overlay.entry }, { coord: overlay.current }]] : []
        }
      }]
    });
  }
};

function calculateOverlay(target) {
  const store = getAppStore();
  const entryPosition = store ? store.entryPosition : null;
  if (!entryPosition || !target) return null;

  const { moneyYield, underlyingYield } = entryPosition;
  const moneyRatio = target.moneyYield ? moneyYield / target.moneyYield : null;
  const underlyingRatio = target.underlyingYield ? underlyingYield / target.underlyingYield : null;
  const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
  const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

  if (moneyDiffers || underlyingDiffers) {
    return {
      entry: [moneyYield, underlyingYield],
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
        id: 'entryOverlay',
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
          data: overlay ? [{ coord: overlay.entry }] : []
        },
        markLine: {
          symbol: ['none', 'arrow'],
          symbolSize: 18,
          lineStyle: {
            color: '#e1e355ff',
            width: 3,
            type: 'solid'
          },
          data: overlay ? [[{ coord: overlay.entry }, { coord: overlay.current }]] : []
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
