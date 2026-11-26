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

@WebServlet("/CommonLoginServlet")
public class CommonLoginServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String role = request.getParameter("role");
        String id = request.getParameter("id");
        String password = request.getParameter("password");

        if (role == null || id == null || password == null
                || role.trim().isEmpty()
                || id.trim().isEmpty()
                || password.trim().isEmpty()) {

            response.sendRedirect(
                "index.jsp?message=Please enter all details"
            );

            return;
        }


        // =========================
        // ADMIN LOGIN
        // =========================

        if ("ADMIN".equals(role)) {

            if ("admin".equals(id)
                    && "admin123".equals(password)) {

                HttpSession session = request.getSession();

                session.setAttribute("adminUsername", id);

                response.sendRedirect("adminPanel.jsp");

            } else {

                response.sendRedirect(
                    "index.jsp?message=Invalid Admin ID or Password"
                );
            }

            return;
        }


        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;


        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                    "index.jsp?message=Database connection failed"
                );

                return;
            }


            // =========================
            // MANAGER LOGIN
            // =========================

            if ("MANAGER".equals(role)) {

                String sql =
                    "SELECT employee_id, name, email " +
                    "FROM managers " +
                    "WHERE employee_id = ? " +
                    "AND password = ? " +
                    "AND status = 'ACTIVE'";


                ps = con.prepareStatement(sql);

                ps.setString(1, id);

                ps.setString(2, password);

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

                    session.setAttribute("role", "MANAGER");


                    response.sendRedirect(
                        "managerDashboard.jsp"
                    );

                } else {

                    response.sendRedirect(
                        "index.jsp?message=Invalid Manager ID or Password"
                    );
                }

                return;
            }


            // Close previous query objects
            if (rs != null) {
                rs.close();
                rs = null;
            }

            if (ps != null) {
                ps.close();
                ps = null;
            }


            // =========================
            // EMPLOYEE LOGIN
            // =========================

            if ("EMPLOYEE".equals(role)) {

                String sql =
                    "SELECT employee_id, name, email " +
                    "FROM employees " +
                    "WHERE employee_id = ? " +
                    "AND password = ? " +
                    "AND status = 'ACTIVE'";


                ps = con.prepareStatement(sql);

                ps.setString(1, id);

                ps.setString(2, password);

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

                    session.setAttribute("role", "EMPLOYEE");


                    response.sendRedirect(
                        "employeeDashboard.jsp"
                    );

                } else {

                    response.sendRedirect(
                        "index.jsp?message=Invalid Employee ID or Password"
                    );
                }

                return;
            }


            // Invalid role

            response.sendRedirect(
                "index.jsp?message=Please select a valid login type"
            );


        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "index.jsp?message=Login error"
            );


        } finally {

            try {
                if (rs != null) {
                    rs.close();
                }
            } catch (Exception e) {}

            try {
                if (ps != null) {
                    ps.close();
                }
            } catch (Exception e) {}

            try {
                if (con != null) {
                    con.close();
                }
            } catch (Exception e) {}
        }
    }


    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        response.sendRedirect("index.jsp");
    }
}