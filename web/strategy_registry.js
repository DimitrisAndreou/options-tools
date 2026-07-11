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
   * Optional callback to serialize strategy state into URL query params.
   * @param {URL} url
   * @param {object} dataObj
   */
  updateUrlParams(url, dataObj) {
    const openPos = this.createOpenPosition(dataObj);
    if (!openPos) return;
    const store = getAppStore();
    if (store) {
      store.openPosition = openPos;
    }
    const encoded = this.encodeOpenPosition(openPos);
    UrlManager.set(url, URL_PARAMS.POS, encoded);
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
  updateSelection(idToSelect) {}

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

    const registryTypes = getRegistryTypesForStrategy(strategy);
    for (const type of registryTypes) {
      const config = StrategyRegistry[type];
      if (config) {
        UrlManager.clearParams(url, [URL_PARAMS.POS]);
        if (config.updateSelection) {
          config.updateSelection(null);
        }
      }
    }
    UrlManager.replaceState(url);
    return;
  }

  store.selectedId = idToSelect;
  populateStrategyDetails(targetItem);

  const url = UrlManager.createUrl();
  const previousUrlId = url.searchParams.get(URL_PARAMS.ID);
  UrlManager.set(url, URL_PARAMS.ID, idToSelect);

  const config = StrategyRegistry[targetItem.strategyType];
  if (config) {
    const hasParams = url.searchParams.has(URL_PARAMS.POS);
    if (previousUrlId !== idToSelect || !hasParams) {
      UrlManager.clearParams(url, [URL_PARAMS.POS]);
      if (config.updateUrlParams) {
        config.updateUrlParams(url, targetItem);
      }
    }
    UrlManager.replaceState(url);

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

function populateStrategyDetails(dataObj) {
  if (!dataObj || !dataObj.strategyType) {
    throw new Error('Missing strategyType in data object');
  }

  const config = StrategyRegistry[dataObj.strategyType];
  if (!config) {
    throw new Error(`Unknown strategyType: ${dataObj.strategyType}`);
  }

  const store = getAppStore();

  if (dataObj.id) {
    const url = UrlManager.createUrl();
    const previousUrlId = url.searchParams.get(URL_PARAMS.ID);
    UrlManager.set(url, URL_PARAMS.ID, dataObj.id);

    const hasParams = url.searchParams.has(URL_PARAMS.POS);
    if (previousUrlId !== dataObj.id || !hasParams) {
      UrlManager.clearParams(url, [URL_PARAMS.POS]);
      if (config.updateUrlParams) {
        config.updateUrlParams(url, dataObj);
      }
    }
    UrlManager.replaceState(url);
  }

  if (store) {
    // 1. Prepare and store unrealized data
    if (config.prepareUnrealizedData) {
      store.unrealized = config.prepareUnrealizedData(dataObj);
    } else {
      store.unrealized = null;
    }

    // 2. Prepare and store details data
    store.details = config.prepareData(dataObj);
  }
}
