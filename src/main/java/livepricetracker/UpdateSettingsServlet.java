package livepricetracker;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import java.sql.*;

public class UpdateSettingsServlet extends HttpServlet {
    
    private static final String DB_URL = "jdbc:mysql://localhost:3306/userdb";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "root123";
    
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        
        // Check if user is logged in
        if (session == null || session.getAttribute("username") == null) {
            response.sendRedirect("login.jsp?error=Please login first");
            return;
        }
        
        String username = (String) session.getAttribute("username");
        String action = request.getParameter("action");
        
        // Route to appropriate handler based on action
        if ("updateTrading".equals(action)) {
            handleTradingPreferences(request, response, session, username);
        } else if ("updatePreferences".equals(action)) {
            handleNotificationPreferences(request, response, session);
        } else if ("updatePrivacy".equals(action)) {
            handlePrivacySettings(request, response, session);
        } else {
            response.sendRedirect("settings.jsp?error=Invalid action");
        }
    }
    
    // Handle Trading Preferences Update
    private void handleTradingPreferences(HttpServletRequest request, HttpServletResponse response, 
                                         HttpSession session, String username) 
            throws ServletException, IOException {
        
        String tradeMode = request.getParameter("tradeMode");
        boolean autoExecute = "on".equals(request.getParameter("autoExecute"));
        boolean riskAlerts = "on".equals(request.getParameter("riskAlerts"));
        boolean realtimePrices = "on".equals(request.getParameter("realtimePrices"));
        
        Connection conn = null;
        PreparedStatement ps = null;
        
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            conn = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD);
            
            // Update account_type based on trade mode
            String accountType = "paper".equals(tradeMode) ? "Paper Trader" : "Live Trader";
            
            ps = conn.prepareStatement(
                "UPDATE users SET account_type = ? WHERE username = ?");
            ps.setString(1, accountType);
            ps.setString(2, username);
            
            int rowsUpdated = ps.executeUpdate();
            
            if (rowsUpdated > 0) {
                // Update session with new account type
                session.setAttribute("accountType", accountType);
                
                // Store preferences in session (you can add a settings table later)
                session.setAttribute("tradeMode", tradeMode);
                session.setAttribute("autoExecute", autoExecute);
                session.setAttribute("riskAlerts", riskAlerts);
                session.setAttribute("realtimePrices", realtimePrices);
                
                response.sendRedirect("settings.jsp?success=Trading preferences updated successfully");
            } else {
                response.sendRedirect("settings.jsp?error=Failed to update preferences");
            }
            
        } catch (SQLException e) {
            e.printStackTrace();
            response.sendRedirect("settings.jsp?error=Database error: " + e.getMessage());
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
            response.sendRedirect("settings.jsp?error=Database driver not found");
        } finally {
            try {
                if (ps != null) ps.close();
                if (conn != null) conn.close();
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }
    
    // Handle Notification & Display Preferences
    private void handleNotificationPreferences(HttpServletRequest request, HttpServletResponse response, 
                                              HttpSession session) 
            throws ServletException, IOException {
        
        boolean emailNotify = "on".equals(request.getParameter("emailNotify"));
        boolean smsAlerts = "on".equals(request.getParameter("smsAlerts"));
        boolean pushNotify = "on".equals(request.getParameter("pushNotify"));
        boolean darkTheme = "on".equals(request.getParameter("darkTheme"));
        boolean soundEffects = "on".equals(request.getParameter("soundEffects"));
        
        // Store in session (you can create a user_preferences table later for persistence)
        session.setAttribute("emailNotify", emailNotify);
        session.setAttribute("smsAlerts", smsAlerts);
        session.setAttribute("pushNotify", pushNotify);
        session.setAttribute("darkTheme", darkTheme);
        session.setAttribute("soundEffects", soundEffects);
        
        response.sendRedirect("settings.jsp?success=Notification preferences saved successfully");
    }
    
    // Handle Data & Privacy Settings
    private void handlePrivacySettings(HttpServletRequest request, HttpServletResponse response, 
                                      HttpSession session) 
            throws ServletException, IOException {
        
        boolean shareStats = "on".equals(request.getParameter("shareStats"));
        boolean analytics = "on".equals(request.getParameter("analytics"));
        
        // Store in session
        session.setAttribute("shareStats", shareStats);
        session.setAttribute("analytics", analytics);
        
        response.sendRedirect("settings.jsp?success=Privacy settings updated successfully");
    }
}
