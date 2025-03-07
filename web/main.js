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

  const gccs = JSON.parse(await analyzeMarket("BTC"));
  console.log({gccs});

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
