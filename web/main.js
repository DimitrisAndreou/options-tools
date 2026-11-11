document.addEventListener('alpine:init', () => {
  Alpine.store('app', {
    source: 'yfinance',
    ticker: '',
    tickerInput: '',
    strategy: 'coveredCall',
    slippage: 0.5,
    minDte: 7,
    maxDte: 1092,
    avgPrice: '',
    size: 1,
    underlyingTax: 0,
    derivativeTax: 0,
    selectedId: null,
    details: null,
    unrealized: null,
    spotPrice: null,
    chartData: null,
    entryPosition: null,
    loadedParams: null,

    normalizeAvgPrice(val) {
      if (val === '' || val === null || val === undefined) return null;
      const n = parseFloat(val);
      return (!isNaN(n) && n >= 0) ? n : null;
    },

    normalizeSize(val) {
      const n = parseInt(val, 10);
      return (!isNaN(n) && n >= 1) ? n : 1;
    },

    getCurrentParamsSnapshot() {
      return {
        source: this.source,
        ticker: (this.tickerInput || '').trim().toUpperCase(),
        minDte: Number(this.minDte),
        maxDte: Number(this.maxDte),
        slippage: Number(this.slippage),
        avgPrice: this.normalizeAvgPrice(this.avgPrice),
        size: this.normalizeSize(this.size),
        underlyingTax: Number(this.underlyingTax) || 0,
        derivativeTax: Number(this.derivativeTax) || 0,
      };
    },

    get hasPendingChanges() {
      const current = this.getCurrentParamsSnapshot();
      if (!current.ticker) return false;
      if (!this.loadedParams) return true;
      if (
        current.source !== this.loadedParams.source ||
        current.ticker !== this.loadedParams.ticker ||
        current.minDte !== this.loadedParams.minDte ||
        current.maxDte !== this.loadedParams.maxDte ||
        current.slippage !== this.loadedParams.slippage
      ) {
        return true;
      }
      if (this.strategy === 'coveredCall') {
        if (
          current.avgPrice !== this.loadedParams.avgPrice ||
          current.size !== this.loadedParams.size ||
          current.underlyingTax !== this.loadedParams.underlyingTax ||
          current.derivativeTax !== this.loadedParams.derivativeTax
        ) {
          return true;
        }
      }
      return false;
    },

    // DTE Formatting helper
    formatDteDate(days) {
      const date = new Date();
      date.setDate(date.getDate() + days);
      return new Intl.DateTimeFormat('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
      }).format(date);
    },

    formatDte(days) {
      return `${this.formatDteDate(days)} (${days}d)`;
    },

    get dteValueDisplay() {
      return `${this.formatDte(this.minDte)} – ${this.formatDte(this.maxDte)}`;
    },

    get dteDateRangeDisplay() {
      return `${this.formatDteDate(this.minDte)} – ${this.formatDteDate(this.maxDte)}`;
    },

    get dteDaysRangeDisplay() {
      return `${this.minDte}d – ${this.maxDte}d`;
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

    get existingHolding() {
      if (this.strategy !== 'coveredCall') return null;
      if (!this.chartData || this.chartData.length === 0) return null;
      const sample = this.chartData[0];
      const avgPrice = sample.avgPrice != null ? Number(sample.avgPrice) : null;
      if (avgPrice === null || !(avgPrice > 0)) return null;

      const existing = sample.existingPosition;
      if (!existing || !existing.preTax) return null;

      const underlying = sample.underlying || this.ticker || 'Underlying';
      const unitsHeld = Number(existing.unitsHeld);
      const costBasis = Number(existing.costBasis);
      const currentValue = Number(existing.currentValue);
      if (
        !Number.isFinite(unitsHeld) || unitsHeld <= 0 ||
        !Number.isFinite(costBasis) || !Number.isFinite(currentValue)
      ) {
        return null;
      }

      const unitsFmt = new Intl.NumberFormat('en-US', { maximumFractionDigits: 3 });

      return {
        underlying,
        unitsHeld: unitsFmt.format(unitsHeld),
        costBasisHtml: formatExistingDollarHtml(costBasis),
        currentValueHtml: formatExistingDollarHtml(currentValue),
        unrealizedPnlHtml: formatExistingUnrealizedPnlHtml(existing.preTax.pnl, existing.preTax.yield),
        postTaxPnlHtml: existing.postTax
          ? formatExistingUnrealizedPnlHtml(existing.postTax.pnl, existing.postTax.yield)
          : null,
        taxImpactHtml: existing.postTax
          ? formatExistingTaxImpactHtml(existing.preTax, existing.postTax)
          : null,
      };
    },

    get selectedItem() {
      if (!this.selectedId || !this.chartData) return null;
      return this.chartData.find(item => item.id === this.selectedId);
    },

    get entryDetails() {
      if (!this.entryPosition) return null;
      const strategyType = this.entryPosition.strategyType || this.strategy;
      const config = StrategyRegistry[strategyType];
      if (config && config.prepareData) {
        return config.prepareData(this.entryPosition);
      }
      return null;
    },

    updateEntryPosition() {
      const item = this.selectedItem;
      const strategyType = item?.strategyType || this.entryPosition?.strategyType || this.strategy;
      const config = StrategyRegistry[strategyType];
      if (!item && !this.entryPosition) {
        this.details = null;
      } else if (!item && this.entryPosition && config?.prepareData) {
        this.details = config.prepareData(this.entryPosition);
      }
      this.updateUnrealized();

      if (config && config.updateSelection) {
        config.updateSelection(this.selectedId);
      }
    },

    updateUnrealized() {
      const item = this.selectedItem;
      if (!item && !this.entryPosition) {
        this.unrealized = null;
        return;
      }
      const strategyType = item?.strategyType || this.entryPosition?.strategyType || this.strategy;
      const config = StrategyRegistry[strategyType];
      if (config && config.prepareUnrealizedOrRollData) {
        this.unrealized = config.prepareUnrealizedOrRollData(item);
      } else {
        this.unrealized = null;
      }
    },

    clearEntryPosition() {
      this.entryPosition = null;
      this.updateEntryPosition();
    },

    pinSelected() {
      const item = this.selectedItem;
      if (!item) return;
      const config = StrategyRegistry[item.strategyType];
      if (config) {
        const entryPos = config.createEntryPosition(item);
        if (entryPos) {
          this.entryPosition = entryPos;
          this.updateEntryPosition();
        }
      }
    },

    selectEntryPosition() {
      if (this.entryPosition && this.entryPosition.id) {
        selectStrategyById(this.entryPosition.id);
      }
    },

    init() {
      // 1. Load initial params from URL
      let urlTicker = UrlManager.get(URL_PARAMS.TICKER);
      if (urlTicker) {
        this.ticker = urlTicker.toUpperCase();
        this.tickerInput = this.ticker;
      }
      const defaultSource = (urlTicker && ['BTC', 'ETH', 'SOL'].includes(urlTicker.toUpperCase())) ? 'deribit' : 'yfinance';
      this.source = UrlManager.get(URL_PARAMS.SOURCE, defaultSource);
      this.strategy = UrlManager.get(URL_PARAMS.STRATEGY, 'coveredCall');
      this.slippage = parseFloat(UrlManager.get(URL_PARAMS.SLIPPAGE, '0.5'));
      this.minDte = parseInt(UrlManager.get(URL_PARAMS.MIN_DTE, '7'), 10);
      this.maxDte = parseInt(UrlManager.get(URL_PARAMS.MAX_DTE, '1092'), 10);
      this.avgPrice = UrlManager.get(URL_PARAMS.AVG_PRICE, '') ?? '';
      this.size = this.normalizeSize(UrlManager.get(URL_PARAMS.SIZE, '1'));
      this.underlyingTax = parseFloat(UrlManager.get(URL_PARAMS.UND_TAX, '0')) || 0;
      this.derivativeTax = parseFloat(UrlManager.get(URL_PARAMS.DERIV_TAX, '0')) || 0;
      this.selectedId = UrlManager.get(URL_PARAMS.ID);

      const encodedPos = UrlManager.get(URL_PARAMS.POS);
      if (this.strategy === 'coveredCall' && encodedPos) {
        this.entryPosition = UrlManager.decodeState(encodedPos);
        if (!this.selectedId && this.entryPosition?.id) {
          this.selectedId = this.entryPosition.id;
        }
      } else {
        this.entryPosition = null;
      }

      if (this.ticker) {
        this.loadedParams = this.getCurrentParamsSnapshot();
      }

      // Listen to popstate for back/forward browser navigation
      window.addEventListener('popstate', () => {
        this.syncFromUrl();
      });

      // 2. Start reactive synchronization from Store to URL
      Alpine.effect(() => {
        const source = this.source;
        const ticker = this.ticker;
        const strategy = this.strategy;
        const slippage = this.slippage;
        const minDte = this.minDte;
        const maxDte = this.maxDte;
        const avgPrice = this.avgPrice;
        const size = this.size;
        const underlyingTax = this.underlyingTax;
        const derivativeTax = this.derivativeTax;
        const selectedId = this.selectedId;
        const entryPosition = this.entryPosition;

        const url = UrlManager.createUrl();
        UrlManager.setWithDefault(url, URL_PARAMS.SOURCE, source, 'yfinance');
        UrlManager.set(url, URL_PARAMS.TICKER, ticker || null);
        UrlManager.set(url, URL_PARAMS.STRATEGY, strategy || null);
        UrlManager.setWithDefault(url, URL_PARAMS.SLIPPAGE, slippage, 0.5);
        UrlManager.setWithDefault(url, URL_PARAMS.MIN_DTE, minDte, 7);
        UrlManager.setWithDefault(url, URL_PARAMS.MAX_DTE, maxDte, 1092);
        UrlManager.set(url, URL_PARAMS.AVG_PRICE, (avgPrice !== '' && avgPrice !== null) ? String(avgPrice) : null);
        UrlManager.setWithDefault(url, URL_PARAMS.SIZE, this.normalizeSize(size), 1);
        UrlManager.setWithDefault(url, URL_PARAMS.UND_TAX, Number(underlyingTax) || 0, 0);
        UrlManager.setWithDefault(url, URL_PARAMS.DERIV_TAX, Number(derivativeTax) || 0, 0);
        UrlManager.set(url, URL_PARAMS.ID, selectedId || null);

        if (entryPosition) {
          const strategyType = entryPosition.strategyType || strategy;
          const config = StrategyRegistry[strategyType];
          if (config) {
            const encoded = config.encodeEntryPosition(entryPosition);
            UrlManager.set(url, URL_PARAMS.POS, encoded);
          } else {
            const encoded = UrlManager.encodeState(entryPosition);
            UrlManager.set(url, URL_PARAMS.POS, encoded);
          }
        } else {
          UrlManager.set(url, URL_PARAMS.POS, null);
        }

        UrlManager.replaceState(url);
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
      const defaultSource = (urlTicker && ['BTC', 'ETH', 'SOL'].includes(urlTicker.toUpperCase())) ? 'deribit' : 'yfinance';
      this.source = UrlManager.get(URL_PARAMS.SOURCE, defaultSource);
      this.strategy = UrlManager.get(URL_PARAMS.STRATEGY, 'coveredCall');
      this.slippage = parseFloat(UrlManager.get(URL_PARAMS.SLIPPAGE, '0.5'));
      this.minDte = parseInt(UrlManager.get(URL_PARAMS.MIN_DTE, '7'), 10);
      this.maxDte = parseInt(UrlManager.get(URL_PARAMS.MAX_DTE, '1092'), 10);
      this.avgPrice = UrlManager.get(URL_PARAMS.AVG_PRICE, '') ?? '';
      this.size = this.normalizeSize(UrlManager.get(URL_PARAMS.SIZE, '1'));
      this.underlyingTax = parseFloat(UrlManager.get(URL_PARAMS.UND_TAX, '0')) || 0;
      this.derivativeTax = parseFloat(UrlManager.get(URL_PARAMS.DERIV_TAX, '0')) || 0;
      
      const encodedPos = UrlManager.get(URL_PARAMS.POS);
      if (this.strategy === 'coveredCall' && encodedPos) {
        this.entryPosition = UrlManager.decodeState(encodedPos);
      } else {
        this.entryPosition = null;
      }

      const newSelectedId = UrlManager.get(URL_PARAMS.ID) || (this.entryPosition?.id ?? null);
      if (this.selectedId !== newSelectedId) {
        this.selectedId = newSelectedId;
        selectStrategyById(this.selectedId);
      } else {
        this.updateUnrealized();
      }

      if (this.ticker) {
        this.loadData();
      }
    },

    clearAllStrategyParams(url) {
      UrlManager.set(url, URL_PARAMS.ID, null);
      UrlManager.clearParams(url, [URL_PARAMS.POS, URL_PARAMS.AVG_PRICE, URL_PARAMS.SIZE]);
    },

    submitTicker() {
      const userInput = this.tickerInput.trim().toUpperCase();
      if (!userInput) return;

      if (userInput !== this.ticker) {
        const avgPriceWasModified = this.loadedParams
          ? this.normalizeAvgPrice(this.avgPrice) !== this.loadedParams.avgPrice
          : this.normalizeAvgPrice(this.avgPrice) !== null;
        this.ticker = userInput;
        this.tickerInput = userInput;
        this.selectedId = null;
        this.entryPosition = null;
        this.details = null;
        this.unrealized = null;
        if (!avgPriceWasModified) {
          this.avgPrice = '';
        }
      }
      this.reloadData();
    },

    changeSource() {
      // Clear selection & details when switching data source, but do not
      // automatically trigger computation because the ticker is likely for the old source.
      this.selectedId = null;
      this.details = null;
      this.unrealized = null;
      this.entryPosition = null;
    },

    changeStrategy() {
      // Clear selection & details when switching strategy types
      this.selectedId = null;
      this.details = null;
      this.unrealized = null;
      this.entryPosition = null;

      this.loadData();
    },

    reloadData() {
      if (!this.ticker) return;
      this.loadData();
    },

    async loadData() {
      if (!this.ticker) return;

      this.tickerInput = this.ticker;
      this.loadedParams = this.getCurrentParamsSnapshot();

      try {

        const chartDom = document.getElementById("strategyChartContainer");
        let existingChart = echarts.getInstanceByDom(chartDom);
        if (existingChart) existingChart.dispose();

        const config = STRATEGY_CONFIGS[this.strategy];
        if (!config) {
          console.warn(`Strategy ${this.strategy} is not implemented yet.`);
          return;
        }

        const fetcherName = this.source === 'deribit' ? config.deribitFetcherName : config.yfinanceFetcherName;
        const fetcher = window[fetcherName];
        if (!fetcher) {
          throw new Error(`Fetcher ${fetcherName} is not registered on window by Dart.`);
        }

        const parsedAvg = (this.avgPrice !== '' && this.avgPrice !== null)
          ? parseFloat(this.avgPrice)
          : NaN;
        const avgPriceArg = (!isNaN(parsedAvg) && parsedAvg >= 0) ? parsedAvg : null;
        const sizeArg = this.normalizeSize(this.size);
        const undTaxRate = (parseFloat(this.underlyingTax) || 0) / 100.0;
        const derivTaxRate = (parseFloat(this.derivativeTax) || 0) / 100.0;

        const rawData = this.strategy === 'coveredCall'
          ? await fetcher(this.ticker, this.slippage, this.minDte, this.maxDte, avgPriceArg, undTaxRate, derivTaxRate, sizeArg)
          : await fetcher(this.ticker, this.slippage, this.minDte, this.maxDte);
        const dataJson = JSON.parse(rawData);
        console.log({ strategy: this.strategy, dataJson });

        this.chartData = dataJson;
        this.spotPrice = extractSpotPrice(dataJson);

        config.renderer(dataJson, chartDom, this.selectedId);

      } catch (error) {
        console.error("JavaScript caught Dart error:", error.error || error, error.stack || "");
        
        let errorMsg = "An unexpected error occurred.";
        if (error) {
          const getMsg = (val) => {
            if (!val) return '';
            if (typeof val === 'string') return val;
            if (typeof val === 'object') {
              if (val.message) return String(val.message);
              if (typeof val.toString === 'function') {
                const s = val.toString();
                if (s && s !== '[object Object]') return s;
              }
              try {
                const json = JSON.stringify(val);
                if (json && json !== '{}' && json !== '[]' && json !== 'null') {
                  return json;
                }
                return '';
              } catch (e) {
                return '';
              }
            }
            return String(val);
          };

          const rawMessage = (typeof error.message === 'string' &&
            !error.message.includes('Dart exception thrown from converted Future'))
            ? error.message
            : '';

          errorMsg =
            rawMessage ||
            getMsg(error.error) ||
            getMsg(error) ||
            "An unexpected error occurred.";
        }
        errorMsg = errorMsg.replace(/^(Exception|StateError|Error|Invalid argument\(s\)):\s*/i, "");

        document.getElementById('error-message').textContent = errorMsg;

        const hasPosParam = new URLSearchParams(window.location.search).has('pos');
        const migrateTip = document.getElementById('error-migrate-tip');
        const migrateLink = document.getElementById('error-migrate-link');
        if (migrateTip) {
          if (hasPosParam || errorMsg.includes('moneyYield') || errorMsg.includes('preTax')) {
            migrateTip.style.display = 'block';
            if (migrateLink) {
              migrateLink.href = `migrate.html?url=${encodeURIComponent(window.location.href)}`;
            }
          } else {
            migrateTip.style.display = 'none';
          }
        }

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
  }
};

window.jsMain = function() {
  const store = getAppStore();
  if (store && store.ticker) {
    store.loadData();
  }
};

