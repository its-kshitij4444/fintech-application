

<%@ page import="java.net.*, java.io.*" %>
<%@ page import="org.json.*" %>
<%@ page contentType="application/json; charset=UTF-8" pageEncoding="UTF-8" %>
<%
    response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    response.setHeader("Pragma", "no-cache");
    response.setDateHeader("Expires", 0);

    try {
        String symbol = request.getParameter("symbol");
        if (symbol == null || symbol.trim().isEmpty()) {
            symbol = "TCS";
        }
        symbol = symbol.trim().toUpperCase();

        // Remove .NS / .BO suffix — Breeze uses plain codes (TCS, WIPRO, SBIN)
        symbol = symbol.replaceAll("\\.(NS|BO|BSE|NSE)$", "");

        if (!symbol.matches("^[A-Z0-9]{1,20}$")) {
            out.print("{\"error\": \"Invalid symbol. Use plain NSE code like TCS, WIPRO, INFY\"}");
            return;
        }

        // ── Call local Flask/Breeze server instead of Yahoo Finance ──
        String exchange = request.getParameter("exchange");
        if (exchange == null || exchange.trim().isEmpty()) exchange = "NSE";
        exchange = exchange.trim().toUpperCase();

        String flaskUrl = "http://localhost:5000/quote"
                        + "?stock_code=" + URLEncoder.encode(symbol, "UTF-8")
                        + "&exchange_code=" + URLEncoder.encode(exchange, "UTF-8");

        URL url = new URL(flaskUrl);
        HttpURLConnection con = (HttpURLConnection) url.openConnection();
        con.setRequestMethod("GET");
        con.setConnectTimeout(10000);
        con.setReadTimeout(15000);
        con.setRequestProperty("Accept", "application/json");

        int responseCode = con.getResponseCode();
        if (responseCode != 200) {
            out.print("{\"error\": \"Flask/Breeze server error: " + responseCode + "\"}");
            return;
        }

        BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream(), "UTF-8"));
        StringBuilder jsonResponse = new StringBuilder();
        String inputLine;
        while ((inputLine = in.readLine()) != null) {
            jsonResponse.append(inputLine);
        }
        in.close();
        con.disconnect();

        // Parse Flask response
        JSONObject flaskData = new JSONObject(jsonResponse.toString());

        if (flaskData.has("error")) {
            out.print("{\"error\": \"" + flaskData.getString("error").replace("\"", "'") + "\"}");
            return;
        }

        // Map Breeze fields → same JSON structure your frontend already expects
        JSONObject quoteData = new JSONObject();
        quoteData.put("symbol",        flaskData.optString("symbol",   symbol));
        quoteData.put("price",         flaskData.optString("ltp",      "0.00"));   // LTP = current price
        quoteData.put("open",          flaskData.optString("open",     "0.00"));
        quoteData.put("high",          flaskData.optString("high",     "0.00"));
        quoteData.put("low",           flaskData.optString("low",      "0.00"));
        quoteData.put("change",        flaskData.optString("change",   "0.00"));
        quoteData.put("changePercent", flaskData.optString("change%",  "0.00"));
        quoteData.put("volume",        flaskData.optString("volume",   "0"));
        quoteData.put("timestamp",     flaskData.optString("time",     "N/A"));
        quoteData.put("exchange",      flaskData.optString("exchange", exchange));

        out.print(quoteData.toString());

    } catch (ConnectException ce) {
        out.print("{\"error\": \"Breeze server not running. Start stock_agent_server.py first.\"}");
    } catch (Exception e) {
        out.print("{\"error\": \"Server error: " + e.getMessage().replace("\"", "'") + "\"}");
    }
%>