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
        symbol = symbol.replaceAll("\\.(NS|BO|BSE|NSE)$", "");

        if (!symbol.matches("^[A-Z0-9]{1,20}$")) {
            out.print("{\"error\": \"Invalid symbol. Use plain NSE code like TCS, WIPRO, INFY\"}");
            return;
        }

        String exchange = request.getParameter("exchange");
        if (exchange == null || exchange.trim().isEmpty()) exchange = "NSE";
        exchange = exchange.trim().toUpperCase();

        String[] baseUrls = {
            "http://localhost:5000",
            "https://fintech-application-backend.onrender.com",
        };

        JSONObject flaskData = null;
        Exception lastError = null;

        for (String baseUrl : baseUrls) {
            try {
                String flaskUrl = baseUrl + "/quote"
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
                    con.disconnect();
                    continue;
                }

                BufferedReader in = new BufferedReader(new InputStreamReader(con.getInputStream(), "UTF-8"));
                StringBuilder jsonResponse = new StringBuilder();
                String inputLine;
                while ((inputLine = in.readLine()) != null) {
                    jsonResponse.append(inputLine);
                }
                in.close();
                con.disconnect();

                flaskData = new JSONObject(jsonResponse.toString());
                if (flaskData.has("error")) {
                    continue;
                }

                break;
            } catch (Exception ex) {
                lastError = ex;
            }
        }

        if (flaskData == null) {
            if (lastError != null) {
                out.print("{\"error\": \"Breeze server not running or unreachable\"}");
            } else {
                out.print("{\"error\": \"Unable to fetch quote\"}");
            }
            return;
        }

        JSONObject quoteData = new JSONObject();
        quoteData.put("symbol",        flaskData.optString("symbol", symbol));
        quoteData.put("price",         flaskData.optString("ltp", "0.00"));
        quoteData.put("open",          flaskData.optString("open", "0.00"));
        quoteData.put("high",          flaskData.optString("high", "0.00"));
        quoteData.put("low",           flaskData.optString("low", "0.00"));
        quoteData.put("change",        flaskData.optString("change", "0.00"));
        quoteData.put("changePercent", flaskData.optString("change%", "0.00"));
        quoteData.put("volume",        flaskData.optString("volume", "0"));
        quoteData.put("timestamp",     flaskData.optString("time", "N/A"));
        quoteData.put("exchange",      flaskData.optString("exchange", exchange));

        out.print(quoteData.toString());

    } catch (Exception e) {
        out.print("{\"error\": \"Server error: " + e.getMessage().replace("\"", "'") + "\"}");
    }
%>