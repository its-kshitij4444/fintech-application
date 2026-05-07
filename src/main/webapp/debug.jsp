<%@ page language="java" contentType="application/json; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*" %>
<%
    // Drop this file in webapp/ and open http://localhost:8080/debug.jsp
    // It shows exactly what is stored in your session right now

    response.setContentType("application/json");

    HttpSession s = request.getSession(false);
    if (s == null) {
        out.print("{\"session\": \"NULL — no session exists\"}");
        return;
    }

    StringBuilder sb = new StringBuilder();
    sb.append("{");
    sb.append("\"sessionId\":\"").append(s.getId()).append("\",");

    // balance
    Object bal = s.getAttribute("balance");
    sb.append("\"balance\":").append(bal != null ? bal.toString() : "null").append(",");

    // trades
    List<Map<String,String>> trades = (List<Map<String,String>>) s.getAttribute("trades");
    sb.append("\"tradeCount\":").append(trades != null ? trades.size() : 0).append(",");
    sb.append("\"trades\":");
    if (trades == null || trades.isEmpty()) {
        sb.append("[]");
    } else {
        sb.append("[");
        for (int i = 0; i < trades.size(); i++) {
            Map<String,String> t = trades.get(i);
            sb.append("{");
            sb.append("\"action\":\"").append(t.get("action")).append("\",");
            sb.append("\"symbol\":\"").append(t.get("symbol")).append("\",");
            sb.append("\"qty\":\"").append(t.get("quantity")).append("\",");
            sb.append("\"price\":\"").append(t.get("price")).append("\",");
            sb.append("\"time\":\"").append(t.get("time")).append("\"");
            sb.append("}");
            if (i < trades.size()-1) sb.append(",");
        }
        sb.append("]");
    }

    // portfolio
    Map<String,Object> portfolio = (Map<String,Object>) s.getAttribute("portfolio");
    sb.append(",\"portfolio\":");
    if (portfolio == null) {
        sb.append("null");
    } else {
        sb.append("{");
        boolean first = true;
        for (Map.Entry<String,Object> e : portfolio.entrySet()) {
            if (!first) sb.append(",");
            sb.append("\"").append(e.getKey()).append("\":");
            sb.append("\"").append(e.getValue()).append("\"");
            first = false;
        }
        sb.append("}");
    }

    sb.append("}");
    out.print(sb.toString());
%>