// stockChart.js - Reusable Stock Chart Component

let stockChart; // Global reference to chart instance

/**
 * Fetches stock history data using the backend
 * @param {string} symbol - Stock symbol
 * @returns {Object} - Object containing labels and prices arrays
 */
async function fetchStockHistory(symbol) {
    try {
        // Use existing backend endpoint
        const response = await fetch(`getPrice.jsp?symbol=${symbol}`);
        const data = await response.json();
        
        if (data.error) {
            console.error("Backend error:", data.error);
            return { labels: [], prices: [] };
        }
        
        // Generate mock historical data for the last 30 days
        const currentPrice = parseFloat(data.price);
        const labels = [];
        const prices = [];
        
        const today = new Date();
        for (let i = 29; i >= 0; i--) {
            const date = new Date(today);
            date.setDate(date.getDate() - i);
            labels.push(date.toLocaleDateString());
            
            // Generate realistic price variations (±5% from current price)
            const variation = (Math.random() - 0.5) * 0.1; // ±5%
            const historicalPrice = currentPrice * (1 + variation);
            prices.push(Math.max(0, parseFloat(historicalPrice.toFixed(2))));
        }
        
        return { labels, prices };
        
    } catch (error) {
        console.error("Error fetching history:", error);
        return { labels: [], prices: [] };
    }
}

/**
 * Renders a stock chart using Chart.js
 * @param {string} canvasId - ID of the canvas element
 * @param {string} symbol - Stock symbol
 * @param {Object} options - Chart configuration options
 */
async function renderStockChart(canvasId, symbol, options = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) {
        console.error(`Canvas with id '${canvasId}' not found`);
        return;
    }
    
    // IMPORTANT: Remove fixed width/height attributes to prevent sizing issues
    canvas.removeAttribute('width');
    canvas.removeAttribute('height');
    
    const ctx = canvas.getContext('2d');
    const history = await fetchStockHistory(symbol);
    
    // Destroy existing chart if it exists
    if (stockChart) {
        stockChart.destroy();
    }
    
    // Default chart options
    const defaultOptions = {
        type: 'line',
        data: {
            labels: history.labels,
            datasets: [{
                label: `${symbol} Price`,
                data: history.prices,
                borderColor: '#007bff',
                backgroundColor: 'rgba(0, 123, 255, 0.1)',
                tension: 0.2,
                pointRadius: 2,
                pointHoverRadius: 5,
                borderWidth: 2,
                fill: true
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            aspectRatio: 2, // width:height ratio (2:1)
            plugins: {
                legend: { 
                    display: true,
                    position: 'top'
                },
                title: {
                    display: true,
                    text: `${symbol} - 30 Day Price Chart`
                }
            },
            scales: {
                x: { 
                    display: true, 
                    title: { 
                        display: true, 
                        text: "Date",
                        font: { weight: 'bold' }
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.1)'
                    }
                },
                y: { 
                    display: true, 
                    title: { 
                        display: true, 
                        text: "Price ($)",
                        font: { weight: 'bold' }
                    },
                    grid: {
                        color: 'rgba(0, 0, 0, 0.1)'
                    }
                }
            },
            interaction: {
                intersect: false,
                mode: 'index'
            },
            elements: {
                point: {
                    backgroundColor: '#007bff',
                    borderColor: '#fff',
                    borderWidth: 2
                }
            }
        }
    };
    
    // Merge custom options with defaults
    const chartConfig = { ...defaultOptions, ...options };
    
    // Create the chart
    stockChart = new Chart(ctx, chartConfig);
    
    return stockChart;
}

/**
 * Updates the chart with new symbol data
 * @param {string} canvasId - ID of the canvas element
 * @param {string} symbol - New stock symbol
 */
async function updateStockChart(canvasId, symbol) {
    await renderStockChart(canvasId, symbol);
}

/**
 * Destroys the current chart instance
 */
function destroyStockChart() {
    if (stockChart) {
        stockChart.destroy();
        stockChart = null;
    }
}

/**
 * Initialize chart when DOM is ready (optional auto-init function)
 * @param {string} canvasId - ID of the canvas element
 * @param {string} symbol - Stock symbol
 */
function initStockChart(canvasId, symbol) {
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            renderStockChart(canvasId, symbol);
        });
    } else {
        renderStockChart(canvasId, symbol);
    }
}

// Export functions for use in other scripts (if using modules)
// export { renderStockChart, updateStockChart, destroyStockChart, initStockChart };