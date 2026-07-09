function prepareStraddleData(value) {
  const money = value.money;
  const underlying = value.underlying;

  return {
    underlying,
    underlyingName: underlying,
    underlyingURL: value.underlyingURL,
    money,
    strategyName: 'Straddle',
    strategyURL: value.strategyURL,
    formattedDate: value.formattedDate,
    DTE: value.DTE,
    strikeAbsolute: dollarFmt.format(value.strikeAbsolute),
    strikeRelative: percentFmt.format(value.strikeAbsolute / value.spotPrice - 1.0),

    callName: value.call,
    callURL: value.callURL,
    callSize: value.callSize,
    callCostInMoney: dollarFmt.format(value.callCostInMoney),
    callCostInUnderlying: underlyingFmt.format(value.callCostInUnderlying),

    putName: value.put,
    putURL: value.putURL,
    putSize: value.putSize,
    putCostInMoney: dollarFmt.format(value.putCostInMoney),
    putCostInUnderlying: underlyingFmt.format(value.putCostInUnderlying),

    costInMoney: dollarFmt.format(-value.moneySize),
    costInUnderlying: underlyingFmt.format(value.costInUnderlying),

    // Distance between breakevens
    distanceAbsolute: dollarFmt.format(value.distanceBetweenBreakEvensAbsolute),
    distanceRelative: `${percentFmt.format(value.breakEvenVsFullMoneyDownRelative - 1.0)} ... ${percentFmt.format(value.breakEvenVsFullMoneyUpRelative - 1.0)}`,

    // Breakeven vs cash/money
    beMoneyDownAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyDownAbsolute),
    beMoneyDownRelative: percentFmt.format(value.breakEvenVsFullMoneyDownRelative - 1.0),
    beMoneyUpAbsolute: dollarFmt.format(value.breakEvenVsFullMoneyUpAbsolute),
    beMoneyUpRelative: percentFmt.format(value.breakEvenVsFullMoneyUpRelative - 1.0),

    // Breakeven vs underlying
    beUnderlyingDownAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingDownAbsolute),
    beUnderlyingDownRelative: percentFmt.format(value.breakEvenVsFullUnderlyingDownRelative - 1.0),
    beUnderlyingUpAbsolute: dollarFmt.format(value.breakEvenVsFullUnderlyingUpAbsolute),
    beUnderlyingUpRelative: percentFmt.format(value.breakEvenVsFullUnderlyingUpRelative - 1.0),

    capitalRequired: dollarFmt.format(-value.moneySize),
    capitalRequiredUnderlying: `${underlyingFmt.format(value.costInUnderlying)} ${underlying}`
  };
}

function renderTooltipStraddle(d) {
  return `
    <div class="tooltip-container">
      <div class="tooltip-header">
        <span class="tooltip-date">${d.formattedDate}</span>
        <span class="text-bad">${d.DTE}d</span>
      </div>
      
      <div class="tooltip-body">
        <div class="tooltip-yield-bad">Risk Zone: ${d.distanceRelative}</div>
        <div class="tooltip-divider"></div>
        <div class="tooltip-strike-badge">
          Strike: ${d.strikeAbsolute} <span class="strike-relative">(${d.strikeRelative})</span>
        </div>
      </div>

      <div class="tooltip-breakeven">
        <span class="text-label">Breakevens:</span> <br/>
        &bull; Down: <span class="text-good">${d.beMoneyDownAbsolute}</span> <span class="text-good">(${d.beMoneyDownRelative})</span> <br/>
        &bull; Up: <span class="text-good">${d.beMoneyUpAbsolute}</span> <span class="text-good">(${d.beMoneyUpRelative})</span>
      </div>
      
      <div class="tooltip-footer">
        Cost: <span class="text-light-alt">${d.costInMoney}</span> (${d.costInUnderlying} ${d.underlying})
      </div>
    </div>
  `;
}

StrategyRegistry['straddle'] = {
  templateId: 'straddle-details-template',
  prepareData: prepareStraddleData,
  renderTooltip: renderTooltipStraddle
};

function renderStraddlesChart(data, chartDom, idToSelect) {
  const money = data.at(0)?.money || '';
  const underlying = data.at(0)?.underlying || '';
  const dataset = {
    id: "original",
    dimensions: [
      "DTE",
      "breakEvenVsFullMoneyDownRelative",
      "breakEvenVsFullMoneyUpRelative",
      "strikeRelative",
      "id"
    ],
    source: data
  };
  const highlightDataset = {
    id: 'highlightDataset',
    fromDatasetId: 'original',
    transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect || '' } }
  };

  const chart = echarts.init(chartDom);
  window.addEventListener('resize', function () {
    chart.resize();
  });

  chart.setOption({
    dataset: [dataset, highlightDataset],
    xAxis: {
      type: 'value',
      name: 'DTE (Days to Expiration)➡',
      nameLocation: 'end',
      nameGap: 0,
      nameTextStyle: {
        ...axisTitleNameTextStyle,
        align: 'right',
        verticalAlign: 'top',
        padding: [30, 0, 0, 0]
      },
      axisLabel: axisXValuesNameTextStyle,
      axisLine,
      min: function (value) { return Math.max(0, value.min - 7); },
      max: function (value) { return value.max + 7; },
      position: 'bottom',
    },
    grid,
    yAxis: {
      type: 'value',
      name: `⇳ Breakevens`,
      nameLocation: 'end',
      nameTextStyle: yAxisTitleNameTextStyle,
      axisLabel: {
        ...axisYValuesNameTextStyle,
        formatter: function (value) {
          return `${percentFmt.format(value - 1.0)}`;
        },
      },
      axisLine,
      min: function (value) { return Math.max(0.0, value.min - 0.05); },
      max: function (value) { return value.max + 0.05; }
    },
    tooltip: {
      ...tooltipStyle,
      formatter: strategyTooltipFormatter,
    },
    series: [
      {
        type: 'custom',
        name: 'Straddles',
        renderItem: function (params, api) {
          var dte = api.value(0);
          var down = api.value(1);
          var up = api.value(2);
          var strike = api.value(3);

          var coordDown = api.coord([dte, down]);
          var coordUp = api.coord([dte, up]);
          var coordStrike = api.coord([dte, strike]);

          var barWidth = 3;
          var capRadius = 5;
          var strikeRadius = 4;

          return {
            type: 'group',
            children: [
              {
                type: 'line',
                shape: {
                  x1: coordDown[0],
                  y1: coordDown[1],
                  x2: coordUp[0],
                  y2: coordUp[1]
                },
                style: api.style({
                  stroke: '#ef4444',
                  lineWidth: barWidth
                }),
                emphasis: {
                  style: {
                    stroke: 'red',
                    lineWidth: barWidth + 1
                  }
                }
              },
              {
                type: 'circle',
                shape: {
                  cx: coordDown[0],
                  cy: coordDown[1],
                  r: capRadius
                },
                style: api.style({
                  fill: '#10b981'
                }),
                emphasis: {
                  style: {
                    fill: '#10b981',
                    stroke: 'white',
                    lineWidth: 2
                  }
                }
              },
              {
                type: 'circle',
                shape: {
                  cx: coordUp[0],
                  cy: coordUp[1],
                  r: capRadius
                },
                style: api.style({
                  fill: '#10b981'
                }),
                emphasis: {
                  style: {
                    fill: '#10b981',
                    stroke: 'white',
                    lineWidth: 2
                  }
                }
              },
              {
                type: 'circle',
                shape: {
                  cx: coordStrike[0],
                  cy: coordStrike[1],
                  r: strikeRadius
                },
                style: api.style({
                  fill: '#fcd34d'
                }),
                emphasis: {
                  style: {
                    fill: '#fcd34d',
                    stroke: 'white',
                    lineWidth: 2
                  }
                }
              }
            ]
          };
        },
        encode: {
          x: 'DTE',
          y: ['breakEvenVsFullMoneyDownRelative', 'breakEvenVsFullMoneyUpRelative']
        },
        emphasis: {
          focus: 'self'
        },
        dimensions: [
          "DTE",
          "breakEvenVsFullMoneyDownRelative",
          "breakEvenVsFullMoneyUpRelative",
          "strikeRelative"
        ],
        datasetId: 'original'
      },
      {
        ...selectionHighlightSeries,
        encode: { x: 'DTE', y: 'strikeRelative' }
      }
    ],
    legend: { show: false },
    animationDurationUpdate: 800,
    animationEasingUpdate: 'quinticOut',
  });

  chart.on('click', function (params) {
    if (params.componentType === 'series' && params.data) {
      selectStrategyById(chart, data, params.data.id);
    }
  });

  selectStrategyById(chart, data, idToSelect);
  return chart;
}
