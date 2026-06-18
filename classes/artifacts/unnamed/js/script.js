// script.js — Stock quote fetcher + autocomplete search
// Preserves all original functionality + adds scrip master autocomplete

let refreshInterval = null;
let isLoading       = false;
let scripData       = [];        // loaded from scrip_master.csv via Flask
let activeIndex     = -1;        // keyboard nav index for dropdown
const API_BASE = "http://localhost:5000";

// ── Load scrip master from Flask ─────────────────────────────────────────────
async function loadScripMaster() {
    try {
        const resp = await fetch(`${API_BASE}/scrip-list`);
        if (!resp.ok) return;
        scripData = await resp.json();
        console.log("✅ Scrip master loaded:", scripData.length, "stocks");
    } catch (e) {
        console.warn("Scrip master not available:", e.message);
    }
}

// ── Autocomplete ─────────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", function () {
    const input = document.getElementById("symbolInput");
    const list  = document.getElementById("autocompleteList");
    if (!input || !list) return;

    input.addEventListener("input", function () {
        const q = this.value.trim().toUpperCase();
        activeIndex = -1;
        if (!q || scripData.length === 0) { list.style.display = "none"; return; }

        const matches = scripData.filter(s =>
            s.stock_code.includes(q) ||
            s.company_name.toUpperCase().includes(q)
        ).slice(0, 12);

        if (matches.length === 0) {
            list.innerHTML = '<div class="autocomplete-empty">No results found</div>';
            list.style.display = "block";
            return;
        }

        list.innerHTML = matches.map((s, i) =>
            `<div class="autocomplete-item" data-index="${i}" data-code="${s.stock_code}"
                  onmousedown="selectSymbol('${s.stock_code}')">
                <span class="autocomplete-symbol">${s.stock_code}</span>
                <span class="autocomplete-name">${s.company_name}</span>
             </div>`
        ).join("");
        list.style.display = "block";
    });

    // Keyboard navigation
    input.addEventListener("keydown", function (e) {
        const items = list.querySelectorAll(".autocomplete-item");
        if (e.key === "ArrowDown") {
            activeIndex = Math.min(activeIndex + 1, items.length - 1);
            highlightItem(items);
        } else if (e.key === "ArrowUp") {
            activeIndex = Math.max(activeIndex - 1, 0);
            highlightItem(items);
        } else if (e.key === "Enter") {
            if (activeIndex >= 0 && items[activeIndex]) {
                selectSymbol(items[activeIndex].dataset.code);
            } else {
                fetchStockData(true);
            }
        } else if (e.key === "Escape") {
            list.style.display = "none";
        }
    });

    // Close dropdown when clicking outside
    document.addEventListener("mousedown", function (e) {
        if (!e.target.closest(".search-wrapper")) list.style.display = "none";
    });
});

function highlightItem(items) {
    items.forEach((el, i) => el.classList.toggle("active", i === activeIndex));
    if (items[activeIndex]) items[activeIndex].scrollIntoView({ block: "nearest" });
}

function selectSymbol(code) {
    document.getElementById("symbolInput").value = code;
    document.getElementById("autocompleteList").style.display = "none";
    fetchStockData(true);
    renderCandlestick(code, typeof currentChartDays !== "undefined" ? currentChartDays : 1);
}

// ── UI helpers ───────────────────────────────────────────────────────────────
function updateUI(loading = false) {
    const button = document.getElementById("fetchBtn");
    const input  = document.getElementById("symbolInput");
    if (loading) {
        button.disabled = true;
        button.textContent = "Loading...";
        isLoading = true;
    } else {
        button.disabled = false;
        button.textContent = "Get Quote";
        isLoading = false;
    }
}

function formatNumber(num, decimals = 2) {
    if (isNaN(parseFloat(num))) return "N/A";
    return "₹" + parseFloat(num).toLocaleString("en-IN", {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
    });
}

function formatVolume(volume) {
    const num = parseInt(volume);
    if (isNaN(num)) return "N/A";
    if (num >= 1e9)  return (num / 1e9).toFixed(2)  + "B";
    if (num >= 1e6)  return (num / 1e6).toFixed(2)  + "M";
    if (num >= 1e3)  return (num / 1e3).toFixed(2)  + "K";
    return num.toLocaleString();
}

function setError(message) {
    ["symbol","price","change","changePercent","open","high","low","volume"].forEach(id => {
        document.getElementById(id).textContent  = "Error";
        document.getElementById(id).className    = "info-value error";
    });
    document.getElementById("time").textContent = message;
    document.getElementById("time").className   = "info-value error";
}

function setLoading() {
    ["symbol","price","change","changePercent","open","high","low","volume","time"].forEach(id => {
        document.getElementById(id).textContent = "Loading...";
        document.getElementById(id).className   = "info-value loading";
    });
}

// ── Main fetch ───────────────────────────────────────────────────────────────
function fetchStockData(userInitiated = false) {
    if (isLoading) return;

    const symbol = document.getElementById("symbolInput").value.trim();
    if (!symbol) { alert("Please enter a stock symbol"); return; }

    updateUI(true);
    if (userInitiated) setLoading();

    fetch(`getPrice.jsp?symbol=${encodeURIComponent(symbol)}`, {
        headers: { "Cache-Control": "no-cache" }
    })
    .then(r => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); })
    .then(data => {
        updateUI(false);
        if (data.error) { setError(data.error); return; }

        document.getElementById("symbol").textContent = data.symbol || "N/A";
        document.getElementById("symbol").className   = "info-value";

        document.getElementById("price").textContent  = formatNumber(data.price);
        document.getElementById("price").className    = "info-value price";

        const change = parseFloat(data.change) || 0;
        const sign   = change >= 0 ? "+" : "";
        const cls    = change >= 0 ? "positive" : "negative";

        document.getElementById("change").textContent       = sign + formatNumber(data.change);
        document.getElementById("change").className         = "info-value change " + cls;
        document.getElementById("changePercent").textContent = sign + (parseFloat(data.changePercent) || 0).toFixed(2) + "%";
        document.getElementById("changePercent").className  = "info-value change " + cls;

        document.getElementById("open").textContent   = formatNumber(data.open);
        document.getElementById("open").className     = "info-value";
        document.getElementById("high").textContent   = formatNumber(data.high);
        document.getElementById("high").className     = "info-value";
        document.getElementById("low").textContent    = formatNumber(data.low);
        document.getElementById("low").className      = "info-value";
        document.getElementById("volume").textContent = formatVolume(data.volume);
        document.getElementById("volume").className   = "info-value";
        document.getElementById("time").textContent   = data.timestamp || "N/A";
        document.getElementById("time").className     = "info-value";
    })
    .catch(err => { updateUI(false); setError("Network error: " + err.message); });
}

// ── Auto-refresh ─────────────────────────────────────────────────────────────
function setupAutoRefresh() {
    const cb = document.getElementById("autoRefresh");
    if (!cb) return;

    // ✅ Uncheck by default — user must opt in
    cb.checked = false;

    function toggle() {
        clearInterval(refreshInterval);
        refreshInterval = null;
        if (cb.checked) {
            refreshInterval = setInterval(() => {
                const symbol = document.getElementById("symbolInput").value.trim();
                if (!isLoading && symbol) fetchStockData(false); // ✅ only if symbol exists
            }, 15000);
        }
    }
    cb.addEventListener("change", toggle);
    // ❌ Don't call toggle() here — so interval doesn't start on load
}

function setupEnterKey() {
    const input = document.getElementById("symbolInput");
    if (!input) return;
    input.addEventListener("keypress", function (e) {
        if (e.key === "Enter") fetchStockData(true);
    });
}

window.addEventListener("load", function () {
    setupAutoRefresh();
    setupEnterKey();
    // ❌ Removed fetchStockData(true) — no auto-fetch on load

    // ✅ Only fetch if symbol came from URL (e.g. Buy button redirect)
    const params = new URLSearchParams(window.location.search);
    const symbolFromUrl = params.get("symbol");
    if (symbolFromUrl) {
        document.getElementById("symbolInput").value = symbolFromUrl;
        fetchStockData(true);
        if (typeof renderCandlestick === "function") renderCandlestick(symbolFromUrl, 1);
    }
});

window.addEventListener("beforeunload", function () {
    if (refreshInterval) clearInterval(refreshInterval);
});