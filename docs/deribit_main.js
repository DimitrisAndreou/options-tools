
async function jsDeribitMain() {
  const slippage = 0.5;
  try {
    const btcCoveredCallsJson = await parseAndLog("btcCoveredCallsJson", () => coveredCallsDart("BTC", slippage));
    document.getElementById('btc-price').textContent = dollarFmt.format(extractSpotPrice(btcCoveredCallsJson));
    coveredCallToBreakEvenLockup(btcCoveredCallsJson, "btcCoveredCallsChart", "btcCoveredCallsTable");

    const btcVerticalSpreadsJson = await parseAndLog("btcVerticalSpreadsJson", () => verticalSpreadsDart("BTC", slippage));
    // verticalSpreadsChart(btcVerticalSpreadsJson, "btcVerticalSpreadsChart");

    const ethCoveredCallsJson = await parseAndLog("ethCoveredCallsJson", () => coveredCallsDart("ETH", slippage));
    document.getElementById('eth-price').textContent = dollarFmt.format(extractSpotPrice(ethCoveredCallsJson));
    coveredCallToBreakEvenLockup(ethCoveredCallsJson, "ethCoveredCallsChart", "ethCoveredCallsTable");
    const ethVerticalSpreadsJson = await parseAndLog("ethVerticalSpreadsJson", () => verticalSpreadsDart("ETH", slippage));
    // verticalSpreadsChart(ethVerticalSpreadsJson, "btcVerticalSpreadsChart");

    const btcBondsJson = await parseAndLog("btcBondsJson", () => syntheticBondsDart("BTC", slippage));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}

