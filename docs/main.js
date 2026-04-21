async function loadData(ticker, slippage, minDte, maxDte) {
  if (!ticker) return;
  try {
    const coveredCallsJson = JSON.parse(await (
      ticker === "BTC" || ticker === "ETH" || ticker === "SOL" ||
        ticker === "AVAX" || ticker === "TRX" || ticker === "XRP"
        ? deribitCoveredCallsDart(ticker, slippage, minDte, maxDte)
        : yfinanceCoveredCallsDart(ticker, slippage, minDte, maxDte)
    ));
    console.log({ coveredCallsJson });
    coveredCallToBreakEvenLockup(coveredCallsJson, "coveredCallsChart", "coveredCallsTable");

    document.getElementById('spot-price').textContent = dollarFmt.format(extractSpotPrice(coveredCallsJson));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error.error);
    console.error("Dart stack trace:", error.stack);

    document.getElementById('error-message').textContent =
      `Error! This tool only works in Chrome (sorry!). ` +
      `If you are using Chrome, check the ticker.`;
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

  function reloadData() {
    if (!ticker) return;
    const slippage = slippageInput ? parseFloat(slippageInput.value) : 0.0;
    const minDte = minDteInput ? parseInt(minDteInput.value, 10) : 7;
    const maxDte = maxDteInput ? parseInt(maxDteInput.value, 10) : 1095;

    const url = new URL(window.location);
    url.searchParams.set('slippage', slippage);
    url.searchParams.set('minDTE', minDte);
    url.searchParams.set('maxDTE', maxDte);
    window.history.replaceState({}, '', url);

    loadData(ticker, slippage, minDte, maxDte);
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
