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
    
    // Python agent endpoint
    private static final String PYTHON_AGENT_URL = "http://127.0.0.1:5000/chat";
    
    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        
        response.setContentType("application/json; charset=UTF-8");
        PrintWriter out = response.getWriter();
        
        try {
            String userMessage = request.getParameter("message");
            String model = request.getParameter("model");  // ← ADD THIS
            if (model == null || model.trim().isEmpty()) {
                model = "qwen/qwen3-32b";  // default
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
            
            // Call Python agent
            System.out.println("Calling Python agent at: " + PYTHON_AGENT_URL);
            //String aiReply = callPythonAgent(userMessage);
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
    
    private static String callPythonAgent(String message, String model) throws Exception {
        try {
            System.out.println("Creating connection to: " + PYTHON_AGENT_URL);
            
            URL url = new URL(PYTHON_AGENT_URL);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setConnectTimeout(60000);  // 60 seconds
            conn.setReadTimeout(120000);    // 120 seconds (2 minutes)

            conn.setDoOutput(true);
            
            System.out.println("Connection created, sending request...");
            
            // Build request
            JSONObject requestBody = new JSONObject();
            requestBody.put("message", message);
            requestBody.put("model", model);
            
            String jsonInput = requestBody.toString();
            System.out.println("Request JSON: " + jsonInput);
            
            byte[] input = jsonInput.getBytes(StandardCharsets.UTF_8);
            
            // Send request
            OutputStream os = conn.getOutputStream();
            os.write(input, 0, input.length);
            os.close();
            
            System.out.println("Request sent, waiting for response...");
            
            // Get response code
            int responseCode = conn.getResponseCode();
            System.out.println("Response code: " + responseCode);
            
            if (responseCode != 200) {
                System.out.println("ERROR: Got response code " + responseCode);
                
                BufferedReader errorReader = new BufferedReader(
                    new InputStreamReader(conn.getErrorStream(), StandardCharsets.UTF_8)
                );
                String errorLine;
                StringBuilder errorMsg = new StringBuilder();
                while ((errorLine = errorReader.readLine()) != null) {
                    errorMsg.append(errorLine).append("\n");
                }
                errorReader.close();
                
                System.out.println("Error response: " + errorMsg.toString());
                return "⚠️ Python service returned error (Code: " + responseCode + ")";
            }
            
            // Read response
            BufferedReader in = new BufferedReader(
                new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8)
            );
            StringBuilder result = new StringBuilder();
            String line;
            while ((line = in.readLine()) != null) {
                result.append(line);
            }
            in.close();
            conn.disconnect();
            
            String responseText = result.toString();
            System.out.println("Response from Python: " + responseText);
            
            // Parse response
            JSONObject responseObj = new JSONObject(responseText);
            String reply = responseObj.optString("reply", responseObj.optString("error", "No response"));
            
            System.out.println("Extracted reply: " + reply);
            return reply;
            
        } catch (java.net.ConnectException e) {
            System.err.println("❌ CONNECT ERROR: Cannot reach Python at " + PYTHON_AGENT_URL);
            System.err.println("Message: " + e.getMessage());
            e.printStackTrace();
            return "❌ Cannot connect to Python server at " + PYTHON_AGENT_URL + ". Is it running?";
            
        } catch (java.net.SocketTimeoutException e) {
            System.err.println("❌ TIMEOUT: Python server took too long to respond");
            System.err.println("Message: " + e.getMessage());
            return "⏱️ Python server timeout. Try again.";
            
        } catch (Exception e) {
            System.err.println("❌ ERROR: " + e.getClass().getName() + " - " + e.getMessage());
            e.printStackTrace();
            return "❌ Error: " + e.getClass().getSimpleName() + " - " + e.getMessage();
        }
    }
}
