package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.DBcConnection;
import service.EmailService;

@WebServlet("/AddManagerServlet")
public class AddManagerServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String name = request.getParameter("name");
        String email = request.getParameter("email");
        String phone = request.getParameter("phone");
        String department = request.getParameter("department");
        String designation = request.getParameter("designation");
        String status = request.getParameter("status");
        String password = request.getParameter("password");

        // Check required fields
        if (name == null || email == null || phone == null
                || department == null || designation == null
                || status == null || password == null
                || name.trim().isEmpty()
                || email.trim().isEmpty()
                || phone.trim().isEmpty()
                || department.trim().isEmpty()
                || designation.trim().isEmpty()
                || status.trim().isEmpty()
                || password.trim().isEmpty()) {

            response.sendRedirect(
                    "addManager.jsp?message=Please fill all fields"
            );

            return;
        }

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                        "addManager.jsp?message=Database connection failed"
                );

                return;
            }

            // =====================================================
            // AUTOMATIC MANAGER ID
            // EMP001, EMP002, EMP003...
            // =====================================================

            String lastIdSql =
                    "SELECT employee_id " +
                    "FROM managers " +
                    "WHERE employee_id LIKE 'EMP%' " +
                    "ORDER BY CAST(SUBSTRING(employee_id, 4) AS UNSIGNED) DESC " +
                    "LIMIT 1";

            ps = con.prepareStatement(lastIdSql);

            rs = ps.executeQuery();

            int nextNumber = 1;

            if (rs.next()) {

                String lastId =
                        rs.getString("employee_id");

                if (lastId != null &&
                        lastId.startsWith("EMP")) {

                    try {

                        int lastNumber =
                                Integer.parseInt(
                                        lastId.substring(3)
                                );

                        nextNumber = lastNumber + 1;

                    } catch (NumberFormatException e) {

                        nextNumber = 1;
                    }
                }
            }

            rs.close();
            ps.close();

            // Example: EMP004
            String managerId =
                    String.format(
                            "EMP%03d",
                            nextNumber
                    );

            // =====================================================
            // INSERT MANAGER INTO MANAGERS TABLE
            // =====================================================

            String sql =
                    "INSERT INTO managers " +
                    "(employee_id, name, email, phone, department, " +
                    "designation, status, password) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

            ps = con.prepareStatement(sql);

            ps.setString(1, managerId);
            ps.setString(2, name);
            ps.setString(3, email);
            ps.setString(4, phone);
            ps.setString(5, department);
            ps.setString(6, designation);
            ps.setString(7, status);
            ps.setString(8, password);

            int rows =
                    ps.executeUpdate();

            ps.close();

            // =====================================================
            // MANAGER ADDED SUCCESSFULLY
            // SEND LOGIN CREDENTIALS
            // =====================================================

            if (rows > 0) {

                boolean emailSent =
                        EmailService.sendCredentials(
                                email,
                                name,
                                managerId,
                                password,
                                "Manager"
                        );

                // =================================================
                // EMAIL SENT
                // =================================================

                if (emailSent) {

                    response.sendRedirect(
                            "addManager.jsp?message="
                            + "Manager added successfully. "
                            + "Manager ID: "
                            + managerId
                            + ". Login credentials sent to email."
                    );

                }

                // =================================================
                // MANAGER ADDED BUT EMAIL FAILED
                // =================================================

                else {

                    response.sendRedirect(
                            "addManager.jsp?message="
                            + "Manager added successfully. "
                            + "Manager ID: "
                            + managerId
                            + ". But email could not be sent."
                    );
                }

            } else {

                response.sendRedirect(
                        "addManager.jsp?message=Manager not added"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                    "addManager.jsp?message=Error adding manager"
            );

        } finally {

            try {
                if (rs != null) {
                    rs.close();
                }
            } catch (Exception e) {
            }

            try {
                if (ps != null) {
                    ps.close();
                }
            } catch (Exception e) {
            }

            try {
                if (con != null) {
                    con.close();
                }
            } catch (Exception e) {
            }
        }
    }

    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        response.sendRedirect("addManager.jsp");
    }
}