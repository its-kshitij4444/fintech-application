<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <title>Trade History</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Poppins', sans-serif; }
        
        body {
            display: flex;
            height: 100vh;
            background: #f5f6fa;
            color: #333;
        }

        .sidebar {
            width: 250px;
            background: #1e1e2f;
            color: #fff;
            display: flex;
            flex-direction: column;
            padding: 20px;
        }

        .sidebar h2 {
            text-align: center;
            margin-bottom: 30px;
            font-size: 22px;
        }

        .sidebar a {
            color: #bbb;
            text-decoration: none;
            padding: 12px 15px;
            border-radius: 8px;
            margin-bottom: 10px;
            transition: 0.3s;
        }

        .sidebar a:hover, .sidebar a.active {
            background: #4b4b6e;
            color: #fff;
        }

        .main-content {
            flex: 1;
            padding: 30px;
            overflow-y: auto;
        }

        h1 {
            margin-bottom: 30px;
            color: #1e1e2f;
            text-align: center;
        }

        .card {
            background: #fff;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.1);
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }

        thead {
            background: #4b4b6e;
            color: white;
        }

        th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }

        td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }

        tbody tr:hover {
            background: #f9f9f9;
        }

        .buy {
            color: #28a745;
            font-weight: 600;
        }

        .sell {
            color: #dc3545;
            font-weight: 600;
        }

        .no-trades {
            text-align: center;
            padding: 40px;
            color: #999;
            font-size: 16px;
        }

        .price {
            color: #4b4b6e;
            font-weight: 600;
        }

        .refresh-btn {
            background: #4b4b6e;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 14px;
            margin-bottom: 15px;
            transition: 0.3s;
        }

        .refresh-btn:hover {
            background: #3a3a52;
        }

        .header-section {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }

        @media(max-width: 900px) {
            body { flex-direction: column; }
            .sidebar { width: 100%; }
            .main-content { padding: 15px; }
            table { font-size: 14px; }
            th, td { padding: 10px; }
        }
    </style>
</head>
<body>

    <div class="sidebar">
        <h2>📈 Trading App</h2>
        <a href="dashboard.jsp">Dashboard</a>
        <a href="index.jsp">Search Stocks</a>
        <a href="paperTrading.jsp">Practice Trading</a>
        <a href="profile.jsp">Profile</a>
        <a href="TradeHistory.jsp" class="active">Trade History</a>
        <a href="settings.jsp">Settings</a>
        <form action="LogoutServlet" method="post" style="margin-top: auto;">
            <button type="submit" style="width:100%; padding:12px; background:#dc3545; color:#fff; border:none; border-radius:8px; cursor:pointer; font-weight:600;">Logout</button>
        </form>
    </div>

    <div class="main-content">
        <div class="header-section">
            <h1>📜 Trade History</h1>
            <button class="refresh-btn" onclick="loadTradeHistory()">🔄 Refresh</button>
        </div>

        <div class="card">
            <table>
                <thead>
                    <tr>
                        <th>Stock Symbol</th>
                        <th>Action</th>
                        <th>Quantity</th>
                        <th>Price (₹)</th>
                        <th>Total Value (₹)</th>
                        <th>Time</th>
                    </tr>
                </thead>
                <tbody id="tradeTableBody">
                    <tr><td colspan="6" class="no-trades">Loading trades...</td></tr>
                </tbody>
            </table>
        </div>
    </div>

    <script>
    async function loadTradeHistory() {
        try {
            const response = await fetch('PortfolioServlet');
            const data = await response.json();
            
            console.log('Trade data:', data);
            
            const tbody = document.getElementById('tradeTableBody');
            tbody.innerHTML = '';
            
            if (!data.trades || data.trades.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" class="no-trades">No trades yet. Start trading to see history!</td></tr>';
                return;
            }
            
            // Display trades in reverse order (latest first)
            data.trades.slice().reverse().forEach(trade => {
                const row = document.createElement('tr');
                
                const actionClass = trade.action === 'BUY' ? 'buy' : 'sell';
                
                row.innerHTML = '<td>' + (trade.symbol || 'UNKNOWN') + '</td>' +  // USE SYMBOL FROM TRADE
                                '<td class="' + actionClass + '">' + trade.action + '</td>' +
                                '<td>' + trade.quantity + '</td>' +
                                '<td class="price">₹' + parseFloat(trade.price).toFixed(2) + '</td>' +
                                '<td class="price">₹' + parseFloat(trade.totalValue).toFixed(2) + '</td>' +
                                '<td>' + trade.time + '</td>';
                
                tbody.appendChild(row);
            });
            
        } catch (error) {
            console.error('Error loading trades:', error);
            document.getElementById('tradeTableBody').innerHTML = 
                '<tr><td colspan="6" class="no-trades">Error loading trades. Please refresh the page.</td></tr>';
        }
    }

    // Load trades on page load
    loadTradeHistory();
    
    // Auto-refresh every 5 seconds
    setInterval(loadTradeHistory, 5000);
</script>


</body>
</html>
