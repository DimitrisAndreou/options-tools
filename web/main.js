function chartViaApache(data) {
  // data = data.slice(0, 20);
  // Prepare [x, y, size, label] data
  const scatterData = data.map(item => [
    item.maxYieldAt,        // x
    item.breakEven,         // y
    item.maxYield,          // used as size or color
    item.call,              // label
    item.DTE,
  ]);

  // Get unique DTE values
  const uniqueDTEs = [...new Set(data.map(item => item.DTE))];

  // Create a color map for each DTE
  const colorPalette = [
    '#5470C6', '#91CC75', '#EE6666', '#73C0DE', '#FAC858',
    '#3BA272', '#FC8452', '#9A60B4', '#EA7CCC'
  ];
  const dteColorMap = {};
  uniqueDTEs.forEach((dte, index) => {
    dteColorMap[dte] = colorPalette[index % colorPalette.length];
  });

  const maxYieldAts = data.map(item => item.maxYieldAt);
  const breakevens = data.map(item => item.breakEven);
  const minX = Math.min(...maxYieldAts);
  const maxX = Math.max(...maxYieldAts);
  const minY = Math.min(...breakevens);
  const maxY = Math.max(...breakevens);
  
  // Compute a common scale
  const min = Math.min(minX, minY);
  const max = Math.max(maxX, maxY);

  const chart = echarts.init(document.getElementById('btcPriceChart'));
  window.addEventListener('resize', function() {
    chart.resize();
  });

  chart.setOption({
    title: {
      text: 'BTC Covered Calls: Max Yield vs Breakeven',
      left: 'center',
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace', // Optional
        fontSize: 16
      }
    },
    tooltip: {
      formatter: function (params) {
        const { value, data } = params;
        console.log({value, data});
        return `
          <b>${value[3]}</b><br/>
          Max Yield At: $${value[0]}<br/>
          Break Even: $${value[1]}<br/>
          Max Yield: ${value[2]}%<br/>
          DTE: ${value[4]}
        `;
      },
      textStyle: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      backgroundColor: '#333', // optional, for contrast
      borderColor: 'yellow'
    },
    xAxis: {
      name: 'Max Yield At ($)',
      nameLocation: 'middle',
      nameTextStyle: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      axisLabel: {
        color: 'yellow',
        fontFamily: 'monospace',
      },
      axisLine: {
        lineStyle: {
          color: 'yellow'
        }
      },
      type: 'value',
      scale: true
    },
    yAxis: {
      name: 'Break Even ($)',
      nameTextStyle: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      axisLabel: {
        color: 'yellow',
        fontFamily: 'monospace'
      },
      axisLine: {
        lineStyle: {
          color: 'yellow'
        }
      },
      type: 'value',
      scale: true
    },
    series: [{
      type: 'scatter',
      encode: {
        x: 0, // value[0] = maxYieldAt
        y: 1  // value[1] = breakEven
      },
      symbolSize: function (data) {
        return 4;
        // return Math.sqrt(data[2]) * 5;
      },
      label: {
        show: false
      },
      itemStyle: {
        color: function (params) {
          // return '#FFFFFF';
          const dte = params.data[4];
          console.log({params, dte, color: dteColorMap[dte]});
          return dteColorMap[dte];
        }
      },
      data: scatterData
    }],
    dataZoom: [
      {
        type: 'inside', // enables mouse wheel + drag zooming
        xAxisIndex: 0,
        yAxisIndex: 1
      },
      {
        type: 'slider', // X-axis slider
        xAxisIndex: 0,
        yAxisIndex: 1
      },
      {
        type: 'slider', // Y-axis slider
        yAxisIndex: 0,
        orient: 'vertical',  // This makes the slider vertical
        left: '90%',          // Adjust the position to fit the chart
        height: '80%'         // Adjust the height of the slider
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

// TODOs:
// 1. Create dataset as 2d array. Specify dimensions separately.
// 
// var option = {
//   dataset: {
//     dimensions: ['score', 'amount'],
//     source: [
//       [89.3, 3371],
//       [92.1, 8123],
//       [94.4, 1954],
//       [85.4, 829]
//     ]
//   }
// };

async function jsMain() {
  console.log("Hello from JS!");
  try {
    // TODO: also return spotPrice. Draw vertical line using it.
    // Make the chart isomorphic again.
    const rawData = await coveredCallsDart("BTC");
    const ccs = JSON.parse(rawData);
    console.log({ ccs });
    chartViaApache(ccs);
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }

  try {
    const rawData = await syntheticBondsDart("BTC");
    const bonds = JSON.parse(rawData);
    console.log({ bonds });
  } catch (error) {
    console.error("JavaScript caught Dart error:", error);
    console.error("Dart stack trace:", error.stack);
  }

// data = [['BreakEven ($)', 'Max Yield', 'Max Yield At ($)', 'Contract'],
//   ...gccs.map(gcc =>
//     [
//       gcc.breakEven,
//       gcc.maxYield,
//       gcc.maxYieldAt,
//       gcc.callContract.instrumentName])];
// console.log({data});
  // chartViaApache(data);
}
