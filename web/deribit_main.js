
async function jsDeribitMain() {
  const slippage = 0.5;
  try {
    // const stockCoveredCallsJson = await parseAndLog("yfinanceCoveredCalls", () => yfinanceCoveredCallsDart("GOOG", slippage));
    // console.log({stockCoveredCallsJson});

    const btcCoveredCallsJson = await parseAndLog("btcCoveredCallsJson", () => deribitCoveredCallsDart("BTC", slippage));
    document.getElementById('btc-price').textContent = dollarFmt.format(extractSpotPrice(btcCoveredCallsJson));
    coveredCallToBreakEvenLockup(btcCoveredCallsJson, "btcCoveredCallsChart", "btcCoveredCallsTable");

    const btcVerticalSpreadsJson = await parseAndLog("btcVerticalSpreadsJson", () => deribitVerticalSpreadsDart("BTC", slippage));
    // verticalSpreadsChart(btcVerticalSpreadsJson, "btcVerticalSpreadsChart");

    const ethCoveredCallsJson = await parseAndLog("ethCoveredCallsJson", () => deribitCoveredCallsDart("ETH", slippage));
    document.getElementById('eth-price').textContent = dollarFmt.format(extractSpotPrice(ethCoveredCallsJson));
    coveredCallToBreakEvenLockup(ethCoveredCallsJson, "ethCoveredCallsChart", "ethCoveredCallsTable");
    const ethVerticalSpreadsJson = await parseAndLog("ethVerticalSpreadsJson", () => deribitVerticalSpreadsDart("ETH", slippage));
    // verticalSpreadsChart(ethVerticalSpreadsJson, "btcVerticalSpreadsChart");

    const btcBondsJson = await parseAndLog("btcBondsJson", () => deribitSyntheticBondsDart("BTC", slippage));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}

