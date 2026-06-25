<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    String username = (String) session.getAttribute("username");
    if (username == null) username = "User";
%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Paper Trading | LivePriceTracker</title>
  <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Poppins', sans-serif; }

    body { display: flex; height: 100vh; background: #f5f6fa; color: #333; }

    /* ── Sidebar ── */
    .sidebar {
      width: 250px; background: #1e1e2f; color: #fff;
      display: flex; flex-direction: column; padding: 20px;
      flex-shrink: 0;
    }
    .sidebar h2 { text-align: center; margin-bottom: 30px; font-size: 22px; }
    .sidebar a {
      color: #bbb; text-decoration: none; padding: 12px 15px;
      border-radius: 8px; margin-bottom: 10px; transition: 0.3s;
    }
    .sidebar a:hover, .sidebar a.active { background: #4b4b6e; color: #fff; }

    /* ── Main ── */
    .main-content { flex: 1; padding: 24px; overflow-y: auto; }
    h1 { margin-bottom: 20px; font-size: 22px; color: #1e1e2f; }

    .trade-section {
      display: grid;
      grid-template-columns: 2fr 1fr;
      gap: 20px;
    }

    .card {
      background: #fff; border-radius: 12px;
      padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);
    }

    /* ── Chart ── */
    #priceChart { width: 100%; height: 360px; border-radius: 8px; }

    .chart-header {
      display: flex; justify-content: space-between;
      align-items: center; margin-bottom: 12px;
    }
    .chart-header h3 { font-size: 16px; color: #1e1e2f; }

    .symbol-badge {
      background: #4b4b6e; color: #fff;
      padding: 4px 14px; border-radius: 20px;
      font-size: 13px; font-weight: 600;
    }

    /* ── Live price ticker ── */
    .price-ticker {
      display: flex; align-items: baseline; gap: 10px;
      margin-bottom: 16px;
    }
    .price-main {
      font-size: 34px; font-weight: 700; color: #1e1e2f;
      transition: color 0.3s;
    }
    .price-main.up   { color: #00c087; }
    .price-main.down { color: #ff4b4b; }

    .price-change {
      font-size: 14px; font-weight: 600; padding: 3px 10px;
      border-radius: 12px;
    }
    .price-change.up   { background: #e6faf4; color: #00c087; }
    .price-change.down { background: #ffeaea; color: #ff4b4b; }

    /* ── Balance ── */
    .balance-card {
      background: linear-gradient(135deg, #1e1e2f, #4b4b6e);
      color: #fff; border-radius: 10px;
      padding: 14px 16px; margin-bottom: 16px;
    }
    .balance-label { font-size: 11px; opacity: 0.7; text-transform: uppercase; letter-spacing: 0.5px; }
    .balance-value { font-size: 24px; font-weight: 700; margin-top: 4px; }

    /* ── Holdings ── */
    .holdings-card {
      background: #f8f9ff; border-radius: 10px;
      padding: 12px 14px; margin-bottom: 16px;
      border: 1px solid #e8e8f0;
    }
    .holdings-label { font-size: 11px; color: #999; text-transform: uppercase; }
    .holdings-value { font-size: 16px; font-weight: 600; color: #4b4b6e; margin-top: 4px; }

    /* ── Trade controls ── */
    .trade-controls { display: flex; flex-direction: column; gap: 12px; }

    .qty-row { display: flex; gap: 8px; align-items: center; }
    .qty-row label { font-size: 13px; color: #666; white-space: nowrap; }
    .qty-row input {
      flex: 1; padding: 10px 12px; border-radius: 8px;
      border: 1px solid #ddd; font-size: 15px; outline: none;
    }
    .qty-row input:focus { border-color: #4b4b6e; }

    .cost-preview {
      background: #f0f0f8; border-radius: 8px;
      padding: 8px 12px; font-size: 13px; color: #555;
    }
    .cost-preview span { font-weight: 700; color: #1e1e2f; }

    .trade-btns { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .buy-btn  { background: #00c087; color: #fff; padding: 12px; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; transition: 0.2s; }
    .sell-btn { background: #ff4b4b; color: #fff; padding: 12px; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; transition: 0.2s; }
    .buy-btn:hover  { background: #00a875; }
    .sell-btn:hover { background: #e03030; }

    .msg-box { border-radius: 8px; padding: 10px 14px; font-size: 13px; font-weight: 500; }
    .msg-box.success { background: #e6faf4; color: #00875a; }
    .msg-box.error   { background: #ffeaea; color: #cc2200; }

    /* ── Order log ── */
    .order-log {
      margin-top: 22px; background: #fff;
      border-radius: 12px; padding: 18px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      max-height: 260px; overflow-y: auto;
    }
    .order-log h3 { margin-bottom: 12px; font-size: 15px; }

    .log-entry {
      display: flex; justify-content: space-between;
      border-bottom: 1px solid #f0f0f0;
      padding: 8px 0; font-size: 13px;
    }
    .log-entry .tag {
      padding: 2px 10px; border-radius: 10px;
      font-weight: 600; font-size: 11px; text-transform: uppercase;
    }
    .log-entry.buy  .tag { background: #e6faf4; color: #00875a; }
    .log-entry.sell .tag { background: #ffeaea; color: #cc2200; }

    @media(max-width: 900px) {
      .trade-section { grid-template-columns: 1fr; }
      .sidebar { display: none; }
    }
  </style>
</head>
<body>

<div class="sidebar">
  <a href="dashboard.jsp">Dashboard</a>
  <a href="index.jsp">Search Stocks</a>
  <a href="paperTrading.jsp" class="active">Practice Trading</a>
  <a href="profile.jsp">Profile</a>
  <a href="TradeHistory.jsp">Trade History</a>
  <a href="chat.jsp">Chat Assistant</a>
  <a href="settings.jsp">Settings</a>
  <form action="LogoutServlet" method="post" style="margin-top:auto;">
    <button type="submit" style="width:100%;padding:12px;background:#dc3545;color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:600;">Logout</button>
  </form>
</div>

<div class="main-content">
  <h1>📊 Paper Trading — Welcome, <%= username %></h1>

  <div class="trade-section">

    <!-- ── Left: Chart ── -->
    <div class="card">
      <div class="chart-header">
        <h3>Live Price Simulation</h3>
        <span class="symbol-badge" id="symbolBadge">—</span>
      </div>
      <div id="priceChart"></div>
      
      
      <!-- ── Strategy Description Panel ── -->
	<div id="strategyInfo" style="display:none; margin-top:16px; padding:16px 20px;
	     background:#f8f9ff; border:1px solid #e0e4f0; border-radius:12px;
	     border-left:4px solid #4b4b6e;">
	
	    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:10px;">
	        <span id="strategyInfoTitle" style="font-size:15px; font-weight:700; color:#2d2d5e;"></span>
	        <span id="strategyInfoBadge" style="font-size:11px; font-weight:600; padding:3px 10px;
	              border-radius:20px; background:#4b4b6e; color:#fff;"></span>
	    </div>
	
	    <p id="strategyInfoDesc" style="font-size:13px; color:#555; line-height:1.7; margin:0 0 12px 0;"></p>
	
	    <div id="strategyInfoDetails" style="display:grid; grid-template-columns:1fr 1fr; gap:10px;"></div>
	
	    <div style="margin-top:12px; padding:10px 14px; background:#fff8e6; border-radius:8px;
	         border-left:3px solid #f5a623;">
	        <span style="font-size:12px; color:#a06000;">
	            💡 <strong>When to use:</strong>
	            <span id="strategyInfoTip"></span>
	        </span>
	    </div>
	</div>
    </div>
    
    

    <!-- ── Right: Controls ── -->
    <div class="card trade-controls">

      <!-- Live price -->
      <div class="price-ticker">
        <div class="price-main" id="livePrice">—</div>
        <div class="price-change" id="priceChange">—</div>
      </div>

      <!-- Balance -->
      <div class="balance-card">
        <div class="balance-label">Available Balance</div>
        <div class="balance-value">₹<span id="balance">—</span></div>
      </div>

      <!-- Holdings -->
      <div class="holdings-card">
        <div class="holdings-label">Holdings in <span id="holdingSymbol">—</span></div>
        <div class="holdings-value"><span id="holdingQty">0</span> units &nbsp;|&nbsp; Avg ₹<span id="holdingAvg">0.00</span></div>
      </div>
      
      <!-- ── Strategy Selector ── -->
		<div style="margin-bottom:4px;">
		    <label style="font-size:12px;color:#999;text-transform:uppercase;letter-spacing:0.5px;">
		        🤖 Auto Strategy
		    </label>
		    <select id="strategySelect" onchange="changeStrategy(this.value)"
		            style="width:100%;padding:9px 12px;border-radius:8px;border:1px solid #ddd;
		                   font-size:14px;margin-top:6px;outline:none;color:#333;">
		        <option value="none">— Off (Manual Trading) —</option>
                <option value="fintrade">FinTradeSim Strategy</option>
		        <option value="momentum">📈 Momentum</option>
		        <option value="trend">〰️ Trend Following (MA Cross)</option>
		        <option value="breakout">🚀 Breakout</option>
		    </select>
		</div>
		<div id="strategySignal"
		     style="display:none;padding:8px 12px;border-radius:8px;font-size:13px;
		            font-weight:600;margin-bottom:4px;text-align:center;">
		</div>

      <!-- Quantity + cost preview -->
      <div class="qty-row">
        <label>Qty</label>
        <input type="number" id="qty" min="1" value="1" oninput="updateCostPreview()" />
      </div>
      <div class="cost-preview">
        Total cost: <span id="costPreview">₹0.00</span>
      </div>

      <div id="message"></div>

      <div class="trade-btns">
        <button class="buy-btn"  onclick="executeTrade('buy')">🟢 Buy</button>
        <button class="sell-btn" onclick="executeTrade('sell')">🔴 Sell</button>
      </div>

      <!-- Order log -->
      <div class="order-log" id="orderLog">
        <h3>Order History</h3>
        <div style="color:#aaa;font-size:13px;">No trades yet</div>
      </div>
    </div>

  </div>
</div>

<script>
// ── Init ─────────────────────────────────────────────────────────────────────
const urlParams      = new URLSearchParams(window.location.search);
const selectedSymbol = urlParams.get("symbol") || "TCS";

document.getElementById("symbolBadge").textContent  = selectedSymbol;
document.getElementById("holdingSymbol").textContent = selectedSymbol;

let basePrice    = 0;
let currentPrice = 0;
let prevPrice    = 0;
let tickCount    = 0;
let simInterval  = null;

// Plotly trace data
const MAX_POINTS = 60;
const times  = [];
const prices = [];

// ── Fetch real base price from Breeze ────────────────────────────────────────
async function initFromLive() {
  try {
    const resp = await fetch("getPrice.jsp?symbol=" + encodeURIComponent(selectedSymbol));
    const data = await resp.json();
    if (data.error || !data.price) throw new Error(data.error || "no price");
    basePrice    = parseFloat(data.price);
    currentPrice = basePrice;
    prevPrice    = basePrice;
    console.log("✅ Base price loaded:", basePrice);
  } catch (e) {
    console.warn("Could not fetch live price, using fallback:", e.message);
    basePrice = currentPrice = prevPrice = 1000;
  }
  initChart();
  startSimulation();
  loadPortfolio();
  setInterval(loadPortfolio, 8000);
}

// ── Plotly init ───────────────────────────────────────────────────────────────
function initChart() {
  const now = new Date();
  for (let i = MAX_POINTS; i >= 0; i--) {
    const t = new Date(now - i * 2000);
    times.push(t);
    prices.push(basePrice);
  }

  const trace = {
    x: [...times], y: [...prices],
    type: "scatter", mode: "lines",
    name: selectedSymbol,
    line: { color: "#4b4b6e", width: 2 },
    fill: "tozeroy",
    fillcolor: "rgba(75,75,110,0.08)",
  };

  const layout = {
    paper_bgcolor: "#fff",
    plot_bgcolor:  "#fff",
    font: { color: "#333" },
    xaxis: {
      type: "date",
      tickformat: "%H:%M:%S",
      nticks: 6,
      showgrid: true, gridcolor: "#f0f0f0",
      rangeslider: { visible: false },
      title: { text: "" }
    },
    yaxis: {
      tickprefix: "\u20B9",
      showgrid: true, gridcolor: "#f0f0f0",
      title: { text: "Price", font: { color: "#888" } },
      range: [basePrice * 0.98, basePrice * 1.02],
    },
    margin: { t: 20, b: 40, l: 75, r: 20 },
    height: 360,
    hovermode: "x unified",
    hoverlabel: { bgcolor: "#1e1e2f", font: { color: "#fff" } },
    showlegend: false,
  };

  const config = { responsive: true, displayModeBar: false };
  Plotly.newPlot("priceChart", [trace], layout, config);
  updatePriceTicker(basePrice, 0);
}

// ── Simulation tick ───────────────────────────────────────────────────────────
function startSimulation() {
  simInterval = setInterval(() => {
    prevPrice    = currentPrice;

    // Brownian-motion style random walk anchored near base price
    const drift  = (basePrice - currentPrice) * 0.03;  // gentle pull back to base
    const noise  = (Math.random() - 0.5) * basePrice * 0.003; // ±0.15% per tick
    currentPrice = Math.max(0.01, currentPrice + drift + noise);

    const newTime = new Date();
    times.push(newTime);
    prices.push(parseFloat(currentPrice.toFixed(2)));

    if (times.length > MAX_POINTS)  { times.shift();  prices.shift(); }

    // Plotly streaming update — no full redraw
    Plotly.extendTraces("priceChart", { x: [[newTime]], y: [[currentPrice]] }, [0]);
    if (times.length > MAX_POINTS) {
      Plotly.relayout("priceChart", { "xaxis.range": [times[0], times[times.length-1]] });
    }

    // Dynamic y-axis range — ±1.5% window around current
    const lo = currentPrice * 0.985;
    const hi = currentPrice * 1.015;
    Plotly.relayout("priceChart", { "yaxis.range": [lo, hi] });

    // Update price ticker
    const change = currentPrice - basePrice;
    updatePriceTicker(currentPrice, change);
    updateCostPreview();
    tickCount++;
  }, 2000);
}

// ── Ticker display ────────────────────────────────────────────────────────────
function updatePriceTicker(price, change) {
  const priceEl  = document.getElementById("livePrice");
  const changeEl = document.getElementById("priceChange");
  const changePct = basePrice > 0 ? ((change / basePrice) * 100).toFixed(2) : "0.00";
  const sign      = change >= 0 ? "+" : "";
  const dir       = change >= 0 ? "up" : "down";

  priceEl.textContent  = "\u20B9" + price.toFixed(2);
  priceEl.className    = "price-main " + dir;
  changeEl.textContent = sign + price.toFixed(2) !== "\u20B9" + basePrice.toFixed(2)
    ? sign + change.toFixed(2) + " (" + sign + changePct + "%)"
    : "0.00 (0.00%)";
  changeEl.className = "price-change " + dir;
}

// ── Cost preview ──────────────────────────────────────────────────────────────
function updateCostPreview() {
  const qty   = parseInt(document.getElementById("qty").value) || 0;
  const total = (qty * currentPrice).toFixed(2);
  document.getElementById("costPreview").textContent = "\u20B9" + total;
}

// ── Portfolio loader ──────────────────────────────────────────────────────────
async function loadPortfolio() {
  try {
    const res  = await fetch("PortfolioServlet");
    const data = await res.json();

    document.getElementById("balance").textContent = parseFloat(data.balance).toFixed(2);

    // Holdings for this symbol
    const holding = data.holdings && data.holdings[selectedSymbol];
    if (holding) {
      document.getElementById("holdingQty").textContent = holding.quantity  || 0;
      document.getElementById("holdingAvg").textContent = parseFloat(holding.avgPrice || 0).toFixed(2);
    } else {
      document.getElementById("holdingQty").textContent = 0;
      document.getElementById("holdingAvg").textContent = "0.00";
    }

    // Order log
    const orderLog = document.getElementById("orderLog");
    orderLog.innerHTML = "<h3>Order History</h3>";

    if (data.trades && data.trades.length > 0) {
      const recent = [...data.trades].reverse().slice(0, 20);
      recent.forEach(t => {
        const entry = document.createElement("div");
        entry.classList.add("log-entry", t.action.toLowerCase());
        entry.innerHTML =
          '<span class="tag">' + t.action + '</span>' +
          '<span>' + t.quantity + ' × \u20B9' + parseFloat(t.price).toFixed(2) + '</span>' +
          '<span style="color:#aaa;font-size:11px;">' + (t.time || "") + '</span>';
        orderLog.appendChild(entry);
      });
    } else {
      orderLog.innerHTML += '<div style="color:#aaa;font-size:13px;">No trades yet</div>';
    }
  } catch (e) {
    console.error("Portfolio load error:", e);
  }
}

// ── Execute trade ─────────────────────────────────────────────────────────────
async function executeTrade(type) {
  const qty        = parseInt(document.getElementById("qty").value);
  const msgDiv     = document.getElementById("message");

  if (!qty || qty <= 0) {
    showMsg("Please enter a valid quantity.", "error"); return;
  }
  if (!currentPrice || isNaN(currentPrice)) {
    showMsg("Price not loaded yet. Please wait.", "error"); return;
  }

  const body = "action=" + type
             + "&quantity=" + qty
             + "&price="    + currentPrice.toFixed(2)
             + "&symbol="   + encodeURIComponent(selectedSymbol);

  try {
    const resp = await fetch("TradeServlet", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body
    });
    const data = await resp.json();

    if (data.error)           { showMsg(data.error, "error"); return; }
    if (data.result === "success") {
      showMsg(type === "buy"
        ? "✅ Bought " + qty + " units at \u20B9" + currentPrice.toFixed(2)
        : "✅ Sold "   + qty + " units at \u20B9" + currentPrice.toFixed(2),
        "success");
      loadPortfolio();
    }
  } catch (e) {
    showMsg("Trade failed: " + e.message, "error");
  }
}

function showMsg(text, type) {
  const d = document.getElementById("message");
  d.innerHTML = '<div class="msg-box ' + type + '">' + text + '</div>';
  setTimeout(() => { d.innerHTML = ""; }, 4000);
}


//── STRATEGY ENGINE ───────────────────────────────────────────────────────────

const STRATEGY_INFO = {
    fintrade: {
        title: "FinTradeSim Strategy",
        badge: "Prediction Model",
        desc: "This strategy is based on the FinTradeSim prediction workflow. It uses moving average behavior and recent return patterns to generate BUY / SELL / HOLD style signals for paper trading simulation.",
        details: [
            { label: "Signal Speed", value: "Medium" },
            { label: "Based On", value: "SMA20, SMA50, recent return, price trend" },
            { label: "Best For", value: "Balanced simulation trading" },
            { label: "Risk Level", value: "Medium" }
        ],
        tip: "Use when you want a broader predictive-style strategy instead of only momentum, crossover, or breakout logic."
    },

    momentum: {
        title:  "📈 Momentum Strategy",
        badge:  "Trend-Based",
        desc:   "Momentum trading is based on the idea that stocks which are rising tend to keep rising, and stocks that are falling tend to keep falling — at least for a short while. This strategy watches the last few price ticks: if prices have been consistently going up, it signals a BUY. If they've been consistently going down, it signals a SELL.",
        details: [
            { label: "⚡ Signal Speed",   value: "Fast — fires within seconds" },
            { label: "📊 Based On",       value: "Recent price direction" },
            { label: "🎯 Best For",       value: "Short-term trades" },
            { label: "⚠️ Risk Level",     value: "Medium — can give false signals in choppy markets" },
        ],
        tip: "Use when the market is moving strongly in one direction. Avoid in sideways or volatile markets."
    },
    trend: {
        title:  "〰️ Trend Following (MA Crossover)",
        badge:  "Moving Average",
        desc:   "This strategy uses two Moving Averages — a Fast MA (average of last 5 prices) and a Slow MA (average of last 15 prices). When the Fast MA crosses above the Slow MA, it means short-term momentum is picking up — BUY signal. When it crosses below, the trend is weakening — SELL signal. Think of it like two lines: when the faster one overtakes the slower one, the trend is changing.",
        details: [
            { label: "⚡ Signal Speed",   value: "Medium — needs a few ticks to build" },
            { label: "📊 Based On",       value: "Fast MA (5) vs Slow MA (15)" },
            { label: "🎯 Best For",       value: "Catching the start of a new trend" },
            { label: "⚠️ Risk Level",     value: "Low-Medium — smoother, fewer false signals" },
        ],
        tip: "Best used when markets are trending. Less effective in flat or sideways markets where MAs keep crossing back and forth."
    },
    breakout: {
        title:  "🚀 Breakout Strategy",
        badge:  "Price Level",
        desc:   "Breakout trading watches key price levels — specifically the highest and lowest prices over the last 20 ticks. When the current price breaks above the recent high (resistance), buyers are taking control — BUY signal. When it breaks below the recent low (support), sellers are taking control — SELL signal. It's like watching a ball bounce between a ceiling and a floor — when it finally breaks through either, that's the signal.",
        details: [
            { label: "⚡ Signal Speed",   value: "Slower — needs 20 ticks of history first" },
            { label: "📊 Based On",       value: "20-tick high/low price levels" },
            { label: "🎯 Best For",       value: "Catching explosive price moves" },
            { label: "⚠️ Risk Level",     value: "Medium-High — breakouts can be false (fakeouts)" },
        ],
        tip: "Works best when price has been stuck in a range for a while and then suddenly breaks out. The longer the range, the stronger the breakout."
    }
};

function changeStrategy(val) {
    activeStrategy  = val;
    strategyEnabled = val !== "none";
    lastSignal      = "HOLD";
    document.getElementById("strategySignal").style.display = "none";

    const panel = document.getElementById("strategyInfo");

    if (val === "none") {
        panel.style.display = "none";
        return;
    }

    const info = STRATEGY_INFO[val];
    document.getElementById("strategyInfoTitle").textContent = info.title;
    document.getElementById("strategyInfoBadge").textContent = info.badge;
    document.getElementById("strategyInfoDesc").textContent  = info.desc;
    document.getElementById("strategyInfoTip").textContent   = info.tip;

    // Render detail cards
    document.getElementById("strategyInfoDetails").innerHTML = info.details.map(function(d) {
    return '<div style="background:#fff; border:1px solid #e8e8f0; border-radius:8px; padding:10px 12px;">' +
        '<div style="font-size:11px; color:#888; margin-bottom:4px; font-weight:500;">' + d.label + '</div>' +
        '<div style="font-size:13px; font-weight:600; color:#1e1e2f;">' + d.value + '</div>' +
    '</div>';
	}).join("");

    panel.style.display = "block";
    panel.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

//── Config ────────────────────────────────────────────────────────────────────
let activeStrategy   = "none";   // "none" | "momentum" | "trend" | "breakout" | "fintrade"
let strategyEnabled  = false;
let lastSignal       = "HOLD";   // prevent repeat signals
const signalTimes    = [];       // for Plotly markers
const signalPrices   = [];
const signalColors   = [];
const signalSymbols  = [];
const signalTexts    = [];

// 0. FinTradeSim Strategy
function avg(arr) {
    return arr.reduce((a, b) => a + b, 0) / arr.length;
}

function strategyFinTrade(priceArr) {
    if (priceArr.length < 50) return "HOLD";

    const latest = priceArr[priceArr.length - 1];
    const prev = priceArr[priceArr.length - 2];

    const sma20 = avg(priceArr.slice(-20));
    const sma50 = avg(priceArr.slice(-50));

    const recentReturn = prev !== 0 ? ((latest - prev) / prev) : 0;

    let score = 0;

    if (latest > sma20) score += 1;
    if (sma20 > sma50) score += 1;
    if (recentReturn > 0) score += 1;

    if (score >= 3) return "BUY";
    if (score <= 1) return "SELL";
    return "HOLD";
}

//── 1. MOMENTUM STRATEGY ─────────────────────────────────────────────────────
//Buys when last N ticks are consistently rising, sells when falling
function strategyMomentum(priceArr) {
 const N = 5;
 if (priceArr.length < N) return "HOLD";
 const slice = priceArr.slice(-N);
 const rising  = slice.every((p, i) => i === 0 || p > slice[i - 1]);
 const falling = slice.every((p, i) => i === 0 || p < slice[i - 1]);
 if (rising)  return "BUY";
 if (falling) return "SELL";
 return "HOLD";
}

//── 2. TREND FOLLOWING (Moving Average Crossover) ────────────────────────────
//Buys when fast MA crosses above slow MA, sells when it crosses below
function strategyTrend(priceArr) {
 const FAST = 5, SLOW = 15;
 if (priceArr.length < SLOW) return "HOLD";
 const avg = (arr) => arr.reduce((a, b) => a + b, 0) / arr.length;
 const fastNow  = avg(priceArr.slice(-FAST));
 const slowNow  = avg(priceArr.slice(-SLOW));
 const fastPrev = avg(priceArr.slice(-FAST - 1, -1));
 const slowPrev = avg(priceArr.slice(-SLOW - 1, -1));
 if (fastPrev <= slowPrev && fastNow > slowNow) return "BUY";
 if (fastPrev >= slowPrev && fastNow < slowNow) return "SELL";
 return "HOLD";
}

//── 3. BREAKOUT STRATEGY ─────────────────────────────────────────────────────
//Buys when price breaks above recent high, sells when it breaks below recent low
function strategyBreakout(priceArr) {
 const LOOKBACK = 20;
 if (priceArr.length < LOOKBACK + 1) return "HOLD";
 const window   = priceArr.slice(-LOOKBACK - 1, -1);
 const recentHigh = Math.max(...window);
 const recentLow  = Math.min(...window);
 const latest     = priceArr[priceArr.length - 1];
 if (latest > recentHigh) return "BUY";
 if (latest < recentLow)  return "SELL";
 return "HOLD";
}

//── Signal dispatcher ─────────────────────────────────────────────────────────
function runStrategy() {
 if (!strategyEnabled || activeStrategy === "none") return;

 let signal = "HOLD";
 if (activeStrategy === "fintrade") signal = strategyFinTrade(prices);
 if (activeStrategy === "momentum") signal = strategyMomentum(prices);
 if (activeStrategy === "trend")    signal = strategyTrend(prices);
 if (activeStrategy === "breakout") signal = strategyBreakout(prices);

 if (signal === "HOLD" || signal === lastSignal) return;
 lastSignal = signal;

 // ── Plot marker on chart ──────────────────────────────────────────────────
 const color  = signal === "BUY" ? "#00c087" : "#ff4b4b";
 const symbol = signal === "BUY" ? "triangle-up" : "triangle-down";
 signalTimes.push(times[times.length - 1]);
 signalPrices.push(currentPrice);
 signalColors.push(color);
 signalSymbols.push(symbol);
 signalTexts.push(signal);

 Plotly.addTraces("priceChart", {
     x: [times[times.length - 1]],
     y: [currentPrice],
     mode: "markers+text",
     type: "scatter",
     marker: { color: color, size: 14, symbol: symbol },
     text: [signal],
     textposition: signal === "BUY" ? "top center" : "bottom center",
     textfont: { color: color, size: 11, family: "Poppins" },
     showlegend: false,
     hoverinfo: "text",
     hovertext: signal + " @ ₹" + currentPrice.toFixed(2),
 });

 // ── Show signal banner ────────────────────────────────────────────────────
 const banner = document.getElementById("strategySignal");
 banner.textContent = "🤖 Strategy Signal: " + signal + " @ ₹" + currentPrice.toFixed(2);
 banner.style.background = signal === "BUY" ? "#e6faf4" : "#ffeaea";
 banner.style.color      = signal === "BUY" ? "#00875a" : "#cc2200";
 banner.style.display    = "block";

 // ── Auto-fill quantity and highlight button ───────────────────────────────
 document.getElementById("qty").value = 1;
 updateCostPreview();

 // Briefly flash the relevant button
 const btn = signal === "BUY"
     ? document.querySelector(".buy-btn")
     : document.querySelector(".sell-btn");
 btn.style.transform = "scale(1.08)";
 btn.style.boxShadow = "0 0 12px " + color;
 setTimeout(() => {
     btn.style.transform = "";
     btn.style.boxShadow = "";
 }, 1500);
}

//── Hook strategy into simulation tick ───────────────────────────────────────
//Patch startSimulation to also call runStrategy every tick
const _origInterval = simInterval;
clearInterval(simInterval);
simInterval = setInterval(() => {
 prevPrice = currentPrice;
 const drift  = (basePrice - currentPrice) * 0.03;
 const noise  = (Math.random() - 0.5) * basePrice * 0.003;
 currentPrice = Math.max(0.01, currentPrice + drift + noise);
 const newTime = new Date();
 times.push(newTime);
 prices.push(parseFloat(currentPrice.toFixed(2)));
 if (times.length > MAX_POINTS) { times.shift(); prices.shift(); }
 Plotly.extendTraces("priceChart", { x: [[newTime]], y: [[currentPrice]] }, [0]);
 if (times.length > MAX_POINTS) {
     Plotly.relayout("priceChart", { "xaxis.range": [times[0], times[times.length - 1]] });
 }
 const lo = currentPrice * 0.985, hi = currentPrice * 1.015;
 Plotly.relayout("priceChart", { "yaxis.range": [lo, hi] });
 const change = currentPrice - basePrice;
 updatePriceTicker(currentPrice, change);
 updateCostPreview();
 tickCount++;

 runStrategy(); // ✅ strategy runs every tick
}, 2000);

// ── Start ─────────────────────────────────────────────────────────────────────
initFromLive();
</script>

</body>
</html>
