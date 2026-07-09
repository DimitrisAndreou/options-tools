const URL_PARAMS = {
  TICKER: 'ticker',
  STRATEGY: 'strategy',
  SLIPPAGE: 'slippage',
  MIN_DTE: 'minDTE',
  MAX_DTE: 'maxDTE',
  ID: 'id',
  OPEN_DTE: 'openDTE',
  OPEN_MONEY_YIELD: 'openMoneyYield',
  OPEN_UNDERLYING_YIELD: 'openUnderlyingYield',
  OPEN_MONEY: 'openMoney',
  OPEN_UNDERLYING: 'openUnderlying'
};

const UrlManager = {
  get(key, defaultValue = null) {
    const urlParams = new URLSearchParams(window.location.search);
    const val = urlParams.get(key);
    return val !== null ? val : defaultValue;
  },

  createUrl() {
    return new URL(window.location);
  },

  set(url, key, val) {
    if (val === undefined || val === null) {
      url.searchParams.delete(key);
    } else {
      url.searchParams.set(key, val);
    }
  },

  setWithDefault(url, key, val, defaultVal) {
    if (val === defaultVal) {
      this.set(url, key, null);
    } else {
      this.set(url, key, val);
    }
  },

  setIfMissing(url, key, val) {
    if (!url.searchParams.has(key)) {
      url.searchParams.set(key, val);
    }
  },

  clearParams(url, paramsList) {
    if (paramsList) {
      for (const param of paramsList) {
        url.searchParams.delete(param);
      }
    }
  },

  replaceState(url) {
    window.history.replaceState({}, '', url);
  }
};
