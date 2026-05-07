package livepricetracker;

import java.io.*;
import java.sql.*;
import javax.servlet.*;
import javax.servlet.http.*;
import org.json.JSONObject;
import org.json.JSONArray;

public class PortfolioServlet extends HttpServlet {

    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws IOException, ServletException {

        resp.setContentType("application/json; charset=UTF-8");
        PrintWriter out = resp.getWriter();

        String username = (String) req.getSession().getAttribute("username");
        if (username == null) {
            out.write("{\"error\":\"Not logged in\"}"); return;
        }

        try (Connection conn = DBConnection.getConnection()) {

            // ── 1. Get balance from users table ───────────────────────────────
            double balance = 100000.0;
            PreparedStatement balStmt = conn.prepareStatement(
                "SELECT balance FROM users WHERE username = ?");
            balStmt.setString(1, username);
            ResultSet balRs = balStmt.executeQuery();
            if (balRs.next()) balance = balRs.getDouble("balance");
            balRs.close(); balStmt.close();

            // ── 2. Get all trades for this user ───────────────────────────────
            JSONArray trades = new JSONArray();
            PreparedStatement tStmt = conn.prepareStatement(
                "SELECT symbol, action, quantity, price, total_value, " +
                "DATE_FORMAT(trade_time, \'%d %b %H:%i\') AS trade_time " +
                "FROM trades WHERE username = ? ORDER BY trade_time ASC");
            tStmt.setString(1, username);
            ResultSet tRs = tStmt.executeQuery();

            // Track buy cost per symbol to compute avgPrice
            java.util.Map<String, Double> totalCost = new java.util.HashMap<>();
            java.util.Map<String, Integer> totalQty  = new java.util.HashMap<>();

            while (tRs.next()) {
                String sym    = tRs.getString("symbol");
                String action = tRs.getString("action");
                int    qty    = tRs.getInt("quantity");
                double price  = tRs.getDouble("price");
                double tv     = tRs.getDouble("total_value");
                String time   = tRs.getString("trade_time");

                JSONObject t = new JSONObject();
                t.put("symbol",     sym);
                t.put("action",     action);
                t.put("quantity",   String.valueOf(qty));
                t.put("price",      String.format("%.2f", price));
                t.put("totalValue", String.format("%.2f", tv));
                t.put("time",       time);
                trades.put(t);

                // Build cost basis for holdings
                if ("BUY".equals(action)) {
                    totalCost.put(sym, totalCost.getOrDefault(sym, 0.0) + price * qty);
                    totalQty.put(sym,  totalQty.getOrDefault(sym,  0)   + qty);
                } else {
                    int    prevQty  = totalQty.getOrDefault(sym, 0);
                    double prevCost = totalCost.getOrDefault(sym, 0.0);
                    double avg      = prevQty > 0 ? prevCost / prevQty : 0;
                    int    newQty   = Math.max(0, prevQty - qty);
                    totalQty.put(sym,  newQty);
                    totalCost.put(sym, avg * newQty);
                }
            }
            tRs.close(); tStmt.close();

            // ── 3. Build holdings JSON ────────────────────────────────────────
            JSONObject holdings  = new JSONObject();
            JSONObject portfolio = new JSONObject();   // kept for backward compat
            for (String sym : totalQty.keySet()) {
                int qty = totalQty.get(sym);
                if (qty <= 0) continue;
                double avg = totalQty.get(sym) > 0
                    ? totalCost.get(sym) / totalQty.get(sym) : 0;
                JSONObject h = new JSONObject();
                h.put("quantity", qty);
                h.put("avgPrice", String.format("%.2f", avg));
                holdings.put(sym, h);
                portfolio.put(sym, qty);
            }

            // ── 4. Send response ──────────────────────────────────────────────
            JSONObject response = new JSONObject();
            response.put("balance",   balance);
            response.put("trades",    trades);
            response.put("holdings",  holdings);
            response.put("portfolio", portfolio);
            out.write(response.toString());

        } catch (SQLException e) {
            e.printStackTrace();
            out.write("{\"error\":\"Database error: " + e.getMessage().replace("\"","'") + "\"}");
        }
    }
}
