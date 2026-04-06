async function parseAndLog(name, jsonLoaderFn) {
  const rawJson = await jsonLoaderFn();
  console.log(`Raw ${name} data:`);
  console.log(rawJson);
  return JSON.parse(rawJson);
}


function logToScreen(message) {
  const outputArea = document.getElementById('output-log');

  // Add a timestamp (optional but helpful for logs)
  const timestamp = new Date().toLocaleTimeString();
  const formattedMessage = `[${timestamp}] ${message}\n`;

  // Append the text
  outputArea.value += formattedMessage;

  // Auto-scroll to the bottom so the newest message is always visible
  outputArea.scrollTop = outputArea.scrollHeight;
}

async function jsYfMain() {
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
    logToScreen("No ticker provided. Please enter a ticker symbol above.");
    return;
  }

  const slippage = 0.5;
  try {
    logToScreen(`Fetch ${ticker} option chains...`);
    const stockCoveredCallsJson = await parseAndLog("yfinanceCoveredCalls", () => yfinanceCoveredCallsDart(ticker, slippage));
    console.log(stockCoveredCallsJson);
    logToScreen(JSON.stringify(stockCoveredCallsJson, null, 2));

  } catch (error) {
    const errorMessage = `❌ ERROR: ${error}\n` +
      `STORY: ${error.stack || 'No stack trace available'}`;

    logToScreen(errorMessage);
    console.error("Dart Error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}
