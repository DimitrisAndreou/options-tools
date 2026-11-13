function formatCleanStrikeNumber(val) {
  const n = Number(val);
  if (!Number.isFinite(n)) return String(val);
  return Number.isInteger(n) ? String(n) : String(Number(n.toFixed(4)));
}

function getExpiryTargetPrice(item) {
  if (!item) return 0;
  if (item.maxYieldAtAbsolute != null && Number.isFinite(Number(item.maxYieldAtAbsolute))) {
    return Number(item.maxYieldAtAbsolute);
  }
  return Number(item.spreadType === 'over' ? item.highStrike : item.lowStrike);
}

function formatTouchBetInstructions(rawInstructions, item, isTouchMode) {
  if (!Array.isArray(rawInstructions)) return [];
  return rawInstructions.map(inst => {
    const isBuy = inst.action === 'Buy';
    const isSell = inst.action === 'Sell';
    const sizeNum = Number(inst.size);
    const sizeStr = Number.isFinite(sizeNum) ? Number(sizeNum.toFixed(4)) : inst.size;
    let unitText = formatOptionName(inst.unit);
    if (!isTouchMode && item && inst.action === 'Hold to Expiration') {
      const cmp = item.spreadType === 'over' ? '>=' : '<=';
      const expiryStrike = formatCleanStrikeNumber(getExpiryTargetPrice(item));
      unitText = `payout if ${item.underlying} ${cmp} ${expiryStrike}`;
    }
    return {
      action: inst.action,
      target: `${sizeStr}x ${unitText}`,
      targetClass: isBuy ? 'text-good' : (isSell ? 'text-bad' : 'text-probs'),
      consideration: dollarFmt.format(Number(inst.price)),
      considerationClass: isBuy ? 'text-bad' : 'text-good'
    };
  });
}

function buildTouchBetSideData(item, isTouchMode, isYesSide) {
  if (!item) return null;

  const rawYield = Number(isTouchMode ? item.maxYield : item.expirationMaxYield);
  const rawProfit = Number(isTouchMode ? item.maxProfit : item.expirationMaxProfit);
  const rawRisk = Number(isTouchMode ? item.maxRisk : item.expirationMaxRisk);
  const rawProb = Number(isTouchMode ? item.winProbability : item.expirationWinProbability);
  const rawInstructions = isTouchMode ? item.instructions : item.expirationInstructions;

  const touchExitStr = dollarFmt.format(Number(item.touchExitValue));
  const fullWidthStr = dollarFmt.format(Number(item.spreadPayoffWidth));
  const payoutStr = (isTouchMode && isYesSide) ? touchExitStr : fullWidthStr;

  const spotVal = Number(item.spotPrice);
  const lowStrikeStr = dollarFmt.format(Number(item.lowStrike));
  const highStrikeStr = dollarFmt.format(Number(item.highStrike));
  const midpointAbsStr = dollarFmt.format(Number(item.targetPriceAbsolute));
  const midpointRelStr = percentFmt.format(Number(item.targetPriceRelative) - 1.0);

  const expiryTargetVal = getExpiryTargetPrice(item);
  const expiryTargetAbsStr = dollarFmt.format(expiryTargetVal);
  const expiryTargetRelStr = spotVal > 0
    ? percentFmt.format(expiryTargetVal / spotVal - 1.0)
    : midpointRelStr;
  const expiryCmp = item.spreadType === 'over' ? '≥' : '≤';

  const targetRowLabel = isTouchMode ? 'Target Price' : 'Max Payoff Price';
  const targetRowSubtitle = isTouchMode
    ? `Midpoint of [${lowStrikeStr} – ${highStrikeStr}]`
    : `Spread [${lowStrikeStr} – ${highStrikeStr}]`;
  const targetRowAbsolute = isTouchMode
    ? midpointAbsStr
    : `${expiryCmp} ${expiryTargetAbsStr}`;
  const targetRowRelative = isTouchMode ? midpointRelStr : expiryTargetRelStr;

  const eventSummary = isTouchMode
    ? `${item.underlying} touches ${midpointAbsStr} (${midpointRelStr}) within ${item.DTE}d`
    : `${item.underlying} expires ${expiryCmp} ${expiryTargetAbsStr} (${expiryTargetRelStr}) in ${item.DTE}d`;

  const tabLabel = isTouchMode
    ? (isYesSide ? `Bet YES: Touches ${midpointAbsStr}` : `Bet NO: Never touches ${midpointAbsStr}`)
    : `Bet ${isYesSide ? 'YES' : 'NO'}: Expires ${expiryCmp} ${expiryTargetAbsStr}`;

  const shortLabel = isTouchMode
    ? (isYesSide ? 'Touch' : 'No-Touch')
    : `${expiryCmp} ${expiryTargetAbsStr}`;

  const hasBe = item.breakEvenVsFullMoneyAbsolute != null && item.breakEvenVsFullMoneyRelative != null;
  const breakevenStr = hasBe
    ? `${dollarFmt.format(Number(item.breakEvenVsFullMoneyAbsolute))} (${percentFmt.format(Number(item.breakEvenVsFullMoneyRelative) - 1.0)})`
    : '—';

  return {
    id: item.id,
    betType: item.betType,
    spreadType: item.spreadType,
    spreadTypeName: item.spreadType === 'over' ? 'Bull (Over) Spread' : 'Bear (Under) Spread',
    strategyURL: item.strategyURL,
    longLeg: formatOptionName(item.longLeg),
    longLegURL: item.longLegURL,
    shortLeg: formatOptionName(item.shortLeg),
    shortLegURL: item.shortLegURL,
    probRaw: rawProb,
    probPct: unsignedPercentFmt.format(rawProb),
    yieldRaw: rawYield,
    yieldPct: percentFmt.format(rawYield - 1.0),
    yieldMultiple: `${rawYield.toFixed(2)}x`,
    profitRaw: rawProfit,
    profitStr: formatSignedDollar(rawProfit),
    riskRaw: rawRisk,
    riskStr: dollarFmt.format(rawRisk),
    payoutStr,
    breakevenStr,
    targetRowLabel,
    targetRowSubtitle,
    targetRowAbsolute,
    targetRowRelative,
    eventSummary,
    tabLabel,
    shortLabel,
    instructions: formatTouchBetInstructions(rawInstructions, item, isTouchMode)
  };
}

let _touchBetGroupsByKey = new Map();

function getTouchBetNodeKey(item) {
  return `${item.formattedDate}~${item.targetPriceAbsolute}`;
}

function pairTouchBetNodes(rawItems) {
  _touchBetGroupsByKey = new Map();
  if (!Array.isArray(rawItems)) return [];
  for (const item of rawItems) {
    const key = getTouchBetNodeKey(item);
    let g = _touchBetGroupsByKey.get(key);
    if (!g) {
      g = { touch: null, noTouch: null, primary: null };
      _touchBetGroupsByKey.set(key, g);
    }
    if (item.betType === 'touch') {
      g.touch = item;
    } else {
      g.noTouch = item;
    }
    g.primary = g.touch || g.noTouch;
  }

  const nodes = [];
  for (const g of _touchBetGroupsByKey.values()) {
    if (g.primary) {
      nodes.push(g.primary);
    }
  }
  return nodes;
}

function getTouchBetGroupForItem(value) {
  if (!value) return { touch: null, noTouch: null, primary: null };
  const key = getTouchBetNodeKey(value);
  let g = _touchBetGroupsByKey.get(key);
  if (!g) {
    const store = getAppStore();
    if (store && Array.isArray(store.chartData)) {
      pairTouchBetNodes(store.chartData);
      g = _touchBetGroupsByKey.get(key);
    }
  }
  if (g) return g;
  return {
    touch: value.betType === 'touch' ? value : null,
    noTouch: value.betType === 'noTouch' ? value : null,
    primary: value
  };
}

function prepareTouchBetData(value) {
  if (!value) return null;
  const store = getAppStore();
  const oddsMode = store?.oddsMode || 'touch';
  const isTouchMode = oddsMode === 'touch';

  const group = getTouchBetGroupForItem(value);
  const touchItem = group.touch;
  const noTouchItem = group.noTouch;
  const primary = group.primary || value;
  const money = primary.money;
  const underlying = primary.underlying;
  const isUpsideTarget = Boolean(primary.isUpsideTarget);
  const directionArrow = isUpsideTarget ? '▲' : '▼';
  const directionWord = isUpsideTarget ? 'above' : 'below';
  const oppositeDirectionWord = isUpsideTarget ? 'at or below' : 'at or above';

  const spotVal = Number(primary.spotPrice);
  const targetAbsolute = dollarFmt.format(Number(primary.targetPriceAbsolute));
  const targetRelative = percentFmt.format(Number(primary.targetPriceRelative) - 1.0);
  const lowStrikeVal = Number(primary.lowStrike);
  const highStrikeVal = Number(primary.highStrike);
  const lowStrike = dollarFmt.format(lowStrikeVal);
  const highStrike = dollarFmt.format(highStrikeVal);
  const spotPrice = dollarFmt.format(spotVal);

  const yesSide = buildTouchBetSideData(touchItem, isTouchMode, true);
  const noSide = buildTouchBetSideData(noTouchItem, isTouchMode, false);

  const yesProbRaw = yesSide
    ? yesSide.probRaw
    : (noSide ? 1.0 - noSide.probRaw : 0.0);
  const noProbRaw = 1.0 - yesProbRaw;

  const yesProbPct = unsignedPercentFmt.format(yesProbRaw);
  const noProbPct = unsignedPercentFmt.format(noProbRaw);
  const yesBarWidth = `${Math.max(6, Math.min(94, Math.round(yesProbRaw * 100)))}%`;

  const discountFactor = Number(primary.discountFactor ?? 1.0);
  const impliedInterestRate = Number(primary.impliedInterestRate ?? 0.0);
  const impliedApr = Number(primary.impliedApr ?? 0.0);
  const spreadPayoffWidth = Number(primary.spreadPayoffWidth ?? 0.0);
  const boxPresentValue = Number(primary.boxPresentValue ?? spreadPayoffWidth);

  const yesExpiryPrice = isUpsideTarget ? highStrikeVal : lowStrikeVal;
  const noExpiryPrice = isUpsideTarget ? lowStrikeVal : highStrikeVal;
  const yesExpiryCmp = isUpsideTarget ? '≥' : '≤';
  const noExpiryCmp = isUpsideTarget ? '≤' : '≥';
  const yesExpiryAbsStr = dollarFmt.format(yesExpiryPrice);
  const noExpiryAbsStr = dollarFmt.format(noExpiryPrice);
  const yesExpiryRelStr = spotVal > 0
    ? percentFmt.format(yesExpiryPrice / spotVal - 1.0)
    : targetRelative;

  const eventSummary = isTouchMode
    ? `${underlying} touches ${targetAbsolute} (${targetRelative}) within ${primary.DTE}d`
    : (yesSide?.eventSummary || `${underlying} expires ${yesExpiryCmp} ${yesExpiryAbsStr} (${yesExpiryRelStr}) in ${primary.DTE}d`);

  const shortYesLabel = isTouchMode
    ? 'Touch'
    : (yesSide?.shortLabel || `${yesExpiryCmp} ${yesExpiryAbsStr}`);
  const shortNoLabel = isTouchMode
    ? 'No-Touch'
    : (noSide?.shortLabel || `${noExpiryCmp} ${noExpiryAbsStr}`);

  const yesTabLabel = isTouchMode
    ? `Bet YES: Touches ${targetAbsolute}`
    : (yesSide?.tabLabel || `Bet YES: Expires ${yesExpiryCmp} ${yesExpiryAbsStr}`);
  const noTabLabel = isTouchMode
    ? `Bet NO: Never touches ${targetAbsolute}`
    : (noSide?.tabLabel || `Bet NO: Expires ${noExpiryCmp} ${noExpiryAbsStr}`);

  const activeTargetBadge = isTouchMode
    ? targetAbsolute
    : `${yesExpiryCmp} ${yesExpiryAbsStr}`;
  const activeTargetRelative = isTouchMode
    ? targetRelative
    : yesExpiryRelStr;

  return {
    id: primary.id,
    underlying,
    underlyingName: underlying,
    underlyingURL: primary.underlyingURL,
    money,
    oddsMode,
    isTouchMode,
    isUpsideTarget,
    directionArrow,
    directionWord,
    oppositeDirectionWord,
    formattedDate: primary.formattedDate,
    DTE: primary.DTE,
    spotPrice,
    targetAbsolute,
    targetRelative,
    activeTargetBadge,
    activeTargetRelative,
    lowStrike,
    highStrike,
    eventSummary,
    shortYesLabel,
    shortNoLabel,
    yesTabLabel,
    noTabLabel,
    yesProbRaw,
    noProbRaw,
    yesProbPct,
    noProbPct,
    yesBarWidth,
    discountFactorStr: discountFactor.toFixed(4),
    impliedInterestStr: percentFmt.format(impliedInterestRate),
    impliedAprStr: `${percentFmt.format(impliedApr)} APR`,
    spreadPayoffWidthStr: dollarFmt.format(spreadPayoffWidth),
    boxPresentValueStr: dollarFmt.format(boxPresentValue),
    touchExitValueStr: dollarFmt.format(Number(primary.touchExitValue ?? 0.5 * spreadPayoffWidth)),
    yesSide,
    noSide
  };
}

function renderTooltipTouchBet(d) {
  if (!d) return '';
  return `
    <div class="tooltip-container" style="min-width: 215px;">
      <div class="tooltip-header" style="margin-bottom: 8px;">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      <div class="tooltip-body" style="gap: 6px;">
        <div class="tooltip-strike-badge">
          ${d.directionArrow} ${d.activeTargetBadge} <span class="strike-relative">(${d.activeTargetRelative})</span>
        </div>
        <div class="w-100 mt-1" style="font-size: 0.85em;">
          <div class="d-flex justify-content-between align-items-center mb-1">
            <span class="text-light-alt">${d.shortYesLabel} <span class="text-probs">(${d.yesProbPct})</span></span>
            <span class="text-good ms-2">${d.yesSide ? `${d.yesSide.yieldPct} (${d.yesSide.yieldMultiple})` : '—'}</span>
          </div>
          <div class="d-flex justify-content-between align-items-center">
            <span class="text-light-alt">${d.shortNoLabel} <span class="text-probs">(${d.noProbPct})</span></span>
            <span class="text-neutral ms-2">${d.noSide ? `${d.noSide.yieldPct} (${d.noSide.yieldMultiple})` : '—'}</span>
          </div>
        </div>
      </div>
      <div class="tooltip-footer" style="margin-top: 6px; padding-top: 5px;">
        Spread [${d.lowStrike} – ${d.highStrike}]
      </div>
    </div>
  `;
}

const wholeDollarFmt = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0
});

function formatRangeCapPrice(val) {
  const n = Number(val);
  if (!Number.isFinite(n)) return '';
  if (Math.abs(n) >= 100 && Math.abs(n - Math.round(n)) < 1e-4) {
    return wholeDollarFmt.format(n);
  }
  return dollarFmt.format(n);
}

function touchBetTooltipFormatter(params) {
  return strategyTooltipFormatter(params);
}

let _touchBetNodesCache = [];
let _touchBetUniqueDTEsCache = [];
let _touchBetAxisRangeCache = { minX: 0, maxX: 100 };

function normalizeTouchBetSelectedId(idToSelect, rawData) {
  let normalizedId = idToSelect || '';
  if (normalizedId && Array.isArray(rawData)) {
    const found = rawData.find(item => item.id === normalizedId);
    const group = getTouchBetGroupForItem(found);
    if (group && group.primary) {
      normalizedId = group.primary.id;
    }
  }
  return normalizedId;
}

function updateTouchBetNodesActiveProb(nodes, isTouchMode) {
  for (const node of nodes) {
    const group = getTouchBetGroupForItem(node);
    const touchItem = group.touch;
    const noTouchItem = group.noTouch;
    const spotVal = Number(node.spotPrice);
    if (isTouchMode) {
      node.activeWinProb = touchItem
        ? Number(touchItem.winProbability)
        : (noTouchItem ? 1.0 - Number(noTouchItem.winProbability) : 0.0);
      node.activeTargetPrice = Number(node.targetPriceAbsolute);
      node.activeTargetRelative = Number(node.targetPriceRelative);
    } else {
      node.activeWinProb = touchItem
        ? Number(touchItem.expirationWinProbability)
        : (noTouchItem ? 1.0 - Number(noTouchItem.expirationWinProbability) : 0.0);
      const expiryStrike = Number(node.isUpsideTarget ? node.highStrike : node.lowStrike);
      node.activeTargetPrice = expiryStrike;
      node.activeTargetRelative = spotVal > 0 ? expiryStrike / spotVal : Number(node.targetPriceRelative);
    }
  }
  nodes.sort((a, b) => Number(a.activeTargetPrice) - Number(b.activeTargetPrice));
}

function buildTouchBetThresholdSeries(axisMinX, axisMaxX, minProbPct) {
  const clampedPct = Math.max(0, Math.min(100, Math.round(Number(minProbPct))));
  const minProbDecimal = clampedPct / 100.0;
  return {
    id: 'probRangeSegmentsSeries',
    type: 'custom',
    name: 'Odds Range',
    data: [{
      value: [axisMinX, axisMaxX, minProbDecimal],
      minProbPct: clampedPct
    }],
    itemStyle: {
      color: 'rgba(0, 255, 163, 0.35)',
      borderColor: '#00ffa3',
      borderWidth: 1
    },
    encode: {
      x: -1,
      y: -1
    },
    silent: true,
    clip: true,
    z: 1,
    renderItem: function (params, api) {
      const sys = params.coordSys;
      const prob = api.value(2);
      const coord = api.coord([axisMinX, prob]);
      if (!coord || !sys) return null;

      const topY = sys.y;
      const bottomY = sys.y + sys.height;
      const clampedY = Math.max(topY, Math.min(bottomY, coord[1]));
      const bandHeight = Math.max(0, clampedY - topY);
      const labelAbove = clampedY - topY >= 20;

      return {
        type: 'group',
        children: [
          {
            type: 'rect',
            shape: {
              x: sys.x,
              y: topY,
              width: sys.width,
              height: bandHeight
            },
            style: {
              fill: 'rgba(0, 255, 163, 0.06)'
            }
          },
          {
            type: 'line',
            shape: {
              x1: sys.x,
              y1: clampedY,
              x2: sys.x + sys.width,
              y2: clampedY
            },
            style: {
              stroke: 'rgba(0, 255, 163, 0.65)',
              lineWidth: 1.5,
              lineDash: [6, 4]
            }
          },
          {
            type: 'text',
            style: {
              x: sys.x + 8,
              y: labelAbove ? clampedY - 5 : clampedY + 5,
              text: `Odds ≥ ${clampedPct}%`,
              textAlign: 'left',
              textVerticalAlign: labelAbove ? 'bottom' : 'top',
              fill: '#a7f3d0',
              font: '600 11px "Roboto Mono", monospace',
              stroke: '#0f172a',
              lineWidth: 3
            }
          }
        ]
      };
    }
  };
}

function buildTouchBetDteSeries(uniqueDTEs, normalizedSelectedId) {
  return uniqueDTEs.map(dte => ({
    id: `series_dte_${dte}`,
    type: 'line',
    name: `${dte}d`,
    datasetId: `dte_${dte}`,
    encode: {
      x: 'activeTargetPrice',
      y: 'activeWinProb'
    },
    lineStyle: {
      width: 2,
      opacity: 0.85
    },
    symbol: 'circle',
    symbolSize: function (value, params) {
      const d = params?.data;
      if (!d) return 7;
      if (normalizedSelectedId && d.id === normalizedSelectedId) {
        return 16;
      }
      return 7;
    },
    emphasis: {
      scale: 1.7,
      itemStyle: {
        color: '#00ffa3',
        borderColor: 'white',
        borderWidth: 2
      },
      focus: 'series'
    },
    label: {
      show: false
    },
    z: 4
  }));
}

let _touchBetTableNodesById = new Map();
let _touchBetTableRenderedMode = null;

function escapeTouchBetHtml(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatCompactDteDate(formattedDate) {
  if (!formattedDate || typeof formattedDate !== 'string') return '';
  const parts = formattedDate.trim().split(/\s+/);
  if (parts.length === 3) {
    const day = parts[0];
    const mon = parts[1].slice(0, 3);
    const yr = parts[2].slice(-2);
    return `${day} ${mon} '${yr}`;
  }
  return formattedDate;
}

function canonicalTouchPriceKey(price) {
  const n = Number(price);
  return Number.isFinite(n) ? Number(n.toFixed(6)) : 0;
}

function getTouchBetProbTierClass(probRaw) {
  const p = Number(probRaw ?? 0);
  if (p >= 0.50) return 'tier-high';
  if (p >= 0.25) return 'tier-mid-high';
  if (p >= 0.10) return 'tier-mid';
  if (p >= 0.04) return 'tier-low';
  return 'tier-tail';
}

function formatTouchBetCellText(node, isTouchMode, metric) {
  const group = getTouchBetGroupForItem(node);
  const yesSide = buildTouchBetSideData(group.touch, isTouchMode, true);
  const probRaw = Number(node.activeWinProb ?? 0);
  const yieldRaw = yesSide ? yesSide.yieldRaw : null;

  if (metric === 'odds') {
    return unsignedPercentFmt.format(probRaw);
  }
  if (metric === 'return') {
    return yieldRaw != null ? percentFmt.format(yieldRaw - 1.0) : '—';
  }
  if (metric === 'both') {
    const pct = (probRaw > 0 && probRaw < 0.01)
      ? `${(probRaw * 100).toFixed(1)}%`
      : `${Math.round(probRaw * 100)}%`;
    return yieldRaw != null ? `${yieldRaw.toFixed(2)}x (${pct})` : unsignedPercentFmt.format(probRaw);
  }
  // Default: 'yield'
  return yieldRaw != null ? `${yieldRaw.toFixed(2)}x` : '—';
}

function hideTouchBetTableTooltip() {
  const tip = document.getElementById('touchBetTableTooltip');
  if (tip) {
    tip.style.display = 'none';
  }
}

function showTouchBetTableTooltip(cellEl, node) {
  const container = document.getElementById('touchBetTableContainer');
  if (!container || !cellEl || !node) return;
  let tip = document.getElementById('touchBetTableTooltip');
  if (!tip) {
    tip = document.createElement('div');
    tip.id = 'touchBetTableTooltip';
    tip.className = 'touch-bet-table-tooltip';
    container.appendChild(tip);
  }
  const prepared = prepareTouchBetData(node);
  if (!prepared) return;
  tip.innerHTML = renderTooltipTouchBet(prepared);
  tip.style.display = 'block';

  const rect = cellEl.getBoundingClientRect();
  const tipRect = tip.getBoundingClientRect();
  const margin = 10;

  let left = rect.right + margin;
  if (left + tipRect.width > window.innerWidth - margin) {
    left = rect.left - tipRect.width - margin;
  }
  if (left < margin) {
    left = Math.max(margin, Math.min(window.innerWidth - tipRect.width - margin, rect.left));
  }

  let top = rect.top + (rect.height / 2) - (tipRect.height / 2);
  top = Math.max(margin, Math.min(window.innerHeight - tipRect.height - margin, top));

  tip.style.left = `${Math.round(left)}px`;
  tip.style.top = `${Math.round(top)}px`;
}

function bindTouchBetTableEvents(container) {
  if (!container || container._touchBetListenersBound) return;
  container._touchBetListenersBound = true;

  container.addEventListener('click', function (e) {
    const cell = e.target.closest('td.touch-bet-cell[data-bet-id]');
    if (!cell || !container.contains(cell)) return;
    const betId = cell.getAttribute('data-bet-id');
    if (betId) {
      selectStrategyById(betId);
    }
  });

  container.addEventListener('mouseover', function (e) {
    const cell = e.target.closest('td.touch-bet-cell[data-bet-id]');
    if (!cell || !container.contains(cell)) return;
    const betId = cell.getAttribute('data-bet-id');
    const node = _touchBetTableNodesById.get(betId);
    if (node) {
      showTouchBetTableTooltip(cell, node);
    }
  });

  container.addEventListener('mouseout', function (e) {
    const cell = e.target.closest('td.touch-bet-cell[data-bet-id]');
    if (!cell) return;
    if (e.relatedTarget && cell.contains(e.relatedTarget)) return;
    hideTouchBetTableTooltip();
  });

  container.addEventListener('mouseleave', hideTouchBetTableTooltip);
  container.addEventListener('scroll', hideTouchBetTableTooltip, true);
}

function updateTouchBetTableSelection(normalizedId) {
  const container = document.getElementById('touchBetTableContainer');
  if (!container) return;
  const prev = container.querySelectorAll('td.touch-bet-cell.selected');
  for (const el of prev) {
    el.classList.remove('selected');
  }
  if (!normalizedId) return;
  const cells = container.querySelectorAll('td.touch-bet-cell[data-bet-id]');
  for (const cell of cells) {
    if (cell.getAttribute('data-bet-id') === normalizedId) {
      cell.classList.add('selected');
      break;
    }
  }
}

function updateTouchBetTableProbFilter(minProbPct) {
  const container = document.getElementById('touchBetTableContainer');
  if (!container) return;
  const minProbDecimal = Math.max(0.0, Math.min(1.0, Number(minProbPct) / 100.0));
  const cells = container.querySelectorAll('td.touch-bet-cell[data-prob]');
  for (const cell of cells) {
    const p = Number(cell.getAttribute('data-prob') ?? 0);
    if (p + 1e-9 < minProbDecimal) {
      cell.classList.add('below-min-prob');
    } else {
      cell.classList.remove('below-min-prob');
    }
  }
}

function renderTouchBetsTable(rawData, idToSelect, options = {}) {
  const container = document.getElementById('touchBetTableContainer');
  if (!container) return;

  const { centerOnSpot = true } = options;
  const store = getAppStore();
  const isTouchMode = (store?.oddsMode || 'touch') === 'touch';
  const minProbPct = Number(store?.minProb ?? 25);
  const minProbDecimal = Math.max(0.0, Math.min(1.0, minProbPct / 100.0));
  const metric = store?.touchBetMetric || 'yield';

  let nodes = _touchBetNodesCache;
  if ((!nodes || nodes.length === 0) && Array.isArray(rawData) && rawData.length > 0) {
    nodes = pairTouchBetNodes(rawData);
    _touchBetNodesCache = nodes;
  }

  if (!nodes || nodes.length === 0) {
    container.innerHTML = '<div class="touch-bet-table-empty">No Over / Under bets available for the selected filters.</div>';
    _touchBetTableNodesById = new Map();
    _touchBetTableRenderedMode = isTouchMode ? 'touch' : 'expiration';
    return;
  }

  const prevScrollEl = container.querySelector('.touch-bet-table-scroll');
  const prevScrollTop = prevScrollEl ? prevScrollEl.scrollTop : 0;
  const prevScrollLeft = prevScrollEl ? prevScrollEl.scrollLeft : 0;

  updateTouchBetNodesActiveProb(nodes, isTouchMode);
  const normalizedSelectedId = normalizeTouchBetSelectedId(idToSelect, rawData || store?.chartData);
  const spotPrice = Number(extractSpotPrice(nodes)) || 0;

  // Build sorted DTE columns (ascending by DTE)
  const colMap = new Map();
  for (const node of nodes) {
    const colKey = `${node.DTE}~${node.formattedDate}`;
    if (!colMap.has(colKey)) {
      colMap.set(colKey, {
        key: colKey,
        dte: Number(node.DTE),
        formattedDate: node.formattedDate,
        shortDate: formatCompactDteDate(node.formattedDate)
      });
    }
  }
  const cols = [...colMap.values()].sort((a, b) => a.dte - b.dte || a.formattedDate.localeCompare(b.formattedDate));

  // Build rows sorted DESCENDING (higher targets at top, lower targets at bottom)
  const rowCells = new Map();
  _touchBetTableNodesById = new Map();
  for (const node of nodes) {
    const pKey = canonicalTouchPriceKey(node.activeTargetPrice);
    const colKey = `${node.DTE}~${node.formattedDate}`;
    if (!rowCells.has(pKey)) {
      rowCells.set(pKey, new Map());
    }
    const colCells = rowCells.get(pKey);
    if (!colCells.has(colKey)) {
      colCells.set(colKey, node);
      _touchBetTableNodesById.set(node.id, node);
    }
  }
  const sortedPrices = [...rowCells.keys()].sort((a, b) => b - a);

  const theadColsHtml = cols.map(col => `
    <th class="touch-bet-dte-th" title="${escapeTouchBetHtml(col.formattedDate)} (${col.dte}d)">
      <div class="touch-bet-th-dte">${col.dte}d</div>
      <div class="touch-bet-th-sub">${escapeTouchBetHtml(col.shortDate)}</div>
    </th>
  `).join('');

  const spotRowHtml = spotPrice > 0 ? `
    <tr class="touch-bet-spot-row">
      <th class="touch-bet-spot-label">
        <span class="touch-bet-spot-badge">SPOT</span>
        <span class="touch-bet-spot-val">${escapeTouchBetHtml(dollarFmt.format(spotPrice))}</span>
      </th>
      <td class="touch-bet-spot-line" colspan="${cols.length}"></td>
    </tr>
  ` : '';

  let spotInserted = false;
  const bodyRows = [];

  for (const price of sortedPrices) {
    if (spotRowHtml && !spotInserted && price < spotPrice) {
      bodyRows.push(spotRowHtml);
      spotInserted = true;
    }

    const relStr = spotPrice > 0 ? percentFmt.format(price / spotPrice - 1.0) : '';
    const relCls = spotPrice > 0
      ? (price > spotPrice ? 'text-good' : (price < spotPrice ? 'text-bad' : 'text-neutral'))
      : 'text-muted';
    const colCells = rowCells.get(price);

    const cellsHtml = cols.map(col => {
      const node = colCells.get(col.key);
      if (!node) {
        return '<td class="touch-bet-empty"></td>';
      }
      const probRaw = Number(node.activeWinProb ?? 0);
      const tierCls = getTouchBetProbTierClass(probRaw);
      const belowCls = (probRaw + 1e-9 < minProbDecimal) ? ' below-min-prob' : '';
      const selectedCls = (normalizedSelectedId && node.id === normalizedSelectedId) ? ' selected' : '';
      const cellText = formatTouchBetCellText(node, isTouchMode, metric);
      return `<td class="touch-bet-cell ${tierCls}${belowCls}${selectedCls}" data-bet-id="${escapeTouchBetHtml(node.id)}" data-prob="${probRaw}">${escapeTouchBetHtml(cellText)}</td>`;
    }).join('');

    bodyRows.push(`
      <tr>
        <th class="touch-bet-price-th">
          <span class="touch-bet-price-abs">${escapeTouchBetHtml(formatRangeCapPrice(price))}</span>
          ${relStr ? `<span class="touch-bet-price-rel ${relCls}">${escapeTouchBetHtml(relStr)}</span>` : ''}
        </th>
        ${cellsHtml}
      </tr>
    `);
  }

  if (spotRowHtml && !spotInserted) {
    bodyRows.push(spotRowHtml);
  }

  container.innerHTML = `
    <div class="touch-bet-table-scroll">
      <table class="touch-bet-matrix">
        <thead>
          <tr>
            <th class="touch-bet-corner-th">
              <div>Target</div>
              <div class="touch-bet-th-sub">Price / Move</div>
            </th>
            ${theadColsHtml}
          </tr>
        </thead>
        <tbody>
          ${bodyRows.join('')}
        </tbody>
      </table>
    </div>
    <div id="touchBetTableTooltip" class="touch-bet-table-tooltip"></div>
  `;

  bindTouchBetTableEvents(container);
  _touchBetTableRenderedMode = isTouchMode ? 'touch' : 'expiration';

  const scrollEl = container.querySelector('.touch-bet-table-scroll');
  if (scrollEl) {
    if (centerOnSpot) {
      const spotEl = scrollEl.querySelector('.touch-bet-spot-row');
      const theadEl = scrollEl.querySelector('thead');
      const theadHeight = theadEl ? theadEl.offsetHeight : 0;
      if (spotEl) {
        const visibleHeight = Math.max(0, scrollEl.clientHeight - theadHeight);
        const targetTop = spotEl.offsetTop - theadHeight - (visibleHeight / 2) + (spotEl.offsetHeight / 2);
        scrollEl.scrollTop = Math.max(0, targetTop);
      } else {
        const maxScroll = Math.max(0, scrollEl.scrollHeight - scrollEl.clientHeight);
        scrollEl.scrollTop = maxScroll / 2;
      }
    } else {
      scrollEl.scrollTop = prevScrollTop;
      scrollEl.scrollLeft = prevScrollLeft;
    }
  }
}

StrategyRegistry['touchBet'] = new class extends BaseStrategyConfig {
  prepareData = prepareTouchBetData;
  renderTooltip = renderTooltipTouchBet;
  renderTable = renderTouchBetsTable;

  updateSelection(idToSelect) {
    const store = getAppStore();
    const normalizedId = normalizeTouchBetSelectedId(idToSelect, store?.chartData);

    updateTouchBetTableSelection(normalizedId);

    const chartDom = document.getElementById("strategyChartContainer");
    const chart = echarts.getInstanceByDom(chartDom);
    if (!chart) return;

    chart.setOption({
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': normalizedId } }
      }],
      series: buildTouchBetDteSeries(_touchBetUniqueDTEsCache, normalizedId)
    });
  }

  updateProbabilityFilter() {
    const store = getAppStore();
    const isTouchMode = (store?.oddsMode || 'touch') === 'touch';
    const minProbPct = Number(store?.minProb ?? 25);
    const normalizedId = normalizeTouchBetSelectedId(store?.selectedId, store?.chartData);

    updateTouchBetNodesActiveProb(_touchBetNodesCache, isTouchMode);

    if (store?.touchBetView === 'table') {
      const desiredMode = isTouchMode ? 'touch' : 'expiration';
      if (_touchBetTableRenderedMode !== desiredMode) {
        renderTouchBetsTable(store?.chartData, normalizedId, { centerOnSpot: true });
      } else {
        updateTouchBetTableProbFilter(minProbPct);
      }
    }

    const chartDom = document.getElementById("strategyChartContainer");
    const chart = echarts.getInstanceByDom(chartDom);
    if (!chart) return;

    chart.setOption({
      dataset: [
        {
          id: 'original',
          dimensions: ['activeTargetPrice', 'activeWinProb', 'DTE', 'id'],
          source: _touchBetNodesCache
        },
        {
          id: 'highlightDataset',
          fromDatasetId: 'original',
          transform: { type: 'filter', config: { dimension: 'id', '=': normalizedId } }
        }
      ],
      series: [
        buildTouchBetThresholdSeries(_touchBetAxisRangeCache.minX, _touchBetAxisRangeCache.maxX, minProbPct),
        ...buildTouchBetDteSeries(_touchBetUniqueDTEsCache, normalizedId)
      ]
    });
  }
};

function renderTouchBetsChart(data, chartDom, idToSelect) {
  const nodes = pairTouchBetNodes(data);
  _touchBetNodesCache = nodes;
  const spotPrice = Number(extractSpotPrice(data)) || 0;
  const store = getAppStore();
  const isTouchMode = (store?.oddsMode || 'touch') === 'touch';
  const minProbPct = Number(store?.minProb ?? 25);

  updateTouchBetNodesActiveProb(nodes, isTouchMode);

  const normalizedSelectedId = normalizeTouchBetSelectedId(idToSelect, data);

  const allTargets = nodes.flatMap(n => [Number(n.lowStrike), Number(n.highStrike), Number(n.targetPriceAbsolute)]).filter(Number.isFinite);
  const minTarget = allTargets.length ? Math.min(...allTargets) : spotPrice * 0.7;
  const maxTarget = allTargets.length ? Math.max(...allTargets) : spotPrice * 1.3;

  const rawMinX = Math.min(spotPrice > 0 ? spotPrice * 0.9 : minTarget, minTarget);
  const rawMaxX = Math.max(spotPrice > 0 ? spotPrice * 1.1 : maxTarget, maxTarget);
  const xPad = Math.max(1.0, (rawMaxX - rawMinX) * 0.04);
  const axisMinX = Math.max(0, rawMinX - xPad);
  const axisMaxX = rawMaxX + xPad;
  _touchBetAxisRangeCache = { minX: axisMinX, maxX: axisMaxX };

  // Default zoom window around Spot (+/- 45%) so probability curves stay readable initially
  let xStart = spotPrice > 0 ? Math.max(axisMinX, spotPrice * 0.55) : axisMinX;
  let xEnd = spotPrice > 0 ? Math.min(axisMaxX, spotPrice * 1.45) : axisMaxX;
  if (xEnd <= xStart) {
    xStart = axisMinX;
    xEnd = axisMaxX;
  }

  const targetItem = nodes.find(n => n.id === normalizedSelectedId);
  if (targetItem) {
    const tx = Number(targetItem.activeTargetPrice);
    if (Number.isFinite(tx)) {
      xStart = Math.min(xStart, Math.max(axisMinX, tx - xPad));
      xEnd = Math.max(xEnd, Math.min(axisMaxX, tx + xPad));
    }
  }

  const dataset = {
    id: 'original',
    dimensions: ['activeTargetPrice', 'activeWinProb', 'DTE', 'id'],
    source: nodes
  };
  const highlightDataset = {
    id: 'highlightDataset',
    fromDatasetId: 'original',
    transform: { type: 'filter', config: { dimension: 'id', '=': normalizedSelectedId } }
  };
  const uniqueDTEs = [...new Set(nodes.map(item => item.DTE))].sort((a, b) => a - b);
  _touchBetUniqueDTEsCache = uniqueDTEs;
  const datasetPerDTE = uniqueDTEs.map(dte => ({
    id: `dte_${dte}`,
    fromDatasetId: 'original',
    label: `${dte}d`,
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
    grid: {
      left: '5%',
      right: '6%',
      top: '10%',
      bottom: '16%',
      containLabel: true
    },
    xAxis: {
      type: 'value',
      name: 'Target Price ➡',
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
        hideOverlap: true,
        formatter: function (value) {
          const priceStr = formatRangeCapPrice(value);
          if (spotPrice > 0) {
            return `${priceStr} (${percentFmt.format(value / spotPrice - 1.0)})`;
          }
          return priceStr;
        }
      },
      axisLine,
      splitLine: {
        show: true,
        lineStyle: {
          color: 'rgba(148, 163, 184, 0.14)',
          type: 'dashed'
        }
      },
      min: axisMinX,
      max: axisMaxX,
      position: 'bottom'
    },
    yAxis: {
      type: 'value',
      name: '⇳ Probability',
      nameLocation: 'end',
      nameTextStyle: yAxisTitleNameTextStyle,
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return unsignedPercentFmt.format(value);
        }
      },
      axisLine,
      splitLine: {
        show: true,
        lineStyle: {
          color: 'rgba(148, 163, 184, 0.14)',
          type: 'dashed'
        }
      },
      min: 0,
      max: 1
    },
    tooltip: {
      ...tooltipStyle,
      formatter: touchBetTooltipFormatter
    },
    series: [
      buildTouchBetThresholdSeries(axisMinX, axisMaxX, minProbPct),
      ...buildTouchBetDteSeries(uniqueDTEs, normalizedSelectedId),
      {
        id: 'selectedPointGlow',
        type: 'scatter',
        datasetId: 'highlightDataset',
        encode: { x: 'activeTargetPrice', y: 'activeWinProb' },
        symbol: 'circle',
        symbolSize: 34,
        itemStyle: {
          color: 'rgba(252, 211, 77, 0.25)',
          borderColor: '#fcd34d',
          borderWidth: 2.5,
          shadowBlur: 14,
          shadowColor: '#fcd34d'
        },
        silent: true,
        z: 9
      },
      {
        ...selectionHighlightSeries,
        encode: { x: 'activeTargetPrice', y: 'activeWinProb' }
      },
      ...(spotPrice > 0 ? [{
        id: 'spotReferenceSeries',
        type: 'line',
        name: 'Spot',
        data: [
          [spotPrice, 0],
          {
            value: [spotPrice, 1],
            symbolSize: 1,
            itemStyle: { opacity: 0 },
            label: {
              show: true,
              position: 'top',
              distance: 6,
              formatter: `SPOT ${dollarFmt.format(spotPrice)}`,
              color: '#00ff00',
              fontFamily: 'Roboto Mono, monospace',
              fontWeight: 'bold',
              fontSize: 12
            }
          }
        ],
        symbol: 'circle',
        symbolSize: function (value) {
          return value && value[1] === 0 ? 10 : 1;
        },
        silent: true,
        animation: false,
        itemStyle: {
          color: '#00ff00'
        },
        lineStyle: {
          color: '#00ff00',
          type: 'dashed',
          width: 1.75,
          opacity: 0.65
        }
      }] : [])
    ],
    legend: legend,
    animationDurationUpdate: 300,
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
        startValue: 0,
        endValue: 1
      }
    ]
  }, true);

  chart.on('click', function (params) {
    if (params.componentType === 'series' && params.data && params.data.id) {
      selectStrategyById(params.data.id);
    }
  });
  chart.on('datazoom', function () {
    chart.dispatchAction({
      type: 'hideTip'
    });
  });

  selectStrategyById(normalizedSelectedId || null);
  if (store?.touchBetView === 'table') {
    requestAnimationFrame(() => {
      renderTouchBetsTable(data, normalizedSelectedId, { centerOnSpot: true });
    });
  }
  return chart;
}

