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

@WebServlet("/AddEmployeeServlet")
public class AddEmployeeServlet extends HttpServlet {

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
        String salary = request.getParameter("salary");
        String password = request.getParameter("password");
        String status = request.getParameter("status");

        // ==========================================
        // CHECK REQUIRED FIELDS
        // ==========================================

        if (name == null || email == null || phone == null
                || department == null || designation == null
                || salary == null || password == null
                || status == null
                || name.trim().isEmpty()
                || email.trim().isEmpty()
                || phone.trim().isEmpty()
                || department.trim().isEmpty()
                || designation.trim().isEmpty()
                || salary.trim().isEmpty()
                || password.trim().isEmpty()) {

            response.sendRedirect(
                    "addEmployee.jsp?message=Please fill all fields"
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
                        "addEmployee.jsp?message=Database connection failed"
                );

                return;
            }

            // ==========================================
            // GENERATE EMPLOYEE ID
            // ==========================================

            String lastIdSql =
                    "SELECT employee_id " +
                    "FROM employees " +
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

                        nextNumber =
                                lastNumber + 1;

                    } catch (NumberFormatException e) {

                        nextNumber = 1;
                    }
                }
            }

            rs.close();
            ps.close();

            String employeeId =
                    String.format(
                            "EMP%03d",
                            nextNumber
                    );

            // ==========================================
            // INSERT EMPLOYEE
            // ==========================================

            String sql =
                    "INSERT INTO employees " +
                    "(employee_id, name, email, phone, department, " +
                    "designation, salary, password, status) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

            ps = con.prepareStatement(sql);

            ps.setString(1, employeeId);
            ps.setString(2, name);
            ps.setString(3, email);
            ps.setString(4, phone);
            ps.setString(5, department);
            ps.setString(6, designation);
            ps.setDouble(
                    7,
                    Double.parseDouble(salary)
            );
            ps.setString(8, password);
            ps.setString(9, status);

            int rows =
                    ps.executeUpdate();

            // ==========================================
            // EMPLOYEE ADDED SUCCESSFULLY
            // ==========================================

            if (rows > 0) {

                // ======================================
                // SEND LOGIN CREDENTIALS BY EMAIL
                // ======================================

                String role;

                if ("Manager".equalsIgnoreCase(designation)) {
                    role = "Manager";
                } else {
                    role = "Employee";
                }

                boolean emailSent =
                        EmailService.sendCredentials(
                                email,
                                name,
                                employeeId,
                                password,
                                role
                        );

                // ======================================
                // CONSOLE OUTPUT
                // ======================================

                System.out.println(
                        "======================================"
                );

                System.out.println(
                        "EMPLOYEE ADDED SUCCESSFULLY"
                );

                System.out.println(
                        "Employee ID : " + employeeId
                );

                System.out.println(
                        "Name        : " + name
                );

                System.out.println(
                        "Email       : " + email
                );

                System.out.println(
                        "Role        : " + role
                );

                System.out.println(
                        "Email Sent  : " + emailSent
                );

                System.out.println(
                        "======================================"
                );

                // ======================================
                // SUCCESS MESSAGE
                // ======================================

                if (emailSent) {

                    response.sendRedirect(
                            "addEmployee.jsp?message="
                            + "Employee added successfully. "
                            + "Employee ID: "
                            + employeeId
                            + ". Login credentials sent to email."
                    );

                } else {

                    response.sendRedirect(
                            "addEmployee.jsp?message="
                            + "Employee added successfully. "
                            + "Employee ID: "
                            + employeeId
                            + ". But email could not be sent."
                    );
                }

            } else {

                response.sendRedirect(
                        "addEmployee.jsp?message=Employee not added"
                );
            }

        } catch (NumberFormatException e) {

            response.sendRedirect(
                    "addEmployee.jsp?message=Please enter a valid salary"
            );

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                    "addEmployee.jsp?message=Error adding employee"
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

    // ==========================================
    // GET
    // ==========================================

    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        response.sendRedirect(
                "addEmployee.jsp"
        );
    }
}