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

@WebServlet("/managerLogin")
public class ManagerLoginServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        String email = request.getParameter("email");
        String password = request.getParameter("password");

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con = DBcConnection.getConnection();

            String sql =
                    "SELECT employee_id, name, email " +
                    "FROM managers " +
                    "WHERE email = ? " +
                    "AND password = ? " +
                    "AND status = 'ACTIVE'";

            ps = con.prepareStatement(sql);

            ps.setString(1, email);
            ps.setString(2, password);

            rs = ps.executeQuery();

            if (rs.next()) {

                String employeeId =
                        rs.getString("employee_id");

                String name =
                        rs.getString("name");

                HttpSession session =
                        request.getSession(true);

                /*
                 * Manager ID is EMP001, EMP002, EMP003...
                 * Manager ID comes from managers table.
                 */

                session.setAttribute(
                        "managerId",
                        employeeId
                );

                session.setAttribute(
                        "managerName",
                        name
                );

                session.setAttribute("role", "MANAGER");

                System.out.println(
                        "MANAGER LOGIN ID = "
                        + employeeId
                );

                response.sendRedirect(
                        request.getContextPath()
                        + "/manager"
                );

            } else {

                response.sendRedirect(
                        request.getContextPath()
                        + "/managerLogin.jsp?error=Invalid login"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                    request.getContextPath()
                    + "/managerLogin.jsp?error=Login failed"
            );

        } finally {

            try {
                if (rs != null) rs.close();
            } catch (Exception e) {}

            try {
                if (ps != null) ps.close();
            } catch (Exception e) {}

            try {
                if (con != null) con.close();
            } catch (Exception e) {}
        }
    }
}