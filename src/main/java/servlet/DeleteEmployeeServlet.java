package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.DBcConnection;
import service.AuditService;

@WebServlet("/DeleteEmployeeServlet")
public class DeleteEmployeeServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    protected void doGet(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        String employeeId =
                request.getParameter("employeeId");

        if (employeeId == null ||
            employeeId.trim().isEmpty()) {

            response.sendRedirect(
                "managerDashboard.jsp?message=Invalid Employee ID"
            );

            return;
        }


        Connection con = null;
        PreparedStatement ps = null;

        try {

            con =
                DBcConnection.getConnection();

            // ---- audit: remember what is about to be deleted (never the password) ----
            java.util.Map<String, Object> before = null;
            try (PreparedStatement snap = con.prepareStatement(
                    "SELECT name, email, department, designation, status " +
                    "FROM employees WHERE employee_id = ?")) {
                snap.setString(1, employeeId);
                try (java.sql.ResultSet r = snap.executeQuery()) {
                    if (r.next()) {
                        before = AuditService.map("employee_id", employeeId, "name", r.getString(1),
                                "email", r.getString(2), "department", r.getString(3),
                                "designation", r.getString(4), "status", r.getString(5));
                    }
                }
            }



            String sql =
                "DELETE FROM employees " +
                "WHERE employee_id = ?";


            ps =
                con.prepareStatement(sql);


            ps.setString(
                1,
                employeeId
            );


            int rows =
                ps.executeUpdate();


            if (rows > 0) {

                AuditService.log(request, "Employee", "DELETE", employeeId,
                        "Employee deleted", before, null);

                response.sendRedirect(
                    "managerDashboard.jsp?message=Employee deleted successfully"
                );

            } else {

                response.sendRedirect(
                    "managerDashboard.jsp?message=Employee not found"
                );
            }


        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "managerDashboard.jsp?message=Error deleting employee"
            );

        } finally {

            try {

                if (ps != null)
                    ps.close();

            } catch (Exception e) {
            }


            try {

                if (con != null)
                    con.close();

            } catch (Exception e) {
            }

        }
    }
}