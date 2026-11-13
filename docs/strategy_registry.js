class BaseStrategyConfig {
  constructor() {
    if (this.constructor === BaseStrategyConfig) {
      throw new TypeError("Cannot construct BaseStrategyConfig instances directly");
    }
  }

  /**
   * Prepares strategy-specific data for binding to the details template.
   * @param {object} dataObj - The raw strategy item data.
   * @returns {object} The template-bound fields.
   */
  prepareData(dataObj) {
    throw new Error(`${this.constructor.name} must implement prepareData`);
  }

  /**
   * Formats and returns HTML tooltip content for chart hover.
   * @param {object} dataObj - The raw strategy item data.
   * @returns {string} The HTML formatted tooltip.
   */
  renderTooltip(dataObj) {
    throw new Error(`${this.constructor.name} must implement renderTooltip`);
  }

  /**
   * Optional callback preparing data for the unrealized template.
   * @param {object} dataObj
   * @returns {object|null}
   */
  prepareUnrealizedOrRollData(dataObj) {
    return null;
  }

  /**
   * Optional callback called when selection changes on the chart.
   * @param {string|null} idToSelect - The strategy item ID selected, or null to clear selection.
   */
  updateSelection(idToSelect) { }

  createEntryPosition(dataObj) {
    return null;
  }

  encodeEntryPosition(entryPosition) {
    if (!entryPosition) return null;
    return UrlManager.encodeState(entryPosition);
  }

  decodeEntryPosition(encoded) {
    if (!encoded) return null;
    return UrlManager.decodeState(encoded);
  }
}

function getAppStore() {
  const store = Alpine.store('app');
  if (!store) {
    throw new Error("Alpine app store is not initialized");
  }
  return store;
}

const StrategyRegistry = {};

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

function extractSpotPrice(data) {
  return data.at(0)?.spotPrice;
}

function selectStrategyById(idToSelect) {
  const store = getAppStore();
  if (!store) return;

  const strategy = store.strategy; // 'coveredCall', 'longOption'

  let targetItem = null;
  if (idToSelect && store.chartData) {
    targetItem = store.chartData.find(item => item.id === idToSelect);
  }

  if (!idToSelect || !targetItem) {
    store.selectedId = null;

    if (store.entryPosition) {
      const entryType = store.entryPosition.strategyType || strategy;
      const entryConfig = StrategyRegistry[entryType];
      store.details = entryConfig && entryConfig.prepareData ? entryConfig.prepareData(store.entryPosition) : null;
    } else {
      store.details = null;
    }
    store.updateUnrealized();

    const registryTypes = getRegistryTypesForStrategy(strategy);
    for (const type of registryTypes) {
      const config = StrategyRegistry[type];
      if (config && config.updateSelection) {
        config.updateSelection(null);
      }
    }
    return;
  }

  store.selectedId = idToSelect;

  const config = StrategyRegistry[targetItem.strategyType];
  if (config) {
    // Update details and unrealized/unified view
    store.details = config.prepareData(targetItem);
    store.updateUnrealized();

    if (config.updateSelection) {
      config.updateSelection(idToSelect);
    }
  }
}

function getRegistryTypesForStrategy(strategy) {
  if (strategy === 'longOption') {
    return ['longCall', 'longPut'];
  }
  return [strategy];
}

function resolveInitialChartZoom(defaultZoom) {
  const store = getAppStore();
  const z = store?.chartZoom;
  if (
    Array.isArray(z) &&
    z.length === 4 &&
    z.map(Number).every(Number.isFinite) &&
    Number(z[1]) > Number(z[0]) &&
    Number(z[3]) > Number(z[2])
  ) {
    return [Number(z[0]), Number(z[1]), Number(z[2]), Number(z[3])];
  }
  return defaultZoom;
}

function extractZoomAxisRange(dzEntry, fallbackStart, fallbackEnd, axisMin, axisMax) {
  if (dzEntry && Number.isFinite(Number(dzEntry.startValue)) && Number.isFinite(Number(dzEntry.endValue))) {
    return [Number(dzEntry.startValue), Number(dzEntry.endValue)];
  }
  if (
    dzEntry &&
    Number.isFinite(Number(dzEntry.start)) &&
    Number.isFinite(Number(dzEntry.end)) &&
    Number.isFinite(axisMin) &&
    Number.isFinite(axisMax)
  ) {
    const span = axisMax - axisMin;
    return [
      axisMin + (Number(dzEntry.start) / 100) * span,
      axisMin + (Number(dzEntry.end) / 100) * span
    ];
  }
  return [fallbackStart, fallbackEnd];
}

function bindChartZoomSync(chart, defaultZoom, axisBounds = []) {
  if (!chart || typeof chart.on !== 'function') return;
  const [axisMinX, axisMaxX, axisMinY, axisMaxY] = axisBounds;
  let debounceTimer = null;

  chart.on('datazoom', function () {
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      const store = getAppStore();
      if (!store || typeof store.setChartZoom !== 'function') return;
      const opt = typeof chart.getOption === 'function' ? chart.getOption() : null;
      const dz = Array.isArray(opt?.dataZoom) ? opt.dataZoom : [];
      const [x0, x1] = extractZoomAxisRange(dz[0], defaultZoom[0], defaultZoom[1], axisMinX, axisMaxX);
      const [y0, y1] = extractZoomAxisRange(dz[1], defaultZoom[2], defaultZoom[3], axisMinY, axisMaxY);
      const cur = [x0, x1, y0, y1];
      const isDefault = defaultZoom.every((dv, i) => Math.abs(cur[i] - dv) <= Math.max(1e-4, Math.abs(dv) * 1e-4));
      store.setChartZoom(isDefault ? null : cur);
    }, 100);
  });
}
