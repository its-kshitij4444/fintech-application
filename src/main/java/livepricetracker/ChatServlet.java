package livepricetracker;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebServlet;
import org.json.JSONObject;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class ChatServlet extends HttpServlet {

    private static final String[] PYTHON_AGENT_URLS = {
            "https://fintech-application-backend.onrender.com/chat",
            "http://127.0.0.1:5000/chat"
    };

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

            System.out.println("\n========== CHAT REQUEST ==========");
            System.out.println("User message: " + userMessage);
            System.out.println("Model selected: " + model);

            if (userMessage == null || userMessage.trim().isEmpty()) {
                JSONObject error = new JSONObject();
                error.put("error", "Message cannot be empty");
                System.out.println("ERROR: Empty message");
                out.print(error.toString());
                return;
            }

            String aiReply = callPythonAgent(userMessage, model);
            System.out.println("AI Reply: " + aiReply);

            JSONObject response_obj = new JSONObject();
            response_obj.put("reply", aiReply);

            System.out.println("Sending response: " + response_obj.toString());
            System.out.println("========== END REQUEST ==========\n");

            out.print(response_obj.toString());

        } catch (Exception e) {
            System.err.println("❌ SERVLET ERROR: " + e.getClass().getName());
            e.printStackTrace();
            JSONObject error = new JSONObject();
            error.put("error", e.getMessage());
            out.print(error.toString());
        }
    }

    private static String callPythonAgent(String message, String model) {
        JSONObject requestBody = new JSONObject();
        requestBody.put("message", message);
        requestBody.put("model", model);
        String jsonInput = requestBody.toString();
        System.out.println("Request JSON: " + jsonInput);

        Exception lastError = null;

        for (String agentUrl : PYTHON_AGENT_URLS) {
            HttpURLConnection conn = null;
            try {
                System.out.println("Trying Python agent at: " + agentUrl);

                URL url = new URL(agentUrl);
                conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setConnectTimeout(10000);   // 10s to connect
                conn.setReadTimeout(120000);      // 2 min to read (LLM takes time)
                conn.setDoOutput(true);

                byte[] input = jsonInput.getBytes(StandardCharsets.UTF_8);
                try (OutputStream os = conn.getOutputStream()) {
                    os.write(input, 0, input.length);
                }

                System.out.println("Request sent, waiting for response...");
                int responseCode = conn.getResponseCode();
                System.out.println("Response code from " + agentUrl + ": " + responseCode);

                if (responseCode != 200) {
                    BufferedReader errorReader = new BufferedReader(
                            new InputStreamReader(conn.getErrorStream(), StandardCharsets.UTF_8)
                    );
                    StringBuilder errorMsg = new StringBuilder();
                    String errorLine;
                    while ((errorLine = errorReader.readLine()) != null) {
                        errorMsg.append(errorLine).append("\n");
                    }
                    errorReader.close();
                    System.out.println("⚠️ Non-200 from " + agentUrl + ": " + errorMsg);
                    // Don't break — try next URL
                    continue;
                }

                BufferedReader in = new BufferedReader(
                        new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8)
                );
                StringBuilder result = new StringBuilder();
                String line;
                while ((line = in.readLine()) != null) {
                    result.append(line);
                }
                in.close();

                String responseText = result.toString();
                System.out.println("✅ Response from " + agentUrl + ": " + responseText);

                JSONObject responseObj = new JSONObject(responseText);
                return responseObj.optString("reply", responseObj.optString("error", "No response"));

            } catch (java.net.ConnectException e) {
                lastError = e;
                System.err.println("❌ Cannot connect to " + agentUrl + ": " + e.getMessage());
            } catch (java.net.SocketTimeoutException e) {
                lastError = e;
                System.err.println("⏱️ Timeout on " + agentUrl + ": " + e.getMessage());
            } catch (Exception e) {
                lastError = e;
                System.err.println("❌ Error on " + agentUrl + ": " + e.getClass().getName() + " - " + e.getMessage());
            } finally {
                if (conn != null) conn.disconnect();
            }
        }

        // All URLs failed
        System.err.println("❌ All backend URLs exhausted");
        if (lastError != null) lastError.printStackTrace();
        return "❌ Could not reach the Python backend on Render or localhost. Is the server running?";
    }
}