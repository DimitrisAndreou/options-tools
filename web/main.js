document.addEventListener('alpine:init', () => {
  Alpine.store('app', {
    ticker: '',
    strategy: 'coveredCall',
    slippage: 0.5,
    minDte: 7,
    maxDte: 1092,
    selectedId: null,
    details: null,
    unrealized: null,
    spotPrice: null,
    chartData: null,

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

    init() {
      // 1. Load initial params from URL
      let urlTicker = UrlManager.get(URL_PARAMS.TICKER);
      if (urlTicker) {
        this.ticker = urlTicker.toUpperCase();
      }
      this.strategy = UrlManager.get(URL_PARAMS.STRATEGY, 'coveredCall');
      this.slippage = parseFloat(UrlManager.get(URL_PARAMS.SLIPPAGE, '0.5'));
      this.minDte = parseInt(UrlManager.get(URL_PARAMS.MIN_DTE, '7'), 10);
      this.maxDte = parseInt(UrlManager.get(URL_PARAMS.MAX_DTE, '1092'), 10);
      this.selectedId = UrlManager.get(URL_PARAMS.ID);

      // Listen to popstate for back/forward browser navigation
      window.addEventListener('popstate', () => {
        this.syncFromUrl();
      });
    },

    syncFromUrl() {
      let urlTicker = UrlManager.get(URL_PARAMS.TICKER);
      if (urlTicker) {
        this.ticker = urlTicker.toUpperCase();
      } else {
        this.ticker = '';
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

      if (this.ticker) {
        this.loadData(true); // pass skipUrlUpdate = true
      }
    },

    clearAllStrategyParams(url) {
      UrlManager.set(url, URL_PARAMS.ID, null);
      for (const key in StrategyRegistry) {
        const config = StrategyRegistry[key];
        if (config && config.urlParams) {
          UrlManager.clearParams(url, config.urlParams);
        }
      }
    },

    submitTicker() {
      const userInput = this.ticker.trim().toUpperCase();
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
          if (error.error) {
            errorMsg = String(error.error);
          } else {
            errorMsg = String(error);
          }
        }
        errorMsg = errorMsg.replace(/^(Exception|StateError|Error):\s*/i, "");

        document.getElementById('error-message').textContent = errorMsg;
        const myModal = new bootstrap.Modal(document.getElementById('errorModal'));
        myModal.show();
      }
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

