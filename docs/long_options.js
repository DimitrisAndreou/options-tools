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

  const entryX = Number(entryPosition.maxLeverage);
  const entryY = Number(entryPosition.breakEvenVsFullUnderlyingRelative);
  if (!Number.isFinite(entryX) || !Number.isFinite(entryY)) return null;

  if (!target) {
    return {
      entry: [entryX, entryY],
      current: null
    };
  }

  const targetX = Number(target.maxLeverage);
  const targetY = Number(target.breakEvenVsFullUnderlyingRelative);
  if (!Number.isFinite(targetX) || !Number.isFinite(targetY)) {
    return {
      entry: [entryX, entryY],
      current: null
    };
  }

  const xDiffers = Math.abs(entryX - targetX) > 1e-4;
  const yDiffers = Math.abs(entryY - targetY) > 1e-4;

  return {
    entry: [entryX, entryY],
    current: (xDiffers || yDiffers) ? [targetX, targetY] : null
  };
}

class LongOptionStrategyConfig extends BaseStrategyConfig {
  prepareData = prepareLongOptionData;
  renderTooltip = renderTooltipLongOption;

  createEntryPosition(pos) {
    if (!pos || pos.id === undefined) {
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

    const formatContractCell = (pos, compact) => {
      if (!pos) return '—';
      const rawName = pos.call || pos.put;
      const url = pos.callURL || pos.putURL;
      const formatted = formatOptionName(rawName);
      const label = compact ? formatted.replace(/^([A-Z0-9.^_-]+-)/, '') : formatted;
      return url
        ? `<a href="${url}" class="text-neutral" target="_blank" title="${formatted}" style="text-decoration: underline;">${label}</a>`
        : `<span class="text-neutral" title="${formatted}">${label}</span>`;
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
      const rel = spot > 0
        ? percentFmt.format(strike / spot - 1.0)
        : percentFmt.format(Number(pos.strikeRelative) - 1.0);
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
      return `<span class="text-neutral text-nowrap">${underlyingFmt.format(pos.costInUnderlying)}${suffix}</span>`;
    };

    const formatLeverageCell = (pos) => {
      if (!pos || pos.maxLeverage == null) return '—';
      return `<span class="text-good text-nowrap">${Number(pos.maxLeverage).toFixed(2)}x</span>`;
    };

    const formatBeCell = (absVal, relVal, spotVal, compact, relCls) => {
      if (absVal == null || !Number.isFinite(Number(absVal))) return '—';
      const absNum = Number(absVal);
      const spot = Number(spotVal);
      const rel = spot > 0
        ? percentFmt.format(absNum / spot - 1.0)
        : percentFmt.format(Number(relVal) - 1.0);
      const sep = compact ? '<br/>' : ' ';
      return `<span class="text-neutral text-nowrap">${dollarFmt.format(absNum)}</span>${sep}<small class="${relCls} text-nowrap">(${rel})</small>`;
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

    const computePriceDiff = (entryVal, curVal, higherIsGood) => {
      if (entryVal == null || curVal == null) {
        return { text: '—', className: 'text-muted-alt' };
      }
      const e = Number(entryVal);
      const c = Number(curVal);
      const diff = c - e;
      const pct = e > 0 ? (diff / e) * 100 : 0;
      const text = `${formatSignedDollar(diff)}<br/><small>(${diff >= 0 ? '+' : ''}${pct.toFixed(1)}%)</small>`;
      if (diff === 0 || higherIsGood == null) {
        return { text, className: 'text-neutral-alt' };
      }
      const isGood = higherIsGood ? diff > 0 : diff < 0;
      return { text, className: isGood ? 'text-good' : 'text-bad' };
    };

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
      const dteDiff = currentPos.DTE - entryPos.DTE;
      const dtePct = entryPos.DTE > 0 ? (dteDiff / entryPos.DTE) * 100 : 0;
      dteDiffText = `${dteDiff >= 0 ? '+' : ''}${dteDiff}d<br/><small>(${dteDiff >= 0 ? '+' : ''}${dtePct.toFixed(1)}%)</small>`;
      dteDiffClass = dteDiff > 0 ? 'text-bad' : (dteDiff < 0 ? 'text-good' : 'text-neutral-alt');

      // 3. Spot Price
      const entrySpot = Number(entryPos.spotPrice);
      const currentSpot = Number(currentPos.spotPrice);
      const spotDiff = currentSpot - entrySpot;
      const spotPct = entrySpot > 0 ? (spotDiff / entrySpot) * 100 : 0;
      spotDiffText = `${formatSignedDollar(spotDiff)}<br/><small>(${spotDiff >= 0 ? '+' : ''}${spotPct.toFixed(1)}%)</small>`;
      spotDiffClass = spotDiff >= 0 ? 'text-good' : 'text-bad';

      // 4. Strike Price
      const strikeDirectionGood = isDirectionFlip ? null : (activePos.strategyType === 'longPut');
      const strikeRes = computePriceDiff(entryPos.strikeAbsolute, currentPos.strikeAbsolute, strikeDirectionGood);
      strikeDiffText = strikeRes.text;
      strikeDiffClass = strikeRes.className;

      // 5. Capital (Money)
      const entryMoney = -Number(entryPos.moneySize);
      const currentMoney = -Number(currentPos.moneySize);
      const moneyDiff = currentMoney - entryMoney;
      const moneyPct = entryMoney > 0 ? (moneyDiff / entryMoney) * 100 : 0;
      moneyDiffText = `${formatSignedDollar(moneyDiff)}<br/><small>(${moneyDiff >= 0 ? '+' : ''}${moneyPct.toFixed(1)}%)</small>`;
      moneyDiffClass = isRoll
        ? (moneyDiff <= 0 ? 'text-good' : 'text-bad')
        : (moneyDiff >= 0 ? 'text-good' : 'text-bad');

      // 6. Capital (Underlying)
      const entryUnd = Number(entryPos.costInUnderlying);
      const currentUnd = Number(currentPos.costInUnderlying);
      const undDiff = currentUnd - entryUnd;
      const undPct = entryUnd > 0 ? (undDiff / entryUnd) * 100 : 0;
      undDiffText = `${undDiff >= 0 ? '+' : ''}${underlyingFmt.format(undDiff)}<br/><small>(${undDiff >= 0 ? '+' : ''}${undPct.toFixed(1)}%)</small>`;
      undDiffClass = isRoll
        ? (undDiff <= 0 ? 'text-good' : 'text-bad')
        : (undDiff >= 0 ? 'text-good' : 'text-bad');

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
            before: formatBeCell(entryPos?.breakEvenVsFullMoneyAbsolute, entryPos?.breakEvenVsFullMoneyRelative, entryPos?.spotPrice, true, 'text-bad'),
            after: formatBeCell(currentPos?.breakEvenVsFullMoneyAbsolute, currentPos?.breakEvenVsFullMoneyRelative, currentPos?.spotPrice, true, 'text-bad'),
            single: formatBeCell(activePos?.breakEvenVsFullMoneyAbsolute, activePos?.breakEvenVsFullMoneyRelative, activePos?.spotPrice, false, 'text-bad'),
            diff: beMoneyDiffText,
            diffClass: beMoneyDiffClass
          },
          {
            key: 'beUnderlying',
            label: `vs 100% ${activePos.underlying}`,
            subtitle: beUndSubtitle,
            before: formatBeCell(entryPos?.breakEvenVsFullUnderlyingAbsolute, entryPos?.breakEvenVsFullUnderlyingRelative, entryPos?.spotPrice, true, 'text-good'),
            after: formatBeCell(currentPos?.breakEvenVsFullUnderlyingAbsolute, currentPos?.breakEvenVsFullUnderlyingRelative, currentPos?.spotPrice, true, 'text-good'),
            single: formatBeCell(activePos?.breakEvenVsFullUnderlyingAbsolute, activePos?.breakEvenVsFullUnderlyingRelative, activePos?.spotPrice, false, 'text-good'),
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
    if (!chart) return;

    const targetItem = store?.chartData?.find(item => item.id === idToSelect);
    const overlay = calculateLongOptionsOverlay(targetItem);

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
