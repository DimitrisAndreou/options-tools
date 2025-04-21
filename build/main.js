const percentFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1
});

const dollarFmt = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0
});

const priceFmt = new Intl.NumberFormat('en-US', {
  style: 'percent',
  maximumFractionDigits: 1
});

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
      axisLine: {
        lineStyle: {
          color: 'green'
        }
      },
      scale: true
    },
    // TODO: reusable
    grid: {
      left: 80,
      right: 50,
      top: 50,
      bottom: 80
    },
    yAxis: {
      type: 'value',
      name: 'Break-Even ($)',
      nameLocation: 'end',
      align: 'right',
      nameTextStyle: {
        color: 'red',
        fontFamily: 'monospace',
        fontSize: 16
      },
      axisLabel: {
        color: 'red',
        fontFamily: 'monospace',
        fontSize: 12
      },
      axisLine: {
        lineStyle: {
          color: 'red'
        }
      },
      scale: true
    },
    tooltip: {
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Yield At: $${value.maxYieldAt}<br/>
          Break Even: $${value.breakEven}<br/>
          Max Yield: ${percentFmt.format(value.maxYield)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}%<br/>
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
        // TODO: function of maxYield? Or of time value?
        return 4;
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
          return `The spot strategy`;
        }
      },
    }],
    // TODO: reusable
    legend: {
      show: true,
      type: 'scroll',
      orient: 'horizontal',
      top: 'bottom',
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 12
      }
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
        startValue: 0,
        endValue: spotPrice
      }
    ],
    toolbox: {
      feature: {
        dataZoom: {
          yAxisIndex: 'none',
          type: 'inside',  // This enables mouse drag to pan
        }
      }
    },
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
      axisLine: {
        lineStyle: {
          color: 'green'
        }
      },
      scale: true
    },
    // TODO: reusable
    grid: {
      left: 80,
      right: 50,
      top: 50,
      bottom: 80
    },
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
      axisLine: {
        lineStyle: {
          color: 'yellow'
        }
      },
      scale: true
    },
    tooltip: {
      formatter: function (params) {
        const value = params.value;
        return `
          <b>${value.call}</b><br/>
          Max Yield At: $${value.maxYieldAt}<br/>
          Break Even: $${value.breakEven}<br/>
          Max Yield: ${percentFmt.format(value.maxYield)}<br/>
          Time Value: ${percentFmt.format(value.timeValue)}%<br/>
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
    // TODO: reusable
    legend: {
      show: true,
      type: 'scroll',
      orient: 'horizontal',
      top: 'bottom',
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace',
        fontSize: 12
      }
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
        startValue: 0,
        endValue: spotPrice
      }
    ],
    toolbox: {
      feature: {
        dataZoom: {
          yAxisIndex: 'none',
          type: 'inside',  // This enables mouse drag to pan
        }
      }
    },
  });
}

async function jsMain() {
  const slippage = 0.5;
  try {
    const btcCoveredCallsJson = JSON.parse(await coveredCallsDart("BTC", slippage));
    document.getElementById('btc-price').textContent = dollarFmt.format(extractSpotPrice(btcCoveredCallsJson));
    coveredCallToBreakEvenChart(btcCoveredCallsJson, "btcCoveredCallsChart");
    coveredCallToTimeValueChart(btcCoveredCallsJson, "btcCoveredCallsTimeValueChart");

    const ethCoveredCallsJson = JSON.parse(await coveredCallsDart("ETH", slippage));
    document.getElementById('eth-price').textContent = dollarFmt.format(extractSpotPrice(ethCoveredCallsJson));
    coveredCallToBreakEvenChart(ethCoveredCallsJson, "ethCoveredCallsChart");
    coveredCallToTimeValueChart(ethCoveredCallsJson, "ethCoveredCallsTimeValueChart");
    const bondsJson = JSON.parse(await syntheticBondsDart("BTC", slippage));
    console.log({ bondsJson });
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }
}
