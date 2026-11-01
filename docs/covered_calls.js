

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
    if (!entryPos && !currentPos) return null;

    const hasDiff = Boolean(entryPos && currentPos);
    const activePos = currentPos || entryPos;

    // Rolls mean replacing the old position with a new one.
    // Their difference does not represent a loss or a gain.
    // If it's not a roll, i.e. we are comparing the same position in two different moments,
    // then the difference is the unrealized loss or gain.
    // In both cases we are showing the diff of the various important aspects,
    // but only the direction of the good/bad changes.
    // E.g. for an unrealized result, going to less capital means a capital loss.
    // But for a roll, it means that we get more premium, thus capital return,
    // thus we retain less risk, which is "good".
    const isRoll = hasDiff && currentPos.id !== entryPos.id;
    const mode = hasDiff ? (isRoll ? 'roll' : 'unrealized') : (entryPos ? 'pinnedOnly' : 'single');

    const header = prepareCCData(activePos);

    const formatContractCell = (pos, compact) => {
      if (!pos) return '—';
      const label = compact ? pos.call.replace(/^([A-Z]+-)/, '') : pos.call;
      if (pos.callURL) {
        return `<a href="${pos.callURL}" class="text-neutral" target="_blank" title="${pos.call}" style="text-decoration: underline;">${label}</a>`;
      }
      return `<span class="text-neutral" title="${pos.call}">${label}</span>`;
    };

    const formatExpirationCell = (pos, compact) => {
      if (!pos) return '—';
      const sep = compact ? '<br/>' : ' ';
      return `<span class="text-neutral text-nowrap">${pos.formattedDate}</span>${sep}<small class="text-bad text-nowrap">(${pos.DTE}d)</small>`;
    };

    const formatSpotCell = (pos) => {
      if (!pos) return '—';
      return `<span class="text-spot text-nowrap">${dollarFmt.format(Number(pos.spotPrice))}</span>`;
    };

    const formatStrikeCell = (pos, compact) => {
      if (!pos) return '—';
      const strike = Number(pos.strikeAbsolute);
      const spot = Number(pos.spotPrice);
      const rel = percentFmt.format(strike / spot - 1.0);
      const sep = compact ? '<br/>' : ' ';
      return `<span class="text-neutral text-nowrap">${dollarFmt.format(strike)}</span>${sep}<small class="strike-relative text-nowrap">(${rel})</small>`;
    };

    const formatCapitalMoneyCell = (pos) => {
      if (!pos) return '—';
      return `<span class="text-neutral text-nowrap">${dollarFmt.format(-pos.moneySize)}</span>`;
    };

    const formatCapitalUnderlyingCell = (pos, compact) => {
      if (!pos) return '—';
      const suffix = compact ? '' : ` ${pos.underlying}`;
      return `<span class="text-neutral text-nowrap">${underlyingFmt.format(pos.underlyingToBuy)}${suffix}</span>`;
    };

    const formatMoneyYieldCell = (pos, compact) => {
      if (!pos) return '—';
      const yieldStr = percentFmt.format(pos.moneyYield - 1.0);
      const profitStr = `+${dollarFmt.format(pos.moneyProfit)}`;
      const probStr = pos.moneyProbability != null ? `${Math.round(pos.moneyProbability * 100)}% prob` : '';
      if (compact) {
        return `<span class="text-good text-nowrap">${yieldStr}</span><br/><small class="text-good-alt text-nowrap">(${profitStr})</small>${probStr ? `<br/><small class="text-probs text-nowrap">${probStr}</small>` : ''}`;
      }
      return `<span class="text-good text-nowrap">${yieldStr} ${pos.money}</span> <small class="text-good-alt text-nowrap">(${profitStr})</small>${probStr ? `<br/><small class="text-probs text-nowrap">(${probStr})</small>` : ''}`;
    };

    const formatUndYieldCell = (pos, compact) => {
      if (!pos) return '—';
      const yieldStr = percentFmt.format(pos.underlyingYield - 1.0);
      const profitStr = `+${underlyingFmt.format(pos.premiumToReceive)} ${pos.underlying}`;
      const probStr = pos.underlyingProbability != null ? `${Math.round(pos.underlyingProbability * 100)}% prob` : '';
      if (compact) {
        return `<span class="text-good text-nowrap">${yieldStr}</span><br/><small class="text-good-alt text-nowrap">(+${underlyingFmt.format(pos.premiumToReceive)})</small>${probStr ? `<br/><small class="text-probs text-nowrap">${probStr}</small>` : ''}`;
      }
      return `<span class="text-good text-nowrap">${yieldStr} ${pos.underlying}</span> <small class="text-good-alt text-nowrap">(${profitStr})</small>${probStr ? `<br/><small class="text-probs text-nowrap">(${probStr})</small>` : ''}`;
    };

    const formatBeMoneyCell = (pos, compact) => {
      if (!pos) return '—';
      const absStr = dollarFmt.format(pos.breakEvenVsFullMoneyAbsolute);
      const relStr = percentFmt.format(pos.breakEvenVsFullMoneyRelative - 1.0);
      const sep = compact ? '<br/>' : ' ';
      return `<span class="text-neutral text-nowrap">${absStr}</span>${sep}<small class="text-bad text-nowrap">(${relStr})</small>`;
    };

    const formatBeUndCell = (pos, compact) => {
      if (!pos) return '—';
      const absStr = dollarFmt.format(pos.breakEvenVsFullUnderlyingAbsolute);
      const relStr = percentFmt.format(pos.breakEvenVsFullUnderlyingRelative - 1.0);
      const sep = compact ? '<br/>' : ' ';
      return `<span class="text-neutral text-nowrap">${absStr}</span>${sep}<small class="text-good text-nowrap">(${relStr})</small>`;
    };

    // Diff calculations when both entryPos and currentPos are present
    let contractDiff = '', contractDiffClass = 'text-neutral-alt';
    let dteDiffText = '', dteDiffClass = 'text-neutral-alt';
    let spotDiffText = '', spotDiffClass = 'text-neutral-alt';
    let strikeDiffText = '', strikeDiffClass = 'text-neutral-alt';
    let moneyDiffText = '', moneyDiffClass = 'text-neutral-alt';
    let undDiffText = '', undDiffClass = 'text-neutral-alt';
    let moneyYieldDiffText = '', moneyYieldDiffClass = 'text-neutral-alt';
    let undYieldDiffText = '', undYieldDiffClass = 'text-neutral-alt';
    let beMoneyDiffText = '', beMoneyDiffClass = 'text-neutral-alt';
    let beUndDiffText = '', beUndDiffClass = 'text-neutral-alt';

    if (hasDiff) {
      // 1. Contract
      const sameContract = entryPos.call === currentPos.call;
      contractDiff = sameContract ? 'Same' : 'Roll';
      contractDiffClass = sameContract ? 'text-muted-alt' : 'text-warning-icon';

      // 2. Expiration
      const dteDiff = currentPos.DTE - entryPos.DTE;
      const dtePct = entryPos.DTE > 0 ? (dteDiff / entryPos.DTE) * 100 : 0;
      dteDiffText = `${dteDiff >= 0 ? '+' : ''}${dteDiff}d<br/><small>(${dteDiff >= 0 ? '+' : ''}${dtePct.toFixed(1)}%)</small>`;
      dteDiffClass = dteDiff > 0 ? 'text-bad' : (dteDiff < 0 ? 'text-good' : 'text-neutral-alt');

      // 3. Spot Price
      const entrySpot = Number(entryPos.spotPrice);
      const currentSpot = Number(currentPos.spotPrice);
      const spotDiff = currentSpot - entrySpot;
      const spotPct = entrySpot > 0 ? (spotDiff / entrySpot) * 100 : 0;
      spotDiffText = `${spotDiff >= 0 ? '+' : ''}${dollarFmt.format(spotDiff)}<br/><small>(${spotDiff >= 0 ? '+' : ''}${spotPct.toFixed(1)}%)</small>`;
      spotDiffClass = spotDiff >= 0 ? 'text-good' : 'text-bad';

      // 4. Strike Price
      const entryStrike = Number(entryPos.strikeAbsolute);
      const currentStrike = Number(currentPos.strikeAbsolute);
      const strikeDiff = currentStrike - entryStrike;
      const strikeDiffPct = entryStrike > 0 ? (strikeDiff / entryStrike) * 100 : 0;
      strikeDiffText = `${strikeDiff >= 0 ? '+' : ''}${dollarFmt.format(strikeDiff)}<br/><small>(${strikeDiff >= 0 ? '+' : ''}${strikeDiffPct.toFixed(1)}%)</small>`;
      strikeDiffClass = strikeDiff > 0 ? 'text-good' : (strikeDiff < 0 ? 'text-bad' : 'text-neutral-alt');

      // 5. Capital (Money)
      const entryMoney = -entryPos.moneySize;
      const currentMoney = -currentPos.moneySize;
      const moneyDiff = currentMoney - entryMoney;
      const moneyPct = entryMoney > 0 ? (moneyDiff / entryMoney) * 100 : 0;
      moneyDiffText = `${moneyDiff >= 0 ? '+' : ''}${dollarFmt.format(moneyDiff)}<br/><small>(${moneyDiff >= 0 ? '+' : ''}${moneyPct.toFixed(1)}%)</small>`;
      moneyDiffClass = isRoll
        ? (moneyDiff <= 0 ? 'text-good' : 'text-bad')
        : (moneyDiff >= 0 ? 'text-good' : 'text-bad');

      // 6. Capital (Underlying)
      const undDiff = currentPos.underlyingToBuy - entryPos.underlyingToBuy;
      const undPct = entryPos.underlyingToBuy > 0 ? (undDiff / entryPos.underlyingToBuy) * 100 : 0;
      undDiffText = `${undDiff >= 0 ? '+' : ''}${underlyingFmt.format(undDiff)}<br/><small>(${undDiff >= 0 ? '+' : ''}${undPct.toFixed(1)}%)</small>`;
      undDiffClass = isRoll
        ? (undDiff <= 0 ? 'text-good' : 'text-bad')
        : (undDiff >= 0 ? 'text-good' : 'text-bad');

      // 7. Money Yield
      const moneyYieldRatioChange = currentPos.moneyYield / entryPos.moneyYield - 1.0;
      const profitDiff = currentPos.moneyProfit - entryPos.moneyProfit;
      moneyYieldDiffText = `${percentFmt.format(moneyYieldRatioChange)}<br/><small>(${profitDiff >= 0 ? '+' : ''}${dollarFmt.format(profitDiff)})</small>`;
      moneyYieldDiffClass = moneyYieldRatioChange >= 0 ? 'text-good' : 'text-bad';

      // 8. Underlying Yield
      const undYieldRatioChange = currentPos.underlyingYield / entryPos.underlyingYield - 1.0;
      const premDiff = currentPos.premiumToReceive - entryPos.premiumToReceive;
      undYieldDiffText = `${percentFmt.format(undYieldRatioChange)}<br/><small>(${premDiff >= 0 ? '+' : ''}${underlyingFmt.format(premDiff)})</small>`;
      undYieldDiffClass = undYieldRatioChange >= 0 ? 'text-good' : 'text-bad';

      // 9. Breakeven (vs full money)
      const beMoneyDiff = currentPos.breakEvenVsFullMoneyAbsolute - entryPos.breakEvenVsFullMoneyAbsolute;
      const beMoneyDiffPct = entryPos.breakEvenVsFullMoneyAbsolute > 0 ? (beMoneyDiff / entryPos.breakEvenVsFullMoneyAbsolute) * 100 : 0;
      beMoneyDiffText = `${beMoneyDiff >= 0 ? '+' : ''}${dollarFmt.format(beMoneyDiff)}<br/><small>(${beMoneyDiff >= 0 ? '+' : ''}${beMoneyDiffPct.toFixed(1)}%)</small>`;
      beMoneyDiffClass = beMoneyDiff <= 0 ? 'text-good' : 'text-bad';

      // 10. Breakeven (vs full underlying)
      const beUndDiff = currentPos.breakEvenVsFullUnderlyingAbsolute - entryPos.breakEvenVsFullUnderlyingAbsolute;
      const beUndDiffPct = entryPos.breakEvenVsFullUnderlyingAbsolute > 0 ? (beUndDiff / entryPos.breakEvenVsFullUnderlyingAbsolute) * 100 : 0;
      beUndDiffText = `${beUndDiff >= 0 ? '+' : ''}${dollarFmt.format(beUndDiff)}<br/><small>(${beUndDiff >= 0 ? '+' : ''}${beUndDiffPct.toFixed(1)}%)</small>`;
      beUndDiffClass = beUndDiff >= 0 ? 'text-good' : 'text-bad';
    }

    const sameStrike = !hasDiff || Number(entryPos.strikeAbsolute) === Number(currentPos.strikeAbsolute);
    const strikeLabelForOutcome = sameStrike
      ? dollarFmt.format(Number(activePos.strikeAbsolute))
      : 'Strike';

    const sections = [
      {
        title: 'Parameters',
        rows: [
          {
            label: 'Contract',
            subtitle: null,
            before: formatContractCell(entryPos, hasDiff),
            after: formatContractCell(currentPos, hasDiff),
            single: formatContractCell(activePos, false),
            diff: contractDiff,
            diffClass: contractDiffClass
          },
          {
            label: 'Expiration',
            subtitle: null,
            before: formatExpirationCell(entryPos, true),
            after: formatExpirationCell(currentPos, true),
            single: formatExpirationCell(activePos, false),
            diff: dteDiffText,
            diffClass: dteDiffClass
          },
          {
            label: 'Spot Price',
            subtitle: null,
            before: formatSpotCell(entryPos),
            after: formatSpotCell(currentPos),
            single: formatSpotCell(activePos),
            diff: spotDiffText,
            diffClass: spotDiffClass
          },
          {
            label: 'Strike Price',
            subtitle: null,
            before: formatStrikeCell(entryPos, true),
            after: formatStrikeCell(currentPos, true),
            single: formatStrikeCell(activePos, false),
            diff: strikeDiffText,
            diffClass: strikeDiffClass
          },
          {
            label: `Capital (${activePos.money})`,
            subtitle: null,
            before: formatCapitalMoneyCell(entryPos),
            after: formatCapitalMoneyCell(currentPos),
            single: formatCapitalMoneyCell(activePos),
            diff: moneyDiffText,
            diffClass: moneyDiffClass
          },
          {
            label: `Capital (${activePos.underlying})`,
            subtitle: null,
            before: formatCapitalUnderlyingCell(entryPos, true),
            after: formatCapitalUnderlyingCell(currentPos, true),
            single: formatCapitalUnderlyingCell(activePos, false),
            diff: undDiffText,
            diffClass: undDiffClass
          }
        ]
      },
      {
        title: 'Outcomes at Expiration',
        rows: [
          {
            label: `${activePos.money} Yield`,
            subtitle: `If ${activePos.underlying} &ge; ${strikeLabelForOutcome}`,
            before: formatMoneyYieldCell(entryPos, true),
            after: formatMoneyYieldCell(currentPos, true),
            single: formatMoneyYieldCell(activePos, false),
            diff: moneyYieldDiffText,
            diffClass: moneyYieldDiffClass
          },
          {
            label: `${activePos.underlying} Yield`,
            subtitle: `If ${activePos.underlying} &lt; ${strikeLabelForOutcome}`,
            before: formatUndYieldCell(entryPos, true),
            after: formatUndYieldCell(currentPos, true),
            single: formatUndYieldCell(activePos, false),
            diff: undYieldDiffText,
            diffClass: undYieldDiffClass
          }
        ]
      },
      {
        title: 'Breakevens',
        rows: [
          {
            label: `vs 100% ${activePos.money}`,
            subtitle: `<i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i>Less ${activePos.money} below this`,
            before: formatBeMoneyCell(entryPos, true),
            after: formatBeMoneyCell(currentPos, true),
            single: formatBeMoneyCell(activePos, false),
            diff: beMoneyDiffText,
            diffClass: beMoneyDiffClass
          },
          {
            label: `vs 100% ${activePos.underlying}`,
            subtitle: `<i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i>Less ${activePos.underlying} above this`,
            before: formatBeUndCell(entryPos, true),
            after: formatBeUndCell(currentPos, true),
            single: formatBeUndCell(activePos, false),
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
          data: overlay?.entry ? [{ coord: overlay.entry }] : []
        },
        markLine: {
          data: (overlay?.entry && overlay?.current) ? [[{ coord: overlay.entry }, { coord: overlay.current }]] : []
        }
      }]
    });
  }
};

function calculateOverlay(target) {
  const store = getAppStore();
  const entryPosition = store ? store.entryPosition : null;
  if (!entryPosition) return null;

  const { moneyYield, underlyingYield } = entryPosition;
  if (!target) {
    return {
      entry: [moneyYield, underlyingYield],
      current: null
    };
  }

  const moneyRatio = target.moneyYield ? moneyYield / target.moneyYield : null;
  const underlyingRatio = target.underlyingYield ? underlyingYield / target.underlyingYield : null;
  const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
  const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

  return {
    entry: [moneyYield, underlyingYield],
    current: (moneyDiffers || underlyingDiffers) ? [target.moneyYield, target.underlyingYield] : null
  };
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
          data: overlay?.entry ? [{ coord: overlay.entry }] : []
        },
        markLine: {
          symbol: ['none', 'arrow'],
          symbolSize: 18,
          lineStyle: {
            color: '#e1e355ff',
            width: 3,
            type: 'solid'
          },
          data: (overlay?.entry && overlay?.current) ? [[{ coord: overlay.entry }, { coord: overlay.current }]] : []
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
