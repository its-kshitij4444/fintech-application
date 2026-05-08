let refreshInterval = null;
let isLoading = false;

function updateUI(loading = false) {
    const button = document.getElementById("fetchBtn");
    const symbolInput = document.getElementById("symbolInput");
    
    if (loading) {
        button.disabled = true;
        button.textContent = "Loading...";
        symbolInput.disabled = true;
        isLoading = true;
    } else {
        button.disabled = false;
        button.textContent = "Get Quote";
        symbolInput.disabled = false;
        isLoading = false;
    }
}

function formatNumber(num, symbol = "", decimals = 2) {
    if (isNaN(parseFloat(num))) return "N/A";
    
    const isIndianStock = symbol.endsWith(".NS") || symbol.endsWith(".BO");
    const currencySymbol = isIndianStock ? "\u20B9" : "$"; // \u20B9 is ₹
    
    return currencySymbol + parseFloat(num).toLocaleString("en-IN", {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
    });
}
function formatVolume(volume) {
    const num = parseInt(volume);
    if (isNaN(num)) return "N/A";
    
    if (num >= 1000000000) {
        return (num / 1000000000).toFixed(2) + "B";
    } else if (num >= 1000000) {
        return (num / 1000000).toFixed(2) + "M";
    } else if (num >= 1000) {
        return (num / 1000).toFixed(2) + "K";
    }
    return num.toLocaleString();
}

function setError(message) {
    const elements = ["symbol", "price", "change", "changePercent", "open", "high", "low", "volume"];
    elements.forEach(id => {
        const element = document.getElementById(id);
        element.textContent = "Error";
        element.className = "info-value error";
    });
    document.getElementById("time").textContent = message;
    document.getElementById("time").className = "info-value error";
}

function setLoading() {
    const elements = ["symbol", "price", "change", "changePercent", "open", "high", "low", "volume", "time"];
    elements.forEach(id => {
        const element = document.getElementById(id);
        element.textContent = "Loading...";
        element.className = "info-value loading";
    });
}

function fetchStockData(userInitiated = false) {
    if (isLoading) return;
    
    const symbol = document.getElementById("symbolInput").value.trim();
    if (!symbol) {
        alert("Please enter a stock symbol");
        return;
    }
    
    updateUI(true);
    if (userInitiated) {
        setLoading();
    }
    
    const url = `getPrice.jsp?symbol=${encodeURIComponent(symbol)}`;
    
    fetch(url, {
        method: 'GET',
        headers: {
            'Cache-Control': 'no-cache'
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return response.json();
    })
    .then(data => {
        updateUI(false);
        
        if (data.error) {
            console.error("Server error:", data.error);
            setError(data.error);
            return;
        }
        
        // Update all fields
        document.getElementById("symbol").textContent = data.symbol || "N/A";
        document.getElementById("symbol").className = "info-value";
        
        const price = document.getElementById("price");
        price.textContent = formatNumber(data.price, symbol);
        price.className = "info-value price";

        // Handle change values
        const change = parseFloat(data.change) || 0;
        const changeElement = document.getElementById("change");
        const changePercentElement = document.getElementById("changePercent");

        changeElement.textContent = (change >= 0 ? "+" : "") + formatNumber(data.change, symbol);
        changeElement.className = "info-value change " + (change >= 0 ? "positive" : "negative");

        changePercentElement.textContent = (change >= 0 ? "+" : "") + (data.changePercent || "0.00%");
        changePercentElement.className = "info-value change " + (change >= 0 ? "positive" : "negative");
        
        // Update other fields
        document.getElementById("open").textContent = formatNumber(data.open, symbol);
        document.getElementById("open").className = "info-value";
        
        document.getElementById("high").textContent = formatNumber(data.high, symbol);
        document.getElementById("high").className = "info-value";
        
        document.getElementById("low").textContent = formatNumber(data.low, symbol);
        document.getElementById("low").className = "info-value";
        
        document.getElementById("volume").textContent = formatVolume(data.volume);
        document.getElementById("volume").className = "info-value";
        
        const timeElement = document.getElementById("time");
        timeElement.textContent = data.timestamp || "N/A";
        timeElement.className = "info-value";
        
        console.log("Stock data updated successfully");
    })
    .catch(error => {
        updateUI(false);
        console.error("Fetch error:", error);
        setError("Network error: " + error.message);
    });
}

function setupAutoRefresh() {
    const checkbox = document.getElementById("autoRefresh");
    
    function toggleAutoRefresh() {
        if (checkbox.checked) {
            refreshInterval = setInterval(() => {
                if (!isLoading) {
                    fetchStockData(false);
                }
            }, 10000); // 30 seconds
        } else {
            if (refreshInterval) {
                clearInterval(refreshInterval);
                refreshInterval = null;
            }
        }
    }
    
    checkbox.addEventListener("change", toggleAutoRefresh);
    toggleAutoRefresh(); // Initialize
}

function setupEnterKeyListener() {
    document.getElementById("symbolInput").addEventListener("keypress", function(event) {
        if (event.key === "Enter") {
            fetchStockData(true);
        }
    });
}

// Initialize when page loads
window.addEventListener("load", function() {
    setupAutoRefresh();
    setupEnterKeyListener();
    fetchStockData(true); // Initial load
});

// Cleanup on page unload
window.addEventListener("beforeunload", function() {
    if (refreshInterval) {
        clearInterval(refreshInterval);
    }
});