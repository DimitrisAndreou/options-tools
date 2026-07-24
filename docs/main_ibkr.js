const STORAGE_KEY_TOKEN = 'ibkr_flex_token';
const STORAGE_KEY_QUERY_ID = 'ibkr_flex_query_id';
const STORAGE_KEY_WORKER_URL = 'ibkr_flex_worker_url';

let reportBaseCurrency = 'USD';

const CURRENCY_SYMBOLS = {
  'USD': '$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CAD': 'CA$',
  'AUD': 'A$',
  'CHF': 'CHF'
};

function getCurrencySymbol(cc) {
  return CURRENCY_SYMBOLS[cc] || cc || '$';
}

document.addEventListener('DOMContentLoaded', () => {
  // 1. Read URL query parameters first (e.g. ?token=...&queryId=...)
  const urlParams = new URLSearchParams(window.location.search);
  const urlToken = urlParams.get('token') || urlParams.get('t');
  const urlQueryId = urlParams.get('queryId') || urlParams.get('q');

  // 2. Read saved values from localStorage
  const savedToken = localStorage.getItem(STORAGE_KEY_TOKEN);
  const savedQueryId = localStorage.getItem(STORAGE_KEY_QUERY_ID);
  const savedWorkerUrl = localStorage.getItem(STORAGE_KEY_WORKER_URL);

  if (urlToken) {
    document.getElementById('ibkr-token').value = urlToken;
  } else if (savedToken) {
    document.getElementById('ibkr-token').value = savedToken;
  }

  if (urlQueryId) {
    document.getElementById('ibkr-query-id').value = urlQueryId;
  } else if (savedQueryId) {
    document.getElementById('ibkr-query-id').value = savedQueryId;
  }

  if (savedWorkerUrl) document.getElementById('ibkr-worker-url').value = savedWorkerUrl;

  // Update URL to ensure current parameters are reflected
  updateUrlParams();

  // Listen for input changes to continuously update bookmarkable URL
  document.getElementById('ibkr-token').addEventListener('input', updateUrlParams);
  document.getElementById('ibkr-query-id').addEventListener('input', updateUrlParams);

  // Listen for local XML file upload
  const fileInput = document.getElementById('xml-file-input');
  if (fileInput) {
    fileInput.addEventListener('change', handleFileUpload);
  }
});

function updateUrlParams() {
  const token = document.getElementById('ibkr-token').value.trim();
  const queryId = document.getElementById('ibkr-query-id').value.trim();
  const url = new URL(window.location.href);

  if (token) {
    url.searchParams.set('token', token);
  } else {
    url.searchParams.delete('token');
  }

  if (queryId) {
    url.searchParams.set('queryId', queryId);
  } else {
    url.searchParams.delete('queryId');
  }

  window.history.replaceState({}, '', url.toString());
}

function toggleTokenVisibility() {
  const tokenInput = document.getElementById('ibkr-token');
  const toggleIcon = document.getElementById('toggle-token-icon');
  if (tokenInput.type === 'password') {
    tokenInput.type = 'text';
    toggleIcon.className = 'fas fa-eye-slash';
  } else {
    tokenInput.type = 'password';
    toggleIcon.className = 'fas fa-eye';
  }
}

function clearStoredCredentials() {
  localStorage.removeItem(STORAGE_KEY_TOKEN);
  localStorage.removeItem(STORAGE_KEY_QUERY_ID);
  localStorage.removeItem(STORAGE_KEY_WORKER_URL);
  document.getElementById('ibkr-token').value = '';
  document.getElementById('ibkr-query-id').value = '';
  updateUrlParams();
  showStatus('Stored credentials cleared.', 'info');
}

function showStatus(message, type = 'info', loading = false) {
  const resultsRow = document.getElementById('results-row');
  const statusAlert = document.getElementById('status-alert');
  const statusMessage = document.getElementById('status-message');
  const statusSpinner = document.getElementById('status-spinner');

  resultsRow.style.display = 'block';
  statusAlert.style.display = 'block';
  statusAlert.className = `alert alert-${type} border-0 mb-3`;
  statusMessage.textContent = message;
  statusSpinner.style.display = loading ? 'inline-block' : 'none';

  resultsRow.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

async function handleFetchTrades(event) {
  event.preventDefault();

  const token = document.getElementById('ibkr-token').value.trim();
  const queryId = document.getElementById('ibkr-query-id').value.trim();
  const workerUrl = document.getElementById('ibkr-worker-url').value.trim().replace(/\/$/, '');
  const saveCreds = document.getElementById('save-credentials-check').checked;

  if (!token || !queryId || !workerUrl) {
    showStatus('Please fill in Token, Query ID, and Worker URL.', 'danger');
    return;
  }

  updateUrlParams();

  if (saveCreds) {
    localStorage.setItem(STORAGE_KEY_TOKEN, token);
    localStorage.setItem(STORAGE_KEY_QUERY_ID, queryId);
    localStorage.setItem(STORAGE_KEY_WORKER_URL, workerUrl);
  }

  const fetchBtn = document.getElementById('fetch-btn');
  fetchBtn.disabled = true;

  showStatus('Fetching Flex Statement from IBKR via proxy worker...', 'info', true);

  const pnlContainer = document.getElementById('pnl-table-container');
  if (pnlContainer) pnlContainer.style.display = 'none';
  document.getElementById('trade-count-badge').style.display = 'none';

  try {
    let attempts = 0;
    let xmlText = '';
    const maxAttempts = 6;

    while (attempts < maxAttempts) {
      attempts++;
      const targetRequestUrl = `${workerUrl}/?token=${encodeURIComponent(token)}&queryId=${encodeURIComponent(queryId)}`;
      console.log(`[IBKR Page] Fetch attempt ${attempts}/${maxAttempts}:`, targetRequestUrl);

      if (attempts > 1) {
        showStatus(`IBKR report generation in progress (Code 1019). Waiting for IBKR... (Attempt ${attempts}/${maxAttempts})`, 'warning', true);
      } else {
        showStatus('Fetching Flex Statement from IBKR via proxy worker...', 'info', true);
      }

      const response = await fetch(targetRequestUrl);
      xmlText = await response.text();
      console.log(`[IBKR Page] Attempt ${attempts} Raw XML Response:`, xmlText);

      if (!response.ok) {
        throw new Error(`Proxy error (${response.status}): ${xmlText.slice(0, 300)}`);
      }

      if (xmlText.includes('1019') || xmlText.includes('generation in progress')) {
        if (attempts < maxAttempts) {
          console.warn(`[IBKR Page] Statement generation in progress (1019). Retrying in 4s (Attempt ${attempts}/${maxAttempts})...`);
          await new Promise(res => setTimeout(res, 4000));
          continue;
        }
      }

      break;
    }

    processAndRenderXml(null, xmlText, 'API Web Service');

  } catch (err) {
    console.error('[IBKR Page] Fetch Error:', err);
    showStatus(`Error fetching statement: ${err.message}`, 'danger');
  } finally {
    fetchBtn.disabled = false;
  }
}

async function handleFileUpload(event) {
  const file = event.target.files[0];
  if (!file) return;

  showStatus(`Reading local XML file "${file.name}"...`, 'info', true);

  try {
    const xmlText = await file.text();
    processAndRenderXml(null, xmlText, `File: ${file.name}`);
  } catch (err) {
    console.error('[IBKR Page] File Upload Error:', err);
    showStatus(`Error reading XML file: ${err.message}`, 'danger');
  }
}
window.handleFileUpload = handleFileUpload;

function processAndRenderXml(xmlDoc, xmlText, sourceLabel) {
  if (!window.parseIbkrXmlDart) {
    throw new Error('Dart JS-Interop was not loaded. Please wait a moment and try again.');
  }

  const jsonText = window.parseIbkrXmlDart(xmlText);
  const resultObject = JSON.parse(jsonText);

  if (resultObject.error) {
    throw new Error(`Dart XML Parser Error: ${resultObject.error}`);
  }

  // Update base currency dynamically from Dart
  reportBaseCurrency = resultObject.baseCurrency || 'USD';

  const queryName = resultObject.queryName || sourceLabel || 'Flex Report';
  const fromDate = formatFlexDate(resultObject.fromDate);
  const toDate = formatFlexDate(resultObject.toDate);
  const flexPeriod = resultObject.flexPeriod;
  let periodText = '';

  if (fromDate && toDate) {
    periodText = ` (Covered Period: ${fromDate} to ${toDate})`;
  } else if (flexPeriod) {
    periodText = ` (Covered Period: ${flexPeriod})`;
  }

  showStatus(`Success! Processed report "${queryName}"${periodText}. Aggregated P&L for ${resultObject.symbolsCount} underlying symbol(s) across ${resultObject.tradesCount} trade(s) and ${resultObject.openPositionsCount} position(s).`, 'success');

  document.getElementById('trade-count-badge').textContent = `${resultObject.symbolsCount} Symbol(s)`;
  document.getElementById('trade-count-badge').style.display = 'inline-block';

  renderAccountNavSummary(resultObject.accountNavSummary);
  document.getElementById('pnl-table-container').style.display = 'block';

  renderSymbolPnlTable(resultObject.perSymbolPnL);
}

function formatFlexDate(str) {
  if (!str) return '';
  if (/^\d{8}$/.exec(str)) {
    return `${str.slice(0, 4)}-${str.slice(4, 6)}-${str.slice(6, 8)}`;
  }
  return str;
}

function renderAccountNavSummary(navSummary) {
  const container = document.getElementById('account-nav-container');
  if (!container) return;

  if (!navSummary) {
    container.style.display = 'block';
    container.innerHTML = `
      <div class="alert bg-dark border border-secondary text-white-50 small mb-0 d-flex align-items-center">
        <i class="fas fa-circle-info text-info fs-5 me-3"></i>
        <div>
          <strong class="text-white">Account NAV Summary Tip:</strong> To see starting &amp; ending Account Value (NAV), total realized/unrealized P&amp;L, and cash flows in this summary, select the <strong>Change in NAV</strong> section when configuring your IBKR Flex Query.
        </div>
      </div>
    `;
    return;
  }

  container.style.display = 'block';
  const netChangeClass = navSummary.netChange > 0 ? 'pnl-positive' : (navSummary.netChange < 0 ? 'pnl-negative' : 'pnl-zero');

  container.innerHTML = `
    <div class="card bg-dark border border-secondary shadow-sm">
      <div class="card-header bg-transparent border-secondary d-flex align-items-center justify-content-between py-2">
        <h6 class="mb-0 text-white fw-bold">
          <i class="fas fa-vault me-2 text-warning"></i>Account Starting &amp; Ending State
        </h6>
        <span class="badge bg-dark border border-secondary text-info fw-normal">Base Currency</span>
      </div>
      <div class="card-body py-3">
        <div class="row text-center g-3">
          <div class="col-md-3 col-6">
            <div class="text-white-50 small text-uppercase fw-semibold mb-1">Starting Account NAV</div>
            <div class="fs-5 fw-bold text-white">${formatCurrency(navSummary.startingNAV)}</div>
          </div>
          <div class="col-md-3 col-6">
            <div class="text-white-50 small text-uppercase fw-semibold mb-1">Ending Account NAV</div>
            <div class="fs-5 fw-bold text-white">${formatCurrency(navSummary.endingNAV)}</div>
          </div>
          <div class="col-md-3 col-6">
            <div class="text-white-50 small text-uppercase fw-semibold mb-1">Total Period NAV Change</div>
            <div class="fs-5 ${netChangeClass}">${navSummary.netChange >= 0 ? '+' : ''}${formatCurrency(navSummary.netChange)}</div>
          </div>
          <div class="col-md-3 col-6">
            <div class="text-white-50 small text-uppercase fw-semibold mb-1">Period Realized P&amp;L</div>
            <div class="fs-5 ${getPnlBadgeClass(navSummary.realizedPNL)}">${formatCurrency(navSummary.realizedPNL)}</div>
          </div>
        </div>

        ${navSummary.hasChangeInNavSection ? `
          <hr class="border-secondary my-3">
          <div class="row text-center g-2 small">
            <div class="col-md-3 col-6">
              <span class="text-white-50">Unrealized P&amp;L:</span>
              <span class="${getPnlBadgeClass(navSummary.unrealizedPNL)} ms-1">${formatCurrency(navSummary.unrealizedPNL)}</span>
            </div>
            <div class="col-md-3 col-6">
              <span class="text-white-50">Deposits / Withdrawals:</span>
              <span class="text-light ms-1">${formatCurrency(navSummary.depositsWithdrawals)}</span>
            </div>
            <div class="col-md-3 col-6">
              <span class="text-white-50">Dividends (in Realized):</span>
              <span class="text-light ms-1">${formatCurrency(navSummary.dividends)}</span>
            </div>
            <div class="col-md-3 col-6">
              <span class="text-white-50">Interest:</span>
              <span class="text-light ms-1">${formatCurrency(navSummary.interest)}</span>
            </div>
          </div>
        ` : ''}
      </div>
    </div>
  `;
}

function formatCurrency(num) {
  const symbol = getCurrencySymbol(reportBaseCurrency);
  const formatted = Math.abs(num).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  if (symbol === 'CHF') {
    return (num < 0 ? '-' : '') + formatted + ' ' + symbol;
  }
  return (num < 0 ? '-' + symbol : symbol) + formatted;
}

function getPnlBadgeClass(val) {
  if (val > 0) return 'pnl-positive';
  if (val < 0) return 'pnl-negative';
  return 'pnl-zero';
}

function renderSymbolPnlTable(symbolSummaries) {
  const tableBody = document.getElementById('pnl-table-body');
  const tableFoot = document.getElementById('pnl-table-foot');
  tableBody.innerHTML = '';
  tableFoot.innerHTML = '';

  if (symbolSummaries.length === 0) {
    tableBody.innerHTML = `<tr><td colspan="7" class="text-center text-muted py-3">No underlying symbol data found in statement.</td></tr>`;
    return;
  }

  let totalRealized = 0;
  let totalDividends = 0;
  let totalUnrealized = 0;
  let grandTotal = 0;

  symbolSummaries.forEach((s, idx) => {
    totalRealized += s.realized;
    totalDividends += (s.dividends || 0);
    totalUnrealized += s.unrealized;
    grandTotal += s.total;

    const hasSubRows = s.instruments && s.instruments.length > 0;

    // Parent Roll-up Row
    const tr = document.createElement('tr');
    tr.className = `symbol-row ${hasSubRows ? 'has-subrows' : ''}`;
    tr.onclick = () => toggleSubRows(idx);

    const chevronHtml = hasSubRows
      ? `<i id="chevron-${idx}" class="fas fa-chevron-right me-2 text-warning chevron-icon"></i>`
      : `<span class="me-3"></span>`;

    tr.innerHTML = `
      <td class="fw-bold text-warning fs-6">${chevronHtml}${s.symbol} <span class="badge bg-dark border border-secondary text-info ms-2 fw-normal small">${s.instruments.length} contract(s)</span></td>
      <td class="text-center">${s.tradesCount}</td>
      <td class="text-center">${s.openPositionsCount}</td>
      <td class="text-end ${getPnlBadgeClass(s.realized)}">${formatCurrency(s.realized)}</td>
      <td class="text-end ${getPnlBadgeClass(s.dividends)}">${formatCurrency(s.dividends)}</td>
      <td class="text-end ${getPnlBadgeClass(s.unrealized)}">${formatCurrency(s.unrealized)}</td>
      <td class="text-end fs-6 ${getPnlBadgeClass(s.total)}">${formatCurrency(s.total)}</td>
    `;
    tableBody.appendChild(tr);

    // Sub-rows Container (hidden by default)
    if (hasSubRows) {
      const subTr = document.createElement('tr');
      subTr.id = `subrows-${idx}`;
      subTr.style.display = 'none';

      let subRowsHtml = `<td colspan="7" class="p-0 border-0">
        <div class="subrow-table p-2">
          <table class="table table-dark table-sm mb-0 align-middle small">
            <tbody>`;

      s.instruments.forEach(inst => {
        const assetBadge = inst.assetCategory ? `<span class="badge bg-dark border border-secondary text-white-50 ms-2">${inst.assetCategory}</span>` : '';
        subRowsHtml += `
          <tr>
            <td class="ps-4 font-monospace text-light fw-bold">${inst.symbol}${assetBadge}</td>
            <td class="text-center text-white-50">${inst.tradesCount}</td>
            <td class="text-center text-white-50">${inst.openPositionsCount > 0 ? '<span class="badge bg-success-subtle text-success border border-success-subtle px-2">Open</span>' : '-'}</td>
            <td class="text-end ${getPnlBadgeClass(inst.realized)}">${formatCurrency(inst.realized)}</td>
            <td class="text-end ${getPnlBadgeClass(inst.dividends)}">${formatCurrency(inst.dividends)}</td>
            <td class="text-end ${getPnlBadgeClass(inst.unrealized)}">${formatCurrency(inst.unrealized)}</td>
            <td class="text-end ${getPnlBadgeClass(inst.total)}">${formatCurrency(inst.total)}</td>
          </tr>
        `;
      });

      subRowsHtml += `</tbody></table></div></td>`;
      subTr.innerHTML = subRowsHtml;
      tableBody.appendChild(subTr);
    }
  });

  // Render Footer Totals Row
  tableFoot.innerHTML = `
    <tr class="table-dark">
      <td colspan="3" class="text-uppercase text-white-50">Total Portfolio P&amp;L Summary:</td>
      <td class="text-end ${getPnlBadgeClass(totalRealized)}">${formatCurrency(totalRealized)}</td>
      <td class="text-end ${getPnlBadgeClass(totalDividends)}">${formatCurrency(totalDividends)}</td>
      <td class="text-end ${getPnlBadgeClass(totalUnrealized)}">${formatCurrency(totalUnrealized)}</td>
      <td class="text-end fs-6 ${getPnlBadgeClass(grandTotal)}">${formatCurrency(grandTotal)}</td>
    </tr>
  `;
}

function toggleSubRows(idx) {
  const subRow = document.getElementById(`subrows-${idx}`);
  const chevron = document.getElementById(`chevron-${idx}`);
  if (!subRow) return;

  if (subRow.style.display === 'none' || subRow.style.display === '') {
    subRow.style.display = 'table-row';
    if (chevron) chevron.classList.add('chevron-expanded');
  } else {
    subRow.style.display = 'none';
    if (chevron) chevron.classList.remove('chevron-expanded');
  }
}
window.toggleSubRows = toggleSubRows;

window.jsMainIbkr = function() {
  console.log("Dart JS-Interop for IBKR loaded successfully.");
};
