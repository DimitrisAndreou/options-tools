// Clone covered call details template into placeholders before Alpine compiles them
document.addEventListener('DOMContentLoaded', () => {
  const tpl = document.getElementById('cc-details-tpl');
  if (tpl) {
    document.querySelectorAll('.cc-details-placeholder').forEach(el => {
      el.appendChild(tpl.content.cloneNode(true));
    });
  }
});

document.addEventListener('alpine:init', () => {
  Alpine.store('app', {
    ticker: '',
    tickerInput: '',
    strategy: 'coveredCall',
    slippage: 0.5,
    minDte: 7,
    maxDte: 1092,
    selectedId: null,
    details: null,
    unrealized: null,
    spotPrice: null,
    chartData: null,
    openPosition: null,

    // DTE Formatting helper
    formatDte(days) {
      const date = new Date();
      date.setDate(date.getDate() + days);
      const dateString = new Intl.DateTimeFormat('en-GB', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
      }).format(date);
      return `${dateString} (${days}d)`;
    },

    get dteValueDisplay() {
      return `${this.formatDte(this.minDte)} - ${this.formatDte(this.maxDte)}`;
    },

    get dteRangeStyle() {
      const min = 0;
      const max = 1095;
      const percent1 = ((this.minDte - min) / (max - min)) * 100;
      const percent2 = ((this.maxDte - min) / (max - min)) * 100;
      return {
        left: percent1 + '%',
        width: (percent2 - percent1) + '%'
      };
    },

    get spotPriceDisplay() {
      if (this.spotPrice === null) return '';
      return dollarFmt.format(this.spotPrice);
    },

    get selectedItem() {
      if (!this.selectedId || !this.chartData) return null;
      return this.chartData.find(item => item.id === this.selectedId);
    },

    get entryDetails() {
      if (!this.openPosition) return null;
      const strategyType = this.openPosition.strategyType || this.strategy;
      const config = StrategyRegistry[strategyType];
      if (config && config.prepareData) {
        return config.prepareData(this.openPosition);
      }
      return null;
    },

    updateOpenPosition() {
      const url = UrlManager.createUrl();
      if (this.openPosition) {
        const item = this.selectedItem;
        const strategyType = item ? item.strategyType : this.strategy;
        const config = StrategyRegistry[strategyType];
        if (config) {
          const encoded = config.encodeOpenPosition(this.openPosition);
          UrlManager.set(url, URL_PARAMS.POS, encoded);
        } else {
          const encoded = UrlManager.encodeState(this.openPosition);
          UrlManager.set(url, URL_PARAMS.POS, encoded);
        }
      } else {
        UrlManager.set(url, URL_PARAMS.POS, null);
      }
      UrlManager.replaceState(url);
      
      this.updateUnrealized();

      const item = this.selectedItem;
      if (item) {
        const config = StrategyRegistry[item.strategyType];
        if (config && config.updateSelection) {
          config.updateSelection(this.selectedId);
        }
      }
    },

    updateUnrealized() {
      const item = this.selectedItem;
      if (!item) {
        this.unrealized = null;
        return;
      }
      const config = StrategyRegistry[item.strategyType];
      if (config && config.prepareUnrealizedData) {
        this.unrealized = config.prepareUnrealizedData(item);
      } else {
        this.unrealized = null;
      }
    },

    clearOpenPosition() {
      this.openPosition = null;
      this.updateOpenPosition();
    },


    init() {
      // 1. Load initial params from URL
      let urlTicker = UrlManager.get(URL_PARAMS.TICKER);
      if (urlTicker) {
        this.ticker = urlTicker.toUpperCase();
        this.tickerInput = this.ticker;
      }
      this.strategy = UrlManager.get(URL_PARAMS.STRATEGY, 'coveredCall');
      this.slippage = parseFloat(UrlManager.get(URL_PARAMS.SLIPPAGE, '0.5'));
      this.minDte = parseInt(UrlManager.get(URL_PARAMS.MIN_DTE, '7'), 10);
      this.maxDte = parseInt(UrlManager.get(URL_PARAMS.MAX_DTE, '1092'), 10);
      this.selectedId = UrlManager.get(URL_PARAMS.ID);

      const encodedPos = UrlManager.get(URL_PARAMS.POS);
      if (this.strategy === 'coveredCall' && encodedPos) {
        this.openPosition = UrlManager.decodeState(encodedPos);
      } else {
        this.openPosition = null;
      }

      // Listen to popstate for back/forward browser navigation
      window.addEventListener('popstate', () => {
        this.syncFromUrl();
      });
    },

    syncFromUrl() {
      let urlTicker = UrlManager.get(URL_PARAMS.TICKER);
      if (urlTicker) {
        this.ticker = urlTicker.toUpperCase();
        this.tickerInput = this.ticker;
      } else {
        this.ticker = '';
        this.tickerInput = '';
      }
      this.strategy = UrlManager.get(URL_PARAMS.STRATEGY, 'coveredCall');
      this.slippage = parseFloat(UrlManager.get(URL_PARAMS.SLIPPAGE, '0.5'));
      this.minDte = parseInt(UrlManager.get(URL_PARAMS.MIN_DTE, '7'), 10);
      this.maxDte = parseInt(UrlManager.get(URL_PARAMS.MAX_DTE, '1092'), 10);
      
      const newSelectedId = UrlManager.get(URL_PARAMS.ID);
      if (this.selectedId !== newSelectedId) {
        this.selectedId = newSelectedId;
        selectStrategyById(this.selectedId);
      }

      const encodedPos = UrlManager.get(URL_PARAMS.POS);
      if (this.strategy === 'coveredCall' && encodedPos) {
        this.openPosition = UrlManager.decodeState(encodedPos);
      } else {
        this.openPosition = null;
      }
      this.updateUnrealized();

      if (this.ticker) {
        this.loadData(true); // pass skipUrlUpdate = true
      }
    },

    clearAllStrategyParams(url) {
      UrlManager.set(url, URL_PARAMS.ID, null);
      UrlManager.clearParams(url, [URL_PARAMS.POS]);
    },

    submitTicker() {
      const userInput = this.tickerInput.trim().toUpperCase();
      if (userInput) {
        const url = UrlManager.createUrl();
        UrlManager.set(url, URL_PARAMS.TICKER, userInput);
        this.clearAllStrategyParams(url);
        window.location.href = url.toString();
      }
    },

    changeStrategy() {
      const url = UrlManager.createUrl();
      this.clearAllStrategyParams(url);
      UrlManager.set(url, URL_PARAMS.STRATEGY, this.strategy);
      UrlManager.replaceState(url);
      
      // Clear selection & details when switching strategy types
      this.selectedId = null;
      this.details = null;
      this.unrealized = null;
      this.openPosition = null;

      this.loadData();
    },

    reloadData() {
      if (!this.ticker) return;
      this.loadData();
    },

    async loadData(skipUrlUpdate = false) {
      if (!this.ticker) return;
      try {
        if (!skipUrlUpdate) {
          const url = UrlManager.createUrl();
          UrlManager.setWithDefault(url, URL_PARAMS.SLIPPAGE, this.slippage, 0.5);
          UrlManager.setWithDefault(url, URL_PARAMS.MIN_DTE, this.minDte, 7);
          UrlManager.setWithDefault(url, URL_PARAMS.MAX_DTE, this.maxDte, 1092);
          UrlManager.setWithDefault(url, URL_PARAMS.STRATEGY, this.strategy, 'coveredCall');
          UrlManager.replaceState(url);
        }

        const chartDom = document.getElementById("strategyChartContainer");
        let existingChart = echarts.getInstanceByDom(chartDom);
        if (existingChart) existingChart.dispose();

        const config = STRATEGY_CONFIGS[this.strategy];
        if (!config) {
          console.warn(`Strategy ${this.strategy} is not implemented yet.`);
          return;
        }

        const isCrypto = ["BTC", "ETH", "SOL"].includes(this.ticker);
        const fetcherName = isCrypto ? config.deribitFetcherName : config.yfinanceFetcherName;
        const fetcher = window[fetcherName];
        if (!fetcher) {
          throw new Error(`Fetcher ${fetcherName} is not registered on window by Dart.`);
        }

        const rawData = await fetcher(this.ticker, this.slippage, this.minDte, this.maxDte);
        const dataJson = JSON.parse(rawData);
        console.log({ strategy: this.strategy, dataJson });

        this.chartData = dataJson;
        this.spotPrice = extractSpotPrice(dataJson);

        config.renderer(dataJson, chartDom, this.selectedId);

      } catch (error) {
        console.error("JavaScript caught Dart error:", error.error || error);
        
        let errorMsg = "An unexpected error occurred.";
        if (error) {
          const getMsg = (val) => {
            if (!val) return '';
            if (typeof val === 'string') return val;
            if (typeof val === 'object') {
              if (val.message) return String(val.message);
              if (typeof val.toString === 'function') {
                const s = val.toString();
                if (s !== '[object Object]') return s;
              }
              try {
                return JSON.stringify(val);
              } catch (e) {
                return '[Complex Object]';
              }
            }
            return String(val);
          };

          if (error.error) {
            errorMsg = getMsg(error.error);
          } else if (error.message) {
            errorMsg = getMsg(error.message);
          } else {
            errorMsg = getMsg(error);
          }
        }
        errorMsg = errorMsg.replace(/^(Exception|StateError|Error):\s*/i, "");

        document.getElementById('error-message').textContent = errorMsg;
        const myModal = new bootstrap.Modal(document.getElementById('errorModal'));
        myModal.show();
      }
    },

    async shareUrl() {
      const modalEl = document.getElementById('shareModal');
      const modalInput = document.getElementById('share-url-input');
      const copyBtnText = document.getElementById('copy-btn-text');
      const copyIcon = document.getElementById('copy-icon');
      const loadingEl = document.getElementById('share-loading');
      const errorEl = document.getElementById('share-error');

      // Show modal
      const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
      modal.show();

      // Reset UI state
      modalInput.value = '';
      copyBtnText.textContent = 'Copy';
      copyIcon.className = 'fas fa-copy me-1';
      loadingEl.style.display = 'block';
      errorEl.style.display = 'none';

      const longUrl = window.location.href;

      try {
        const target = `https://tinyurl.com/api-create.php?url=${encodeURIComponent(longUrl)}`;
        const proxyUrl = `https://yahoo-proxy-v2.jim-andreou.workers.dev/?target=${encodeURIComponent(target)}`;
        
        const res = await fetch(proxyUrl);
        if (!res.ok) {
          throw new Error(`Proxy returned status ${res.status}`);
        }
        const shortUrl = (await res.text()).trim();
        if (!shortUrl.startsWith('http')) {
          throw new Error(`Invalid short URL received: ${shortUrl}`);
        }
        modalInput.value = shortUrl;
      } catch (err) {
        console.error("URL shortening failed:", err);
        modalInput.value = longUrl;
        errorEl.style.display = 'block';
      } finally {
        loadingEl.style.display = 'none';
      }
    },

    copyShareUrl() {
      const modalInput = document.getElementById('share-url-input');
      if (!modalInput || !modalInput.value) return;

      modalInput.select();
      modalInput.setSelectionRange(0, 99999); // For mobile devices

      navigator.clipboard.writeText(modalInput.value)
        .then(() => {
          const copyBtnText = document.getElementById('copy-btn-text');
          const copyIcon = document.getElementById('copy-icon');
          
          copyBtnText.textContent = 'Copied!';
          copyIcon.className = 'fas fa-check me-1';
          
          setTimeout(() => {
            copyBtnText.textContent = 'Copy';
            copyIcon.className = 'fas fa-copy me-1';
          }, 2000);
        })
        .catch(err => {
          console.error('Failed to copy text: ', err);
        });
    }
  });
});

const STRATEGY_CONFIGS = {
  coveredCall: {
    deribitFetcherName: 'deribitCoveredCallsDart',
    yfinanceFetcherName: 'yfinanceCoveredCallsDart',
    renderer: renderCoveredCallsChart
  },
  longOption: {
    deribitFetcherName: 'deribitLongOptionsDart',
    yfinanceFetcherName: 'yfinanceLongOptionsDart',
    renderer: renderLongOptionsChart
  },
  straddle: {
    deribitFetcherName: 'deribitStraddlesDart',
    yfinanceFetcherName: 'yfinanceStraddlesDart',
    renderer: renderStraddlesChart
  }
};

window.jsMain = function() {
  const store = getAppStore();
  if (store && store.ticker) {
    store.loadData();
  }
};

