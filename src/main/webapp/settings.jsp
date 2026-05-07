<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%
    // Retrieve logged-in user details from session
    String username = (String) session.getAttribute("username");
    
    // Redirect to login if not authenticated
    if (username == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    
    // ✅ Get saved preferences from session (with defaults)
    Boolean autoExecute = (Boolean) session.getAttribute("autoExecute");
    Boolean riskAlerts = (Boolean) session.getAttribute("riskAlerts");
    Boolean realtimePrices = (Boolean) session.getAttribute("realtimePrices");
    Boolean emailNotify = (Boolean) session.getAttribute("emailNotify");
    Boolean smsAlerts = (Boolean) session.getAttribute("smsAlerts");
    Boolean pushNotify = (Boolean) session.getAttribute("pushNotify");
    Boolean darkTheme = (Boolean) session.getAttribute("darkTheme");
    Boolean soundEffects = (Boolean) session.getAttribute("soundEffects");
    Boolean shareStats = (Boolean) session.getAttribute("shareStats");
    Boolean analytics = (Boolean) session.getAttribute("analytics");
    
    // Set defaults if not in session yet
    if (autoExecute == null) autoExecute = false;
    if (riskAlerts == null) riskAlerts = true;
    if (realtimePrices == null) realtimePrices = true;
    if (emailNotify == null) emailNotify = true;
    if (smsAlerts == null) smsAlerts = false;
    if (pushNotify == null) pushNotify = true;
    if (darkTheme == null) darkTheme = false;
    if (soundEffects == null) soundEffects = true;
    if (shareStats == null) shareStats = false;
    if (analytics == null) analytics = true;
%>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Settings | Trading Dashboard</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Poppins', sans-serif; }
    body {
      display: flex;
      height: 100vh;
      background: #f5f6fa;
      color: #333;
    }

    /* Sidebar */
    .sidebar {
      width: 250px;
      background: #1e1e2f;
      color: #fff;
      display: flex;
      flex-direction: column;
      padding: 20px;
    }

    .sidebar h2 { text-align: center; margin-bottom: 30px; font-size: 22px; }

    .sidebar a {
      color: #bbb;
      text-decoration: none;
      padding: 12px 15px;
      border-radius: 8px;
      margin-bottom: 10px;
      transition: 0.3s;
    }

    .sidebar a:hover, .sidebar a.active { background: #4b4b6e; color: #fff; }

    /* Main content */
    .main-content {
      flex: 1;
      padding: 30px;
      overflow-y: auto;
    }

    h1 { margin-bottom: 10px; }
    
    .subtitle {
      color: #666;
      margin-bottom: 30px;
      font-size: 14px;
    }

    .card {
      background: #fff;
      border-radius: 12px;
      padding: 25px;
      margin-bottom: 20px;
      box-shadow: 0 2px 6px rgba(0,0,0,0.1);
    }

    .card h3 { 
      margin-bottom: 20px; 
      color: #4b4b6e;
      font-size: 18px;
    }

    label {
      display: block;
      margin-top: 15px;
      font-weight: 500;
      margin-bottom: 5px;
    }

    select {
      width: 100%;
      padding: 10px;
      margin-top: 5px;
      border: 1px solid #ccc;
      border-radius: 8px;
      outline: none;
      transition: 0.3s;
    }

    select:focus { border-color: #4b4b6e; }

    .toggle {
      display: flex;
      align-items: center;
      padding: 12px 0;
      border-bottom: 1px solid #f0f0f0;
      transition: all 0.3s ease;
    }

    .toggle:last-child { border-bottom: none; }

    .toggle label {
      flex: 1;
      margin: 0;
      font-weight: 500;
    }

    .toggle input[type="checkbox"] { 
      width: 20px;
      height: 20px;
      cursor: pointer;
    }

    /* Hidden toggle styling */
    .toggle.hidden {
      display: none;
    }

    .save-btn {
      background: #4b4b6e;
      color: #fff;
      border: none;
      padding: 12px 25px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 16px;
      transition: 0.3s;
      margin-top: 20px;
    }

    .save-btn:hover { background: #373757; }

    .info-note {
      background: #e7f3ff;
      padding: 12px;
      border-radius: 8px;
      margin-top: 15px;
      font-size: 13px;
      color: #0066cc;
    }

    .warning-note {
      background: #fff3cd;
      padding: 12px;
      border-radius: 8px;
      margin-top: 15px;
      font-size: 13px;
      color: #856404;
      border: 1px solid #ffeeba;
    }

    @media(max-width:900px){ .sidebar{display:none;} }
    
    /* Alert Messages */
	.alert {
	    padding: 15px 20px;
	    border-radius: 8px;
	    margin-bottom: 20px;
	    font-size: 14px;
	    font-weight: 500;
	    display: flex;
	    align-items: center;
	    gap: 10px;
	    animation: slideIn 0.3s ease-out;
	}
	
	.alert-success {
	    background: #d4edda;
	    color: #155724;
	    border: 1px solid #c3e6cb;
	}
	
	.alert-error {
	    background: #f8d7da;
	    color: #721c24;
	    border: 1px solid #f5c6cb;
	}
	
	@keyframes slideIn {
	    from {
	        opacity: 0;
	        transform: translateY(-10px);
	    }
	    to {
	        opacity: 1;
	        transform: translateY(0);
	    }
	}
	    
  </style>
</head>
<body>

  <!-- Sidebar -->
  <div class="sidebar">
    <h2>My Dashboard</h2>
    <a href="dashboard.jsp">Dashboard</a>
    <a href="index.jsp">Search Stocks</a>
    <a href="paperTrading.jsp">Practice Trading</a>
    <a href="profile.jsp">Profile</a>
    <a href="#">Trade History</a>
    <a href="settings.jsp" class="active">Settings</a>
    <form action="LogoutServlet" method="post" style="margin-top: auto;">
      <button type="submit" style="width:100%; padding:12px; background:#dc3545; color:#fff; border:none; border-radius:8px; cursor:pointer;">Logout</button>
    </form>
  </div>

  <!-- Main Settings Area -->
  <div class="main-content">
  
    <%
      // Display success/error messages
      String success = request.getParameter("success");
      String error = request.getParameter("error");
      
      if (success != null) {
	  %>
	      <div class="alert alert-success">
	          ✅ <%= success %>
	      </div>
	  <%
	      }
	      if (error != null) {
	  %>
	      <div class="alert alert-error">
	          ❌ <%= error %>
	      </div>
	  <%
	      }
	  %>
    <h1>Settings</h1>
    <p class="subtitle">Manage your trading preferences and app settings</p>

    <!-- Trading Preferences -->
    <div class="card">
      <h3>⚙️ Trading Preferences</h3>
      <form action="UpdateSettingsServlet" method="post">
        <label>Trading Mode</label>
        <select name="tradeMode" id="tradeMode" onchange="toggleTradingOptions()">
          <option value="paper" selected>Paper Trading (Practice Mode)</option>
          <option value="live">Live Trading</option>
        </select>

        <div class="info-note" id="paperNote">
          📌 Paper trading lets you practice with virtual money without any real risk.
        </div>

        <div class="warning-note" id="liveNote" style="display: none;">
          ⚠️ Live trading uses real money. Please ensure you understand the risks involved.
        </div>

        <!-- Trading Preferences Section -->
		<div style="margin-top: 20px;">
		    <!-- Only shown in Live Trading mode -->
		    <div class="toggle hidden" id="autoExecuteToggle">
		        <label>Auto Execute Trades</label>
		        <input type="checkbox" name="autoExecute" id="autoExecute" <%= autoExecute ? "checked" : "" %> />
		    </div>
		
		    <!-- Only shown in Live Trading mode -->
		    <div class="toggle hidden" id="riskAlertsToggle">
		        <label>Enable Risk Alerts</label>
		        <input type="checkbox" name="riskAlerts" id="riskAlerts" <%= riskAlerts ? "checked" : "" %> />
		    </div>
		
		    <!-- Always shown (both Paper and Live) -->
		    <div class="toggle" id="realtimePricesToggle">
		        <label>Show Real-Time Price Updates</label>
		        <input type="checkbox" name="realtimePrices" id="realtimePrices" <%= realtimePrices ? "checked" : "" %> />
		    </div>
		</div>


        <button type="submit" name="action" value="updateTrading" class="save-btn">Save Trading Preferences</button>
      </form>
    </div>

    <!-- Notification and Theme -->
    <div class="card">
      <h3>🔔 Notifications & Display</h3>
      <form action="UpdateSettingsServlet" method="post">
        
        <!-- Notification & Display Section -->
		<div class="toggle">
		    <label>Email Notifications</label>
		    <input type="checkbox" name="emailNotify" id="emailNotify" <%= emailNotify ? "checked" : "" %> />
		</div>
		
		<div class="toggle">
		    <label>SMS Alerts</label>
		    <input type="checkbox" name="smsAlerts" id="smsAlerts" <%= smsAlerts ? "checked" : "" %> />
		</div>
		
		<div class="toggle">
		    <label>Push Notifications</label>
		    <input type="checkbox" name="pushNotify" id="pushNotify" <%= pushNotify ? "checked" : "" %> />
		</div>
		
		<div class="toggle">
		    <label>Dark Theme</label>
		    <input type="checkbox" name="darkTheme" id="darkTheme" <%= darkTheme ? "checked" : "" %> />
		</div>
		
		<div class="toggle">
		    <label>Sound Effects</label>
		    <input type="checkbox" name="soundEffects" id="soundEffects" <%= soundEffects ? "checked" : "" %> />
		</div>


        <button type="submit" name="action" value="updatePreferences" class="save-btn">Save Preferences</button>
      </form>
    </div>

    <!-- Data & Privacy -->
    <div class="card">
      <h3>🔒 Data & Privacy</h3>
      <form action="UpdateSettingsServlet" method="post">
        
        <!-- Data & Privacy Section -->
		<div class="toggle">
		    <label>Share Trading Statistics</label>
		    <input type="checkbox" name="shareStats" id="shareStats" <%= shareStats ? "checked" : "" %> />
		</div>
		
		<div class="toggle">
		    <label>Allow Analytics Tracking</label>
		    <input type="checkbox" name="analytics" id="analytics" <%= analytics ? "checked" : "" %> />
		</div>


        <div class="info-note">
          🔐 For account security settings, visit your <a href="profile.jsp" style="color:#0066cc; font-weight:600;">Profile Page</a>
        </div>

        <button type="submit" name="action" value="updatePrivacy" class="save-btn">Save Privacy Settings</button>
      </form>
    </div>
  </div>

  <script>
    // Function to toggle trading options based on selected mode
    function toggleTradingOptions() {
      const tradeMode = document.getElementById('tradeMode').value;
      const autoExecuteToggle = document.getElementById('autoExecuteToggle');
      const riskAlertsToggle = document.getElementById('riskAlertsToggle');
      const paperNote = document.getElementById('paperNote');
      const liveNote = document.getElementById('liveNote');
      
      if (tradeMode === 'paper') {
        // Paper Trading mode - hide advanced options
        autoExecuteToggle.classList.add('hidden');
        riskAlertsToggle.classList.add('hidden');
        paperNote.style.display = 'block';
        liveNote.style.display = 'none';
      } else {
        // Live Trading mode - show all options
        autoExecuteToggle.classList.remove('hidden');
        riskAlertsToggle.classList.remove('hidden');
        paperNote.style.display = 'none';
        liveNote.style.display = 'block';
      }
    }

    // Initialize on page load
    window.addEventListener('DOMContentLoaded', function() {
      toggleTradingOptions();
    });
  </script>

</body>
</html>
