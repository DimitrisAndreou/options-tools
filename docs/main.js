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

    const urlParams = new URLSearchParams(window.location.search);
    const targetId = urlParams.get('id');
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
  const urlParams = new URLSearchParams(window.location.search);
  let ticker = urlParams.get('ticker');
  if (ticker) {
    ticker = ticker.toUpperCase();
  }
  let strategy = urlParams.get('strategy') || 'coveredCall';

  const initialSlippage = urlParams.get('slippage');
  const initialMinDTE = urlParams.get('minDTE');
  const initialMaxDTE = urlParams.get('maxDTE');

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
        const url = new URL(window.location);
        url.searchParams.set('ticker', userInput);
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
      reloadData();
    });
  }

  function reloadData() {
    if (!ticker) return;
    const slippage = slippageInput ? parseFloat(slippageInput.value) : 0.5;
    const minDte = minDteInput ? parseInt(minDteInput.value, 10) : 7;
    const maxDte = maxDteInput ? parseInt(maxDteInput.value, 10) : 1092;

    const url = new URL(window.location);
    if (slippage !== 0.5) url.searchParams.set('slippage', slippage);
    else url.searchParams.delete('slippage');

    if (minDte !== 7) url.searchParams.set('minDTE', minDte);
    else url.searchParams.delete('minDTE');

    if (maxDte !== 1092) url.searchParams.set('maxDTE', maxDte);
    else url.searchParams.delete('maxDTE');

    if (strategy !== 'coveredCall') url.searchParams.set('strategy', strategy);
    else url.searchParams.delete('strategy');
    window.history.replaceState({}, '', url);

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
