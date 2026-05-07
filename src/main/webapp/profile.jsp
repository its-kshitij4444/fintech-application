<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.time.*" %>
<%@ page import="java.time.format.DateTimeFormatter" %>
<%
    // Get user info from session
    String username = (String) session.getAttribute("username");
    String firstName = (String) session.getAttribute("firstName");
    String lastName = (String) session.getAttribute("lastName");
    String email = (String) session.getAttribute("email");
    String phone = (String) session.getAttribute("phone");
    String mobile = (String) session.getAttribute("mobile");
    String address = (String) session.getAttribute("address");
    
    if (username == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    
    // Build full name from first and last name
    String fullName = (firstName != null && lastName != null) ? firstName + " " + lastName : username;
    
    // Use actual session data or provide sensible defaults
    String userEmail = (email != null) ? email : "Not provided";
    String userPhone = (phone != null) ? phone : "Not provided";
    String userMobile = (mobile != null) ? mobile : "Not provided";
    String location = (address != null) ? address : "Not provided";
    
    // Account information
    String role = "Stock Trader";
    String accountType = "Paper Trader"; // Can be made dynamic later
    String memberSince = (String) session.getAttribute("memberSince"); // Can fetch from database later
    
    
 	//  Get login time from session (stored during login)
    String loginTimeStr = (String) session.getAttribute("loginTime");
    String lastLogin = "Not available";
    
    // Last login time (current session start)
    if (loginTimeStr != null) {
        try {
            ZonedDateTime loginTime = ZonedDateTime.parse(loginTimeStr);
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MMM dd, yyyy hh:mm a");
            lastLogin = loginTime.format(formatter) + " IST";
        } catch (Exception e) {
            lastLogin = "Invalid date";
        }
    }
%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>User Profile - <%= username %></title>
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    
    html, body {
      height: 100%;
    }
    
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: #f0f2f5;
      display: flex;
      overflow: hidden;
    }
    
    /* Sidebar */
    .sidebar {
      width: 250px;
      background: #1e1e2f;
      color: #fff;
      display: flex;
      flex-direction: column;
      padding: 20px;
      height: 100vh;
      position: fixed;
      left: 0;
      top: 0;
      overflow-y: auto;
    }

    .sidebar h2 {
      text-align: center;
      margin-bottom: 30px;
      font-size: 22px;
      color: #fff;
    }

    .sidebar a {
      color: #bbb;
      text-decoration: none;
      padding: 12px 15px;
      border-radius: 8px;
      margin-bottom: 10px;
      transition: 0.3s;
    }

    .sidebar a:hover,
    .sidebar a.active {
      background: #4b4b6e;
      color: #fff;
    }
    
    /* Main Content Area */
    .main-content {
      margin-left: 250px;
      flex: 1;
      padding: 20px;
      overflow-y: auto;
      height: 100vh;
    }
    
    .page-wrapper {
      max-width: 1200px;
      margin: 0 auto;
      display: grid;
      grid-template-columns: 280px 1fr;
      gap: 20px;
    }
    
    /* Left Profile Card */
    .profile-card {
      background: white;
      border-radius: 8px;
      padding: 30px 20px;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
      height: fit-content;
    }
    
    .avatar {
      width: 120px;
      height: 120px;
      border-radius: 50%;
      margin: 0 auto 15px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 48px;
      color: white;
      font-weight: bold;
    }
    
    .profile-card h2 {
      font-size: 22px;
      margin-bottom: 5px;
      color: #2c3e50;
    }
    
    .profile-card .role {
      color: #7f8c8d;
      font-size: 14px;
      margin-bottom: 5px;
    }
    
    .profile-card .location {
      color: #95a5a6;
      font-size: 13px;
      margin-bottom: 20px;
    }
    
    /* Right Content */
    .profile-content {
      display: flex;
      flex-direction: column;
      gap: 20px;
    }
    
    .info-card {
      background: white;
      border-radius: 8px;
      padding: 25px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08);
    }
    
    .card-header {
      font-size: 16px;
      font-weight: 600;
      color: #2c3e50;
      margin-bottom: 20px;
      padding-bottom: 10px;
      border-bottom: 2px solid #f0f2f5;
    }
    
    .info-row {
      display: grid;
      grid-template-columns: 150px 1fr;
      padding: 15px 0;
      border-bottom: 1px solid #f0f2f5;
    }
    
    .info-row:last-child {
      border-bottom: none;
    }
    
    .info-label {
      font-weight: 600;
      color: #2c3e50;
      font-size: 14px;
    }
    
    .info-value {
      color: #7f8c8d;
      font-size: 14px;
    }
    
    .badge {
      display: inline-block;
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: 600;
    }
    
    .badge-paper {
      background: #e3f2fd;
      color: #1976d2;
    }
    
    .badge-live {
      background: #e8f5e9;
      color: #388e3c;
    }
    
    .edit-btn {
      background: #007bff;
      color: white;
      border: none;
      padding: 8px 20px;
      border-radius: 5px;
      cursor: pointer;
      font-size: 14px;
    }
    
    .edit-btn:hover {
      background: #0056b3;
    }
    
    @media(max-width: 1024px) {
      .sidebar {
        width: 200px;
      }
      
      .main-content {
        margin-left: 200px;
      }
      
      .page-wrapper {
        grid-template-columns: 1fr;
      }
    }
    
    @media(max-width: 768px) {
      .sidebar {
        width: 100%;
        height: auto;
        position: relative;
      }
      
      .main-content {
        margin-left: 0;
        height: auto;
      }
      
      body {
        flex-direction: column;
        overflow: auto;
      }
    }
  </style>
</head>
<body>

  <!-- Sidebar -->
  <div class="sidebar">
    	<a href="dashboard.jsp">Dashboard</a>
    	<a href="index.jsp">Search Stocks</a>
<!--     <a href="trade.jsp">Live Trades</a> -->
<!--     <a href="analytics.jsp">Analytics</a> -->
        <a href="paperTrading.jsp">Practice Trading</a>
        <a href="profile.jsp">Profile</a>
        <a href="#">Trade History</a>
        <a href="settings.jsp">Settings</a>
    <form action="LogoutServlet" method="post" style="margin-top: auto;">
      <button type="submit" style="width:100%; padding:12px; background:#dc3545; color:#fff; border:none; border-radius:8px; cursor:pointer;">Logout</button>
    </form>
  </div>
  
  <!-- Main Content -->
  <div class="main-content">
    <div class="page-wrapper">
      <!-- Profile Card -->
      <div class="profile-card">
        <div class="avatar">
          <%= fullName.substring(0,1).toUpperCase() %>
        </div>
        <h2><%= fullName %></h2>
        <p class="role"><%= role %></p>
        <p class="location"><%= location %></p>
      </div>

      <!-- Contact Information & Account Status -->
      <div class="profile-content">
        <!-- Contact Information -->
        <div class="info-card">
          <div class="card-header">Contact Information</div>
          <div class="info-row">
            <div class="info-label">Full Name</div>
            <div class="info-value"><%= fullName %></div>
          </div>
          <div class="info-row">
            <div class="info-label">Email</div>
            <div class="info-value"><%= userEmail %></div>
          </div>
          <div class="info-row">
            <div class="info-label">Phone</div>
            <div class="info-value"><%= userPhone %></div>
          </div>
          <div class="info-row">
            <div class="info-label">Mobile</div>
            <div class="info-value"><%= userMobile %></div>
          </div>
          <div class="info-row">
            <div class="info-label">Address</div>
            <div class="info-value"><%= location %></div>
          </div>
          <div style="margin-top: 15px;">
            <button class="edit-btn" onclick="window.location.href='editProfile.jsp'">Edit Profile</button>
          </div>
        </div>

        <!-- Account Status -->
        <div class="info-card">
          <div class="card-header">Account Status</div>
          <div class="info-row">
            <div class="info-label">Account Type</div>
            <div class="info-value">
              <span class="badge badge-paper"><%= accountType %></span>
            </div>
          </div>
          <div class="info-row">
            <div class="info-label">Member Since</div>
            <div class="info-value"><%= memberSince %></div>
          </div>
          <div class="info-row">
            <div class="info-label">Last Login</div>
            <div class="info-value"><%= lastLogin %></div>
          </div>
        </div>
      </div>
    </div>
  </div>

</body>
</html>
