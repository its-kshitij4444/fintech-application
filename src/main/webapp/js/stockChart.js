// stockChart.js — Plotly.js candlestick chart

const BASE_URLS = [
    "https://fintech-application-backend.onrender.com",
    "http://localhost:5000"
];

async function fetchOHLCHistory(symbol, days) {
    for (const baseUrl of BASE_URLS) {
        try {
            const resp = await fetch(
                `${baseUrl}/history?stock_code=${encodeURIComponent(symbol)}&days=${days}`
            );
            if (!resp.ok) continue;

            const data = await resp.json();
            if (data.error) continue;

            return Array.isArray(data) ? data : [];
        } catch (e) {
            console.error("OHLC fetch error from", baseUrl, e.message);
        }
    }
    return [];
}

async function renderCandlestick(symbol, days) {
    days = days || 1;
    const container = document.getElementById("plotlyChart");
    if (!container) return;

    container.innerHTML =
        '<div style="color:#aaa;text-align:center;padding:80px 0;font-size:15px;">⏳ Loading chart for ' + symbol + '...</div>';

    const rows = await fetchOHLCHistory(symbol, days);

    if (!rows || rows.length === 0) {
        container.innerHTML =
            '<div style="color:#ff4b4b;text-align:center;padding:80px 0;font-size:15px;">' +
            '📭 No chart data available.<br><small style="color:#aaa">Market may be closed or symbol not found.</small></div>';
        return;
    }

    function g(row, key) {
        return row[key] !== undefined ? row[key] :
               row[key.toLowerCase()] !== undefined ? row[key.toLowerCase()] : null;
    }

    const dates  = rows.map(r => g(r, "datetime") || g(r, "Date"));
    const opens  = rows.map(r => parseFloat(g(r, "open")   || 0));
    const highs  = rows.map(r => parseFloat(g(r, "high")   || 0));
    const lows   = rows.map(r => parseFloat(g(r, "low")    || 0));
    const closes = rows.map(r => parseFloat(g(r, "close")  || 0));
    const vols   = rows.map(r => parseInt(g(r,  "volume")  || 0));

    const periodLabel = days === 1 ? "Today (1 min)" : days === 5 ? "5 Days (5 min)" : "30 Days (Daily)";

    // ── Smart tick format based on period ─────────────────────────────────────
    // 1D  → show only time  "14:30"
    // 5D  → show date+time  "Mar 20, 14:30"
    // 30D → show date only  "Mar 20"
    const tickformat  = days === 1  ? "%H:%M"
                      : days === 5  ? "%b %d %H:%M"
                      :               "%b %d";

    // Max number of ticks to show — keeps axis readable regardless of data density
    const nticks      = days === 1  ? 10
                      : days === 5  ? 12
                      :               15;

    const candlestick = {
        type:  "candlestick",
        x:     dates,
        open:  opens, high: highs, low: lows, close: closes,
        name:  symbol,
        increasing: { line: { color: "#00c087" }, fillcolor: "#00c087" },
        decreasing: { line: { color: "#ff4b4b" }, fillcolor: "#ff4b4b" },
        hoverinfo: "x+open+high+low+close",
        whiskerwidth: 0.3,
    };

    const volumeBar = {
        type:   "bar",
        x:      dates,
        y:      vols,
        name:   "Volume",
        marker: { color: "rgba(100,100,200,0.35)" },
        yaxis:  "y2",
        hoverinfo: "x+y",
    };

    const layout = {
        title: {
            text: symbol + " — " + periodLabel,
            font: { color: "#fafafa", size: 16 }
        },
        paper_bgcolor: "#0e1117",
        plot_bgcolor:  "#161b22",
        font: { color: "#fafafa" },

        xaxis: {
            type:        "date",
            tickformat:  tickformat,      // clean date/time labels
            nticks:      nticks,          // limit number of ticks shown
            tickangle:   -30,             // slight angle — avoids overlap
            rangeslider: { visible: false },
            showgrid:    true,
            gridcolor:   "#2a2a2a",
            linecolor:   "#444",
            tickfont:    { size: 11, color: "#aaa" },
            title:       { text: "" },    // no axis title — labels are self-explanatory
            // Hide gaps for weekends/market-closed periods
            rangebreaks: days <= 5 ? [
                { bounds: ["sat", "mon"] },            // remove weekends
                { bounds: [16, 9.25], pattern: "hour" } // remove off-market hours (IST ~9:15–15:30)
            ] : []
        },

        yaxis: {
            showgrid:    true,
            gridcolor:   "#2a2a2a",
            linecolor:   "#444",
            tickprefix:  "₹",
            tickfont:    { size: 11, color: "#aaa" },
            title:       { text: "Price", font: { color: "#888" }, standoff: 8 },
            domain:      [0.25, 1],
            automargin:  true,
        },

        yaxis2: {
            showgrid:    false,
            tickfont:    { size: 10, color: "#666" },
            title:       { text: "Vol", font: { color: "#666" }, standoff: 4 },
            domain:      [0, 0.20],
            automargin:  true,
        },

        legend: {
            orientation: "h",
            x: 0, y: 1.06,
            font: { color: "#ccc", size: 12 }
        },
        margin:    { t: 55, b: 55, l: 75, r: 20 },
        height:    440,
        hovermode: "x unified",
        hoverlabel: {
            bgcolor:  "#1e1e2f",
            font:     { color: "#fff", size: 12 },
            bordercolor: "#4b4b6e"
        },
        shapes: [],   // placeholder for future annotations
    };

    const config = {
        responsive:             true,
        displayModeBar:         true,
        modeBarButtonsToRemove: ["lasso2d", "select2d", "autoScale2d"],
        displaylogo:            false,
        toImageButtonOptions:   { format: "png", filename: symbol + "_chart" }
    };

    container.innerHTML = "";
    Plotly.newPlot("plotlyChart", [candlestick, volumeBar], layout, config);
}

// Backward-compat stubs
async function renderStockChart(canvasId, symbol) {
    await renderCandlestick(symbol, typeof currentChartDays !== "undefined" ? currentChartDays : 1);
}
async function updateStockChart(canvasId, symbol) { await renderCandlestick(symbol, 1); }
function destroyStockChart() { if (typeof Plotly !== "undefined") Plotly.purge("plotlyChart"); }
