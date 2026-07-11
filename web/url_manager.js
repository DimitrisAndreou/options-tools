const URL_PARAMS = {
  TICKER: 'ticker',
  STRATEGY: 'strategy',
  SLIPPAGE: 'slippage',
  MIN_DTE: 'minDTE',
  MAX_DTE: 'maxDTE',
  ID: 'id',
  POS: 'pos'
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
  },

  encodeState(obj) {
    try {
      const str = JSON.stringify(obj);
      const base64 = btoa(unescape(encodeURIComponent(str)));
      return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    } catch (e) {
      console.error("Failed to encode state:", e);
      return null;
    }
  },

  decodeState(str) {
    if (!str) return null;
    try {
      let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
      while (base64.length % 4) {
        base64 += '=';
      }
      const decoded = decodeURIComponent(escape(atob(base64)));
      return JSON.parse(decoded);
    } catch (e) {
      console.error("Failed to decode state:", e);
      return null;
    }
  }
};
