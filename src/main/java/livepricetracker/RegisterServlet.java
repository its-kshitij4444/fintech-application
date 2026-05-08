package livepricetracker;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import java.sql.*;

public class RegisterServlet extends HttpServlet {
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        String firstName = request.getParameter("firstName");
        String lastName = request.getParameter("lastName");
        String email = request.getParameter("email");
        String phone = request.getParameter("phone");
        String mobile = request.getParameter("mobile");
        String address = request.getParameter("address");
        String username = request.getParameter("username");
        String password = PasswordUtils.hashPassword(request.getParameter("password"));

        if (firstName == null || firstName.trim().isEmpty() ||
                lastName == null || lastName.trim().isEmpty() ||
                email == null || email.trim().isEmpty() ||
                phone == null || phone.trim().isEmpty() ||
                mobile == null || mobile.trim().isEmpty() ||
                address == null || address.trim().isEmpty() ||
                username == null || username.trim().isEmpty()) {

            response.sendRedirect("register.jsp?error=All fields are required");
            return;
        }

        Connection conn = null;
        PreparedStatement checkStmt = null;
        PreparedStatement insertStmt = null;
        ResultSet rs = null;

        try {
            conn = DBConnection.getConnection();

            checkStmt = conn.prepareStatement(
                    "SELECT * FROM users WHERE username=? OR email=?");
            checkStmt.setString(1, username);
            checkStmt.setString(2, email);
            rs = checkStmt.executeQuery();

            if (rs.next()) {
                String existingUsername = rs.getString("username");

                if (existingUsername.equals(username)) {
                    response.sendRedirect("register.jsp?error=Username already exists");
                } else {
                    response.sendRedirect("register.jsp?error=Email already registered");
                }
            } else {
                insertStmt = conn.prepareStatement(
                        "INSERT INTO users (first_name, last_name, email, phone, mobile, address, username, password) " +
                                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

                insertStmt.setString(1, firstName.trim());
                insertStmt.setString(2, lastName.trim());
                insertStmt.setString(3, email.trim().toLowerCase());
                insertStmt.setString(4, phone.trim());
                insertStmt.setString(5, mobile.trim());
                insertStmt.setString(6, address.trim());
                insertStmt.setString(7, username.trim());
                insertStmt.setString(8, password);

                int rowsInserted = insertStmt.executeUpdate();

                if (rowsInserted > 0) {
                    response.sendRedirect("login.jsp?success=Registration successful! Please login");
                } else {
                    response.sendRedirect("register.jsp?error=Registration failed");
                }
            }

        } catch (SQLException e) {
            e.printStackTrace();
            if (e.getMessage().contains("Duplicate entry")) {
                response.sendRedirect("register.jsp?error=Username or email already exists");
            } else {
                response.sendRedirect("register.jsp?error=Database error: " + e.getMessage());
            }
        } finally {
            try {
                if (rs != null) rs.close();
                if (checkStmt != null) checkStmt.close();
                if (insertStmt != null) insertStmt.close();
                if (conn != null) conn.close();
            } catch (SQLException e) {
                e.printStackTrace();
            }
        }
    }
}