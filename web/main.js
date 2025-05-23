const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const percentNoSignFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
});

const dollarFmt = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0
});

// TODO: Digits of rounding should depend on the underlying.
const underlyingFmt = new Intl.NumberFormat('en-US', {
  style: 'decimal',
  minimumFractionDigits: 3,
  maximumFractionDigits: 3
});

const priceFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1,
  signDisplay: 'always',
});

const tooltipStyle = {
  position: 'top',
  enterable: true,
  textStyle: {
    color: '#fcd34d',
    fontFamily: 'monospace'
  },
  backgroundColor: '#1e1e2f',
  borderColor: '#fcd34d',
};


const ccTooltipFormatter = function (params) {
  function label(str) {
    return `<strong>${str}</strong>`;
  }
  function neutral(str) {
    return `<strong style="color: #38bdf8;">${str}</strong>`;
  }
  function good(str) {
    return `<strong style="color: #00ffa3;">${str}</strong>`;
  }
  function bad(str) {
    return `<strong style="color: #ff5c5c;">${str}</strong>`;
  }
  const value = params.value;
  const DTE = `${value.DTE}`;
  const breakeven = `${percentFmt.format(value.breakEvenAsChange - 1.0)}`;
  const breakevenAt = `${dollarFmt.format(value.breakEven)}`;
  const maxProfitPercent = `${percentFmt.format(value.maxYield - 1.0)}`;
  const maxProfit = `${dollarFmt.format(value.maxProfit)}`;
  const maxProfitAt = `${dollarFmt.format(value.maxYieldAt)}`;
  const maxProfitAtRelative = `${percentFmt.format(value.maxYieldAtChange - 1.0)}`;
  const whatToBuy = `${underlyingFmt.format(value.boughtUnderlyingSize)}</b> ${value.underlying}`;
  const whatToBuyFor = `${dollarFmt.format(-value.moneySize)}`;
  const whatToSell = `${-value.callSize}`;
  const whatToSellFor = `${underlyingFmt.format(value.premiumUnderlyingSize)}</b> ${value.underlying}`;
  return `
    ${neutral(value.call)} (${neutral(DTE)} days)<br/>
    ${label('Breakeven')}: ${neutral(breakeven)}
      (at ${neutral(breakevenAt)})<br/>
    ${label('Max Profit')}:
    <ul style="margin: 0">
    <li>${good(maxProfitPercent)} (${good(maxProfit)})
    <li>at >=${neutral(maxProfitAt)} (${neutral(maxProfitAtRelative)})
    </ul>
    ${label('Instructions')}:
    <ul style="margin: 0">
    <li>Buy ${good(whatToBuy)}, for ${bad(whatToBuyFor)}</li>
    <li>Sell ${bad(whatToSell)} call(s), for ${good(whatToSellFor)}</li>
    </ul>`;
};

const spotPriceSeries = function(spotPrice) {
  return {
    type: 'line',
    data: [],
    markLine: {
      symbol: 'none',
      label: {
        show: false,
      },
      lineStyle: {
        type: 'dashed',
        color: 'yellow',
        width: 1,
      },
      tooltip: {
        show: true,
        formatter: () => {
          return `
            'Just hodl' strategy (no options):
            <BR>You give up no potential profits
            <BR>and you get no breakeven reduction.
            <BR>Your breakeven is ${dollarFmt.format(spotPrice)}
          `;
        },
      },
      data: [
        {
          xAxis: spotPrice,
        }
      ]
    },
  };
};

const axisTitleNameTextStyle = {
  color: 'yellow',
  fontFamily: 'monospace',
  fontSize: 18
};
const yAxisTitleNameTextStyle = {
  ...axisTitleNameTextStyle,
  align: 'left',
};
const axisXValuesNameTextStyle = {
  color: 'lightgreen',
  fontFamily: 'monospace',
  fontSize: 16,
};
const axisYValuesNameTextStyle = {
  color: 'orange',
  fontFamily: 'monospace',
  fontSize: 16,
};
const axisLine = {
  lineStyle: {
    color: 'yellow'
  }
};
const grid = {
  left: 60,
  right: 50,
  top: 50,
  bottom: 100,
};
const legend = {
  show: true,
  type: 'scroll',        // Keeps it scrollable if too long
  orient: 'horizontal',
  top: 'bottom',
  textStyle: {
    color: 'yellow',
    fontFamily: 'monospace',
    fontSize: 12
  },
  pageIconColor: 'yellow',
  pageTextStyle: {
    color: 'yellow'
  },
  width: '75%',
}

function extractSpotPrice(data) {
  return data.at(0)?.spotPrice;
}

function selectDTEs(uniqueDTEs, minDTE) {
  const legendSelected = {};
  uniqueDTEs.forEach(dte => {
    legendSelected[dte] = dte >= minDTE;
  });
  return legendSelected;
}

function coveredCallToBreakEvenChart(data, divId) {
  const spotPrice = extractSpotPrice(data);
  // TODO: share this code across charts.
  const dataset = {
    id: "original",
    dimensions: ["breakEven", "DTE", "equivalentHodlerSellPrice"],
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
      name: 'Max Profit',
      nameLocation: 'center',
      nameGap: 50,
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
      inverse: true,
      max: spotPrice,
      splitNumber: 10,
      name: 'Breakeven Improvement (Reduction)',
      nameLocation: 'start',
      align: 'right',
      nameTextStyle: yAxisTitleNameTextStyle,
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return `${percentNoSignFmt.format(1.0 - value / spotPrice)}`;
        },
      },
      axisLine,
      scale: true
    },
    tooltip: {
      ...tooltipStyle,
      formatter: ccTooltipFormatter,
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'equivalentHodlerSellPrice',
        y: 'breakEven'
      },
      symbolSize: function (data) {
        return 8;
      },
      emphasis: {
        symbolSize: function (data) {
          return 10;
        },
        itemStyle: {
          color: 'red',
          borderColor: 'white',
          borderWidth: 2
        },
        scale: true,
        focus: 'series',
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
          return `
            'Just hodl' strategy:
            <BR>You give up no potential profits
            <BR>and you get no breakeven reduction
          `;
        }
      },
    }, spotPriceSeries(spotPrice)],
    legend: {
      ...legend,
      selected: selectDTEs(uniqueDTEs, 15),
    },
    dataZoom: [
      {
        type: 'inside',
        xAxisIndex: 0,
        startValue: spotPrice * 0.5,
        endValue: spotPrice * 1.5,
      },
      {
        type: 'inside',
        yAxisIndex: 0,
        startValue: spotPrice / 2.0,
        endValue: spotPrice,
      }
    ],
  });
}

function coveredCallToTimeValueChart(data, divId) {
  const spotPrice = extractSpotPrice(data);
  const dataset = {
    id: "original",
    dimensions: ["timeValue", "DTE", "equivalentHodlerSellPrice"],
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
      name: 'Max Profit',
      nameLocation: 'center',
      nameGap: 50,
      nameTextStyle: axisTitleNameTextStyle,
      axisLabel: {
        ...axisXValuesNameTextStyle,
        formatter: function (value) {
          return `${dollarFmt.format(value)}\n(${percentFmt.format(value / spotPrice - 1.0)})`;
        },
      },
      axisLine,
      scale: true
    },
    grid,
    yAxis: {
      type: 'value',
      name: 'Time Value (%)',
      nameTextStyle: yAxisTitleNameTextStyle,
      align: 'right',
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return percentFmt.format(value);
        },
        align: 'left',
        margin: 40,
      },
      axisLine,
      scale: true
    },
    tooltip: {
      ...tooltipStyle,
      formatter: ccTooltipFormatter,
    },
    series: [...datasetPerDTE.map(ds => ({
      type: 'line',
      name: ds.label,
      datasetId: ds.id,
      encode: {
        x: 'equivalentHodlerSellPrice',
        y: 'timeValue'
      },
      symbolSize: function (data) {
        // TODO: function of maxYield? Or of time value?
        return 4;
      },
      label: {
        show: false
      }
    })), spotPriceSeries(spotPrice)],
    legend: {
      ...legend,
      selected: selectDTEs(uniqueDTEs, 15),
    },
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
        startValue: 0.0,
        endValue: 1.0,
      }
    ],
  });
}

function verticalSpreadsChart(data, divId) {
  const spotPrice = extractSpotPrice(data);
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
      ...tooltipStyle,
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Profit At: $${value.maxYieldAt}<br/>
          Break Even: ${dollarFmt.format(value.breakEven)} (${percentFmt.format(value.breakEvenAsChange - 1.0)})<br/>
          Max Profit: ${percentFmt.format(value.maxYield - 1.0)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}<br/>
          DTE: ${value.DTE}
        `;
      },
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

async function parseAndLog(name, jsonLoaderFn) {
  const rawJson = await jsonLoaderFn();
  console.log(`Raw ${name} data:`);
  console.log(rawJson);
  return JSON.parse(rawJson);
}

async function jsMain() {
  const slippage = 0.5;
  try {
    const btcCoveredCallsJson = await parseAndLog("btcCoveredCallsJson", () => coveredCallsDart("BTC", slippage));
    document.getElementById('btc-price').textContent = dollarFmt.format(extractSpotPrice(btcCoveredCallsJson));
    coveredCallToBreakEvenChart(btcCoveredCallsJson, "btcCoveredCallsChart");
    coveredCallToTimeValueChart(btcCoveredCallsJson, "btcCoveredCallsTimeValueChart");

    const btcVerticalSpreadsJson = await parseAndLog("btcVerticalSpreadsJson", () => verticalSpreadsDart("BTC", slippage));
    // verticalSpreadsChart(btcVerticalSpreadsJson, "btcVerticalSpreadsChart");

    const ethCoveredCallsJson = await parseAndLog("ethCoveredCallsJson", () => coveredCallsDart("ETH", slippage));
    document.getElementById('eth-price').textContent = dollarFmt.format(extractSpotPrice(ethCoveredCallsJson));
    coveredCallToBreakEvenChart(ethCoveredCallsJson, "ethCoveredCallsChart");
    coveredCallToTimeValueChart(ethCoveredCallsJson, "ethCoveredCallsTimeValueChart");
    const ethVerticalSpreadsJson = await parseAndLog("ethVerticalSpreadsJson", () => verticalSpreadsDart("ETH", slippage));
    // verticalSpreadsChart(ethVerticalSpreadsJson, "btcVerticalSpreadsChart");
    
    const btcBondsJson = await parseAndLog("btcBondsJson", () => syntheticBondsDart("BTC", slippage));
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}
