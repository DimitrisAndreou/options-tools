async function loadData(ticker, slippage) {
  if (!ticker) return;
  try {
    const coveredCallsJson = JSON.parse(await (
      ticker === "BTC" || ticker === "ETH"
        ? deribitCoveredCallsDart(ticker, slippage)
        : yfinanceCoveredCallsDart(ticker, slippage)
    ));
    console.log({ coveredCallsJson });
    coveredCallToBreakEvenLockup(coveredCallsJson, "coveredCallsChart", "coveredCallsTable");

    document.getElementById('spot-price').textContent = dollarFmt.format(extractSpotPrice(coveredCallsJson));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error.error);
    console.error("Dart stack trace:", error.stack);
  }
}

async function jsMain() {
  const urlParams = new URLSearchParams(window.location.search);
  let ticker = urlParams.get('ticker');
  if (ticker) {
    ticker = ticker.toUpperCase();
  }

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
        // Redirect so the URL contains this ticker
        window.location.href = `${window.location.pathname}?ticker=${userInput}`;
      }
    });
  }

  const slippageInput = document.getElementById('slippage-input');
  const slippageValueDisplay = document.getElementById('slippage-value');
  
  if (slippageInput && slippageValueDisplay) {
    slippageInput.addEventListener('input', (e) => {
      const val = parseFloat(e.target.value);
      slippageValueDisplay.textContent = Math.round(val * 100) + '%';
    });
    
    slippageInput.addEventListener('change', (e) => {
      const slippage = parseFloat(e.target.value);
      loadData(ticker, slippage);
    });
  }

  if (!ticker) {
    return;
  }

  const initialSlippage = slippageInput ? parseFloat(slippageInput.value) : 0.0;
  await loadData(ticker, initialSlippage);
}
