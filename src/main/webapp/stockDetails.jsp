<%@ page import="javax.servlet.http.*, javax.servlet.*" %>
<%
    String username = (session != null && session.getAttribute("username") != null) 
                      ? (String) session.getAttribute("username") : null;

    if (username == null) {
        response.sendRedirect("login.jsp");
        return;
    }

    String symbol = request.getParameter("symbol") != null ? request.getParameter("symbol") : "IBM";
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= symbol %></title>
    <link rel="stylesheet" href="css/style.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="js/stockChart.js"></script>
    <script src="js/script.js" defer></script>
</head>
<body>
    <a href="dashboard.jsp" class="back-button">&#8592; Back to Dashboard</a>

    <h2><%= symbol %></h2>
    
	<div class="chart-section" style="margin-top: 20px;">
	    <h3>Stock Price Chart</h3>
	    <div style="width: 100%; position: relative; height: 400px;">
	        <canvas id="stockChart"></canvas>
	    </div>
	</div>
    
    <div class="input-section">
        <input type="hidden" id="symbolInput" value="<%= symbol %>" disabled>
        <button id="fetchBtn" onclick="fetchStockData(true)">Get Quote</button>
    </div>

    <div class="stock-info">
        <div class="info-card">
            <div class="info-label">Symbol</div>
            <div class="info-value" id="symbol">Loading...</div>
        </div>
        
        <div class="info-card">
            <div class="info-label">Current Price</div>
            <div class="info-value price" id="price">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">Change</div>
            <div class="info-value change" id="change">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">Change %</div>
            <div class="info-value change" id="changePercent">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">Open</div>
            <div class="info-value" id="open">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">High</div>
            <div class="info-value" id="high">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">Low</div>
            <div class="info-value" id="low">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">Volume</div>
            <div class="info-value" id="volume">Loading...</div>
        </div>

        <div class="info-card">
            <div class="info-label">Last Updated</div>
            <div class="info-value" id="time">Loading...</div>
        </div>
    </div>
    
    <script>
        document.addEventListener("DOMContentLoaded", function () {
            const symbol = document.getElementById("symbolInput").value;
            
            // Check if functions exist before calling them
            if (typeof fetchStockData === 'function') {
                fetchStockData(true);  // your existing function
            } else {
                console.error('fetchStockData function not found. Make sure script.js is loaded properly.');
            }
            
            if (typeof renderStockChart === 'function') {
                renderStockChart('stockChart', symbol);  // new chart function
            } else {
                console.error('renderStockChart function not found. Make sure stockChart.js is loaded properly.');
            }
        });
    </script>

</body>
</html>