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
import jakarta.servlet.http.HttpSession;

import model.DBcConnection;
import service.AuditService;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String loginId = request.getParameter("loginId");
        String password = request.getParameter("password");

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                    request.getContextPath()
                    + "/login.html?error=failed"
                );

                return;
            }

            // =========================================
            // 1. ADMIN LOGIN
            // =========================================

            String adminSql =
                "SELECT admin_id, name, email " +
                "FROM admins " +
                "WHERE (admin_id = ? OR email = ?) " +
                "AND password = ? " +
                "AND status = 'ACTIVE'";

            ps = con.prepareStatement(adminSql);

            ps.setString(1, loginId);
            ps.setString(2, loginId);
            ps.setString(3, password);

            rs = ps.executeQuery();

            if (rs.next()) {

                HttpSession session = request.getSession();

                session.setAttribute(
                    "adminId",
                    rs.getString("admin_id")
                );

                session.setAttribute(
                    "adminName",
                    rs.getString("name")
                );

                session.setAttribute(
                    "adminEmail",
                    rs.getString("email")
                );

                session.setAttribute(
                    "role",
                    "ADMIN"
                );

                AuditService.recordLogin(request, session);

                response.sendRedirect(
                    request.getContextPath()
                    + "/admin_dashbaord.jsp"
                );

                return;
            }

            rs.close();
            ps.close();


            // =========================================
            // 1b. HR LOGIN (HR is recruited by the admin)
            // =========================================

            try {
                String hrSql =
                    "SELECT hr_id, name, email " +
                    "FROM hr_users " +
                    "WHERE (hr_id = ? OR email = ?) " +
                    "AND password = ? " +
                    "AND status = 'ACTIVE'";

                ps = con.prepareStatement(hrSql);

                ps.setString(1, loginId);
                ps.setString(2, loginId);
                ps.setString(3, password);

                rs = ps.executeQuery();

                if (rs.next()) {

                    HttpSession session = request.getSession();

                    session.setAttribute("hrId", rs.getString("hr_id"));
                    session.setAttribute("hrName", rs.getString("name"));
                    session.setAttribute("hrEmail", rs.getString("email"));
                    session.setAttribute("role", "HR");

                AuditService.recordLogin(request, session);

                    response.sendRedirect(
                        request.getContextPath() + "/hr"
                    );

                    return;
                }
            } catch (java.sql.SQLException hrEx) {
                // hr_users table missing: keep going so manager and
                // employee logins still work.
                hrEx.printStackTrace();
            } finally {
                try { if (rs != null) rs.close(); } catch (Exception e) { }
                try { if (ps != null) ps.close(); } catch (Exception e) { }
                rs = null;
                ps = null;
            }


            // =========================================
            // 2. MANAGER LOGIN
            // =========================================

            String managerSql =
                "SELECT employee_id, name, email " +
                "FROM managers " +
                "WHERE (employee_id = ? OR email = ?) " +
                "AND password = ? " +
                "AND status = 'ACTIVE'";

            ps = con.prepareStatement(managerSql);

            ps.setString(1, loginId);
            ps.setString(2, loginId);
            ps.setString(3, password);

            rs = ps.executeQuery();

            if (rs.next()) {

                HttpSession session = request.getSession();

                session.setAttribute(
                    "managerId",
                    rs.getString("employee_id")
                );

                session.setAttribute(
                    "managerName",
                    rs.getString("name")
                );

                session.setAttribute(
                    "managerEmail",
                    rs.getString("email")
                );

                session.setAttribute(
                    "role",
                    "MANAGER"
                );

                AuditService.recordLogin(request, session);

                response.sendRedirect(
                    request.getContextPath()
                    + "/managerDashboard.jsp"
                );

                return;
            }

            rs.close();
            ps.close();


            // =========================================
            // 3. EMPLOYEE LOGIN
            // =========================================

            String employeeSql =
                "SELECT employee_id, name, email " +
                "FROM employees " +
                "WHERE (employee_id = ? OR email = ?) " +
                "AND password = ? " +
                "AND status = 'ACTIVE'";

            ps = con.prepareStatement(employeeSql);

            ps.setString(1, loginId);
            ps.setString(2, loginId);
            ps.setString(3, password);

            rs = ps.executeQuery();

            if (rs.next()) {

                HttpSession session = request.getSession();

                session.setAttribute(
                    "employeeId",
                    rs.getString("employee_id")
                );

                session.setAttribute(
                    "employeeName",
                    rs.getString("name")
                );

                session.setAttribute(
                    "name",
                    rs.getString("name")
                );

                session.setAttribute(
                    "email",
                    rs.getString("email")
                );

                session.setAttribute(
                    "role",
                    "EMPLOYEE"
                );

                AuditService.recordLogin(request, session);

                response.sendRedirect(
                    request.getContextPath()
                    + "/employee_dashboard.jsp"
                );

                return;
            }


            // =========================================
            // INVALID LOGIN
            // =========================================

            AuditService.recordFailedLogin(request, loginId);


            response.sendRedirect(
                request.getContextPath()
                + "/login.html?error=invalid"
            );

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                request.getContextPath()
                + "/login.html?error=failed"
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


    // =========================================
    // GET LOGIN PAGE
    // =========================================

    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        response.sendRedirect(
            request.getContextPath()
            + "/login.html"
        );
    }
}