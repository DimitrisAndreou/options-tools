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
    const slippage = 0.5;
    try {
      logToScreen("Fetch GOOG option chains...");
      const stockCoveredCallsJson = await parseAndLog("yfinanceCoveredCalls", () => yfinanceCoveredCallsDart("GOOG", slippage));
      console.log(stockCoveredCallsJson);
      logToScreen(JSON.stringify(stockCoveredCallsJson, null, 2));
  
    } catch (error) {
      console.error("JavaScript caught Dart error:", error);
      console.error("Dart stack trace:", error.stack);
    }
  }
  