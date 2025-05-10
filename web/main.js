const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const dollarFmt = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0
});

const priceFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const axisTitleNameTextStyle = {
  color: 'yellow',
  fontFamily: 'monospace',
  fontSize: 16
};
const axisXValuesNameTextStyle = {
  color: 'lightgreen',
  fontFamily: 'monospace',
  fontSize: 14,
};
const axisYValuesNameTextStyle = {
  color: 'orange',
  fontFamily: 'monospace',
  fontSize: 14,
};
const axisLine = {
  lineStyle: {
    color: 'yellow'
  }
};
const grid = {
  left: 80,
  right: 50,
  top: 50,
  bottom: 100,
};
const legend = {
  show: true,
  type: 'scroll',
  orient: 'horizontal',
  top: 'bottom',
  textStyle: {
    color: 'yellow',
    fontFamily: 'monospace',
    fontSize: 12
  }
};

function extractSpotPrice(data) {
  return data.at(0)?.spotPrice;
}

function coveredCallToBreakEvenChart(data, divId) {
  const spotPrice = extractSpotPrice(data);
  // TODO: share this code across charts.
  const dataset = {
    id: "original",
    dimensions: ["maxYieldAt", "breakEven", "maxYield", "call", "DTE", "timeValue"],
    source: data
  };
  const uniqueDTEs = [...new Set(dataset.source.map(item => item.DTE))];
  const datasetPerDTE = uniqueDTEs.map(dte => ({
    id: `dte_${dte}`,
    fromDatasetId: 'original',
    label: `${dte}`,
    transform: {
      type: 'filter',
      config: {
        dimension: 'DTE',
        '=': dte
      }
    }
  }));

  const chart = echarts.init(document.getElementById(divId));
  window.addEventListener('resize', function() {
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, ...datasetPerDTE],
    xAxis: {
      type: 'value',
      name: 'Max Yield At ($)',
      nameLocation: 'center',
      nameGap: 40,
      nameTextStyle: axisTitleNameTextStyle,
      axisLabel: {
        ...axisXValuesNameTextStyle,
        formatter: function (value) {
          return `${dollarFmt.format(value)}\n(${percentFmt.format(value / spotPrice - 1.0)})`;
        },
      },
      axisLine,
      scale: true,
      position: 'bottom',
    },
    grid,
    yAxis: {
      type: 'value',
      name: 'Break-Even ($)',
      nameLocation: 'end',
      align: 'right',
      nameTextStyle: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 18
      },
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return `${dollarFmt.format(value)}\n(${percentFmt.format(value / spotPrice - 1.0)})`;
        },
      },
      axisLine,
      scale: true
    },
    tooltip: {
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Profit At: $${value.maxYieldAt}<br/>
          Break Even: $${dollarFmt.format(value.breakEven)}<br/>
          Max Profit: ${percentFmt.format(value.maxYield - 1.0)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}<br/>
          DTE: ${value.DTE}
        `;
      },
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      backgroundColor: '#333', // optional, for contrast
      borderColor: 'yellow'
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'maxYieldAt',
        y: 'breakEven'
      },
      symbolSize: function (data) {
        return 5;
      },
      label: {
        show: false
      }
    })), {
      type: 'scatter',
      data: [[Math.max(...data.map(item => item.maxYieldAt)), spotPrice]],
      symbol: 'circle',
      symbolSize: 0,
      itemStyle: {
        color: 'yellow',
      },
      label: {
        show: true,
        formatter: '🚀',
        fontSize: 20,
        color: 'white',
        position: 'inside',
        offset: [0, 0],
      },
      tooltip: {
        show: true,
        formatter: () => {
          return `The spot strategy <BR>(no breakeven reduction, no max gain cap)`;
        }
      },
    }],
    legend,
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        startValue: spotPrice * 0.5,
        endValue: spotPrice * 1.5,
        zoomOnMouseWheel: false, // disable built-in wheel zoom
        moveOnMouseMove: true,
        moveOnMouseWheel: true, // allow moving via wheel
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        startValue: 0,
        endValue: spotPrice,
        zoomOnMouseWheel: false, // disable built-in wheel zoom
        moveOnMouseMove: true,
        moveOnMouseWheel: true, // allow moving via wheel
      }
    ],
  });
}

function coveredCallToTimeValueChart(data, divId) {
  const spotPrice = data.at(0)?.spotPrice;
  const dataset = {
    id: "original",
    dimensions: ["maxYieldAt", "breakEven", "maxYield", "call", "DTE", "timeValue"],
    source: data
  };
  const uniqueDTEs = [...new Set(dataset.source.map(item => item.DTE))];
  const datasetPerDTE = uniqueDTEs.map(dte => ({
    id: `dte_${dte}`,
    fromDatasetId: 'original',
    label: `${dte}`,
    transform: {
      type: 'filter',
      config: {
        dimension: 'DTE',
        '=': dte
      }
    }
  }));

  const chart = echarts.init(document.getElementById(divId));
  window.addEventListener('resize', function() {
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, ...datasetPerDTE],
    xAxis: {
      type: 'value',
      name: 'Strike',
      nameLocation: 'center',
      nameGap: 25,
      nameTextStyle: axisTitleNameTextStyle,
      axisLabel: axisXValuesNameTextStyle,
      axisLine,
      scale: true
    },
    grid,
    yAxis: {
      type: 'value',
      name: 'Time Value (%)',
      nameTextStyle: axisTitleNameTextStyle,
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return percentFmt.format(value);
        }
      },
      axisLine,
      scale: true
    },
    tooltip: {
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Profit At: $${value.maxYieldAt}<br/>
          Break Even: $${dollarFmt.format(value.breakEven)}<br/>
          Max Profit: ${percentFmt.format(value.maxYield - 1.0)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}<br/>
          DTE: ${value.DTE}
        `;
      },
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      backgroundColor: '#333', // optional, for contrast
      borderColor: 'yellow'
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'maxYieldAt',
        y: 'timeValue'
      },
      symbolSize: function (data) {
        // TODO: function of maxYield? Or of time value?
        return 4;
      },
      label: {
        show: false
      }
    }))],
    legend,
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        startValue: spotPrice * 0.5,
        endValue: spotPrice * 1.5
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        startValue: 0,
        endValue: spotPrice
      }
    ],
  });
}

function verticalSpreadsChart(data, divId) {
  const spotPrice = data.at(0)?.spotPrice;
// {
//   "underlying": "BTC",
//   "money": "USD",
//   "credit": 1988.3800000000028,
//   "spotPrice": 103293.5,
//   "shortLeg": "BTC-10MAY25-86000-C",
//   "longLeg": "BTC-10MAY25-88000-C",
//   "type": "over",
//   "DTE": 0,
//   "breakEven": 87988.38,
//   "breakEvenAsChange": 0.8518288178830227,
//   "maxYield": 172.11703958696114,
//   "maxYieldAt": 86000,
//   "maxYieldAtChange": 0.8325790102959044,
//   "maxRisk": 11.619999999997162,
//   "maxRiskAt": 88000,
//   "maxRiskAtChange": 0.8519413128609254,
//   "yieldIfPriceUnchanged": 0
// } 
  const dataset = {
    id: "original",
    dimensions: ["type", "DTE", "maxYield", "maxYieldAt", "shortLeg", "longLeg",
      "credit", "maxRisk", "breakEven"
    ],
    source: data
  };
  const uniqueDTEs = [...new Set(dataset.source.map(item => item.DTE))];
  const datasetPerDTE = uniqueDTEs.map(dte => ({
    id: `dte_${dte}`,
    fromDatasetId: 'original',
    label: `${dte}`,
    transform: {
      type: 'filter',
      config: {
        dimension: 'DTE',
        '=': dte
      }
    }
  }));

  const chart = echarts.init(document.getElementById(divId));
  window.addEventListener('resize', function() {
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, ...datasetPerDTE],
    xAxis: {
      type: 'value',
      name: 'Strike',
      nameLocation: 'center',
      nameGap: 25,
      nameTextStyle: {
        color: 'green',
        fontFamily: 'monospace',
        fontSize: 16
      },
      axisLabel: {
        color: 'green',
        fontFamily: 'monospace',
        fontSize: 12
      },
      axisLine,
      scale: true
    },
    grid,
    yAxis: {
      type: 'value',
      name: 'Time Value (%)',
      nameTextStyle: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 16
      },
      axisLabel: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 12,
        formatter: function (value) {
          return percentFmt.format(value);
        }
      },
      axisLine,
      scale: true
    },
    tooltip: {
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Profit At: $${value.maxYieldAt}<br/>
          Break Even: $${dollarFmt.format(value.breakEven)}<br/>
          Max Profit: ${percentFmt.format(value.maxYield - 1.0)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}<br/>
          DTE: ${value.DTE}
        `;
      },
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      backgroundColor: '#333', // optional, for contrast
      borderColor: 'yellow'
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'maxYieldAt',
        y: 'timeValue'
      },
      symbolSize: function (data) {
        // TODO: function of maxYield? Or of time value?
        return 4;
      },
      label: {
        show: false
      }
    }))],
    legend,
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        startValue: spotPrice * 0.5,
        endValue: spotPrice * 1.5
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        startValue: 0,
        endValue: spotPrice
      }
    ],
  });
}

async function jsMain() {
  const slippage = 0.5;
  try {
    const btcCoveredCallsJson = JSON.parse(await coveredCallsDart("BTC", slippage));
    document.getElementById('btc-price').textContent = dollarFmt.format(extractSpotPrice(btcCoveredCallsJson));
    coveredCallToBreakEvenChart(btcCoveredCallsJson, "btcCoveredCallsChart");
    coveredCallToTimeValueChart(btcCoveredCallsJson, "btcCoveredCallsTimeValueChart");

    // const btcVerticalSpreadsJson = JSON.parse(await verticalSpreadsDart("BTC", slippage));
    // console.log({btcVerticalSpreadsJson});
    // verticalSpreadsChart(btcVerticalSpreadsJson, "btcVerticalSpreadsChart");

    const ethCoveredCallsJson = JSON.parse(await coveredCallsDart("ETH", slippage));
    document.getElementById('eth-price').textContent = dollarFmt.format(extractSpotPrice(ethCoveredCallsJson));
    coveredCallToBreakEvenChart(ethCoveredCallsJson, "ethCoveredCallsChart");
    coveredCallToTimeValueChart(ethCoveredCallsJson, "ethCoveredCallsTimeValueChart");
    const ethVerticalSpreadsJson = JSON.parse(await verticalSpreadsDart("BTC", slippage));
    verticalSpreadsChart(ethVerticalSpreadsJson, "btcVerticalSpreadsChart");
    
    const btcBondsJson = JSON.parse(await syntheticBondsDart("BTC", slippage));
    console.log({ btcBondsJson });
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}
