package livepricetracker;

import java.io.*;
import java.sql.*;
import javax.servlet.*;
import javax.servlet.http.*;
import org.json.JSONObject;

public class TradeServlet extends HttpServlet {

    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws IOException, ServletException {

        resp.setContentType("application/json; charset=UTF-8");
        PrintWriter out = resp.getWriter();

        try {
            // ── Read parameters ───────────────────────────────────────────────
            String username = (String) req.getSession().getAttribute("username");
            String action   = req.getParameter("action");
            String qty      = req.getParameter("quantity");
            String price    = req.getParameter("price");
            String symbol   = req.getParameter("symbol");

            if (username == null) { out.write("{\"error\":\"Not logged in\"}"); return; }
            if (action == null || qty == null || price == null || symbol == null) {
                out.write("{\"error\":\"Missing parameters\"}"); return;
            }

            int    quantity   = Integer.parseInt(qty);
            double priceValue = Double.parseDouble(price);

            if (quantity <= 0 || priceValue <= 0) {
                out.write("{\"error\":\"Invalid quantity or price\"}"); return;
            }

            double totalValue = quantity * priceValue;

            try (Connection conn = DBConnection.getConnection()) {

                // ── Get current balance from DB ───────────────────────────────
                double balance = 100000.0;
                PreparedStatement balStmt = conn.prepareStatement(
                    "SELECT balance FROM users WHERE username = ?");
                balStmt.setString(1, username);
                ResultSet rs = balStmt.executeQuery();
                if (rs.next()) balance = rs.getDouble("balance");
                rs.close(); balStmt.close();

                // ── Get current holdings for this symbol ──────────────────────
                int currentQty = 0;
                PreparedStatement hStmt = conn.prepareStatement(
                    "SELECT SUM(CASE WHEN action=\'BUY\' THEN quantity ELSE -quantity END) AS net_qty " +
                    "FROM trades WHERE username=? AND symbol=?");
                hStmt.setString(1, username);
                hStmt.setString(2, symbol);
                ResultSet hr = hStmt.executeQuery();
                if (hr.next()) currentQty = hr.getInt("net_qty");
                hr.close(); hStmt.close();

                // ── Validate trade ────────────────────────────────────────────
                if ("buy".equalsIgnoreCase(action)) {
                    if (balance < totalValue) {
                        out.write("{\"error\":\"Insufficient balance. Need Rs." + totalValue + ", Have Rs." + balance + "\"}");
                        return;
                    }
                    balance -= totalValue;
                } else if ("sell".equalsIgnoreCase(action)) {
                    if (currentQty < quantity) {
                        out.write("{\"error\":\"Insufficient shares. Have " + currentQty + ", want to sell " + quantity + "\"}");
                        return;
                    }
                    balance += totalValue;
                } else {
                    out.write("{\"error\":\"Unknown action\"}"); return;
                }

                // ── Save trade to trades table ────────────────────────────────
                PreparedStatement tStmt = conn.prepareStatement(
                    "INSERT INTO trades (username, symbol, action, quantity, price, total_value) " +
                    "VALUES (?, ?, ?, ?, ?, ?)");
                tStmt.setString(1, username);
                tStmt.setString(2, symbol.toUpperCase());
                tStmt.setString(3, action.toUpperCase());
                tStmt.setInt(4, quantity);
                tStmt.setDouble(5, priceValue);
                tStmt.setDouble(6, totalValue);
                tStmt.executeUpdate();
                tStmt.close();

                // ── Update balance in users table ─────────────────────────────
                PreparedStatement uStmt = conn.prepareStatement(
                    "UPDATE users SET balance = ? WHERE username = ?");
                uStmt.setDouble(1, balance);
                uStmt.setString(2, username);
                uStmt.executeUpdate();
                uStmt.close();

                // ── Also update session balance for immediate UI response ──────
                req.getSession().setAttribute("balance", balance);

                JSONObject response = new JSONObject();
                response.put("result",  "success");
                response.put("balance", balance);
                out.write(response.toString());

                System.out.println("Trade saved: " + action + " " + quantity + " " + symbol + " @ " + priceValue);
            }

        } catch (NumberFormatException e) {
            out.write("{\"error\":\"Invalid number: " + e.getMessage().replace("\"","'") + "\"}");
        } catch (SQLException e) {
            e.printStackTrace();
            out.write("{\"error\":\"Database error: " + e.getMessage().replace("\"","'") + "\"}");
        } catch (Exception e) {
            e.printStackTrace();
            out.write("{\"error\":\"Server error: " + e.getMessage().replace("\"","'") + "\"}");
        }
    }
}
