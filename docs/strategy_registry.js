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

  const strategy = store.strategy; // 'coveredCall', 'longOption', 'straddle'

  let targetItem = null;
  if (idToSelect && store.chartData) {
    targetItem = store.chartData.find(item => item.id === idToSelect);
  }

  if (!idToSelect || !targetItem) {
    store.selectedId = null;
    store.details = null;
    store.unrealized = null;
    store.entryPosition = null;

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

    // If entry position exists, ensure it is still correctly encoded in URL
    if (store.entryPosition) {
      const encoded = config.encodeEntryPosition(store.entryPosition);
      UrlManager.set(url, URL_PARAMS.POS, encoded);
    }
    UrlManager.replaceState(url);

    // Update details and unrealized
    store.details = config.prepareData(targetItem);
    if (config.prepareUnrealizedOrRollData) {
      store.unrealized = config.prepareUnrealizedOrRollData(targetItem);
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
