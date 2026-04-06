
async function jsDeribitMain() {
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

  if (!ticker) {
    return;
  }

  // TODO: also get slippage from textField/cgi
  const slippage = 0.5;
  try {
    const coveredCallsJson = JSON.parse(await (
      ticker === "BTC" || ticker === "ETH"
        ? deribitCoveredCallsDart(ticker, slippage)
        : yfinanceCoveredCallsDart(ticker, slippage)
    ));
    console.log({ coveredCallsJson });
    coveredCallToBreakEvenLockup(coveredCallsJson, "coveredCallsChart", "coveredCallsTable");

    // const btcVerticalSpreadsJson = await parseAndLog("btcVerticalSpreadsJson", () => deribitVerticalSpreadsDart("BTC", slippage));
    // verticalSpreadsChart(btcVerticalSpreadsJson, "btcVerticalSpreadsChart");

    // const ethCoveredCallsJson = await parseAndLog("ethCoveredCallsJson", () => deribitCoveredCallsDart("ETH", slippage));
    // document.getElementById('eth-price').textContent = dollarFmt.format(extractSpotPrice(ethCoveredCallsJson));
    // coveredCallToBreakEvenLockup(ethCoveredCallsJson, "ethCoveredCallsChart", "ethCoveredCallsTable");
    // const ethVerticalSpreadsJson = await parseAndLog("ethVerticalSpreadsJson", () => deribitVerticalSpreadsDart("ETH", slippage));
    // verticalSpreadsChart(ethVerticalSpreadsJson, "btcVerticalSpreadsChart");

    // const btcBondsJson = await parseAndLog("btcBondsJson", () => deribitSyntheticBondsDart("BTC", slippage));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}

