document.addEventListener("DOMContentLoaded", async () => {
  if (typeof CHURN_DATA === "undefined") {
    console.error("CHURN_DATA payload not loaded!");
    return;
  }

  // Internationalization (i18n) setup
  const defaultGreekDOMContent = {};
  const defaultGreekAttrContent = {};

  document.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    defaultGreekDOMContent[key] = el.innerHTML;
  });
  document.querySelectorAll("[data-i18n-attr]").forEach(el => {
    const attrConfig = el.getAttribute("data-i18n-attr");
    const [attr, key] = attrConfig.split(":");
    defaultGreekAttrContent[attrConfig] = el.getAttribute(attr);
  });

  const GREEK_DEFAULTS = {
    "trades_suffix": "συναλλαγές",
    "kpi_daily_trades_title": "Μέσο Πλήθος Συναλλαγών Ανά Μέρα",
    "kpi_daily_trades_sub": "Μέσος αριθμός εκτελεσμένων συναλλαγών ανά εργάσιμη ημέρα ανά πελάτη",
    "kpi_monthly_comm_title": "Μέσες Προμήθειες Ανά Μήνα / Πελάτη",
    "kpi_monthly_comm_sub": "Μέσες μηνιαίες προμήθειες ανά πελάτη",
    "per_trade_day_format": "(${avgComm}/συν · ${dailyComm}/ημ)",
    "quantile_empty": "Δεν βρέθηκαν θέσεις με τα τρέχοντα κριτήρια φίλτρου.",
    "quantile_q0": "Q0 (Μεγαλύτερη Ζημία / Ελάχιστο)",
    "quantile_q1": "Q1 (25ο Ποσοστημόριο)",
    "quantile_q2": "Q2 (50ο % / ΔΙΑΜΕΣΟΣ)",
    "quantile_q3": "Q3 (75ο Ποσοστημόριο)",
    "quantile_q4": "Q4 (Μέγιστο Κέρδος)",
    "chart_legend_gross_pnl": "PnL Πριν Από Προμήθειες",
    "chart_legend_commissions": "Προμήθειες",
    "chart_legend_net_pnl": "PnL Μετά Από Προμήθειες",
    "stat_days": "Ημέρες",
    "badge_flat_closed": "ΚΛΕΙΣΤΗ / FLAT",
    "badge_active_open": "ΕΝΕΡΓΗ / ΑΝΟΙΧΤΗ",
    "badge_forced_liquidation": "🚨 ΑΝΑΓΚΑΣΤΙΚΗ ΡΕΥΣΤΟΠΟΙΗΣΗ MARGIN",
    "strategy_campaign": "",
    "leg_executions": "εκτέλεση(εις) σκελών",
    "stat_opened_closed": "Άνοιγμα / Κλείσιμο",
    "stat_hold_duration": "Διάρκεια Διακράτησης",
    "stat_gross_pnl": "Μικτό PnL",
    "stat_campaign_comm": "Προμήθειες",
    "stat_net_campaign_pnl": "Καθαρό PnL",
    "stat_executions_in_campaign": "Συναλλαγές: {count}",
    "btn_inspect_executions": "Επιθεώρηση Εκτελέσεων Statement ▼",
    "th_source_file": "Πηγή (Σελίδα)",
    "th_execution_datetime": "Ημερομηνία/Ώρα Εκτέλεσης",
    "th_symbol": "Σύμβολο",
    "th_type": "Τύπος",
    "th_qty": "Ποσότητα",
    "th_price": "Τιμή",
    "th_comm": "Προμήθεια",
    "th_proceeds": "Εισπράξεις/Πληρωμές",
    "th_code": "Κωδικός",
    "tfoot_statement_totals": "Σύνολα Statement:",
    "tfoot_total": "Σύνολο:",
    "btn_showing_positions": "Εμφάνιση {current} από {total} Θέσεις — Φόρτωση Περισσότερων (+100) ▼"
  };

  let currentLang = localStorage.getItem("app_lang") || "el";
  let i18nDict = {};

  async function loadLanguage(lang) {
    if (lang === "el") {
      i18nDict = {};
      currentLang = "el";
      localStorage.setItem("app_lang", "el");
      return;
    }
    try {
      const res = await fetch(`i18n/${lang}.json`);
      if (res.ok) {
        i18nDict = await res.json();
        currentLang = lang;
        localStorage.setItem("app_lang", lang);
      }
    } catch (e) {
      console.warn(`Could not load i18n translation dictionary for ${lang}`, e);
    }
  }

  function t(key, defaultVal, vars = {}) {
    let text = i18nDict[key] || (currentLang === "el" ? GREEK_DEFAULTS[key] : null) || defaultVal || key;
    Object.keys(vars).forEach(k => {
      text = text.replace(new RegExp(`\\{${k}\\}`, "g"), vars[k]);
    });
    return text;
  }

  function applyDOMTranslations() {
    document.querySelectorAll("[data-i18n]").forEach(el => {
      const key = el.getAttribute("data-i18n");
      if (currentLang === "el") {
        if (defaultGreekDOMContent[key]) el.innerHTML = defaultGreekDOMContent[key];
      } else if (i18nDict[key]) {
        el.innerHTML = i18nDict[key];
      }
    });
    document.querySelectorAll("[data-i18n-attr]").forEach(el => {
      const attrConfig = el.getAttribute("data-i18n-attr");
      const [attr, key] = attrConfig.split(":");
      if (currentLang === "el") {
        if (defaultGreekAttrContent[attrConfig]) el.setAttribute(attr, defaultGreekAttrContent[attrConfig]);
      } else if (i18nDict[key]) {
        el.setAttribute(attr, i18nDict[key]);
      }
    });

    // Update active flag button styling
    document.querySelectorAll(".lang-btn").forEach(btn => {
      if (btn.getAttribute("data-lang") === currentLang) {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    });
  }

  await loadLanguage(currentLang);
  applyDOMTranslations();

  // Attach language switcher click handlers
  document.querySelectorAll(".lang-btn").forEach(btn => {
    btn.addEventListener("click", async () => {
      const targetLang = btn.getAttribute("data-lang");
      if (targetLang !== currentLang) {
        await loadLanguage(targetLang);
        applyDOMTranslations();
        render();
      }
    });
  });

  const data = CHURN_DATA;
  let chartCumulative = null;
  let chartAssetClass = null;

  let currentLimit = 100; // Load 100 at a time

  // 1. Initialize Control Dropdowns
  const acctSelect = document.getElementById("select-account");
  const assetSelect = document.getElementById("select-asset");
  const undSelect = document.getElementById("select-underlying");
  const sortSelect = document.getElementById("select-sort");
  const flagSelect = document.getElementById("select-flag");
  const searchInput = document.getElementById("search-input");

  // Populate Accounts
  const accts = Object.keys(data.metrics.accounts).sort();
  accts.forEach(a => {
    const opt = document.createElement("option");
    opt.value = a;
    opt.textContent = a;
    acctSelect.appendChild(opt);
  });

  // Populate Underlyings
  data.metrics.underlyings.forEach(u => {
    const opt = document.createElement("option");
    opt.value = u.underlying;
    opt.textContent = `${u.underlying} (${u.positions_count} ${t("trades_suffix", "trades")})`;
    undSelect.appendChild(opt);
  });

  // 2. Filter Handler
  function getFilteredPositions() {
    const selectedAcct = acctSelect.value;
    const selectedAsset = assetSelect.value;
    const selectedUnd = undSelect.value;
    const selectedFlag = flagSelect ? flagSelect.value : "ALL";
    const sortVal = sortSelect ? sortSelect.value : "COMM_DAY_DESC";
    const q = searchInput.value.toLowerCase().trim();

    const filtered = data.positions.filter(p => {
      if (selectedAcct !== "ALL" && p.account !== selectedAcct) return false;
      if (selectedAsset !== "ALL" && p.asset_class !== selectedAsset) return false;
      if (selectedUnd !== "ALL" && p.underlying !== selectedUnd) return false;
      
      if (selectedFlag === "LIQUIDATION" && p.has_liquidation !== 1) return false;
      if (selectedFlag === "EXERCISE" && p.has_exercise !== 1 && p.has_assignment !== 1) return false;

      if (q) {
        const matchesSym = p.symbol.toLowerCase().includes(q);
        const matchesUnd = p.underlying.toLowerCase().includes(q);
        const matchesAcct = p.account.toLowerCase().includes(q);
        const matchesCode = p.raw_trades.some(t => t.code.toLowerCase().includes(q));
        const matchesLiq = (q === "l" || q === "liquidation") && p.has_liquidation === 1;
        if (!matchesSym && !matchesUnd && !matchesAcct && !matchesCode && !matchesLiq) return false;
      }
      return true;
    });

    filtered.sort((a, b) => {
      if (sortVal === "AVG_COMM_DESC") {
        const avgA = a.raw_trades.length > 0 ? (a.total_comm_fee / a.raw_trades.length) : 0;
        const avgB = b.raw_trades.length > 0 ? (b.total_comm_fee / b.raw_trades.length) : 0;
        return avgB - avgA;
      }
      if (sortVal === "COMM_DAY_DESC") {
        const daysA = Math.max(1.0, a.hold_duration_hours / 24.0);
        const daysB = Math.max(1.0, b.hold_duration_hours / 24.0);
        const rateA = a.total_comm_fee / daysA;
        const rateB = b.total_comm_fee / daysB;
        return rateB - rateA;
      }
      if (sortVal === "COMM_DESC") return b.total_comm_fee - a.total_comm_fee;
      if (sortVal === "LOSS_DESC") return a.net_realized_pl - b.net_realized_pl;
      if (sortVal === "GAIN_DESC") return b.net_realized_pl - a.net_realized_pl;
      if (sortVal === "QTY_DESC") return b.quantity - a.quantity;
      if (sortVal === "FAST_ASC") return a.hold_duration_hours - b.hold_duration_hours;
      return b.open_date_time.localeCompare(a.open_date_time);
    });

    return filtered;
  }

  // 3. Render Dashboard
  function render() {
    const filteredPositions = getFilteredPositions();
    
    // Recalculate KPIs for filtered set
    let totComm = 0;
    let grossPnL = 0;
    let netPnL = 0;

    let totalHoldHours = 0;
    const seenTradeIds = new Set();
    const acctStats = {}; // accountName -> { comm, trades, weekdayDates: Set, months: Set }

    filteredPositions.forEach(p => {
      totComm += p.total_comm_fee;
      grossPnL += p.gross_realized_pl;
      netPnL += p.net_realized_pl;
      totalHoldHours += p.hold_duration_hours;

      const acctName = p.account || "UNKNOWN";
      if (!acctStats[acctName]) {
        acctStats[acctName] = { comm: 0, trades: 0, weekdayDates: new Set(), months: new Set() };
      }
      acctStats[acctName].comm += p.total_comm_fee;

      if (p.raw_trades) {
        p.raw_trades.forEach(t => {
          const tAcct = t.account || acctName;
          if (!acctStats[tAcct]) {
            acctStats[tAcct] = { comm: 0, trades: 0, weekdayDates: new Set(), months: new Set() };
          }

          if (t.id && seenTradeIds.has(t.id)) return;
          if (t.id) seenTradeIds.add(t.id);

          if (t.date_time) {
            const datePart = t.date_time.split(" ")[0];
            const parts = datePart.split("-");
            if (parts.length === 3) {
              const monthStr = parts[0] + "-" + parts[1];
              acctStats[tAcct].months.add(monthStr);

              const year = parseInt(parts[0], 10);
              const month = parseInt(parts[1], 10) - 1;
              const day = parseInt(parts[2], 10);
              const dt = new Date(Date.UTC(year, month, day));
              const dayOfWeek = dt.getUTCDay(); // 0 = Sun, 1 = Mon, ..., 5 = Fri, 6 = Sat
              if (dayOfWeek >= 1 && dayOfWeek <= 5) {
                acctStats[tAcct].trades++;
                acctStats[tAcct].weekdayDates.add(datePart);
              }
            }
          }
        });
      }
    });

    const posCount = filteredPositions.length;
    const avgTradePnL = posCount > 0 ? (netPnL / posCount) : 0;
    const formattedAvgTradePnL = (avgTradePnL >= 0 ? '+' : '') + '$' + avgTradePnL.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});

    const activeAccounts = Object.keys(acctStats);
    const numCustomers = activeAccounts.length > 0 ? activeAccounts.length : 1;

    let sumMonthlyCommRate = 0;
    let sumDailyTradeRate = 0;

    activeAccounts.forEach(acct => {
      const st = acctStats[acct];
      const mCount = st.months.size > 0 ? st.months.size : 1;
      const dCount = st.weekdayDates.size > 0 ? st.weekdayDates.size : 1;

      sumMonthlyCommRate += (st.comm / mCount);
      sumDailyTradeRate += (st.trades / dCount);
    });

    const avgDailyTradesPerCustomer = activeAccounts.length > 0 ? (sumDailyTradeRate / numCustomers) : 0;
    const formattedAvgDailyTrades = avgDailyTradesPerCustomer.toLocaleString('en-US', {minimumFractionDigits: 1, maximumFractionDigits: 2});

    const avgMonthlyCommPerCustomer = activeAccounts.length > 0 ? (sumMonthlyCommRate / numCustomers) : 0;
    const formattedAvgMonthlyComm = `$${avgMonthlyCommPerCustomer.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;

    // Update KPI Elements
    document.getElementById("kpi-comm").textContent = `$${totComm.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    document.getElementById("kpi-gross-pnl").textContent = `$${grossPnL.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById("kpi-gross-pnl").className = `kpi-value ${grossPnL >= 0 ? 'success' : 'danger'}`;

    document.getElementById("kpi-net-pnl").textContent = `$${netPnL.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById("kpi-net-pnl").className = `kpi-value ${netPnL >= 0 ? 'success' : 'danger'}`;

    document.getElementById("kpi-expectancy").textContent = formattedAvgTradePnL;
    document.getElementById("kpi-expectancy").className = `kpi-value ${avgTradePnL >= 0 ? 'success' : 'danger'}`;

    const dailyTradesEl = document.getElementById("kpi-daily-trades");
    if (dailyTradesEl) {
      dailyTradesEl.textContent = formattedAvgDailyTrades;
      dailyTradesEl.className = "kpi-value brand";
    }

    const monthlyCommEl = document.getElementById("kpi-monthly-comm");
    if (monthlyCommEl) {
      monthlyCommEl.textContent = formattedAvgMonthlyComm;
      monthlyCommEl.className = "kpi-value danger";
    }

    // Render 5-Quantile Distribution
    renderQuantiles(filteredPositions);

    // Render Charts
    renderCharts(filteredPositions);

    // Render Account Table
    renderAccountTable();

    // Render Positions Grid
    renderPositionsGrid(filteredPositions);
  }

  // 3b. Render 5-Quantile Distribution
  function renderQuantiles(positions) {
    const container = document.getElementById("quantile-list-container");
    if (!container) return;
    container.innerHTML = "";

    if (positions.length === 0) {
      container.innerHTML = `<div class='app-subtitle' style='padding:12px;'>${t("quantile_empty", "No positions match current filter criteria.")}</div>`;
      return;
    }

    // Extract net_realized_pl values sorted ASC
    const pnls = positions.map(p => p.net_realized_pl).sort((a, b) => a - b);
    const n = pnls.length;

    const quantiles = [];
    const labels = [
      t("quantile_q0", "Q0 (Worst Loss / Min)"),
      t("quantile_q1", "Q1 (25th Percentile)"),
      t("quantile_q2", "Q2 (50th % / MEDIAN)"),
      t("quantile_q3", "Q3 (75th Percentile)"),
      t("quantile_q4", "Q4 (Max Gain)")
    ];

    for (let i = 0; i < 5; i++) {
      const idx = Math.min(n - 1, Math.floor((i / 4) * (n - 1)));
      quantiles.push(pnls[idx]);
    }

    const maxAbs = Math.max(...quantiles.map(v => Math.abs(v)), 1);

    quantiles.forEach((val, idx) => {
      const row = document.createElement("div");
      row.className = `quantile-row ${idx === 2 ? 'median-row' : ''}`;

      const pctWidth = Math.min(100, Math.max(3, (Math.abs(val) / maxAbs) * 100));
      const barColor = val >= 0 ? "linear-gradient(90deg, #10b981, #34d399)" : "linear-gradient(90deg, #f43f5e, #fb7185)";
      const valColor = val >= 0 ? "success" : "danger";
      const formattedVal = (val >= 0 ? "+" : "") + "$" + val.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2});

      row.innerHTML = `
        <div class="quantile-name">${labels[idx]}</div>
        <div class="quantile-bar-bg">
          <div class="quantile-bar-fill" style="width: ${pctWidth}%; background: ${barColor};"></div>
        </div>
        <div class="quantile-val ${valColor}">${formattedVal}</div>
      `;
      container.appendChild(row);
    });
  }

  function renderCharts(positions) {
    const getEffectiveDate = p => (p.is_flat && p.close_date_time && p.close_date_time !== "ACTIVE / OPEN") ? p.close_date_time : p.open_date_time;
    
    // Sort chronologically by effective date, then by campaign id to ensure deterministic order
    const sorted = [...positions].sort((a, b) => {
      const dtA = getEffectiveDate(a);
      const dtB = getEffectiveDate(b);
      const cmp = dtA.localeCompare(dtB);
      if (cmp !== 0) return cmp;
      return a.id - b.id;
    });
    
    let cumComm = 0;
    let cumGrossPnL = 0;
    let cumNetPnL = 0;
    const labels = [];
    const commData = [];
    const grossPnLData = [];
    const netPnLData = [];

    const step = Math.max(1, Math.floor(sorted.length / 30));

    sorted.forEach((p, idx) => {
      cumComm += p.total_comm_fee;
      cumGrossPnL += p.gross_realized_pl;
      cumNetPnL += p.net_realized_pl;
      if (idx % step === 0 || idx === sorted.length - 1) {
        labels.push(getEffectiveDate(p).split(" ")[0]);
        commData.push(-cumComm); // Negative sign from client perspective
        grossPnLData.push(cumGrossPnL);
        netPnLData.push(cumNetPnL);
      }
    });

    const ctx1 = document.getElementById("chart-cumulative").getContext("2d");
    if (chartCumulative) chartCumulative.destroy();

    chartCumulative = new Chart(ctx1, {
      type: "line",
      data: {
        labels: labels,
        datasets: [
          {
            label: t("chart_legend_gross_pnl", "PnL Before Commissions"),
            data: grossPnLData,
            borderColor: "#38bdf8",
            backgroundColor: "rgba(56, 189, 248, 0.05)",
            fill: false,
            tension: 0.3
          },
          {
            label: t("chart_legend_commissions", "Commissions"),
            data: commData,
            borderColor: "#f43f5e",
            backgroundColor: "rgba(244, 63, 94, 0.1)",
            fill: true,
            tension: 0.3
          },
          {
            label: t("chart_legend_net_pnl", "PnL After Commissions"),
            data: netPnLData,
            borderColor: "#a855f7",
            backgroundColor: "rgba(168, 85, 247, 0.1)",
            fill: true,
            tension: 0.3
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            labels: {
              color: "#cbd5e1",
              font: { size: 13, weight: "600", family: "Inter, sans-serif" }
            }
          }
        },
        scales: {
          x: {
            ticks: {
              color: "#94a3b8",
              font: { size: 12, weight: "600", family: "Inter, sans-serif" }
            },
            grid: { color: "rgba(255,255,255,0.06)" }
          },
          y: {
            ticks: {
              color: "#94a3b8",
              font: { size: 12, weight: "600", family: "Inter, sans-serif" },
              callback: function(value) {
                const sign = value < 0 ? "-" : "";
                return sign + "$" + Math.abs(value).toLocaleString('en-US');
              }
            },
            grid: { color: "rgba(255,255,255,0.06)" }
          }
        }
      }
    });

    // Chart 2: Asset Class Breakdown
    const assetTotals = {};
    positions.forEach(p => {
      assetTotals[p.asset_class] = (assetTotals[p.asset_class] || 0) + p.total_comm_fee;
    });

    const ctx2 = document.getElementById("chart-asset-class").getContext("2d");
    if (chartAssetClass) chartAssetClass.destroy();

    chartAssetClass = new Chart(ctx2, {
      type: "doughnut",
      data: {
        labels: Object.keys(assetTotals),
        datasets: [{
          data: Object.values(assetTotals),
          backgroundColor: ["#6366f1", "#10b981", "#f59e0b", "#06b6d4", "#ec4899"]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: "right", labels: { color: "#94a3b8" } } }
      }
    });
  }

  // 5. Render Accounts Table
  function renderAccountTable() {
    const tbody = document.getElementById("table-accounts-body");
    tbody.innerHTML = "";

    Object.values(data.metrics.accounts).forEach(a => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td><strong>${a.account}</strong></td>
        <td>${a.total_trades}</td>
        <td>$${a.total_commissions.toLocaleString('en-US', {minimumFractionDigits: 2})}</td>
        <td class="${a.gross_realized_pl >= 0 ? 'success' : 'danger'}">$${a.gross_realized_pl.toLocaleString('en-US', {minimumFractionDigits: 2})}</td>
        <td class="${a.net_realized_pl >= 0 ? 'success' : 'danger'}"><strong>$${a.net_realized_pl.toLocaleString('en-US', {minimumFractionDigits: 2})}</strong></td>
        <td>${(a.avg_hold_hours / 24).toFixed(1)} ${t("stat_days", "Days")}</td>
      `;
      tbody.appendChild(tr);
    });
  }

  // 6. Render Position Lifecycles Grid (With Load More Pagination)
  function renderPositionsGrid(positions) {
    const container = document.getElementById("positions-container");
    container.innerHTML = "";

    const displayPos = positions.slice(0, currentLimit);

    displayPos.forEach(p => {
      const card = document.createElement("div");
      card.className = "position-card";
      
      const badgeClass = p.asset_class === "Options" ? "badge-options" : (p.asset_class === "Stocks" ? "badge-stocks" : "badge-futures");
      const holdDays = (p.hold_duration_hours / 24).toFixed(1);

      const statusBadgeHtml = p.is_closed
        ? `<span class="badge" style="background:rgba(16,185,129,0.15); color:#10b981; border:1px solid #10b981;">${t("badge_flat_closed", "FLAT / CLOSED")}</span>`
        : `<span class="badge" style="background:rgba(56,189,248,0.15); color:#38bdf8; border:1px solid #38bdf8;">${t("badge_active_open", "ACTIVE / OPEN")}</span>`;

      const liqBadgeHtml = p.has_liquidation === 1 
        ? `<span class="badge" style="background:rgba(244,63,94,0.3); color:#f43f5e; border:1px solid #f43f5e; font-weight:800;">${t("badge_forced_liquidation", "🚨 FORCED MARGIN LIQUIDATION")}</span>` 
        : ``;

      let rawRowsHtml = "";
      let totalProceeds = 0;
      let totalComm = 0;

      p.raw_trades.forEach(t => {
        totalProceeds += t.proceeds;
        totalComm += t.comm_fee;

        const isLiqRow = t.code.includes("L") ? "style='background:rgba(244,63,94,0.15);'" : "";
        rawRowsHtml += `
          <tr ${isLiqRow}>
            <td>${t.file} (p.${t.page})</td>
            <td>${t.date_time}</td>
            <td><strong>${t.symbol}</strong></td>
            <td><span class="badge ${t.buy_sell === 'BUY' ? 'badge-stocks' : 'badge-options'}">${t.buy_sell}</span></td>
            <td>${t.quantity}</td>
            <td>$${t.trade_price}</td>
            <td>$${t.comm_fee.toFixed(2)}</td>
            <td>$${t.proceeds.toFixed(2)}</td>
            <td><code>${t.code}</code></td>
          </tr>
        `;
      });

      const totalNetCash = totalProceeds - totalComm;
      const avgCommTrade = p.raw_trades.length > 0 ? (p.total_comm_fee / p.raw_trades.length).toFixed(2) : "0.00";
      const dailyCommRate = (p.total_comm_fee / Math.max(1.0, p.hold_duration_hours / 24.0)).toFixed(2);
      const perTradeDayStr = t("per_trade_day_format", "(${avgComm}/trd · ${dailyComm}/day)", { avgComm: avgCommTrade, dailyComm: dailyCommRate });

      card.innerHTML = `
        <div class="position-header">
          <div class="position-sym">
            <span style="font-size:18px; font-weight:800; color:#fff;">${p.underlying}${t("strategy_campaign", "") ? ' ' + t("strategy_campaign", "") : ''}</span>
            <span class="badge ${badgeClass}">${p.asset_class}</span>
            ${statusBadgeHtml}
            ${liqBadgeHtml}
            <span class="stat-label">${p.leg_count} ${t("leg_executions", "leg execution(s)")}</span>
          </div>
          <div>
            <span class="stat-label" style="font-weight:700; color:#cbd5e1;">${p.account}</span>
          </div>
        </div>

        <div class="position-stats">
          <div class="stat-item">
            <span class="stat-label">${t("stat_opened_closed", "Opened / Closed")}</span>
            <span class="stat-value" style="font-size:12px;">${p.open_date_time} → ${p.close_date_time}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">${t("stat_hold_duration", "Hold Duration")}</span>
            <span class="stat-value">${holdDays} ${t("stat_days", "Days")} (${p.hold_duration_hours.toFixed(1)}h)</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">${t("stat_gross_pnl", "Gross PnL")}</span>
            <span class="stat-value ${p.gross_realized_pl >= 0 ? 'success' : 'danger'}">$${p.gross_realized_pl.toFixed(2)}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">${t("stat_campaign_comm", "Commissions")}</span>
            <span class="stat-value danger">$${p.total_comm_fee.toFixed(2)} <span style="font-size:11px; opacity:0.85;">${perTradeDayStr}</span></span>
          </div>
          <div class="stat-item">
            <span class="stat-label">${t("stat_net_campaign_pnl", "Net PnL")}</span>
            <span class="stat-value ${p.net_realized_pl >= 0 ? 'success' : 'danger'}"><strong>$${p.net_realized_pl.toFixed(2)}</strong></span>
          </div>
        </div>

        <div style="display:flex; justify-content:space-between; align-items:center;">
          <span class="stat-label">${t("stat_executions_in_campaign", "Trades: {count}", { count: p.raw_trades.length })}</span>
          <button class="btn-inspect" onclick="toggleRawTrades('raw-${p.id}')">${t("btn_inspect_executions", "Inspect Statement Executions ▼")}</button>
        </div>

        <div id="raw-${p.id}" class="raw-trades-table">
          <table class="data-table">
            <thead>
              <tr>
                <th>${t("th_source_file", "Source (Page)")}</th>
                <th>${t("th_execution_datetime", "Execution Date/Time")}</th>
                <th>${t("th_symbol", "Symbol")}</th>
                <th>${t("th_type", "Type")}</th>
                <th>${t("th_qty", "Qty")}</th>
                <th>${t("th_price", "Price")}</th>
                <th>${t("th_comm", "Comm")}</th>
                <th>${t("th_proceeds", "Proceeds")}</th>
                <th>${t("th_code", "Code")}</th>
              </tr>
            </thead>
            <tbody>
              ${rawRowsHtml}
            </tbody>
            <tfoot>
              <tr style="font-weight:bold; background:rgba(255,255,255,0.04);">
                <td colspan="6" style="text-align:right;">${t("tfoot_statement_totals", "Statement Totals:")}</td>
                <td class="danger">$${totalComm.toFixed(2)}</td>
                <td class="${totalProceeds >= 0 ? 'success' : 'danger'}">$${totalProceeds.toFixed(2)}</td>
                <td style="white-space:nowrap;">
                  ${t("tfoot_total", "Total:")} <strong class="${totalNetCash >= 0 ? 'success' : 'danger'}">$${totalNetCash.toFixed(2)}</strong>
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      `;

      container.appendChild(card);
    });

    // Add Load More Button if positions remain
    if (positions.length > currentLimit) {
      const loadBtnDiv = document.createElement("div");
      loadBtnDiv.style.textAlign = "center";
      loadBtnDiv.style.margin = "20px 0";
      const btnText = t("btn_showing_positions", "Showing {current} of {total} Positions — Load More (+100) ▼", {
        current: currentLimit,
        total: positions.length
      });
      loadBtnDiv.innerHTML = `
        <button id="btn-load-more" class="btn-inspect" style="padding: 12px 24px; font-size:14px;">
          ${btnText}
        </button>
      `;
      container.appendChild(loadBtnDiv);

      document.getElementById("btn-load-more").addEventListener("click", () => {
        currentLimit += 100;
        renderPositionsGrid(positions);
      });
    }
  }

  // Event Listeners
  acctSelect.addEventListener("change", () => { currentLimit = 100; render(); });
  assetSelect.addEventListener("change", () => { currentLimit = 100; render(); });
  undSelect.addEventListener("change", () => { currentLimit = 100; render(); });
  if (sortSelect) sortSelect.addEventListener("change", () => { currentLimit = 100; render(); });
  if (flagSelect) flagSelect.addEventListener("change", () => { currentLimit = 100; render(); });
  searchInput.addEventListener("input", () => { currentLimit = 100; render(); });

  // Global Toggle Function for Raw Trades
  window.toggleRawTrades = function(id) {
    const el = document.getElementById(id);
    if (el) {
      el.classList.toggle("active");
    }
  };

  // Initial Render
  render();
});

