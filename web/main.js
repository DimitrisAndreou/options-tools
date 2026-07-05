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

function clearAllStrategyParams(url) {
  UrlManager.set(url, URL_PARAMS.ID, null);
  for (const key in StrategyRegistry) {
    const config = StrategyRegistry[key];
    if (config && config.urlParams) {
      UrlManager.clearParams(url, config.urlParams);
    }
  }
}


async function loadStrategyData(ticker, slippage, minDte, maxDte, strategyName) {
  if (!ticker) return;
  try {
    let chartDom = document.getElementById("strategyChartContainer");
    let existingChart = echarts.getInstanceByDom(chartDom);
    if (existingChart) existingChart.dispose();

    const config = STRATEGY_CONFIGS[strategyName];
    if (!config) {
      console.warn(`Strategy ${strategyName} is not implemented yet.`);
      return;
    }

    const isCrypto = ["BTC", "ETH", "SOL"].includes(ticker);
    const fetcherName = isCrypto ? config.deribitFetcherName : config.yfinanceFetcherName;
    const fetcher = window[fetcherName];
    if (!fetcher) {
      throw new Error(`Fetcher ${fetcherName} is not registered on window by Dart.`);
    }

    const rawData = await fetcher(ticker, slippage, minDte, maxDte);
    const dataJson = JSON.parse(rawData);
    console.log({ strategyName, dataJson });

    const targetId = UrlManager.get(URL_PARAMS.ID);
    config.renderer(dataJson, chartDom, targetId);

    document.getElementById('spot-ticker-name').textContent = ticker;
    document.getElementById('spot-price').textContent = dollarFmt.format(extractSpotPrice(dataJson));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error.error);
    console.error("Dart stack trace:", error.stack);

    let errorMsg = "An unexpected error occurred.";
    if (error) {
      if (error.error) {
        errorMsg = String(error.error);
      } else {
        errorMsg = String(error);
      }
    }

    // Clean common prefixes (e.g. "Exception: ", "StateError: ")
    errorMsg = errorMsg.replace(/^(Exception|StateError|Error):\s*/i, "");

    document.getElementById('error-message').textContent = errorMsg;
    const myModal = new bootstrap.Modal(document.getElementById('errorModal'));
    myModal.show();
  }
}

async function jsMain() {
  let ticker = UrlManager.get(URL_PARAMS.TICKER);
  if (ticker) {
    ticker = ticker.toUpperCase();
  }
  let strategy = UrlManager.get(URL_PARAMS.STRATEGY, 'coveredCall');

  const initialSlippage = UrlManager.get(URL_PARAMS.SLIPPAGE);
  const initialMinDTE = UrlManager.get(URL_PARAMS.MIN_DTE);
  const initialMaxDTE = UrlManager.get(URL_PARAMS.MAX_DTE);

  const tickerInput = document.getElementById('ticker-input');
  if (tickerInput && ticker) {
    tickerInput.value = ticker;
  }

  const tickerForm = document.getElementById('ticker-form');
  if (tickerForm) {
    tickerForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const userInput = tickerInput.value.trim().toUpperCase();
      if (userInput) {
        const url = UrlManager.createUrl();
        UrlManager.set(url, URL_PARAMS.TICKER, userInput);
        clearAllStrategyParams(url);
        window.location.href = url.toString();
      }
    });
  }

  const slippageInput = document.getElementById('slippage-input');
  const slippageValueDisplay = document.getElementById('slippage-value');
  const minDteInput = document.getElementById('min-dte-input');
  const maxDteInput = document.getElementById('max-dte-input');
  const dteValueDisplay = document.getElementById('dte-value-display');
  const dteSliderRange = document.getElementById('dte-slider-range');

  if (slippageInput && initialSlippage !== null) {
    slippageInput.value = initialSlippage;
    if (slippageValueDisplay) {
      slippageValueDisplay.textContent = Math.round(parseFloat(initialSlippage) * 100) + '%';
    }
  }

  if (minDteInput && initialMinDTE !== null) {
    minDteInput.value = initialMinDTE;
  }

  if (maxDteInput && initialMaxDTE !== null) {
    maxDteInput.value = initialMaxDTE;
  }

  function updateDteUI() {
    if (!minDteInput || !maxDteInput || !dteValueDisplay) return;
    const minVal = parseInt(minDteInput.value, 10);
    const maxVal = parseInt(maxDteInput.value, 10);

    function formatDte(days) {
      const date = new Date();
      date.setDate(date.getDate() + days);
      const dateString = new Intl.DateTimeFormat('en-GB', {
        day: 'numeric',
        month: 'long',
        year: 'numeric'
      }).format(date);

      return `${dateString} (${days}d)`;
    }

    dteValueDisplay.textContent = `${formatDte(minVal)} - ${formatDte(maxVal)}`;

    if (dteSliderRange) {
      const min = parseInt(minDteInput.min, 10) || 0;
      const max = parseInt(minDteInput.max, 10) || 1095;
      const percent1 = ((minVal - min) / (max - min)) * 100;
      const percent2 = ((maxVal - min) / (max - min)) * 100;
      dteSliderRange.style.left = percent1 + '%';
      dteSliderRange.style.width = (percent2 - percent1) + '%';
    }
  }

  const strategySelect = document.getElementById('strategy-select');
  if (strategySelect) {
    strategySelect.value = strategy;
    strategySelect.addEventListener('change', (e) => {
      strategy = e.target.value;
      const url = UrlManager.createUrl();
      clearAllStrategyParams(url);
      UrlManager.replaceState(url);
      reloadData();
    });
  }

  function reloadData() {
    if (!ticker) return;
    const slippage = slippageInput ? parseFloat(slippageInput.value) : 0.5;
    const minDte = minDteInput ? parseInt(minDteInput.value, 10) : 7;
    const maxDte = maxDteInput ? parseInt(maxDteInput.value, 10) : 1092;

    const url = UrlManager.createUrl();
    UrlManager.setWithDefault(url, URL_PARAMS.SLIPPAGE, slippage, 0.5);
    UrlManager.setWithDefault(url, URL_PARAMS.MIN_DTE, minDte, 7);
    UrlManager.setWithDefault(url, URL_PARAMS.MAX_DTE, maxDte, 1092);
    UrlManager.setWithDefault(url, URL_PARAMS.STRATEGY, strategy, 'coveredCall');
    UrlManager.replaceState(url);

    loadStrategyData(ticker, slippage, minDte, maxDte, strategy);
  }

  if (slippageInput && slippageValueDisplay) {
    slippageInput.addEventListener('input', (e) => {
      const val = parseFloat(e.target.value);
      slippageValueDisplay.textContent = Math.round(val * 100) + '%';
    });
    slippageInput.addEventListener('change', reloadData);
  }

  if (minDteInput && maxDteInput) {
    minDteInput.addEventListener('input', (e) => {
      let minVal = parseInt(e.target.value, 10);
      let maxVal = parseInt(maxDteInput.value, 10);
      if (minVal > maxVal) {
        maxDteInput.value = minVal;
      }
      updateDteUI();
    });
    minDteInput.addEventListener('change', reloadData);

    maxDteInput.addEventListener('input', (e) => {
      let maxVal = parseInt(e.target.value, 10);
      let minVal = parseInt(minDteInput.value, 10);
      if (maxVal < minVal) {
        minDteInput.value = maxVal;
      }
      updateDteUI();
    });
    maxDteInput.addEventListener('change', reloadData);

    updateDteUI();
  }

  if (!ticker) {
    return;
  }

  reloadData();
}
