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

@WebServlet("/EditTeamServlet")
public class EditTeamServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        String teamId = request.getParameter("teamId");
        String teamName = request.getParameter("teamName");
        String description = request.getParameter("description");
        String department = request.getParameter("department");
        String managerId = request.getParameter("managerId");
        String status = request.getParameter("status");

        if (teamId == null || teamId.trim().isEmpty()) {
            response.sendRedirect("viewTeams.jsp");
            return;
        }

        if (teamName == null || teamName.trim().isEmpty()) {
            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId +
                "&message=Team Name is required&type=error"
            );
            return;
        }

        if (department == null || department.trim().isEmpty()) {
            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId +
                "&message=Department must be selected&type=error"
            );
            return;
        }

        if (managerId == null || managerId.trim().isEmpty()) {
            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId +
                "&message=Team Manager must be selected&type=error"
            );
            return;
        }

        if (status == null || status.trim().isEmpty()) {
            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId +
                "&message=Status must be selected&type=error"
            );
            return;
        }

        teamId = teamId.trim();
        teamName = teamName.trim();
        description = description == null ? "" : description.trim();
        department = department.trim();
        managerId = managerId.trim();
        status = status.trim();

        if (description.length() > 500) {
            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId +
                "&message=Description should not exceed 500 characters&type=error"
            );
            return;
        }

        Connection con = null;
        PreparedStatement checkPs = null;
        PreparedStatement updatePs = null;
        ResultSet rs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {
                response.sendRedirect(
                    "editTeam.jsp?teamId=" + teamId +
                    "&message=Database connection failed&type=error"
                );
                return;
            }

            // Check duplicate team name
            String checkSql =
                "SELECT team_id FROM teams " +
                "WHERE LOWER(team_name) = LOWER(?) " +
                "AND team_id <> ?";

            checkPs = con.prepareStatement(checkSql);

            checkPs.setString(1, teamName);
            checkPs.setString(2, teamId);

            rs = checkPs.executeQuery();

            if (rs.next()) {

                response.sendRedirect(
                    "editTeam.jsp?teamId=" + teamId +
                    "&message=Team Name already exists&type=error"
                );

                return;
            }

            // Update Team
            String updateSql =
                "UPDATE teams SET " +
                "team_name = ?, " +
                "description = ?, " +
                "department = ?, " +
                "manager_id = ?, " +
                "status = ?, " +
                "updated_at = CURRENT_TIMESTAMP " +
                "WHERE team_id = ?";

            updatePs = con.prepareStatement(updateSql);

            updatePs.setString(1, teamName);
            updatePs.setString(2, description);
            updatePs.setString(3, department);
            updatePs.setString(4, managerId);
            updatePs.setString(5, status);
            updatePs.setString(6, teamId);

            int rows = updatePs.executeUpdate();

            if (rows > 0) {

                response.sendRedirect(
                    "viewTeams.jsp" +
                    "?message=Team updated successfully" +
                    "&type=success"
                );

            } else {

                response.sendRedirect(
                    "editTeam.jsp?teamId=" + teamId +
                    "&message=Team could not be updated&type=error"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId +
                "&message=Error updating team&type=error"
            );

        } finally {

            try {
                if (rs != null) rs.close();
            } catch (Exception e) {}

            try {
                if (checkPs != null) checkPs.close();
            } catch (Exception e) {}

            try {
                if (updatePs != null) updatePs.close();
            } catch (Exception e) {}

            try {
                if (con != null) con.close();
            } catch (Exception e) {}
        }
    }

    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        String teamId = request.getParameter("teamId");

        if (teamId != null && !teamId.trim().isEmpty()) {

            response.sendRedirect(
                "editTeam.jsp?teamId=" + teamId
            );

        } else {

            response.sendRedirect("viewTeams.jsp");
        }
    }
}