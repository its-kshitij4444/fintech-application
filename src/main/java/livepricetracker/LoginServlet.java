package livepricetracker;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import java.sql.*;
import java.time.*;

public class LoginServlet extends HttpServlet {
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String username = request.getParameter("username");
        String password = PasswordUtils.hashPassword(request.getParameter("password"));

        if (username == null || username.trim().isEmpty() ||
                password == null || password.isEmpty()) {
            response.sendRedirect("login.jsp?error=Please enter username and password");
            return;
        }

        Connection conn = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {
            conn = DBConnection.getConnection();

            ps = conn.prepareStatement(
                    "SELECT id, username, first_name, last_name, email, phone, mobile, address, created_at, account_type " +
                            "FROM users WHERE username=? AND password=?");
            ps.setString(1, username.trim());
            ps.setString(2, password);

            rs = ps.executeQuery();

            if (rs.next()) {
                HttpSession session = request.getSession();
                session.setAttribute("userId", rs.getInt("id"));
                session.setAttribute("username", rs.getString("username"));
                session.setAttribute("firstName", rs.getString("first_name"));
                session.setAttribute("lastName", rs.getString("last_name"));
                session.setAttribute("email", rs.getString("email"));
                session.setAttribute("phone", rs.getString("phone"));
                session.setAttribute("mobile", rs.getString("mobile"));
                session.setAttribute("address", rs.getString("address"));
                session.setAttribute("memberSince", rs.getString("created_at"));
                session.setAttribute("accountType", rs.getString("account_type"));

                PreparedStatement updateStmt = conn.prepareStatement(
                        "UPDATE users SET last_login = NOW() WHERE username = ?");
                updateStmt.setString(1, username);
                updateStmt.executeUpdate();
                updateStmt.close();

                session.setAttribute("loginTime", ZonedDateTime.now(ZoneId.of("Asia/Kolkata")).toString());
                session.setMaxInactiveInterval(1800);

                // ── Auto-generate Breeze session token via Python script ──
                try {
                    String scriptPath = getServletContext().getRealPath("/python/auto_session.py");

                    ProcessBuilder pb = new ProcessBuilder("python", scriptPath);
                    pb.redirectErrorStream(true);
                    Process process = pb.start();

                    BufferedReader reader = new BufferedReader(
                            new InputStreamReader(process.getInputStream())
                    );

                    String sessionToken = null;
                    String line;
                    while ((line = reader.readLine()) != null) {
                        line = line.trim();
                        if (!line.isEmpty()) {
                            sessionToken = line;
                        }
                    }
                    process.waitFor();

                    System.out.println("🔑 Raw token received: [" + sessionToken + "]");

                    if (sessionToken != null && !sessionToken.isEmpty()) {
                        session.setAttribute("breezeToken", sessionToken);

                        int previewLen = Math.min(10, sessionToken.length());
                        System.out.println("✅ Breeze token stored: " + sessionToken.substring(0, previewLen));

                        java.net.URL url = new java.net.URL("http://localhost:5000/init-session");
                        java.net.HttpURLConnection conn2 = (java.net.HttpURLConnection) url.openConnection();
                        conn2.setRequestMethod("POST");
                        conn2.setRequestProperty("Content-Type", "application/json");
                        conn2.setDoOutput(true);

                        String jsonBody = "{\"session_token\": \"" + sessionToken + "\"}";
                        System.out.println("📤 Sending to Flask: " + jsonBody);

                        try (OutputStream os = conn2.getOutputStream()) {
                            os.write(jsonBody.getBytes("UTF-8"));
                        }

                        int responseCode = conn2.getResponseCode();
                        System.out.println("🔁 Flask /init-session response code: " + responseCode);
                        conn2.disconnect();

                    } else {
                        System.out.println("⚠️ Token was null or empty after script ran");
                    }

                } catch (Exception e) {
                    System.out.println("⚠️ Breeze token fetch failed: " + e.getMessage());
                    e.printStackTrace();
                }
                // ─────────────────────────────────────────────────────────

                response.sendRedirect("dashboard.jsp");

            } else {
                response.sendRedirect("login.jsp?error=Invalid username or password");
            }

        } catch (SQLException e) {
            e.printStackTrace();
            response.sendRedirect("login.jsp?error=Database error occurred");
        } finally {
            try {
                if (rs != null) rs.close();
                if (ps != null) ps.close();
                if (conn != null) conn.close();
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }
}