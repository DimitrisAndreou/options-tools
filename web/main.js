function deribitUriForOptionChain(ticker) {
  return "https://www.deribit.com/api/v2/public/get_book_summary_by_currency?kind=option&currency=" + ticker;
}

async function jsonFromCacheOrService(uri) {
  const cachedData = JSON.parse(localStorage.getItem(uri));
  if (cachedData && Date.now() < cachedData.expirationTimestamp) {
    console.log("Using cache for: " + uri);
    return cachedData.jsonResponse;
  }
  console.log("Fetching live data from: " + uri);
  const jsonResponse = await (await fetch(uri)).text();
  localStorage.setItem(uri, JSON.stringify({
    jsonResponse,
    // 10 minutes
    expirationTimestamp: Date.now() + 10 * 60 * 1000,
  }));
  return jsonResponse;
}

function chartViaApache(data) {
  // Initialize the chart
  var chart = echarts.init(document.getElementById('BTC_gcc_chart'));

  var symbolSize = 4;

  data = [
    ['BreakEven ($)', 'Max Yield', 'Max Yield At ($)', 'Contract'],
    [10000, 1.5, 15000, "xaxa"],
    [20000, 2.5, 35000, "xouxou"]];
  console.log({data});
  option = {
    grid3D: {},
    xAxis3D: {},
    yAxis3D: {},
    zAxis3D: {},
    dataset: {
      dimensions: [
        'BreakEven ($)',
        'Max Yield',
        'Max Yield At ($)',
        'Contract'
      ],
      source: data
    },
    series: [
      {
        type: 'scatter3D',
        symbolSize: symbolSize,
        encode: {
          x: 'BreakEven ($)',
          y: 'Max Yield',
          z: 'Max Yield At ($)',

          tooltip: [0, 1, 2, 3]
        }
      }
    ]
  };
  chart.setOption(option);
}

async function jsMain() {

  console.log("Hello from JS!");

  const json = await jsonFromCacheOrService(deribitUriForOptionChain("BTC"));
  console.log({json});

  const gccs = JSON.parse(processTickerData(json));
  console.log({gccs});
  data = [['BreakEven ($)', 'Max Yield', 'Max Yield At ($)', 'Contract'],
    ...gccs.map(gcc => 
      [
        gcc.breakEven,
        gcc.maxYield,
        gcc.maxYieldAt,
        gcc.callContract.instrumentName])];
  console.log({data});
  // chartViaApache(data);
}
