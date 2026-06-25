package livepricetracker;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebServlet;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.*;

//@WebServlet("/ChatServlet")
public class ChatServlet extends HttpServlet {

    private static final String PYTHON_AGENT_URL = "http://127.0.0.1:5000/chat";

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> getChatHistory(HttpSession session) {
        List<Map<String, Object>> history =
                (List<Map<String, Object>>) session.getAttribute("chatHistory");

        if (history == null) {
            history = new ArrayList<>();
            session.setAttribute("chatHistory", history);
        }
        return history;
    }

    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "")
                .replace("\t", "\\t");
    }

    private String unescapeJson(String s) {
        if (s == null) return null;

        StringBuilder out = new StringBuilder();

        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);

            if (c == '\\' && i + 1 < s.length()) {
                char next = s.charAt(++i);

                switch (next) {
                    case '"': out.append('"'); break;
                    case '\\': out.append('\\'); break;
                    case '/': out.append('/'); break;
                    case 'b': out.append('\b'); break;
                    case 'f': out.append('\f'); break;
                    case 'n': out.append('\n'); break;
                    case 'r': out.append('\r'); break;
                    case 't': out.append('\t'); break;
                    case 'u':
                        if (i + 4 < s.length()) {
                            String hex = s.substring(i + 1, i + 5);
                            out.append((char) Integer.parseInt(hex, 16));
                            i += 4;
                        }
                        break;
                    default:
                        out.append(next);
                        break;
                }
            } else {
                out.append(c);
            }
        }

        return out.toString();
    }

    private String buildHistoryJson(List<Map<String, Object>> history) {
        StringBuilder sb = new StringBuilder();
        sb.append("[");

        for (int i = 0; i < history.size(); i++) {
            Map<String, Object> msg = history.get(i);

            sb.append("{")
                    .append("\"role\":\"").append(escapeJson(String.valueOf(msg.get("role")))).append("\",")
                    .append("\"content\":\"").append(escapeJson(String.valueOf(msg.get("content")))).append("\"")
                    .append("}");

            if (i < history.size() - 1) sb.append(",");
        }

        sb.append("]");
        return sb.toString();
    }

    private String buildFullHistoryResponse(List<Map<String, Object>> history) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"history\":[");

        for (int i = 0; i < history.size(); i++) {
            Map<String, Object> msg = history.get(i);

            sb.append("{")
                    .append("\"role\":\"").append(escapeJson(String.valueOf(msg.get("role")))).append("\",")
                    .append("\"content\":\"").append(escapeJson(String.valueOf(msg.get("content")))).append("\",")
                    .append("\"timestamp\":\"").append(escapeJson(String.valueOf(msg.get("timestamp")))).append("\"")
                    .append("}");

            if (i < history.size() - 1) sb.append(",");
        }

        sb.append("]}");
        return sb.toString();
    }

    private String extractJsonField(String json, String field) {
        String key = "\"" + field + "\":";
        int idx = json.indexOf(key);
        if (idx == -1) return null;

        int startQuote = json.indexOf("\"", idx + key.length());
        if (startQuote == -1) return null;

        StringBuilder value = new StringBuilder();
        boolean escaped = false;

        for (int i = startQuote + 1; i < json.length(); i++) {
            char c = json.charAt(i);

            if (escaped) {
                value.append('\\').append(c);   // preserve the escape sequence
                escaped = false;
            } else if (c == '\\') {
                escaped = true;
            } else if (c == '"') {
                return unescapeJson(value.toString());
            } else {
                value.append(c);
            }
        }

        return null;
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json; charset=UTF-8");
        PrintWriter out = response.getWriter();

        try {
            HttpSession session = request.getSession();
            List<Map<String, Object>> history = getChatHistory(session);
            out.print(buildFullHistoryResponse(history));
        } catch (Exception e) {
            out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("application/json; charset=UTF-8");
        PrintWriter out = response.getWriter();

        try {
            String userMessage = request.getParameter("message");
            String model = request.getParameter("model");

            if (model == null || model.trim().isEmpty()) {
                model = "qwen/qwen3-32b";
            }

            if (userMessage == null || userMessage.trim().isEmpty()) {
                out.print("{\"error\":\"Message cannot be empty\"}");
                return;
            }

            HttpSession session = request.getSession();
            List<Map<String, Object>> history = getChatHistory(session);

            Map<String, Object> userEntry = new HashMap<>();
            userEntry.put("role", "user");
            userEntry.put("content", userMessage.trim());
            userEntry.put("timestamp", String.valueOf(System.currentTimeMillis()));
            history.add(userEntry);

            int start = Math.max(0, history.size() - 6);
            List<Map<String, Object>> recentHistory = new ArrayList<>(history.subList(start, history.size()));

            String aiReply = callPythonAgent(userMessage, model, recentHistory);

            Map<String, Object> aiEntry = new HashMap<>();
            aiEntry.put("role", "assistant");
            aiEntry.put("content", aiReply);
            aiEntry.put("timestamp", String.valueOf(System.currentTimeMillis()));
            history.add(aiEntry);

            if (history.size() > 20) {
                history = new ArrayList<>(history.subList(history.size() - 20, history.size()));
                session.setAttribute("chatHistory", history);
            }

            out.print("{\"reply\":\"" + escapeJson(aiReply) + "\"}");

        } catch (Exception e) {
            e.printStackTrace();
            out.print("{\"error\":\"" + escapeJson(e.getMessage()) + "\"}");
        }
    }

    private String callPythonAgent(String message, String model, List<Map<String, Object>> history) {
        HttpURLConnection conn = null;

        try {
            String historyJson = buildHistoryJson(history);

            String jsonInput = "{"
                    + "\"message\":\"" + escapeJson(message) + "\","
                    + "\"model\":\"" + escapeJson(model) + "\","
                    + "\"history\":" + historyJson
                    + "}";

            URL url = new URL(PYTHON_AGENT_URL);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(120000);
            conn.setDoOutput(true);

            byte[] input = jsonInput.getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = conn.getOutputStream()) {
                os.write(input, 0, input.length);
            }

            int responseCode = conn.getResponseCode();

            InputStream stream = (responseCode >= 200 && responseCode < 300)
                    ? conn.getInputStream()
                    : conn.getErrorStream();

            BufferedReader in = new BufferedReader(
                    new InputStreamReader(stream, StandardCharsets.UTF_8)
            );

            StringBuilder result = new StringBuilder();
            String line;
            while ((line = in.readLine()) != null) {
                result.append(line);
            }
            in.close();

            String responseText = result.toString();

            if (responseCode >= 200 && responseCode < 300) {
                String reply = extractJsonField(responseText, "reply");
                return reply != null ? reply : "No response";
            } else {
                String error = extractJsonField(responseText, "error");
                return "❌ Backend error: " + (error != null ? error : "Unknown error");
            }

        } catch (Exception e) {
            e.printStackTrace();
            return "❌ Could not reach local Python backend. Make sure stock_agent_server.py is running on port 5000.";
        } finally {
            if (conn != null) conn.disconnect();
        }
    }
}