

function formatInstructionValue(amount, unit, money) {
  if (unit === money) {
    return dollarFmt.format(amount);
  }
  if (unit === 'call(s)') {
    return `${Number(Number(amount).toFixed(4))} ${unit}`;
  }
  return `${underlyingFmt.format(amount)} ${unit}`;
}

function prepareCCData(value) {
  const money = value.money;
  const underlying = value.underlying;
  let preTax = value.preTax;
  if (!preTax && value.moneyYield != null) {
    preTax = {
      moneyYield: value.moneyYield,
      underlyingYield: value.underlyingYield,
      moneyProfit: value.moneyProfit,
      premiumToReceive: value.premiumToReceive,
      breakEvenVsFullUnderlying: value.breakEvenVsFullUnderlying ?? (
        value.breakEvenVsFullUnderlyingAbsolute != null ? {
          absolute: value.breakEvenVsFullUnderlyingAbsolute,
          relative: value.breakEvenVsFullUnderlyingRelative
        } : null
      ),
      breakEvenVsFullMoney: value.breakEvenVsFullMoney ?? (
        value.breakEvenVsFullMoneyAbsolute != null ? {
          absolute: value.breakEvenVsFullMoneyAbsolute,
          relative: value.breakEvenVsFullMoneyRelative
        } : null
      )
    };
    value.preTax = preTax;
  }
  const active = value.postTax ?? preTax;

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
    callName: formatOptionName(value.call),
    callURL: value.callURL,
    callPrice: value.callPrice,
    callContractPrice: value.callContractPrice,
    contractLot: value.contractLot,
    minSize: value.minSize,
    avgPrice: value.avgPrice,
    underlyingHeld: value.underlyingHeld,
    costBasis: value.costBasis,
    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.underlyingToBuy)} ${underlying}`,

    // Yields (reflecting postTax when taxes are active, matching chart axes)
    moneyYield: percentFmt.format(active.moneyYield - 1.0),
    moneyYieldPositive: active.moneyYield >= 1.0,
    moneyProfit: `${dollarFmt.format(active.moneyProfit)}`,
    underlyingYield: percentFmt.format(active.underlyingYield - 1.0),
    underlyingYieldPositive: active.underlyingYield >= 1.0,
    underlyingProfit: `${underlyingFmt.format(preTax.premiumToReceive)} ${underlying}`,

    // Breakeven / Caps
    beAbsolute: active.breakEvenVsFullMoney ? dollarFmt.format(active.breakEvenVsFullMoney.absolute) : null,
    beRelative: active.breakEvenVsFullMoney ? percentFmt.format(active.breakEvenVsFullMoney.relative - 1.0) : null,
    capAbsolute: active.breakEvenVsFullUnderlying ? dollarFmt.format(active.breakEvenVsFullUnderlying.absolute) : null,
    capRelative: active.breakEvenVsFullUnderlying ? percentFmt.format(active.breakEvenVsFullUnderlying.relative - 1.0) : null,

    // Instructions
    instructions: (value.instructions || []).map(inst => ({
      action: inst.action,
      target: formatInstructionValue(inst.size, inst.unit, money),
      targetClass: inst.action === 'Buy' ? 'text-good' : 'text-bad',
      consideration: formatInstructionValue(inst.price, inst.priceUnit, money),
      considerationClass: inst.action === 'Buy' ? 'text-bad' : 'text-good',
    })),

    // Probabilities
    moneyProbability: value.moneyProbability,
    underlyingProbability: value.underlyingProbability
  };
}

function renderTooltipCC(d) {
  const moneyProbSuffix = d.moneyProbability != null ? ` <span class="probs">(${Math.round(d.moneyProbability * 100)}% prob)</span>` : '';
  const underlyingProbSuffix = d.underlyingProbability != null ? ` <span class="probs">(${Math.round(d.underlyingProbability * 100)}% prob)</span>` : '';
  const moneyYieldCls = d.moneyYieldPositive === false ? 'tooltip-yield-bad' : 'tooltip-yield-good';
  const undYieldCls = d.underlyingYieldPositive === false ? 'tooltip-yield-bad' : 'tooltip-yield-good';

  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="${moneyYieldCls}">${d.moneyYield} ${d.money} ⬆${moneyProbSuffix}</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
        <div class="tooltip-divider"></div>
        <div class="${undYieldCls}">${d.underlyingYield} ${d.underlying} ⬇${underlyingProbSuffix}</div>
      </div>

      <div class="tooltip-breakeven">
        <span class="text-label">Even vs full ${d.money}:</span> 
        ${d.beAbsolute != null
      ? `<span class="text-neutral">${d.beAbsolute}</span><span class="text-bad ms-1">(${d.beRelative})</span>`
      : `<span class="text-bad">Never</span>`}
        <br/>
        <span class="text-label">Even vs full ${d.underlying}:</span> 
        ${d.capAbsolute != null
      ? `<span class="text-neutral">${d.capAbsolute}</span><span class="text-good ms-1">(${d.capRelative})</span>`
      : `<span class="text-muted-alt">—</span>`}
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
  decodeEntryPosition(encoded) {
    const pos = super.decodeEntryPosition(encoded);
    if (pos && !pos.preTax && pos.moneyYield != null) {
      pos.preTax = {
        moneyYield: pos.moneyYield,
        underlyingYield: pos.underlyingYield,
        moneyProfit: pos.moneyProfit,
        premiumToReceive: pos.premiumToReceive,
        breakEvenVsFullUnderlying: pos.breakEvenVsFullUnderlying ?? (
          pos.breakEvenVsFullUnderlyingAbsolute != null ? {
            absolute: pos.breakEvenVsFullUnderlyingAbsolute,
            relative: pos.breakEvenVsFullUnderlyingRelative
          } : null
        ),
        breakEvenVsFullMoney: pos.breakEvenVsFullMoney ?? (
          pos.breakEvenVsFullMoneyAbsolute != null ? {
            absolute: pos.breakEvenVsFullMoneyAbsolute,
            relative: pos.breakEvenVsFullMoneyRelative
          } : null
        )
      };
      if (pos.instructions === undefined) pos.instructions = [];
      if (pos.underlyingTaxRate === undefined) pos.underlyingTaxRate = 0.0;
      if (pos.derivativeTaxRate === undefined) pos.derivativeTaxRate = 0.0;
      if (pos.unitCostBasis === undefined) pos.unitCostBasis = pos.spotPrice;
      if (pos.costBasis === undefined) pos.costBasis = pos.moneySize ? Math.abs(pos.moneySize) : pos.spotPrice;
      if (pos.contractLot === undefined) pos.contractLot = 1.0;
      if (pos.minSize === undefined) pos.minSize = (pos.underlying === 'BTC' ? 0.1 : 1.0);
    }
    return pos;
  }
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
    const hasTaxes = Boolean(activePos?.postTax || entryPos?.postTax);

    // Rolls mean replacing the old position with a new one.
    // Their difference does not represent a loss or a gain.
    // If it's not a roll, i.e. we are comparing the same position in two different moments,
    // then the difference is the unrealized loss or gain.
    const isRoll = hasDiff && currentPos.id !== entryPos.id;
    const mode = hasDiff ? (isRoll ? 'roll' : 'unrealized') : (entryPos ? 'pinnedOnly' : 'single');

    const header = prepareCCData(activePos);

    const formatContractPrice = (price) => {
      const isWhole = Math.abs(price - Math.round(price)) < 1e-4;
      return isWhole ? `$${Math.round(price)}` : dollarFmt.format(price);
    };

    const formatContractCell = (pos, compact) => {
      if (!pos) return '—';
      const formattedCall = formatOptionName(pos.call);
      const label = compact ? formattedCall.replace(/^([A-Z0-9.^_-]+-)/, '') : formattedCall;
      const contractHtml = pos.callURL
        ? `<a href="${pos.callURL}" class="text-neutral" target="_blank" title="${formattedCall}" style="text-decoration: underline;">${label}</a>`
        : `<span class="text-neutral" title="${formattedCall}">${label}</span>`;
      let callPriceLine = '';
      if (pos.callPrice != null) {
        const cp = Number(pos.callPrice);
        const minSize = pos.minSize != null
          ? Number(pos.minSize)
          : (pos.underlying === 'BTC' ? 0.1 : 1);
        const lot = pos.contractLot != null ? Number(pos.contractLot) : 100;
        const contractPrice = pos.callContractPrice != null
          ? Number(pos.callContractPrice)
          : cp * lot * minSize;
        const contractSizeStr = Number(minSize.toFixed(4));
        callPriceLine = `<br/><small class="text-probs"><span class="text-nowrap">${dollarFmt.format(cp)}</span><br/><span class="text-nowrap">(${formatContractPrice(contractPrice)} per ${contractSizeStr} contract)</span></small>`;
      }
      return `${contractHtml}${callPriceLine}`;
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
      if (!pos || !pos.preTax) return '—';
      const m = pos.preTax;
      const yieldVal = m.moneyYield - 1.0;
      const yieldStr = percentFmt.format(yieldVal);
      const profitStr = formatSignedDollar(m.moneyProfit);
      const cls = yieldVal >= 0 ? 'text-good' : 'text-bad';
      const altCls = m.moneyProfit >= 0 ? 'text-good-alt' : 'text-bad';
      const probStr = pos.moneyProbability != null ? `${Math.round(pos.moneyProbability * 100)}% prob` : '';
      if (compact) {
        return `<span class="${cls} text-nowrap">${yieldStr}</span><br/><small class="${altCls} text-nowrap">(${profitStr})</small>${probStr ? `<br/><small class="text-probs text-nowrap">${probStr}</small>` : ''}`;
      }
      return `<span class="${cls} text-nowrap">${yieldStr} ${pos.money}</span> <small class="${altCls} text-nowrap">(${profitStr})</small>${probStr ? `<br/><small class="text-probs text-nowrap">(${probStr})</small>` : ''}`;
    };

    const formatPostTaxMoneyYieldCell = (pos, compact) => {
      if (!pos || !pos.postTax) return '—';
      const post = pos.postTax;
      const yieldVal = post.moneyYield - 1.0;
      const yieldStr = percentFmt.format(yieldVal);
      const profitStr = formatSignedDollar(post.moneyProfit);
      const cls = yieldVal >= 0 ? 'text-good' : 'text-bad';
      const altCls = post.moneyProfit >= 0 ? 'text-good-alt' : 'text-bad';
      if (compact) {
        return `<span class="${cls} text-nowrap">${yieldStr}</span><br/><small class="${altCls} text-nowrap">(${profitStr})</small>`;
      }
      return `<span class="${cls} text-nowrap">${yieldStr} ${pos.money}</span> <small class="${altCls} text-nowrap">(${profitStr})</small>`;
    };

    const formatDollarImpactCell = (absImpact, money, compact) => {
      const impactCls = absImpact > 0 ? 'text-good' : (absImpact < 0 ? 'text-bad' : 'text-muted-alt');
      const suffix = compact ? '' : ` ${money}`;
      return `<span class="${impactCls} text-nowrap">${formatSignedDollar(absImpact)}${suffix}</span>`;
    };

    const formatMoneyYieldTaxImpactCell = (pos, compact) => {
      if (!pos || !pos.preTax || !pos.postTax) return '—';
      return formatDollarImpactCell(pos.postTax.moneyProfit - pos.preTax.moneyProfit, pos.money, compact);
    };

    const formatUndYieldCell = (pos, compact) => {
      if (!pos || !pos.preTax) return '—';
      const m = pos.preTax;
      const yieldStr = percentFmt.format(m.underlyingYield - 1.0);
      const profitStr = `+${underlyingFmt.format(m.premiumToReceive)} ${pos.underlying}`;
      const probStr = pos.underlyingProbability != null ? `${Math.round(pos.underlyingProbability * 100)}% prob` : '';
      if (compact) {
        return `<span class="text-good text-nowrap">${yieldStr}</span><br/><small class="text-good-alt text-nowrap">(+${underlyingFmt.format(m.premiumToReceive)})</small>${probStr ? `<br/><small class="text-probs text-nowrap">${probStr}</small>` : ''}`;
      }
      return `<span class="text-good text-nowrap">${yieldStr} ${pos.underlying}</span> <small class="text-good-alt text-nowrap">(${profitStr})</small>${probStr ? `<br/><small class="text-probs text-nowrap">(${probStr})</small>` : ''}`;
    };

    const formatPostTaxUndYieldCell = (pos, compact) => {
      if (!pos || !pos.postTax) return '—';
      const yieldVal = pos.postTax.underlyingYield - 1.0;
      const yieldStr = percentFmt.format(yieldVal);
      const yieldCls = yieldVal >= 0 ? 'text-good' : 'text-bad';
      if (compact) {
        return `<span class="${yieldCls} text-nowrap">${yieldStr}</span>`;
      }
      return `<span class="${yieldCls} text-nowrap">${yieldStr} ${pos.underlying}</span>`;
    };

    const formatUndYieldTaxImpactCell = (pos, compact) => {
      if (!pos || !pos.postTax) return '—';
      return formatDollarImpactCell(-(pos.postTax.unassignedTax ?? 0), pos.money, compact);
    };

    const formatBeCell = (be, compact, relCls) => {
      if (!be) return '—';
      const absStr = dollarFmt.format(be.absolute);
      const relStr = percentFmt.format(be.relative - 1.0);
      const sep = compact ? '<br/>' : ' ';
      return `<span class="text-neutral text-nowrap">${absStr}</span>${sep}<small class="${relCls} text-nowrap">(${relStr})</small>`;
    };

    const formatBeTaxImpactCell = (pos, compact, metricKey, higherIsGood) => {
      const preBe = pos?.preTax?.[metricKey];
      const postBe = pos?.postTax?.[metricKey];
      if (!preBe || !postBe) return '—';
      const absDiff = postBe.absolute - preBe.absolute;
      const relDiff = preBe.absolute > 0 ? (postBe.absolute / preBe.absolute - 1.0) : 0;
      const isGood = higherIsGood ? absDiff > 0 : absDiff < 0;
      const isBad = higherIsGood ? absDiff < 0 : absDiff > 0;
      const impactCls = isGood ? 'text-good' : (isBad ? 'text-bad' : 'text-muted-alt');
      const sep = compact ? '<br/>' : ' ';
      return `<span class="${impactCls} text-nowrap">${formatSignedDollar(absDiff)}</span>${sep}<small class="${impactCls} text-nowrap">(${percentFmt.format(relDiff)})</small>`;
    };

    const formatBeMoneyCell = (pos, compact) =>
      formatBeCell(pos?.preTax?.breakEvenVsFullMoney, compact, 'text-bad');

    const formatPostTaxBeMoneyCell = (pos, compact) =>
      formatBeCell(pos?.postTax?.breakEvenVsFullMoney, compact, 'text-bad');

    const formatBeMoneyTaxImpactCell = (pos, compact) =>
      formatBeTaxImpactCell(pos, compact, 'breakEvenVsFullMoney', false);

    const formatBeUndCell = (pos, compact) =>
      formatBeCell(pos?.preTax?.breakEvenVsFullUnderlying, compact, 'text-good');

    const formatPostTaxBeUndCell = (pos, compact) =>
      formatBeCell(pos?.postTax?.breakEvenVsFullUnderlying, compact, 'text-good');

    const formatBeUndTaxImpactCell = (pos, compact) =>
      formatBeTaxImpactCell(pos, compact, 'breakEvenVsFullUnderlying', true);

    // Diff calculations when both entryPos and currentPos are present
    let contractDiff = '', contractDiffClass = 'text-neutral-alt';
    let dteDiffText = '', dteDiffClass = 'text-neutral-alt';
    let spotDiffText = '', spotDiffClass = 'text-neutral-alt';
    let strikeDiffText = '', strikeDiffClass = 'text-neutral-alt';
    let moneyDiffText = '', moneyDiffClass = 'text-neutral-alt';
    let undDiffText = '', undDiffClass = 'text-neutral-alt';
    let moneyYieldDiffText = '', moneyYieldDiffClass = 'text-neutral-alt';
    let postTaxMoneyYieldDiffText = '', postTaxMoneyYieldDiffClass = 'text-neutral-alt';
    let moneyYieldTaxImpactDiffText = '', moneyYieldTaxImpactDiffClass = 'text-neutral-alt';
    let undYieldDiffText = '', undYieldDiffClass = 'text-neutral-alt';
    let postTaxUndYieldDiffText = '', postTaxUndYieldDiffClass = 'text-neutral-alt';
    let undYieldTaxImpactDiffText = '', undYieldTaxImpactDiffClass = 'text-neutral-alt';
    let beMoneyDiffText = '', beMoneyDiffClass = 'text-neutral-alt';
    let postTaxBeMoneyDiffText = '', postTaxBeMoneyDiffClass = 'text-neutral-alt';
    let beMoneyTaxImpactDiffText = '', beMoneyTaxImpactDiffClass = 'text-neutral-alt';
    let beUndDiffText = '', beUndDiffClass = 'text-neutral-alt';
    let postTaxBeUndDiffText = '', postTaxBeUndDiffClass = 'text-neutral-alt';
    let beUndTaxImpactDiffText = '', beUndTaxImpactDiffClass = 'text-neutral-alt';

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
      const moneyYieldRatioChange = currentPos.preTax.moneyYield / entryPos.preTax.moneyYield - 1.0;
      const profitDiff = currentPos.preTax.moneyProfit - entryPos.preTax.moneyProfit;
      moneyYieldDiffText = `${percentFmt.format(moneyYieldRatioChange)}<br/><small>(${formatSignedDollar(profitDiff)})</small>`;
      moneyYieldDiffClass = moneyYieldRatioChange >= 0 ? 'text-good' : 'text-bad';

      if (hasTaxes && entryPos.postTax && currentPos.postTax) {
        const ptRatioChange = currentPos.postTax.moneyYield / entryPos.postTax.moneyYield - 1.0;
        const ptProfitDiff = currentPos.postTax.moneyProfit - entryPos.postTax.moneyProfit;
        postTaxMoneyYieldDiffText = `${percentFmt.format(ptRatioChange)}<br/><small>(${formatSignedDollar(ptProfitDiff)})</small>`;
        postTaxMoneyYieldDiffClass = ptRatioChange >= 0 ? 'text-good' : 'text-bad';

        const entryAbsImpact = entryPos.postTax.moneyProfit - entryPos.preTax.moneyProfit;
        const curAbsImpact = currentPos.postTax.moneyProfit - currentPos.preTax.moneyProfit;
        const absImpactDiff = curAbsImpact - entryAbsImpact;
        moneyYieldTaxImpactDiffText = formatSignedDollar(absImpactDiff);
        moneyYieldTaxImpactDiffClass = absImpactDiff > 0 ? 'text-good' : (absImpactDiff < 0 ? 'text-bad' : 'text-muted-alt');
      }

      // 8. Underlying Yield
      const undYieldRatioChange = currentPos.preTax.underlyingYield / entryPos.preTax.underlyingYield - 1.0;
      const premDiff = currentPos.preTax.premiumToReceive - entryPos.preTax.premiumToReceive;
      undYieldDiffText = `${percentFmt.format(undYieldRatioChange)}<br/><small>(${premDiff >= 0 ? '+' : ''}${underlyingFmt.format(premDiff)})</small>`;
      undYieldDiffClass = undYieldRatioChange >= 0 ? 'text-good' : 'text-bad';

      if (hasTaxes && entryPos.postTax && currentPos.postTax) {
        const ptUndRatioChange = currentPos.postTax.underlyingYield / entryPos.postTax.underlyingYield - 1.0;
        const ptPremDiff = currentPos.postTax.premiumToReceive - entryPos.postTax.premiumToReceive;
        postTaxUndYieldDiffText = `${percentFmt.format(ptUndRatioChange)}<br/><small>(${ptPremDiff >= 0 ? '+' : ''}${underlyingFmt.format(ptPremDiff)})</small>`;
        postTaxUndYieldDiffClass = ptUndRatioChange >= 0 ? 'text-good' : 'text-bad';

        const entryTaxImpact = -(entryPos.postTax.unassignedTax ?? 0);
        const curTaxImpact = -(currentPos.postTax.unassignedTax ?? 0);
        const taxImpactDiff = curTaxImpact - entryTaxImpact;
        undYieldTaxImpactDiffText = formatSignedDollar(taxImpactDiff);
        undYieldTaxImpactDiffClass = taxImpactDiff > 0 ? 'text-good' : (taxImpactDiff < 0 ? 'text-bad' : 'text-muted-alt');
      }

      const computeBeTaxImpactDiff = (metricKey, higherIsGood) => {
        const ePre = entryPos.preTax[metricKey]?.absolute;
        const ePost = entryPos.postTax[metricKey]?.absolute;
        const cPre = currentPos.preTax[metricKey]?.absolute;
        const cPost = currentPos.postTax[metricKey]?.absolute;
        if (ePre == null || ePost == null || cPre == null || cPost == null) {
          return { text: '—', className: 'text-muted-alt' };
        }
        const diffAbs = (cPost - cPre) - (ePost - ePre);
        const diffRel = (cPre > 0 ? (cPost / cPre - 1.0) : 0) - (ePre > 0 ? (ePost / ePre - 1.0) : 0);
        const isGood = higherIsGood ? diffAbs > 0 : diffAbs < 0;
        const isBad = higherIsGood ? diffAbs < 0 : diffAbs > 0;
        return {
          text: `${formatSignedDollar(diffAbs)}<br/><small>(${percentFmt.format(diffRel)})</small>`,
          className: isGood ? 'text-good' : (isBad ? 'text-bad' : 'text-muted-alt')
        };
      };

      // 9. Breakeven (vs full money)
      const entryBeMoney = entryPos.preTax.breakEvenVsFullMoney?.absolute;
      const curBeMoney = currentPos.preTax.breakEvenVsFullMoney?.absolute;
      if (entryBeMoney != null && curBeMoney != null) {
        const beMoneyDiff = curBeMoney - entryBeMoney;
        const beMoneyDiffPct = entryBeMoney > 0 ? (beMoneyDiff / entryBeMoney) * 100 : 0;
        beMoneyDiffText = `${beMoneyDiff >= 0 ? '+' : ''}${dollarFmt.format(beMoneyDiff)}<br/><small>(${beMoneyDiff >= 0 ? '+' : ''}${beMoneyDiffPct.toFixed(1)}%)</small>`;
        beMoneyDiffClass = beMoneyDiff <= 0 ? 'text-good' : 'text-bad';
      } else {
        beMoneyDiffText = '—';
        beMoneyDiffClass = 'text-muted-alt';
      }

      if (hasTaxes && entryPos.postTax && currentPos.postTax) {
        const ptEntryBeMoney = entryPos.postTax.breakEvenVsFullMoney?.absolute;
        const ptCurBeMoney = currentPos.postTax.breakEvenVsFullMoney?.absolute;
        if (ptEntryBeMoney != null && ptCurBeMoney != null) {
          const ptBeMoneyDiff = ptCurBeMoney - ptEntryBeMoney;
          const ptBeMoneyDiffPct = ptEntryBeMoney > 0 ? (ptBeMoneyDiff / ptEntryBeMoney) * 100 : 0;
          postTaxBeMoneyDiffText = `${ptBeMoneyDiff >= 0 ? '+' : ''}${dollarFmt.format(ptBeMoneyDiff)}<br/><small>(${ptBeMoneyDiff >= 0 ? '+' : ''}${ptBeMoneyDiffPct.toFixed(1)}%)</small>`;
          postTaxBeMoneyDiffClass = ptBeMoneyDiff <= 0 ? 'text-good' : 'text-bad';
        } else {
          postTaxBeMoneyDiffText = '—';
          postTaxBeMoneyDiffClass = 'text-muted-alt';
        }
        const beMoneyImpact = computeBeTaxImpactDiff('breakEvenVsFullMoney', false);
        beMoneyTaxImpactDiffText = beMoneyImpact.text;
        beMoneyTaxImpactDiffClass = beMoneyImpact.className;
      }

      // 10. Breakeven (vs full underlying)
      const entryBeUnd = entryPos.preTax.breakEvenVsFullUnderlying?.absolute;
      const curBeUnd = currentPos.preTax.breakEvenVsFullUnderlying?.absolute;
      if (entryBeUnd != null && curBeUnd != null) {
        const beUndDiff = curBeUnd - entryBeUnd;
        const beUndDiffPct = entryBeUnd > 0 ? (beUndDiff / entryBeUnd) * 100 : 0;
        beUndDiffText = `${beUndDiff >= 0 ? '+' : ''}${dollarFmt.format(beUndDiff)}<br/><small>(${beUndDiff >= 0 ? '+' : ''}${beUndDiffPct.toFixed(1)}%)</small>`;
        beUndDiffClass = beUndDiff >= 0 ? 'text-good' : 'text-bad';
      } else {
        beUndDiffText = '—';
        beUndDiffClass = 'text-muted-alt';
      }

      if (hasTaxes && entryPos.postTax && currentPos.postTax) {
        const ptEntryBeUnd = entryPos.postTax.breakEvenVsFullUnderlying?.absolute;
        const ptCurBeUnd = currentPos.postTax.breakEvenVsFullUnderlying?.absolute;
        if (ptEntryBeUnd != null && ptCurBeUnd != null) {
          const ptBeUndDiff = ptCurBeUnd - ptEntryBeUnd;
          const ptBeUndDiffPct = ptEntryBeUnd > 0 ? (ptBeUndDiff / ptEntryBeUnd) * 100 : 0;
          postTaxBeUndDiffText = `${ptBeUndDiff >= 0 ? '+' : ''}${dollarFmt.format(ptBeUndDiff)}<br/><small>(${ptBeUndDiff >= 0 ? '+' : ''}${ptBeUndDiffPct.toFixed(1)}%)</small>`;
          postTaxBeUndDiffClass = ptBeUndDiff >= 0 ? 'text-good' : 'text-bad';
        } else {
          postTaxBeUndDiffText = '—';
          postTaxBeUndDiffClass = 'text-muted-alt';
        }
        const beUndImpact = computeBeTaxImpactDiff('breakEvenVsFullUnderlying', true);
        beUndTaxImpactDiffText = beUndImpact.text;
        beUndTaxImpactDiffClass = beUndImpact.className;
      }
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
            key: 'moneyYield',
            label: `${activePos.money} Yield`,
            subtitle: `If ${activePos.underlying} &ge; ${strikeLabelForOutcome}`,
            hasSubrow: hasTaxes,
            before: formatMoneyYieldCell(entryPos, true),
            after: formatMoneyYieldCell(currentPos, true),
            single: formatMoneyYieldCell(activePos, false),
            diff: moneyYieldDiffText,
            diffClass: moneyYieldDiffClass
          },
          ...(hasTaxes ? [{
            key: 'moneyYieldPostTax',
            label: 'Post-Tax:',
            subtitle: null,
            isSubrow: true,
            hasSubrow: true,
            before: formatPostTaxMoneyYieldCell(entryPos, true),
            after: formatPostTaxMoneyYieldCell(currentPos, true),
            single: formatPostTaxMoneyYieldCell(activePos, false),
            diff: postTaxMoneyYieldDiffText,
            diffClass: postTaxMoneyYieldDiffClass
          }, {
            key: 'moneyYieldTaxImpact',
            label: 'Tax Impact:',
            subtitle: null,
            isSubrow: true,
            before: formatMoneyYieldTaxImpactCell(entryPos, true),
            after: formatMoneyYieldTaxImpactCell(currentPos, true),
            single: formatMoneyYieldTaxImpactCell(activePos, false),
            diff: moneyYieldTaxImpactDiffText,
            diffClass: moneyYieldTaxImpactDiffClass
          }] : []),
          {
            key: 'undYield',
            label: `${activePos.underlying} Yield`,
            subtitle: `If ${activePos.underlying} &lt; ${strikeLabelForOutcome}`,
            hasSubrow: hasTaxes,
            before: formatUndYieldCell(entryPos, true),
            after: formatUndYieldCell(currentPos, true),
            single: formatUndYieldCell(activePos, false),
            diff: undYieldDiffText,
            diffClass: undYieldDiffClass
          },
          ...(hasTaxes ? [{
            key: 'undYieldPostTax',
            label: 'Post-Tax:',
            subtitle: null,
            isSubrow: true,
            hasSubrow: true,
            before: formatPostTaxUndYieldCell(entryPos, true),
            after: formatPostTaxUndYieldCell(currentPos, true),
            single: formatPostTaxUndYieldCell(activePos, false),
            diff: postTaxUndYieldDiffText,
            diffClass: postTaxUndYieldDiffClass
          }, {
            key: 'undYieldTaxImpact',
            label: 'Tax Impact:',
            subtitle: null,
            isSubrow: true,
            before: formatUndYieldTaxImpactCell(entryPos, true),
            after: formatUndYieldTaxImpactCell(currentPos, true),
            single: formatUndYieldTaxImpactCell(activePos, false),
            diff: undYieldTaxImpactDiffText,
            diffClass: undYieldTaxImpactDiffClass
          }] : [])
        ]
      },
      {
        title: 'Breakevens',
        rows: [
          {
            key: 'beMoney',
            label: `vs 100% ${activePos.money}`,
            subtitle: `<i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i>Less ${activePos.money} below this`,
            hasSubrow: hasTaxes,
            before: formatBeMoneyCell(entryPos, true),
            after: formatBeMoneyCell(currentPos, true),
            single: formatBeMoneyCell(activePos, false),
            diff: beMoneyDiffText,
            diffClass: beMoneyDiffClass
          },
          ...(hasTaxes ? [{
            key: 'beMoneyPostTax',
            label: 'Post-Tax:',
            subtitle: null,
            isSubrow: true,
            hasSubrow: true,
            before: formatPostTaxBeMoneyCell(entryPos, true),
            after: formatPostTaxBeMoneyCell(currentPos, true),
            single: formatPostTaxBeMoneyCell(activePos, false),
            diff: postTaxBeMoneyDiffText,
            diffClass: postTaxBeMoneyDiffClass
          }, {
            key: 'beMoneyTaxImpact',
            label: 'Tax Impact:',
            subtitle: null,
            isSubrow: true,
            before: formatBeMoneyTaxImpactCell(entryPos, true),
            after: formatBeMoneyTaxImpactCell(currentPos, true),
            single: formatBeMoneyTaxImpactCell(activePos, false),
            diff: beMoneyTaxImpactDiffText,
            diffClass: beMoneyTaxImpactDiffClass
          }] : []),
          {
            key: 'beUnd',
            label: `vs 100% ${activePos.underlying}`,
            subtitle: `<i class="fas fa-exclamation-triangle me-1 text-warning-icon"></i>Less ${activePos.underlying} above this`,
            hasSubrow: hasTaxes,
            before: formatBeUndCell(entryPos, true),
            after: formatBeUndCell(currentPos, true),
            single: formatBeUndCell(activePos, false),
            diff: beUndDiffText,
            diffClass: beUndDiffClass
          },
          ...(hasTaxes ? [{
            key: 'beUndPostTax',
            label: 'Post-Tax:',
            subtitle: null,
            isSubrow: true,
            hasSubrow: true,
            before: formatPostTaxBeUndCell(entryPos, true),
            after: formatPostTaxBeUndCell(currentPos, true),
            single: formatPostTaxBeUndCell(activePos, false),
            diff: postTaxBeUndDiffText,
            diffClass: postTaxBeUndDiffClass
          }, {
            key: 'beUndTaxImpact',
            label: 'Tax Impact:',
            subtitle: null,
            isSubrow: true,
            before: formatBeUndTaxImpactCell(entryPos, true),
            after: formatBeUndTaxImpactCell(currentPos, true),
            single: formatBeUndTaxImpactCell(activePos, false),
            diff: beUndTaxImpactDiffText,
            diffClass: beUndTaxImpactDiffClass
          }] : [])
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

  updateYieldBand() {
    const store = getAppStore();
    const chartDom = document.getElementById("strategyChartContainer");
    const chart = typeof echarts !== 'undefined' && chartDom ? echarts.getInstanceByDom(chartDom) : null;
    if (!chart || !store) return;

    chart.setOption({
      series: [buildCoveredCallBandSeries(_ccBandCache, store.ccBiasFactor, store.ccToleranceFactor)]
    });
  }
};

let _ccBandCache = { yHold: 1.0, axisMaxX: 2.0, axisMaxY: 2.0 };

function extractCoveredCallHoldYield(data) {
  if (!Array.isArray(data)) return 1.0;
  for (const item of data) {
    const ep = item?.existingPosition;
    if (!ep) continue;
    const y = ep.postTax?.yield ?? ep.preTax?.yield;
    if (Number.isFinite(y) && y > 0) return y;
  }
  return 1.0;
}

function buildCoveredCallBandSeries(bandCache, biasFactor, tolFactor) {
  const yHold = bandCache?.yHold ?? 1.0;
  const b = Number.isFinite(biasFactor) && biasFactor > 0 ? biasFactor : 1.0;
  const t = Number.isFinite(tolFactor) && tolFactor >= 1.0 ? tolFactor : 1.0;
  const hasBand = t > 1.0001;
  const axisMaxX = bandCache?.axisMaxX ?? 2.0;
  const axisMaxY = bandCache?.axisMaxY ?? 2.0;
  // Pivot around the hold benchmark (yHold, 1.0): xCenter(y) = yHold * (1 + b * (y - 1)).
  // Extending from its x = 0 apex yZero = 1 - 1/b guarantees x(y) = xCenter(y) * ratio at every y >= yZero.
  const yZero = 1.0 - 1.0 / b;
  const yForMaxX = 1.0 + (axisMaxX / Math.max(0.05, yHold) - 1.0) / b;
  const yFar = Math.max(axisMaxY, yForMaxX, 2.0) * 2.0;
  const xCenterFar = yHold * (1.0 + b * (yFar - 1.0));
  const xLowFar = xCenterFar / t;
  const xHighFar = xCenterFar * t;

  return {
    id: 'ccBiasBandSeries',
    name: 'Target Band',
    type: 'custom',
    coordinateSystem: 'cartesian2d',
    silent: true,
    clip: true,
    animation: false,
    z: 2,
    itemStyle: {
      color: '#fcd34d'
    },
    data: [0],
    renderItem: function (params, api) {
      const pApex = api.coord([0, yZero]);
      const pCenterFar = api.coord([xCenterFar, yFar]);
      const children = [];

      if (hasBand) {
        const pLowFar = api.coord([xLowFar, yFar]);
        const pHighFar = api.coord([xHighFar, yFar]);
        children.push({
          type: 'polygon',
          shape: {
            points: [pApex, pLowFar, pHighFar]
          },
          style: {
            fill: 'rgba(252, 211, 77, 0.13)'
          }
        });
        children.push({
          type: 'line',
          shape: {
            x1: pApex[0], y1: pApex[1],
            x2: pLowFar[0], y2: pLowFar[1]
          },
          style: {
            stroke: 'rgba(252, 211, 77, 0.45)',
            lineWidth: 1.5,
            lineDash: [4, 4]
          }
        });
        children.push({
          type: 'line',
          shape: {
            x1: pApex[0], y1: pApex[1],
            x2: pHighFar[0], y2: pHighFar[1]
          },
          style: {
            stroke: 'rgba(252, 211, 77, 0.45)',
            lineWidth: 1.5,
            lineDash: [4, 4]
          }
        });
      }

      children.push({
        type: 'line',
        shape: {
          x1: pApex[0], y1: pApex[1],
          x2: pCenterFar[0], y2: pCenterFar[1]
        },
        style: {
          stroke: '#fcd34d',
          lineWidth: 2.0,
          lineDash: [6, 5],
          opacity: 0.85
        }
      });

      return {
        type: 'group',
        children
      };
    }
  };
}

function calculateOverlay(target) {
  const store = getAppStore();
  const entryPosition = store ? store.entryPosition : null;
  const entryMetrics = entryPosition?.postTax ?? entryPosition?.preTax;
  if (!entryMetrics) return null;

  const { moneyYield, underlyingYield } = entryMetrics;
  const targetMetrics = target?.postTax ?? target?.preTax;
  if (!targetMetrics) {
    return {
      entry: [moneyYield, underlyingYield],
      current: null
    };
  }

  const targetMoneyYield = targetMetrics.moneyYield;
  const targetUndYield = targetMetrics.underlyingYield;
  const moneyRatio = targetMoneyYield ? moneyYield / targetMoneyYield : null;
  const underlyingRatio = targetUndYield ? underlyingYield / targetUndYield : null;
  const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
  const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

  return {
    entry: [moneyYield, underlyingYield],
    current: (moneyDiffers || underlyingDiffers) ? [targetMoneyYield, targetUndYield] : null
  };
}


function renderCoveredCallsChart(data, chartDom, idToSelect) {
  const money = data.at(0)?.money || '';
  const underlying = data.at(0)?.underlying || '';

  const store = getAppStore();

  const targetItem = data.find(item => item.id === idToSelect);
  const overlay = calculateOverlay(targetItem);

  const chartSource = data.map(item => {
    const active = item.postTax ?? item.preTax;
    return {
      ...item,
      moneyYield: active.moneyYield,
      underlyingYield: active.underlyingYield
    };
  });

  const moneyYields = chartSource.map(d => d.moneyYield).filter(Number.isFinite);
  const undYields = chartSource.map(d => d.underlyingYield).filter(Number.isFinite);

  const selectedCoord = targetItem
    ? [
      (targetItem.postTax ?? targetItem.preTax).moneyYield,
      (targetItem.postTax ?? targetItem.preTax).underlyingYield
    ]
    : null;
  const entryCoord = overlay?.entry || null;
  const focusCoords = [selectedCoord, entryCoord].filter(
    c => c && Number.isFinite(c[0]) && Number.isFinite(c[1])
  );

  const DEFAULT_SPAN = 0.5;
  const FOCUS_PAD = 0.05;
  const snapDown = (val, step = 0.05) => Math.floor(val / step) * step;
  const snapUp = (val, step = 0.05) => Math.ceil(val / step) * step;

  const minUndYield = undYields.length ? Math.min(...undYields) : 1.0;
  const baseYStart = (minUndYield >= 1.0 && minUndYield <= 1.25)
    ? 1.0
    : snapDown(minUndYield - 0.02);
  let yStart = baseYStart;
  let yEnd = baseYStart + DEFAULT_SPAN;

  for (const [, fy] of focusCoords) {
    if (fy - FOCUS_PAD < yStart) {
      yStart = (fy >= 1.0 && yStart === 1.0) ? 1.0 : snapDown(fy - FOCUS_PAD);
    }
    if (fy + FOCUS_PAD > yEnd) {
      yEnd = snapUp(fy + FOCUS_PAD);
    }
  }

  const yBandMoneyYields = chartSource
    .filter(d => Number.isFinite(d.moneyYield) && Number.isFinite(d.underlyingYield) && d.underlyingYield >= yStart && d.underlyingYield <= yEnd)
    .map(d => d.moneyYield);
  const effectiveMoneyYields = yBandMoneyYields.length ? yBandMoneyYields : moneyYields;
  const minMoneyYield = effectiveMoneyYields.length ? Math.min(...effectiveMoneyYields) : 1.0;

  const baseXStart = (minMoneyYield >= 1.0 && minMoneyYield <= 1.25)
    ? 1.0
    : snapDown(minMoneyYield - 0.02);
  let xStart = baseXStart;
  let xEnd = baseXStart + DEFAULT_SPAN;

  for (const [fx] of focusCoords) {
    if (fx - FOCUS_PAD < xStart) {
      xStart = (fx >= 1.0 && xStart === 1.0) ? 1.0 : snapDown(fx - FOCUS_PAD);
    }
    if (fx + FOCUS_PAD > xEnd) {
      xEnd = snapUp(fx + FOCUS_PAD);
    }
  }

  const allX = [...moneyYields, ...focusCoords.map(c => c[0])];
  const allY = [...undYields, ...focusCoords.map(c => c[1])];
  const minX = allX.length ? Math.min(...allX) : 1.0;
  const maxX = allX.length ? Math.max(...allX) : 1.5;
  const minY = allY.length ? Math.min(...allY) : 1.0;
  const maxY = allY.length ? Math.max(...allY) : 1.5;

  const defaultZoom = [xStart, xEnd, yStart, yEnd];
  [xStart, xEnd, yStart, yEnd] = resolveInitialChartZoom(defaultZoom);

  const axisMinX = Math.min(xStart, minX < 1.0 ? snapDown(minX - 0.1) : 1.0);
  const axisMaxX = Math.max(xEnd, maxX + 0.5);
  const axisMinY = Math.min(yStart, minY < 1.0 ? snapDown(minY - 0.1) : 1.0);
  const axisMaxY = Math.max(yEnd, maxY + 0.5);

  _ccBandCache = {
    yHold: extractCoveredCallHoldYield(data),
    axisMaxX,
    axisMaxY
  };

  const dataset = {
    id: "original",
    dimensions: ["moneyYield", "underlyingYield", "DTE", "id"],
    source: chartSource
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
      min: axisMinX,
      max: axisMaxX,
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
      min: axisMinY,
      max: axisMaxY
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
      buildCoveredCallBandSeries(
        _ccBandCache,
        store?.ccBiasFactor ?? 1.0,
        store?.ccToleranceFactor ?? 1.05
      )
    ],
    legend: legend,
    animationDurationUpdate: 800,
    animationEasingUpdate: 'quinticOut',
    dataZoom: [
      {
        type: 'inside',
        maxValueSpan: Math.max(1.0, xEnd - xStart),
        throttle: 50,
        xAxisIndex: 0,
        filterMode: 'none',
        startValue: xStart,
        endValue: xEnd
      },
      {
        type: 'inside',
        maxValueSpan: Math.max(1.0, yEnd - yStart),
        throttle: 50,
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
  bindChartZoomSync(chart, defaultZoom, [axisMinX, axisMaxX, axisMinY, axisMaxY]);

  selectStrategyById(idToSelect);
  return chart;
}
