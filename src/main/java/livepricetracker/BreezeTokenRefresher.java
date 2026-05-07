package livepricetracker;

import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@WebListener
public class BreezeTokenRefresher implements ServletContextListener {

    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor();

        scheduler.scheduleAtFixedRate(() -> {
            try {
                String scriptPath = sce.getServletContext()
                        .getRealPath("/python/auto_session.py");

                ProcessBuilder pb = new ProcessBuilder("python", scriptPath);
                pb.redirectErrorStream(true);
                Process process = pb.start();

                BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream())
                );

                String token = null;
                String line;
                while ((line = reader.readLine()) != null) {
                    line = line.trim();
                    if (!line.isEmpty()) {
                        token = line;
                    }
                }
                process.waitFor();

                if (token == null || token.isEmpty()) {
                    System.err.println("❌ Token refresh failed: empty token");
                    return;
                }

                // 1️⃣ Store globally in ServletContext (accessible to all servlets)
                sce.getServletContext().setAttribute("breezeToken", token);
                System.out.println("🔄 Breeze token refreshed at " + new java.util.Date()
                        + " → " + token.substring(0, Math.min(10, token.length())));

                // 2️⃣ Also push to Flask server
                URL url = new URL("http://localhost:5000/init-session");
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setDoOutput(true);

                String jsonBody = "{\"session_token\": \"" + token + "\"}";
                try (OutputStream os = conn.getOutputStream()) {
                    os.write(jsonBody.getBytes("UTF-8"));
                }

                int responseCode = conn.getResponseCode();
                System.out.println("🔁 Flask /init-session response: " + responseCode);
                conn.disconnect();

            } catch (Exception e) {
                System.err.println("❌ Token refresh failed: " + e.getMessage());
                e.printStackTrace();
            }

        }, 0, 23, TimeUnit.HOURS); // runs immediately on startup, then every 23 hours

        System.out.println("✅ BreezeTokenRefresher scheduled (every 23 hours)");
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        if (scheduler != null && !scheduler.isShutdown()) {
            scheduler.shutdown();
            System.out.println("🛑 BreezeTokenRefresher stopped");
        }
    }
}