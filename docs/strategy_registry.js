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
  prepareUnrealizedData(dataObj) {
    return null;
  }

  /**
   * Optional callback called when selection changes on the chart.
   * @param {string|null} idToSelect - The strategy item ID selected, or null to clear selection.
   */
  updateSelection(idToSelect) { }

  createOpenPosition(dataObj) {
    return null;
  }

  encodeOpenPosition(openPosition) {
    if (!openPosition) return null;
    return UrlManager.encodeState(openPosition);
  }

  decodeOpenPosition(encoded) {
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

  const strategy = store.strategy; // 'coveredCall', 'longOption', 'straddle'

  let targetItem = null;
  if (idToSelect && store.chartData) {
    targetItem = store.chartData.find(item => item.id === idToSelect);
  }

  if (!idToSelect || !targetItem) {
    store.selectedId = null;
    store.details = null;
    store.unrealized = null;
    store.openPosition = null;

    const url = UrlManager.createUrl();
    UrlManager.set(url, URL_PARAMS.ID, null);
    UrlManager.clearParams(url, [URL_PARAMS.POS]);
    UrlManager.replaceState(url);

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
    const url = UrlManager.createUrl();
    UrlManager.set(url, URL_PARAMS.ID, idToSelect);

    // Only set open position if it does not exist yet!
    if (!store.openPosition) {
      const openPos = config.createOpenPosition(targetItem);
      if (openPos) {
        store.openPosition = openPos;
        const encoded = config.encodeOpenPosition(openPos);
        UrlManager.set(url, URL_PARAMS.POS, encoded);
      }
    } else {
      // If it exists, ensure it is still correctly encoded in URL
      const encoded = config.encodeOpenPosition(store.openPosition);
      UrlManager.set(url, URL_PARAMS.POS, encoded);
    }
    UrlManager.replaceState(url);

    // Update details and unrealized
    store.details = config.prepareData(targetItem);
    if (config.prepareUnrealizedData) {
      store.unrealized = config.prepareUnrealizedData(targetItem);
    } else {
      store.unrealized = null;
    }

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
