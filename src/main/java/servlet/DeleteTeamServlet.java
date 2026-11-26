package servlet;

import java.io.IOException;
import java.net.URLEncoder;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.DBcConnection;

@WebServlet("/DeleteTeamServlet")
public class DeleteTeamServlet extends HttpServlet {

    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        String teamId = request.getParameter("teamId");

        if (teamId == null || teamId.trim().isEmpty()) {

            response.sendRedirect(
                "viewTeams.jsp?message=Team ID is required&type=error"
            );

            return;
        }

        teamId = teamId.trim();

        Connection con = null;

        PreparedStatement teamPs = null;
        PreparedStatement memberPs = null;
        PreparedStatement deletePs = null;

        ResultSet teamRs = null;
        ResultSet memberRs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                    "viewTeams.jsp?message=Database connection failed&type=error"
                );

                return;
            }


            /*
             * Get Team Name
             */

            String teamSql =
                "SELECT team_name " +
                "FROM teams " +
                "WHERE team_id = ?";

            teamPs = con.prepareStatement(teamSql);

            teamPs.setString(1, teamId);

            teamRs = teamPs.executeQuery();

            String teamName = null;

            if (teamRs.next()) {

                teamName =
                    teamRs.getString("team_name");

            } else {

                response.sendRedirect(
                    "viewTeams.jsp?message=Team not found&type=error"
                );

                return;
            }


            teamRs.close();
            teamRs = null;

            teamPs.close();
            teamPs = null;


            /*
             * Check ACTIVE team members
             */

            String memberSql =
                "SELECT COUNT(*) AS active_members " +
                "FROM team_members " +
                "WHERE team_id = ? " +
                "AND status = 'ACTIVE'";

            memberPs =
                con.prepareStatement(memberSql);

            memberPs.setString(1, teamId);

            memberRs =
                memberPs.executeQuery();

            int activeMembers = 0;

            if (memberRs.next()) {

                activeMembers =
                    memberRs.getInt("active_members");
            }


            memberRs.close();
            memberRs = null;

            memberPs.close();
            memberPs = null;


            /*
             * Do NOT delete if active members exist
             */

            if (activeMembers > 0) {

                String message =
                    "This team contains active members. " +
                    "Please remove or transfer the members before deleting the team.";

                response.sendRedirect(
                    "viewTeams.jsp?message=" +
                    URLEncoder.encode(message, "UTF-8") +
                    "&type=error"
                );

                return;
            }


            /*
             * Delete inactive team members
             */

            String deleteMembersSql =
                "DELETE FROM team_members " +
                "WHERE team_id = ?";

            deletePs =
                con.prepareStatement(deleteMembersSql);

            deletePs.setString(1, teamId);

            deletePs.executeUpdate();

            deletePs.close();
            deletePs = null;


            /*
             * Delete Team
             */

            String deleteTeamSql =
                "DELETE FROM teams " +
                "WHERE team_id = ?";

            deletePs =
                con.prepareStatement(deleteTeamSql);

            deletePs.setString(1, teamId);

            int rows =
                deletePs.executeUpdate();


            if (rows > 0) {

                String message =
                    "Team \"" +
                    teamName +
                    "\" deleted successfully";

                response.sendRedirect(
                    "viewTeams.jsp?message=" +
                    URLEncoder.encode(message, "UTF-8") +
                    "&type=success"
                );

            } else {

                response.sendRedirect(
                    "viewTeams.jsp?message=Team could not be deleted&type=error"
                );
            }


        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "viewTeams.jsp?message=Error deleting team&type=error"
            );

        } finally {

            try {
                if (teamRs != null) teamRs.close();
            } catch (Exception e) {}

            try {
                if (memberRs != null) memberRs.close();
            } catch (Exception e) {}

            try {
                if (teamPs != null) teamPs.close();
            } catch (Exception e) {}

            try {
                if (memberPs != null) memberPs.close();
            } catch (Exception e) {}

            try {
                if (deletePs != null) deletePs.close();
            } catch (Exception e) {}

            try {
                if (con != null) con.close();
            } catch (Exception e) {}
        }
    }


    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        doGet(request, response);
    }
}