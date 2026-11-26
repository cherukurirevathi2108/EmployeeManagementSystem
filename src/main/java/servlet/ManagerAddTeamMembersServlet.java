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

@WebServlet("/ManagerAddTeamMembersServlet")
public class ManagerAddTeamMembersServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession();

        String managerId =
            (String) session.getAttribute("managerId");

        String teamId =
            request.getParameter("teamId");

        String[] employeeIds =
            request.getParameterValues("employeeIds");

        if (managerId == null) {
            response.sendRedirect("managerLogin.jsp");
            return;
        }

        if (teamId == null || teamId.trim().isEmpty()) {
            response.sendRedirect(
                "managerDashboard.jsp?message=Team ID is missing"
            );
            return;
        }

        if (employeeIds == null || employeeIds.length == 0) {
            response.sendRedirect(
                "managerTeamMembers.jsp?teamId="
                + teamId
                + "&message=Please select at least one employee"
            );
            return;
        }

        Connection con = null;

        try {

            con = DBcConnection.getConnection();

            /*
             * Check whether this team belongs to
             * the logged-in manager.
             */

            String teamSql =
                "SELECT team_id FROM teams " +
                "WHERE team_id = ? " +
                "AND manager_id = ?";

            PreparedStatement teamPs =
                con.prepareStatement(teamSql);

            teamPs.setString(1, teamId);
            teamPs.setString(2, managerId);

            ResultSet teamRs =
                teamPs.executeQuery();

            if (!teamRs.next()) {

                teamRs.close();
                teamPs.close();

                response.sendRedirect(
                    "managerDashboard.jsp?message=You are not authorized for this team"
                );

                return;
            }

            teamRs.close();
            teamPs.close();


            int addedCount = 0;


            for (String employeeId : employeeIds) {

                String checkSql =
                    "SELECT id FROM team_members " +
                    "WHERE team_id = ? " +
                    "AND employee_id = ?";

                PreparedStatement checkPs =
                    con.prepareStatement(checkSql);

                checkPs.setString(1, teamId);
                checkPs.setString(2, employeeId);

                ResultSet checkRs =
                    checkPs.executeQuery();

                if (checkRs.next()) {

                    checkRs.close();
                    checkPs.close();

                    continue;
                }

                checkRs.close();
                checkPs.close();


                String insertSql =
                    "INSERT INTO team_members " +
                    "(team_id, employee_id, status) " +
                    "VALUES (?, ?, 'ACTIVE')";

                PreparedStatement insertPs =
                    con.prepareStatement(insertSql);

                insertPs.setString(1, teamId);
                insertPs.setString(2, employeeId);

                int rows =
                    insertPs.executeUpdate();

                insertPs.close();

                if (rows > 0) {
                    addedCount++;
                }
            }


            response.sendRedirect(
                "managerTeamMembers.jsp?teamId="
                + teamId
                + "&message="
                + addedCount
                + " employee(s) added successfully"
            );

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "managerTeamMembers.jsp?teamId="
                + teamId
                + "&message=Error adding employees"
            );

        } finally {

            try {
                if (con != null) con.close();
            } catch (Exception e) {}

        }
    }
}