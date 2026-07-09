const StrategyRegistry = {};

const strategyTooltipFormatter = function (params) {
  if (!params || !params.value) return '';
  const type = params.value.strategyType;
  const config = StrategyRegistry[type];
  if (!config) {
    console.error(`Unknown strategyType: ${type}`);
    return '';
  }
  const data = config.prepareData(params.value);
  return config.renderTooltip(data);
};

function extractSpotPrice(data) {
  return data.at(0)?.spotPrice;
}


// Spaghetthi.
function selectStrategyById(chart, data, idToSelect) {
  const panel = document.getElementById('strategyDetailsPanel');
  if (panel) {
    panel.innerHTML = '';
  }
  const strategyType = data.at(0)?.strategyType;
  if (!idToSelect) {
    const url = UrlManager.createUrl();
    UrlManager.set(url, URL_PARAMS.ID, null);
    if (strategyType) {
      const config = StrategyRegistry[strategyType];
      if (config && config.urlParams) {
        UrlManager.clearParams(url, config.urlParams);
      }
    }
    UrlManager.replaceState(url);
    const updateObj = {
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': '' } }
      }]
    };
    chart.setOption(updateObj);
    return;
  }
  const targetItem = data.find(item => item.id === idToSelect);
  if (!targetItem) {
    const url = UrlManager.createUrl();
    UrlManager.set(url, URL_PARAMS.ID, null);
    if (strategyType) {
      const config = StrategyRegistry[strategyType];
      if (config && config.urlParams) {
        UrlManager.clearParams(url, config.urlParams);
      }
    }
    UrlManager.replaceState(url);
    const updateObj = {
      dataset: [{
        id: 'highlightDataset',
        transform: { type: 'filter', config: { dimension: 'id', '=': '' } }
      }]
    };
    chart.setOption(updateObj);
    return;
  }

  populateStrategyDetails(targetItem);

  const updateObj = {
    dataset: [{
      id: 'highlightDataset',
      transform: { type: 'filter', config: { dimension: 'id', '=': idToSelect } }
    }]
  };

  chart.setOption(updateObj);
}

function populateStrategyDetails(dataObj) {
  if (!dataObj || !dataObj.strategyType) {
    throw new Error('Missing strategyType in data object');
  }

  const config = StrategyRegistry[dataObj.strategyType];
  if (!config) {
    throw new Error(`Unknown strategyType: ${dataObj.strategyType}`);
  }

  if (dataObj.id) {
    const url = UrlManager.createUrl();
    const previousUrlId = url.searchParams.get(URL_PARAMS.ID);
    UrlManager.set(url, URL_PARAMS.ID, dataObj.id);

    const hasParams = config.urlParams && config.urlParams.every(param => url.searchParams.has(param));
    if (previousUrlId !== dataObj.id || !hasParams) {
      if (config.urlParams) {
        UrlManager.clearParams(url, config.urlParams);
      }
      if (config.updateUrlParams) {
        config.updateUrlParams(url, dataObj);
      }
    }
    UrlManager.replaceState(url);
  }

  const unrealizedPanel = document.getElementById('unrealizedResultsPanel');
  if (unrealizedPanel) {
    unrealizedPanel.innerHTML = '';
    unrealizedPanel.style.display = 'none';
  }

  if (config.unrealizedTemplateId && config.prepareUnrealizedData) {
    const unrealizedData = config.prepareUnrealizedData(dataObj);
    const template = document.getElementById(config.unrealizedTemplateId);
    if (unrealizedData && unrealizedPanel && template) {
      const clone = template.content.cloneNode(true);
      for (const [key, value] of Object.entries(unrealizedData)) {
        if (key.endsWith('Class')) {
          clone.querySelectorAll(`.tpl-${key}`).forEach(el => {
            el.className = `tpl-${key} ${value}`;
          });
        } else {
          clone.querySelectorAll(`.tpl-${key}`).forEach(el => {
            el.innerHTML = value;
          });
        }
      }
      unrealizedPanel.appendChild(clone);
      unrealizedPanel.style.display = 'block';
    }
  }

  const panel = document.getElementById('strategyDetailsPanel');
  const template = document.getElementById(config.templateId);

  if (panel && template) {
    const d = config.prepareData(dataObj);
    const clone = template.content.cloneNode(true);

    for (const [key, value] of Object.entries(d)) {
      clone.querySelectorAll(`.tpl-${key}`).forEach(el => {
        el.innerHTML = value;
      });
      clone.querySelectorAll(`.tpl-href-${key}`).forEach(el => {
        if (value) {
          el.href = value;
        } else {
          // If there is no URL, unwrap the link
          el.outerHTML = el.innerHTML;
        }
      });
    }

    panel.innerHTML = '';
    panel.appendChild(clone);
  }
}
