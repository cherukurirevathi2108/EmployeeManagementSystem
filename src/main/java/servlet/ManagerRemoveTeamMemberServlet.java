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

@WebServlet("/ManagerRemoveTeamMemberServlet")
public class ManagerRemoveTeamMemberServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession();

        String managerId =
            (String) session.getAttribute("managerId");

        String teamId =
            request.getParameter("teamId");

        String employeeId =
            request.getParameter("employeeId");

        if (managerId == null) {
            response.sendRedirect("managerLogin.jsp");
            return;
        }

        if (teamId == null || employeeId == null) {

            response.sendRedirect(
                "managerDashboard.jsp?message=Invalid team or employee"
            );

            return;
        }

        Connection con = null;

        try {

            con = DBcConnection.getConnection();


            /*
             * Check whether the team belongs
             * to the logged-in manager.
             */

            String checkSql =
                "SELECT team_id FROM teams " +
                "WHERE team_id = ? " +
                "AND manager_id = ?";

            PreparedStatement checkPs =
                con.prepareStatement(checkSql);

            checkPs.setString(1, teamId);
            checkPs.setString(2, managerId);

            var rs = checkPs.executeQuery();

            if (!rs.next()) {

                rs.close();
                checkPs.close();

                response.sendRedirect(
                    "managerDashboard.jsp?message=You are not authorized for this team"
                );

                return;
            }

            rs.close();
            checkPs.close();


            String deleteSql =
                "DELETE FROM team_members " +
                "WHERE team_id = ? " +
                "AND employee_id = ?";

            PreparedStatement deletePs =
                con.prepareStatement(deleteSql);

            deletePs.setString(1, teamId);
            deletePs.setString(2, employeeId);

            int rows =
                deletePs.executeUpdate();

            deletePs.close();


            if (rows > 0) {

                response.sendRedirect(
                    "managerTeamMembers.jsp?teamId="
                    + teamId
                    + "&message=Employee removed successfully"
                );

            } else {

                response.sendRedirect(
                    "managerTeamMembers.jsp?teamId="
                    + teamId
                    + "&message=Employee not found in this team"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "managerTeamMembers.jsp?teamId="
                + teamId
                + "&message=Error removing employee"
            );

        } finally {

            try {
                if (con != null) con.close();
            } catch (Exception e) {}

        }
    }


    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        doGet(request, response);
    }
}