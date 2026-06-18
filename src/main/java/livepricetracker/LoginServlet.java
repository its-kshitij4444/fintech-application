package livepricetracker;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import java.sql.*;
import java.time.*;

public class LoginServlet extends HttpServlet {
    private boolean isMarketOpen() {
        ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Asia/Kolkata"));
        int day  = now.getDayOfWeek().getValue(); // 1=Mon, 7=Sun
        int hour = now.getHour();
        int min  = now.getMinute();

        if (day >= 6) return false; // Saturday or Sunday

        // Before 9:15 AM or after 3:30 PM
        int timeNow    = hour * 100 + min;
        int marketOpen  = 9 * 100 + 15;   // 915
        int marketClose = 15 * 100 + 30;  // 1530

        return timeNow >= marketOpen && timeNow <= marketClose;
    }

    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String username = request.getParameter("username");
        String rawPassword = request.getParameter("password");
        String password = PasswordUtils.hashPassword(rawPassword);

        if (username == null || username.trim().isEmpty() ||
                rawPassword == null || rawPassword.trim().isEmpty()) {
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
                session.setAttribute("loginTime", ZonedDateTime.now(ZoneId.of("Asia/Kolkata")).toString());
                session.setMaxInactiveInterval(1800);

                PreparedStatement updateStmt = conn.prepareStatement(
                        "UPDATE users SET last_login = NOW() WHERE username = ?");
                updateStmt.setString(1, username.trim());
                updateStmt.executeUpdate();
                updateStmt.close();

                // Auto-generate Breeze session token via Python script
                if(isMarketOpen()) try {
                    String scriptPath = getServletContext().getRealPath("/python/auto_session.py");
                    System.out.println("🐍 Running Python script: " + scriptPath);

                    ProcessBuilder pb = new ProcessBuilder("python", scriptPath);
                    pb.redirectErrorStream(true);
                    Process process = pb.start();

                    BufferedReader reader = new BufferedReader(
                            new InputStreamReader(process.getInputStream())
                    );

                    String sessionToken = null;
                    String line;
                    StringBuilder fullOutput = new StringBuilder();

                    while ((line = reader.readLine()) != null) {
                        line = line.trim();
                        if (!line.isEmpty()) {
                            fullOutput.append(line).append("\n");
                            sessionToken = line;
                        }
                    }

                    int exitCode = process.waitFor();
                    System.out.println("🐍 Python exit code: " + exitCode);
                    System.out.println("📜 Python output:\n" + fullOutput);

                    if (exitCode == 0 && sessionToken != null && !sessionToken.isEmpty()) {
                        session.setAttribute("breezeToken", sessionToken);

                        int previewLen = Math.min(10, sessionToken.length());
                        System.out.println("✅ Breeze token stored: " + sessionToken.substring(0, previewLen) + "...");

                        String jsonBody = "{\"session_token\": \"" + sessionToken + "\"}";

                        String[] backendUrls = {
                                "https://fintech-application-backend.onrender.com/init-session",
                                "http://localhost:5000/init-session"
                        };

                        boolean sent = false;
                        Exception lastError = null;

                        for (String backendUrl : backendUrls) {
                            java.net.HttpURLConnection conn2 = null;
                            try {
                                java.net.URL url = new java.net.URL(backendUrl);
                                conn2 = (java.net.HttpURLConnection) url.openConnection();
                                conn2.setConnectTimeout(5000);
                                conn2.setReadTimeout(5000);
                                conn2.setRequestMethod("POST");
                                conn2.setRequestProperty("Content-Type", "application/json");
                                conn2.setDoOutput(true);

                                System.out.println("📤 Sending token to: " + backendUrl);

                                try (OutputStream os = conn2.getOutputStream()) {
                                    os.write(jsonBody.getBytes("UTF-8"));
                                    os.flush();
                                }

                                int responseCode = conn2.getResponseCode();
                                System.out.println("🔁 Response code from " + backendUrl + ": " + responseCode);

                                InputStream responseStream = (responseCode >= 200 && responseCode < 400)
                                        ? conn2.getInputStream()
                                        : conn2.getErrorStream();

                                if (responseStream != null) {
                                    BufferedReader apiReader = new BufferedReader(new InputStreamReader(responseStream));
                                    String apiLine;
                                    StringBuilder apiResponse = new StringBuilder();
                                    while ((apiLine = apiReader.readLine()) != null) {
                                        apiResponse.append(apiLine);
                                    }
                                    System.out.println("📥 Response body: " + apiResponse);
                                }

                                if (responseCode >= 200 && responseCode < 300) {
                                    sent = true;
                                    System.out.println("✅ Session token accepted by backend: " + backendUrl);
                                    break;
                                }

                            } catch (Exception ex) {
                                lastError = ex;
                                System.out.println("⚠️ Failed calling " + backendUrl + ": " + ex.getMessage());
                            } finally {
                                if (conn2 != null) {
                                    conn2.disconnect();
                                }
                            }
                        }

                        if (!sent) {
                            System.out.println("❌ Could not send session token to any backend endpoint");
                            if (lastError != null) {
                                lastError.printStackTrace();
                            }
                        }

                    } else {
                        System.out.println("⚠️ Token was null/empty or Python script failed");
                    }

                } catch (Exception e) {
                    System.out.println("⚠️ Breeze token fetch failed: " + e.getMessage());
                    e.printStackTrace();
                }

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