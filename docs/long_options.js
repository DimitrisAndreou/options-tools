function prepareLongCallData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    strategyType: value.strategyType || 'longCall',
    iconClass: 'fa-arrow-trend-up',
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Long Call',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    callName: formatOptionName(value.call),
    callURL: value.callURL,
    callSize: value.callSize,

    costInMoney: dollarFmt.format(-value.moneySize),
    costInUnderlying: underlyingFmt.format(value.costInUnderlying),
    maxLeverage: Number(value.maxLeverage).toFixed(2) + 'x',

    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeRelative - 1.0),

    // Breakeven / Caps
    beAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyAbsolute),
    beRelative: percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0),
    capAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute),
    capRelative: percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0),

    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.costInUnderlying)} ${underlying}`,

    instructions: [{
      action: 'Buy',
      target: `${Number(Number(value.callSize).toFixed(4))} call(s)`,
      targetClass: 'text-good',
      consideration: `${dollarFmt.format(-value.moneySize)} (${underlyingFmt.format(value.costInUnderlying)} ${underlying})`,
      considerationClass: 'text-bad'
    }]
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
    strategyType: value.strategyType || 'longPut',
    iconClass: 'fa-arrow-trend-down',
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Long Put',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    putName: formatOptionName(value.put),
    putURL: value.putURL,
    putSize: value.putSize,

    costInMoney: dollarFmt.format(-value.moneySize),
    costInUnderlying: underlyingFmt.format(value.costInUnderlying),
    maxLeverage: Number(value.maxLeverage).toFixed(2) + 'x',
    maxMoneyYield: percentFmt.format(value.maxMoneyYield - 1.0) + ' (+' + dollarFmt.format(value.maxMoneyProfit) + ')',

    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeRelative - 1.0),

    // Breakeven / Caps
    beAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyAbsolute),
    beRelative: percentFmt.format(value.breakEvenVsFullMoneyRelative - 1.0),
    capAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingAbsolute),
    capRelative: percentFmt.format(value.breakEvenVsFullUnderlyingRelative - 1.0),

    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.costInUnderlying)} ${underlying}`,

    instructions: [{
      action: 'Buy',
      target: `${Number(Number(value.putSize).toFixed(4))} put(s)`,
      targetClass: 'text-good',
      consideration: `${dollarFmt.format(-value.moneySize)} (${underlyingFmt.format(value.costInUnderlying)} ${underlying})`,
      considerationClass: 'text-bad'
    }]
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

function prepareLongOptionData(value) {
  if (!value) return null;
  return value.strategyType === 'longPut'
    ? prepareLongPutData(value)
    : prepareLongCallData(value);
}

function renderTooltipLongOption(d) {
  if (!d) return '';
  return d.strategyType === 'longPut'
    ? renderTooltipLongPut(d)
    : renderTooltipLongCall(d);
}

function calculateLongOptionsOverlay(target) {
  const store = getAppStore();
  const entryPosition = store ? store.entryPosition : null;
  if (!entryPosition || (entryPosition.strategyType !== 'longCall' && entryPosition.strategyType !== 'longPut')) {
    return null;
  }

  return computeChartOverlay(
    [entryPosition.maxLeverage, entryPosition.breakEvenVsFullUnderlyingRelative],
    target ? [target.maxLeverage, target.breakEvenVsFullUnderlyingRelative] : null
  );
}

class LongOptionStrategyConfig extends BaseStrategyConfig {
  prepareData = prepareLongOptionData;
  renderTooltip = renderTooltipLongOption;
  getChartOverlay = calculateLongOptionsOverlay;

  prepareUnrealizedOrRollData(currentPos) {
    const store = getAppStore();
    const entryPos = store ? store.entryPosition : null;
    if (!entryPos && !currentPos) return null;

    const hasDiff = Boolean(entryPos && currentPos);
    const activePos = currentPos || entryPos;
    const isRoll = hasDiff && currentPos.id !== entryPos.id;
    const isDirectionFlip = hasDiff && entryPos.strategyType !== currentPos.strategyType;
    const mode = hasDiff ? (isRoll ? 'roll' : 'unrealized') : (entryPos ? 'pinnedOnly' : 'single');

    const header = prepareLongOptionData(activePos);
    if (isDirectionFlip && header) {
      const entryLabel = entryPos.strategyType === 'longPut' ? 'Long Put' : 'Long Call';
      const currentLabel = currentPos.strategyType === 'longPut' ? 'Long Put' : 'Long Call';
      header.strategyName = `${entryLabel} → ${currentLabel}`;
      header.iconClass = 'fa-exchange-alt';
    }

    const formatContractCell = (pos, compact) =>
      pos ? formatContractLink(pos.call || pos.put, pos.callURL || pos.putURL, compact) : '—';

    const formatLeverageCell = (pos) => {
      if (!pos || pos.maxLeverage == null) return '—';
      return `<span class="text-good text-nowrap">${Number(pos.maxLeverage).toFixed(2)}x</span>`;
    };

    let contractDiff = '', contractDiffClass = 'text-neutral-alt';
    let dteDiffText = '', dteDiffClass = 'text-neutral-alt';
    let spotDiffText = '', spotDiffClass = 'text-neutral-alt';
    let strikeDiffText = '', strikeDiffClass = 'text-neutral-alt';
    let moneyDiffText = '', moneyDiffClass = 'text-neutral-alt';
    let undDiffText = '', undDiffClass = 'text-neutral-alt';
    let levDiffText = '', levDiffClass = 'text-neutral-alt';
    let beMoneyDiffText = '', beMoneyDiffClass = 'text-neutral-alt';
    let beUndDiffText = '', beUndDiffClass = 'text-neutral-alt';

    if (hasDiff) {
      // 1. Contract
      const entryOpt = entryPos.call || entryPos.put;
      const curOpt = currentPos.call || currentPos.put;
      const sameContract = entryOpt === curOpt && entryPos.strategyType === currentPos.strategyType;
      if (sameContract) {
        contractDiff = 'Same';
        contractDiffClass = 'text-muted-alt';
      } else if (isDirectionFlip) {
        contractDiff = entryPos.strategyType === 'longCall' ? 'Roll (C→P)' : 'Roll (P→C)';
        contractDiffClass = 'text-warning-icon';
      } else {
        contractDiff = 'Roll';
        contractDiffClass = 'text-warning-icon';
      }

      // 2. Expiration
      const dteRes = computeDteDiff(entryPos.DTE, currentPos.DTE);
      dteDiffText = dteRes.text;
      dteDiffClass = dteRes.className;

      // 3. Spot Price
      const spotRes = computeSpotDiff(entryPos.spotPrice, currentPos.spotPrice);
      spotDiffText = spotRes.text;
      spotDiffClass = spotRes.className;

      // 4. Strike Price
      const strikeDirectionGood = isDirectionFlip ? null : (activePos.strategyType === 'longPut');
      const strikeRes = computePriceDiff(entryPos.strikeAbsolute, currentPos.strikeAbsolute, strikeDirectionGood);
      strikeDiffText = strikeRes.text;
      strikeDiffClass = strikeRes.className;

      // 5. Capital (Money)
      const moneyRes = computeCapitalDiff(-entryPos.moneySize, -currentPos.moneySize, isRoll);
      moneyDiffText = moneyRes.text;
      moneyDiffClass = moneyRes.className;

      // 6. Capital (Underlying)
      const undRes = computeCapitalDiff(
        entryPos.costInUnderlying,
        currentPos.costInUnderlying,
        isRoll,
        v => `${v >= 0 ? '+' : ''}${underlyingFmt.format(v)}`
      );
      undDiffText = undRes.text;
      undDiffClass = undRes.className;

      // 7. Leverage
      const entryLev = Number(entryPos.maxLeverage);
      const currentLev = Number(currentPos.maxLeverage);
      const levDiff = currentLev - entryLev;
      const levPct = entryLev > 0 ? (levDiff / entryLev) * 100 : 0;
      levDiffText = `${levDiff >= 0 ? '+' : ''}${levDiff.toFixed(2)}x<br/><small>(${levDiff >= 0 ? '+' : ''}${levPct.toFixed(1)}%)</small>`;
      levDiffClass = levDiff >= 0 ? 'text-good' : 'text-bad';

      // 8. Breakevens
      const beDirectionGood = isDirectionFlip ? null : (activePos.strategyType === 'longPut');
      const beMoneyRes = computePriceDiff(
        entryPos.breakEvenVsFullMoneyAbsolute,
        currentPos.breakEvenVsFullMoneyAbsolute,
        beDirectionGood
      );
      beMoneyDiffText = beMoneyRes.text;
      beMoneyDiffClass = beMoneyRes.className;

      const beUndRes = computePriceDiff(
        entryPos.breakEvenVsFullUnderlyingAbsolute,
        currentPos.breakEvenVsFullUnderlyingAbsolute,
        beDirectionGood
      );
      beUndDiffText = beUndRes.text;
      beUndDiffClass = beUndRes.className;
    }

    const isPut = activePos.strategyType === 'longPut';
    const strikeSubtitle = `<i class="fas fa-skull-crossbones me-1 text-warning-icon"></i>` + (
      isDirectionFlip
        ? '-100% loss threshold'
        : (isPut ? '-100% loss above this' : '-100% loss below this')
    );
    const levSubtitle = isDirectionFlip
      ? `Exposure vs 100% ${activePos.underlying}`
      : (isPut ? `Downside exposure vs 100% ${activePos.underlying}` : `Upside exposure vs 100% ${activePos.underlying}`);
    const beMoneySubtitle = `<i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i>` + (
      isDirectionFlip
        ? `Price for profit (${activePos.money})`
        : (isPut ? `Less ${activePos.money} above this` : `Less ${activePos.money} below this`)
    );
    const beUndSubtitle = `<i class="fas fa-rocket me-1 text-warning-icon"></i>` + (
      isDirectionFlip
        ? `Beats 100% ${activePos.underlying}`
        : (isPut ? `More ${activePos.underlying} below this` : `More ${activePos.underlying} above this`)
    );

    const sections = [
      {
        title: 'Parameters',
        rows: [
          {
            key: 'contract',
            label: 'Contract',
            subtitle: null,
            before: formatContractCell(entryPos, hasDiff),
            after: formatContractCell(currentPos, hasDiff),
            single: formatContractCell(activePos, false),
            diff: contractDiff,
            diffClass: contractDiffClass
          },
          {
            key: 'expiration',
            label: 'Expiration',
            subtitle: null,
            before: formatExpirationCell(entryPos, true),
            after: formatExpirationCell(currentPos, true),
            single: formatExpirationCell(activePos, false),
            diff: dteDiffText,
            diffClass: dteDiffClass
          },
          {
            key: 'spotPrice',
            label: 'Spot Price',
            subtitle: null,
            before: formatSpotCell(entryPos),
            after: formatSpotCell(currentPos),
            single: formatSpotCell(activePos),
            diff: spotDiffText,
            diffClass: spotDiffClass
          },
          {
            key: 'strikePrice',
            label: 'Strike Price',
            subtitle: strikeSubtitle,
            before: formatStrikeCell(entryPos, true),
            after: formatStrikeCell(currentPos, true),
            single: formatStrikeCell(activePos, false),
            diff: strikeDiffText,
            diffClass: strikeDiffClass
          },
          {
            key: 'capitalMoney',
            label: `Capital (${activePos.money})`,
            subtitle: null,
            before: formatCapitalMoneyCell(entryPos),
            after: formatCapitalMoneyCell(currentPos),
            single: formatCapitalMoneyCell(activePos),
            diff: moneyDiffText,
            diffClass: moneyDiffClass
          },
          {
            key: 'capitalUnderlying',
            label: `Capital (${activePos.underlying})`,
            subtitle: null,
            before: formatCapitalUnderlyingCell(entryPos, 'costInUnderlying', true),
            after: formatCapitalUnderlyingCell(currentPos, 'costInUnderlying', true),
            single: formatCapitalUnderlyingCell(activePos, 'costInUnderlying', false),
            diff: undDiffText,
            diffClass: undDiffClass
          }
        ]
      },
      {
        title: 'Outcomes at Expiration',
        rows: [
          {
            key: 'leverage',
            label: 'Leverage',
            subtitle: levSubtitle,
            before: formatLeverageCell(entryPos),
            after: formatLeverageCell(currentPos),
            single: formatLeverageCell(activePos),
            diff: levDiffText,
            diffClass: levDiffClass
          }
        ]
      },
      {
        title: 'Breakevens',
        rows: [
          {
            key: 'beMoney',
            label: `vs 100% ${activePos.money}`,
            subtitle: beMoneySubtitle,
            before: formatBreakevenCell(entryPos?.breakEvenVsFullMoneyAbsolute, entryPos?.breakEvenVsFullMoneyRelative, entryPos?.spotPrice, true, 'text-bad'),
            after: formatBreakevenCell(currentPos?.breakEvenVsFullMoneyAbsolute, currentPos?.breakEvenVsFullMoneyRelative, currentPos?.spotPrice, true, 'text-bad'),
            single: formatBreakevenCell(activePos?.breakEvenVsFullMoneyAbsolute, activePos?.breakEvenVsFullMoneyRelative, activePos?.spotPrice, false, 'text-bad'),
            diff: beMoneyDiffText,
            diffClass: beMoneyDiffClass
          },
          {
            key: 'beUnderlying',
            label: `vs 100% ${activePos.underlying}`,
            subtitle: beUndSubtitle,
            before: formatBreakevenCell(entryPos?.breakEvenVsFullUnderlyingAbsolute, entryPos?.breakEvenVsFullUnderlyingRelative, entryPos?.spotPrice, true, 'text-good'),
            after: formatBreakevenCell(currentPos?.breakEvenVsFullUnderlyingAbsolute, currentPos?.breakEvenVsFullUnderlyingRelative, currentPos?.spotPrice, true, 'text-good'),
            single: formatBreakevenCell(activePos?.breakEvenVsFullUnderlyingAbsolute, activePos?.breakEvenVsFullUnderlyingRelative, activePos?.spotPrice, false, 'text-good'),
            diff: beUndDiffText,
            diffClass: beUndDiffClass
          }
        ]
      }
    ];

    return {
      mode,
      hasDiff,
      isRoll,
      header,
      sections
    };
  }
}

const _longOptionStrategyConfig = new LongOptionStrategyConfig();
StrategyRegistry['longCall'] = _longOptionStrategyConfig;
StrategyRegistry['longPut'] = _longOptionStrategyConfig;
StrategyRegistry['longOption'] = _longOptionStrategyConfig;

function renderLongOptionsChart(data, chartDom, idToSelect) {
  const underlying = data.at(0)?.underlying || '';
  const targetItem = data.find(item => item.id === idToSelect);
  const overlay = calculateLongOptionsOverlay(targetItem);

  let xStart = 0.0;
  let xEnd = 10.0;
  let yStart = 0.8;
  let yEnd = 1.2;

  const focusCoords = [
    targetItem ? [Number(targetItem.maxLeverage), Number(targetItem.breakEvenVsFullUnderlyingRelative)] : null,
    overlay?.entry || null
  ].filter(c => c && Number.isFinite(c[0]) && Number.isFinite(c[1]));

  for (const [fx, fy] of focusCoords) {
    xStart = Math.min(xStart, Math.max(0.0, fx - 1.0));
    xEnd = Math.max(xEnd, fx + 1.0);
    yStart = Math.min(yStart, Math.max(0.0, fy - 0.05));
    yEnd = Math.max(yEnd, fy + 0.05);
  }

  const defaultZoom = [xStart, xEnd, yStart, yEnd];
  [xStart, xEnd, yStart, yEnd] = resolveInitialChartZoom(defaultZoom);

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
      min: function (value) {
        const entry = calculateLongOptionsOverlay(null)?.entry;
        const minVal = entry ? Math.min(value.min, entry[0]) : value.min;
        return Math.max(0, minVal - 1.0);
      },
      max: function (value) {
        const entry = calculateLongOptionsOverlay(null)?.entry;
        const maxVal = entry ? Math.max(value.max, entry[0]) : value.max;
        return maxVal + 1.0;
      },
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
      min: function (value) {
        const entry = calculateLongOptionsOverlay(null)?.entry;
        const minVal = entry ? Math.min(value.min, entry[1]) : value.min;
        return Math.max(0.0, minVal - 0.05);
      },
      max: function (value) {
        const entry = calculateLongOptionsOverlay(null)?.entry;
        const maxVal = entry ? Math.max(value.max, entry[1]) : value.max;
        return maxVal + 0.05;
      }
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
      },
      buildEntryOverlaySeries(overlay)
    ],
    legend: legend,
    animationDurationUpdate: 800,
    animationEasingUpdate: 'quinticOut',
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        filterMode: 'none',
        startValue: xStart,
        endValue: xEnd
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        filterMode: 'none',
        startValue: yStart,
        endValue: yEnd
      }
    ],
  }, true);

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
  bindChartZoomSync(chart, defaultZoom);

  selectStrategyById(idToSelect);
  return chart;
}
