package livepricetracker;

import javax.servlet.*;
import javax.servlet.http.*;
import java.io.*;
import java.util.*;

public class TradeHistoryServlet extends HttpServlet {

    @SuppressWarnings("unchecked")
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {

        HttpSession session = req.getSession();
        List<Map<String, String>> history =
                (List<Map<String, String>>) session.getAttribute("tradeHistory");

        if (history == null) {
            history = new ArrayList<>();
            session.setAttribute("tradeHistory", history);
        }

        // Convert to JSON manually
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < history.size(); i++) {
            Map<String, String> h = history.get(i);
            sb.append("{")
              .append("\"stock\":\"").append(h.get("stock")).append("\",")
              .append("\"action\":\"").append(h.get("action")).append("\",")
              .append("\"price\":\"").append(h.get("price")).append("\",")
              .append("\"time\":\"").append(h.get("time")).append("\"")
              .append("}");
            if (i < history.size() - 1) sb.append(",");
        }
        sb.append("]");

        resp.setContentType("application/json");
        resp.getWriter().write(sb.toString());
    }

    @SuppressWarnings("unchecked")
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {

        HttpSession session = req.getSession();
        List<Map<String, String>> history =
                (List<Map<String, String>>) session.getAttribute("tradeHistory");

        if (history == null) {
            history = new ArrayList<>();
            session.setAttribute("tradeHistory", history);
        }

        String stock = req.getParameter("stock");
        String action = req.getParameter("action");
        String price = req.getParameter("price");

        Map<String, String> record = new HashMap<>();
        record.put("stock", stock);
        record.put("action", action);
        record.put("price", price);
        record.put("time", new Date().toString());
        history.add(record);

        resp.setContentType("application/json");
        resp.getWriter().write("{\"status\":\"ok\"}");
    }
}