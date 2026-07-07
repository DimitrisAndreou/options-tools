const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const unsignedPercentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'never',
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
  confine: true,
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

const selectionHighlightSeries = {
  id: 'selectionHighlight',
  type: 'scatter',
  datasetId: 'highlightDataset',
  symbol: 'circle',
  symbolSize: 80,
  itemStyle: {
    color: 'transparent',
    borderColor: 'rgba(255, 255, 255, 1.0)',
    borderWidth: 4,
    borderType: 'dashed'
  },
  silent: true,
  z: 10
};

/**
 * Prepares and formats the raw data for display.
 */
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

function prepareStraddleData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Straddle',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeRelative - 1.0),

    callName: value.call,
    callURL: value.callURL,
    callSize: value.callSize,
    callCostInMoney: dollarFmt.format(value.callCostInMoney),
    callCostInUnderlying: underlyingFmt.format(value.callCostInUnderlying),

    putName: value.put,
    putURL: value.putURL,
    putSize: value.putSize,
    putCostInMoney: dollarFmt.format(value.putCostInMoney),
    putCostInUnderlying: underlyingFmt.format(value.putCostInUnderlying),

    costInMoney: dollarFmt.format(-value.moneySize),
    costInUnderlying: underlyingFmt.format(value.costInUnderlying),

    // Distance between breakevens
    distanceAbsolute: dollarFmt.format(value.distanceBetweenBreakEvensAbsolute),
    distanceRelative: `${percentFmt.format(value.breakEvenVsFullMoneyDownRelative - 1.0)} ... ${percentFmt.format(value.breakEvenVsFullMoneyUpRelative - 1.0)}`,

    // Breakeven vs cash/money
    beMoneyDownAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyDownAbsolute),
    beMoneyDownRelative: percentFmt.format(value.breakEvenVsFullMoneyDownRelative - 1.0),
    beMoneyUpAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyUpAbsolute),
    beMoneyUpRelative: percentFmt.format(value.breakEvenVsFullMoneyUpRelative - 1.0),

    // Breakeven vs underlying
    beUnderlyingDownAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingDownAbsolute),
    beUnderlyingDownRelative: percentFmt.format(value.breakEvenVsFullUnderlyingDownRelative - 1.0),
    beUnderlyingUpAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingUpAbsolute),
    beUnderlyingUpRelative: percentFmt.format(value.breakEvenVsFullUnderlyingUpRelative - 1.0),

    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.costInUnderlying)} ${underlying}`
  };
}

function renderTooltipStraddle(d) {
  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="tooltip-yield-bad">Risk Zone: ${d.distanceRelative}</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          Strike: ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
      </div>

      <div class="tooltip-breakeven">
        <span class="text-label">Breakevens:</span> <br/>
        &bull; Down: <span class="text-good">${d.beMoneyDownAbsolute}</span> <span class="text-good">(${d.beMoneyDownRelative})</span> <br/>
        &bull; Up: <span class="text-good">${d.beMoneyUpAbsolute}</span> <span class="text-good">(${d.beMoneyUpRelative})</span>
      </div>
      
      <div class="tooltip-footer">
        Cost: <span class="text-light-alt">${d.costInMoney}</span> (${d.costInUnderlying} ${d.underlying})
      </div>
    </div>
  `;
}


// Return the properties of a previously opened position on this strategy,
// from URL params, if such a position is found.
function getOpenParams() {
  const openMoneyYieldStr = UrlManager.get(URL_PARAMS.OPEN_MONEY_YIELD);
  const openUnderlyingYieldStr = UrlManager.get(URL_PARAMS.OPEN_UNDERLYING_YIELD);
  const openDteStr = UrlManager.get(URL_PARAMS.OPEN_DTE);

  const openMoneyYield = openMoneyYieldStr !== null ? parseFloat(openMoneyYieldStr) : NaN;
  const openUnderlyingYield = openUnderlyingYieldStr !== null ? parseFloat(openUnderlyingYieldStr) : NaN;
  const openDTE = openDteStr !== null ? parseInt(openDteStr, 10) : NaN;

  let failed = false;
  let urlModified = false;
  const url = UrlManager.createUrl();

  if (openMoneyYieldStr !== null && isNaN(openMoneyYield)) {
    UrlManager.set(url, URL_PARAMS.OPEN_MONEY_YIELD, null);
    urlModified = true;
    failed = true;
  }
  if (openUnderlyingYieldStr !== null && isNaN(openUnderlyingYield)) {
    UrlManager.set(url, URL_PARAMS.OPEN_UNDERLYING_YIELD, null);
    urlModified = true;
    failed = true;
  }
  if (openDteStr !== null && isNaN(openDTE)) {
    UrlManager.set(url, URL_PARAMS.OPEN_DTE, null);
    urlModified = true;
    failed = true;
  }

  if (urlModified) {
    UrlManager.replaceState(url);
  }

  if (failed || isNaN(openMoneyYield) || isNaN(openUnderlyingYield) || isNaN(openDTE)) {
    return null;
  }

  return {
    openMoneyYield,
    openUnderlyingYield,
    openDTE
  };
}

const StrategyRegistry = {
  'coveredCall': {
    templateId: 'coveredCall-details-template',
    prepareData: prepareCCData,
    renderTooltip: renderTooltipCC,
    urlParams: [
      URL_PARAMS.OPEN_DTE,
      URL_PARAMS.OPEN_MONEY_YIELD,
      URL_PARAMS.OPEN_UNDERLYING_YIELD
    ],
    updateUrlParams: function (url, dataObj) {
      UrlManager.set(url, URL_PARAMS.OPEN_DTE, dataObj.DTE);
      UrlManager.set(url, URL_PARAMS.OPEN_MONEY_YIELD, dataObj.moneyYield !== undefined ? Number(dataObj.moneyYield).toFixed(4) : null);
      UrlManager.set(url, URL_PARAMS.OPEN_UNDERLYING_YIELD, dataObj.underlyingYield !== undefined ? Number(dataObj.underlyingYield).toFixed(4) : null);
    },
    unrealizedTemplateId: 'unrealized-results-template',
    prepareUnrealizedData: function (dataObj) {
      const openParams = getOpenParams();
      if (!openParams) {
        return null;
      }
      const openMoneyYield = openParams.openMoneyYield;
      const openUnderlyingYield = openParams.openUnderlyingYield;
      const openDTE = openParams.openDTE;

      const moneyRatio = !isNaN(openMoneyYield) && dataObj.moneyYield ? openMoneyYield / dataObj.moneyYield : null;
      const underlyingRatio = !isNaN(openUnderlyingYield) && dataObj.underlyingYield ? openUnderlyingYield / dataObj.underlyingYield : null;

      const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
      const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

      if (!moneyDiffers && !underlyingDiffers) {
        return null;
      }

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

      return res;
    }
  },
  'longCall': {
    templateId: 'longCall-details-template',
    prepareData: prepareLongCallData,
    renderTooltip: renderTooltipLongCall
  },
  'longPut': {
    templateId: 'longPut-details-template',
    prepareData: prepareLongPutData,
    renderTooltip: renderTooltipLongPut
  },
  'straddle': {
    templateId: 'straddle-details-template',
    prepareData: prepareStraddleData,
    renderTooltip: renderTooltipStraddle
  }
};

const strategyTooltipFormatter = function (params) {
  if (!params || !params.value) return '';
  const type = params.value.strategyType;
  const config = StrategyRegistry[type];
  if (!config) {
    console.error(`Unknown strategyType: ${type}`);
    return '';
  }
  const data = config.prepareData(params.value);
  return config.renderTooltip(data);
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

function selectStrategyById(chart, data, idToSelect) {
  const panel = document.getElementById('strategyDetailsPanel');
  if (panel) {
    panel.innerHTML = '';
  }
  const strategyType = data.at(0)?.strategyType;
  if (!idToSelect) {
    const url = UrlManager.createUrl();
    UrlManager.set(url, URL_PARAMS.ID, null);
    if (strategyType) {
      const config = StrategyRegistry[strategyType];
      if (config && config.urlParams) {
        UrlManager.clearParams(url, config.urlParams);
      }
    }
    UrlManager.replaceState(url);
    const updateObj = {
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': '' } }
      }]
    };
    chart.setOption(updateObj);
    return;
  }
  const targetItem = data.find(item => item.id === idToSelect);
  if (!targetItem) {
    const url = UrlManager.createUrl();
    UrlManager.set(url, URL_PARAMS.ID, null);
    if (strategyType) {
      const config = StrategyRegistry[strategyType];
      if (config && config.urlParams) {
        UrlManager.clearParams(url, config.urlParams);
      }
    }
    UrlManager.replaceState(url);
    const updateObj = {
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': '' } }
      }]
    };
    chart.setOption(updateObj);
    return;
  }

  populateStrategyDetails(targetItem);

  const updateObj = {
    dataset: [{
      id: 'highlightDataset',
      transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect } }
    }]
  };

  chart.setOption(updateObj);
}

function populateStrategyDetails(dataObj) {
  if (!dataObj || !dataObj.strategyType) {
    throw new Error('Missing strategyType in data object');
  }

  const config = StrategyRegistry[dataObj.strategyType];
  if (!config) {
    throw new Error(`Unknown strategyType: ${dataObj.strategyType}`);
  }

  if (dataObj.id) {
    const url = UrlManager.createUrl();
    const previousUrlId = url.searchParams.get(URL_PARAMS.ID);
    UrlManager.set(url, URL_PARAMS.ID, dataObj.id);

    const hasParams = config.urlParams && config.urlParams.every(param => url.searchParams.has(param));
    if (previousUrlId !== dataObj.id || !hasParams) {
      if (config.urlParams) {
        UrlManager.clearParams(url, config.urlParams);
      }
      if (config.updateUrlParams) {
        config.updateUrlParams(url, dataObj);
      }
    }
    UrlManager.replaceState(url);
  }

  const unrealizedPanel = document.getElementById('unrealizedResultsPanel');
  if (unrealizedPanel) {
    unrealizedPanel.innerHTML = '';
    unrealizedPanel.style.display = 'none';
  }

  if (config.unrealizedTemplateId && config.prepareUnrealizedData) {
    const unrealizedData = config.prepareUnrealizedData(dataObj);
    const template = document.getElementById(config.unrealizedTemplateId);
    if (unrealizedData && unrealizedPanel && template) {
      const clone = template.content.cloneNode(true);
      for (const [key, value] of Object.entries(unrealizedData)) {
        if (key.endsWith('Class')) {
          clone.querySelectorAll(`.tpl-${key}`).forEach(el => {
            el.className = `tpl-${key} ${value}`;
          });
        } else {
          clone.querySelectorAll(`.tpl-${key}`).forEach(el => {
            el.innerHTML = value;
          });
        }
      }
      unrealizedPanel.appendChild(clone);
      unrealizedPanel.style.display = 'block';
    }
  }

  const panel = document.getElementById('strategyDetailsPanel');
  const template = document.getElementById(config.templateId);

  if (panel && template) {
    const d = config.prepareData(dataObj);
    const clone = template.content.cloneNode(true);

    for (const [key, value] of Object.entries(d)) {
      clone.querySelectorAll(`.tpl-${key}`).forEach(el => {
        el.innerHTML = value;
      });
      clone.querySelectorAll(`.tpl-href-${key}`).forEach(el => {
        if (value) {
          el.href = value;
        } else {
          // If there is no URL, unwrap the link
          el.outerHTML = el.innerHTML;
        }
      });
    }

    panel.innerHTML = '';
    panel.appendChild(clone);
  }
}

/**
 * Renders the covered calls options chart.
 * 
 * IMPORTANT: The elements in the `data` array MUST contain `moneyYield` and `underlyingYield` 
 * properties, as these are required to map to the X and Y coordinates on the chart.
 */
function renderCoveredCallsChart(data, chartDom, idToSelect) {
  const money = data.at(0)?.money || '';
  const underlying = data.at(0)?.underlying || '';

  const targetItem = data.find(item => item.id === idToSelect);
  const openParams = getOpenParams();
  let showOverlay = false;
  let openCoords = null;
  let currentCoords = null;

  if (openParams && targetItem) {
    const openMoneyYield = openParams.openMoneyYield;
    const openUnderlyingYield = openParams.openUnderlyingYield;
    const moneyRatio = targetItem.moneyYield ? openMoneyYield / targetItem.moneyYield : null;
    const underlyingRatio = targetItem.underlyingYield ? openUnderlyingYield / targetItem.underlyingYield : null;
    const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
    const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

    if (moneyDiffers || underlyingDiffers) {
      showOverlay = true;
      openCoords = [openMoneyYield, openUnderlyingYield];
      currentCoords = [targetItem.moneyYield, targetItem.underlyingYield];
    }
  }

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
          data: showOverlay ? [{ coord: openCoords }] : []
        },
        markLine: {
          symbol: ['none', 'arrow'],
          symbolSize: [0, 18],
          lineStyle: {
            color: '#ff5c5c',
            width: 3,
            type: 'dashed'
          },
          data: showOverlay ? [[{ coord: openCoords }, { coord: currentCoords }]] : []
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
    animationDurationUpdate: 800,      // Higher = slower/heavier feel
    animationEasingUpdate: 'quinticOut', // A very smooth, slow-stopping curve
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
      selectStrategyById(chart, data, params.data.id);

      const targetItem = data.find(item => item.id === params.data.id);
      const openParams = getOpenParams();
      let clickShowOverlay = false;
      let clickOpenCoords = null;
      let clickCurrentCoords = null;

      if (openParams && targetItem) {
        const { openMoneyYield, openUnderlyingYield } = openParams;
        const moneyRatio = targetItem.moneyYield ? openMoneyYield / targetItem.moneyYield : null;
        const underlyingRatio = targetItem.underlyingYield ? openUnderlyingYield / targetItem.underlyingYield : null;
        const moneyDiffers = moneyRatio !== null && Math.abs(moneyRatio - 1.0) > 0.0001;
        const underlyingDiffers = underlyingRatio !== null && Math.abs(underlyingRatio - 1.0) > 0.0001;

        if (moneyDiffers || underlyingDiffers) {
          clickShowOverlay = true;
          clickOpenCoords = [openMoneyYield, openUnderlyingYield];
          clickCurrentCoords = [targetItem.moneyYield, targetItem.underlyingYield];
        }
      }

      chart.setOption({
        series: [{
          id: 'openOverlay',
          markPoint: {
            data: clickShowOverlay ? [{ coord: clickOpenCoords }] : []
          },
          markLine: {
            symbol: ['none', 'arrow'],
            symbolSize: [0, 18],
            lineStyle: {
              color: '#ff5c5c',
              width: 3,
              type: 'dashed'
            },
            data: clickShowOverlay ? [[{ coord: clickOpenCoords }, { coord: clickCurrentCoords }]] : []
          }
        }]
      });
    }
  });
  chart.on('datazoom', function () {
    chart.dispatchAction({
      type: 'hideTip'
    });
  });

  selectStrategyById(chart, data, idToSelect);
  return chart;
}

/**
 * Renders the long options chart.
 */
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
      selectStrategyById(chart, data, params.data.id);
    }
  });
  chart.on('datazoom', function () {
    chart.dispatchAction({
      type: 'hideTip'
    });
  });

  selectStrategyById(chart, data, idToSelect);
  return chart;
}

function renderStraddlesChart(data, chartDom, idToSelect) {
  const money = data.at(0)?.money || '';
  const underlying = data.at(0)?.underlying || '';
  const dataset = {
    id: "original",
    dimensions: [
      "DTE",
      "breakEvenVsFullMoneyDownRelative",
      "breakEvenVsFullMoneyUpRelative",
      "strikeRelative",
      "id"
    ],
    source: data
  };
  const highlightDataset = {
    id: 'highlightDataset',
    fromDatasetId: 'original',
    transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect || '' } }
  };

  const chart = echarts.init(chartDom);
  window.addEventListener('resize', function () {
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, highlightDataset],
    xAxis: {
      type: 'value',
      name: 'DTE (Days to Expiration)➡',
      nameLocation: 'end',
      nameGap: 0,
      nameTextStyle: {
        ...axisTitleNameTextStyle,
        align: 'right',
        verticalAlign: 'top',
        padding: [30, 0, 0, 0]
      },
      axisLabel: axisXValuesNameTextStyle,
      axisLine,
      min: function (value) { return Math.max(0, value.min - 7); },
      max: function (value) { return value.max + 7; },
      position: 'bottom',
    },
    grid,
    yAxis: {
      type: 'value',
      name: `⇳ Breakevens`,
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
      {
        type: 'custom',
        name: 'Straddles',
        renderItem: function (params, api) {
          var dte = api.value(0);
          var down = api.value(1);
          var up = api.value(2);
          var strike = api.value(3);

          var coordDown = api.coord([dte, down]);
          var coordUp = api.coord([dte, up]);
          var coordStrike = api.coord([dte, strike]);

          var barWidth = 3;
          var capRadius = 5;
          var strikeRadius = 4;

          return {
            type: 'group',
            children: [
              {
                type: 'line',
                shape: {
                  x1: coordDown[0],
                  y1: coordDown[1],
                  x2: coordUp[0],
                  y2: coordUp[1]
                },
                style: api.style({
                  stroke: '#ef4444',
                  lineWidth: barWidth
                }),
                emphasis: {
                  style: {
                    stroke: 'red',
                    lineWidth: barWidth + 1
                  }
                }
              },
              {
                type: 'circle',
                shape: {
                  cx: coordDown[0],
                  cy: coordDown[1],
                  r: capRadius
                },
                style: api.style({
                  fill: '#10b981'
                }),
                emphasis: {
                  style: {
                    fill: '#10b981',
                    stroke: 'white',
                    lineWidth: 2
                  }
                }
              },
              {
                type: 'circle',
                shape: {
                  cx: coordUp[0],
                  cy: coordUp[1],
                  r: capRadius
                },
                style: api.style({
                  fill: '#10b981'
                }),
                emphasis: {
                  style: {
                    fill: '#10b981',
                    stroke: 'white',
                    lineWidth: 2
                  }
                }
              },
              {
                type: 'circle',
                shape: {
                  cx: coordStrike[0],
                  cy: coordStrike[1],
                  r: strikeRadius
                },
                style: api.style({
                  fill: '#fcd34d'
                }),
                emphasis: {
                  style: {
                    fill: '#fcd34d',
                    stroke: 'white',
                    lineWidth: 2
                  }
                }
              }
            ]
          };
        },
        encode: {
          x: 'DTE',
          y: ['breakEvenVsFullMoneyDownRelative', 'breakEvenVsFullMoneyUpRelative']
        },
        emphasis: {
          focus: 'self'
        },
        dimensions: [
          "DTE",
          "breakEvenVsFullMoneyDownRelative",
          "breakEvenVsFullMoneyUpRelative",
          "strikeRelative"
        ],
        datasetId: 'original'
      },
      {
        ...selectionHighlightSeries,
        encode: { x: 'DTE', y: 'strikeRelative' }
      }
    ],
    legend: { show: false },
    animationDurationUpdate: 800,
    animationEasingUpdate: 'quinticOut',
  });

  chart.on('click', function (params) {
    if (params.componentType === 'series' && params.data) {
      selectStrategyById(chart, data, params.data.id);
    }
  });

  selectStrategyById(chart, data, idToSelect);
  return chart;
}
