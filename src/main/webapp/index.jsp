<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Live Stock Price Tracker</title>
    <link rel="stylesheet" href="css/style.css">
    <!-- Plotly for candlestick chart (replaces Chart.js for this page) -->
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <script src="js/script.js?v=4" defer></script>
    <script src="js/stockChart.js?v=4" defer></script>
    <style>
        /* ── Search Autocomplete ── */
        .search-wrapper {
            position: relative;
            flex: 1;
        }
        #symbolInput {
            width: 100%;
            padding: 12px 16px;
            font-size: 15px;
            border: 2px solid #ddd;
            border-radius: 8px;
            outline: none;
            box-sizing: border-box;
            transition: border-color 0.2s;
        }
        #symbolInput:focus { border-color: #4b4b6e; }

        #autocompleteList {
            position: absolute;
            top: 100%;
            left: 0; right: 0;
            background: #fff;
            border: 1px solid #ccc;
            border-top: none;
            border-radius: 0 0 8px 8px;
            max-height: 260px;
            overflow-y: auto;
            z-index: 999;
            box-shadow: 0 4px 12px rgba(0,0,0,0.12);
            display: none;
        }
        .autocomplete-item {
            padding: 10px 16px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #f0f0f0;
            transition: background 0.15s;
        }
        .autocomplete-item:hover,
        .autocomplete-item.active { background: #f0f0f8; }
        .autocomplete-symbol {
            font-weight: 700;
            color: #4b4b6e;
            font-size: 14px;
            min-width: 90px;
        }
        .autocomplete-name {
            color: #555;
            font-size: 13px;
            text-align: right;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 280px;
        }
        .autocomplete-empty {
            padding: 12px 16px;
            color: #999;
            font-size: 13px;
        }

        /* ── Chart container ── */
        #plotlyChart {
            width: 100%;
            height: 420px;
            margin-top: 10px;
            border-radius: 10px;
            background: #0e1117;
        }

        /* ── Chart period tabs ── */
        .chart-tabs {
            display: flex;
            gap: 8px;
            margin-bottom: 12px;
            flex-wrap: wrap;
        }
        .chart-tab {
            padding: 6px 16px;
            border: 1px solid #4b4b6e;
            border-radius: 20px;
            background: transparent;
            color: #4b4b6e;
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
            transition: 0.2s;
        }
        .chart-tab.active,
        .chart-tab:hover {
            background: #4b4b6e;
            color: #fff;
        }

        /* ── Metric cards ── */
        .stock-info {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
            gap: 14px;
            margin-top: 20px;
        }
        .info-card {
            background: #fff;
            border: 1px solid #e8e8f0;
            border-radius: 10px;
            padding: 14px 16px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.05);
        }
        .info-label {
            font-size: 11px;
            color: #999;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 6px;
        }
        .info-value {
            font-size: 18px;
            font-weight: 700;
            color: #1e1e2f;
        }
        .info-value.positive { color: #00c087; }
        .info-value.negative { color: #ff4b4b; }
        .info-value.loading  { color: #aaa; font-size: 14px; font-weight: 400; }
        .info-value.error    { color: #ff4b4b; font-size: 13px; font-weight: 400; }
    </style>
</head>
<body>
<div class="container">

    <!-- Back link -->
    <div style="margin-bottom:20px;">
        <a href="dashboard.jsp" style="text-decoration:none;font-size:18px;color:#4b4b6e;font-weight:bold;">&#8592; Back to Dashboard</a>
    </div>

    <h2>📈 Live Stock Price Tracker</h2>

    <!-- ── Search bar with autocomplete ── -->
    <div class="input-section" style="display:flex;gap:10px;align-items:flex-start;margin-top:20px;">
        <div class="search-wrapper">
            <input type="text" id="symbolInput"
                   placeholder="Search by company name or symbol (e.g. Tata, TCS, Wipro...)"
                   autocomplete="off"/>
            <div id="autocompleteList"></div>
        </div>
        <button id="fetchBtn" onclick="fetchStockData(true)"
                style="padding:12px 24px;background:#4b4b6e;color:#fff;border:none;border-radius:8px;font-size:14px;font-weight:600;cursor:pointer;white-space:nowrap;">
            Get Quote
        </button>
    </div>

    <!-- ── Chart section ── -->
    <div class="chart-section" style="margin-top:28px;">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
            <h3 style="margin:0;">Candlestick Chart</h3>
            <div class="chart-tabs">
                <button class="chart-tab active" onclick="changeChartPeriod(1,   this)">1D</button>
                <button class="chart-tab"         onclick="changeChartPeriod(5,   this)">5D</button>
                <button class="chart-tab"         onclick="changeChartPeriod(30,  this)">1M</button>
            </div>
        </div>
        <div id="plotlyChart"></div>
    </div>

    <!-- ── Stock info cards ── -->
    <div class="stock-info">

        <div class="info-card" style="grid-column: span 2;">
            <div class="info-label">Action</div>
            <div class="info-value">
                <button id="buyBtn" onclick="buyStock()"
                        style="background:#28a745;color:#fff;padding:10px 24px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:14px;">
                    🛒 Buy This Stock
                </button>
            </div>
        </div>

        <div class="info-card">
            <div class="info-label">Symbol</div>
            <div class="info-value" id="symbol">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Current Price</div>
            <div class="info-value price" id="price">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Change</div>
            <div class="info-value change" id="change">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Change %</div>
            <div class="info-value change" id="changePercent">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Open</div>
            <div class="info-value" id="open">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">High</div>
            <div class="info-value" id="high">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Low</div>
            <div class="info-value" id="low">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Volume</div>
            <div class="info-value" id="volume">—</div>
        </div>
        <div class="info-card">
            <div class="info-label">Last Updated</div>
            <div class="info-value" id="time" style="font-size:13px;">—</div>
        </div>
    </div>

    <!-- ── Auto-refresh ── -->
    <div class="auto-refresh" style="margin-top:20px;">
        <input type="checkbox" id="autoRefresh" checked>
        <label for="autoRefresh">Auto-refresh every 15 seconds</label>
    </div>

</div>

<script>
// ── BUY button ──────────────────────────────────────────────────────────────
function buyStock() {
    const symbol = document.getElementById("symbolInput").value.trim();
    const price  = document.getElementById("price").textContent;
    if (!symbol || price === "—") { alert("Please search for a stock first"); return; }
    window.location.href = "paperTrading.jsp?symbol=" + encodeURIComponent(symbol);
}

// ── Chart period state ───────────────────────────────────────────────────────
let currentChartDays = 1;

function changeChartPeriod(days, btn) {
    currentChartDays = days;
    document.querySelectorAll(".chart-tab").forEach(b => b.classList.remove("active"));
    btn.classList.add("active");
    const symbol = document.getElementById("symbolInput").value.trim();
    if (symbol) renderCandlestick(symbol, days);
}

// ── DOMContentLoaded ─────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", function () {
    loadScripMaster();          // load CSV for autocomplete
    //fetchStockData(true);       // initial quote fetch

    //const symbol = document.getElementById("symbolInput").value.trim();
    //if (symbol) renderCandlestick(symbol, 1);
    
    const params = new URLSearchParams(window.location.search);
    const symbolFromUrl = params.get("symbol");
    if (symbolFromUrl) {
        document.getElementById("symbolInput").value = symbolFromUrl;
        fetchStockData(true);
        if (typeof renderCandlestick === "function") renderCandlestick(symbolFromUrl, 1);
    }
});
</script>
</body>
</html>