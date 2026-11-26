package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import model.DBcConnection;

@WebServlet("/ManagerEditTeamServlet")
public class ManagerEditTeamServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession();

        String managerId =
            (String) session.getAttribute("managerId");

        if (managerId == null) {
            response.sendRedirect("managerLogin.jsp");
            return;
        }

        String teamId = request.getParameter("teamId");
        String teamName = request.getParameter("teamName");
        String description = request.getParameter("description");
        String department = request.getParameter("department");
        String status = request.getParameter("status");

        Connection con = null;
        PreparedStatement ps = null;

        try {

            con = DBcConnection.getConnection();

            String sql =
                "UPDATE teams SET " +
                "team_name=?, " +
                "description=?, " +
                "department=?, " +
                "status=?, " +
                "updated_at=CURRENT_TIMESTAMP " +
                "WHERE team_id=? AND manager_id=?";

            ps = con.prepareStatement(sql);

            ps.setString(1, teamName);
            ps.setString(2, description);
            ps.setString(3, department);
            ps.setString(4, status);
            ps.setString(5, teamId);
            ps.setString(6, managerId);

            int rows = ps.executeUpdate();

            if (rows > 0) {

                response.sendRedirect(
                    "managerDashboard.jsp?message=Team updated successfully"
                );

            } else {

                response.sendRedirect(
                    "managerDashboard.jsp?message=Team update failed"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "managerDashboard.jsp?message=Error updating team"
            );

        } finally {

            try {
                if (ps != null) ps.close();
            } catch (Exception e) {}

            try {
                if (con != null) con.close();
            } catch (Exception e) {}
        }
    }

    @Override
    protected void doGet(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        response.sendRedirect("managerDashboard.jsp");
    }
}