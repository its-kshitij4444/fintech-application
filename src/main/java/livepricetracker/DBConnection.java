package livepricetracker;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DBConnection {

    // Production (Render) values come from env vars
    // Fallback values are for local development
    private static final String URL = System.getProperty("DB_URL") != null
            ? System.getProperty("DB_URL")
            : System.getenv("DB_URL") != null
                    ? System.getenv("DB_URL")
                    : "jdbc:mysql://localhost:3306/userdb?useSSL=false";

    private static final String USER = System.getenv("DB_USER") != null
            ? System.getenv("DB_USER")
            : "root";

    private static final String PASSWORD = System.getenv("DB_PASSWORD") != null
            ? System.getenv("DB_PASSWORD")
            : "root123";

    public static Connection getConnection() throws SQLException {
        try {
//            System.out.println("DEBUG DB_URL: " + URL); // add this
//            System.out.println("DEBUG DB_USER: " + USER); // add this
            Class.forName("com.mysql.cj.jdbc.Driver");
            return DriverManager.getConnection(URL, USER, PASSWORD);
        } catch (ClassNotFoundException e) {
            throw new SQLException("MySQL JDBC Driver not found: " + e.getMessage());
        }
    }
}