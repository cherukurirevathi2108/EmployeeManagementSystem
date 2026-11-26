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

@WebServlet("/AssignTeamServlet")
public class AssignTeamServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String teamId = request.getParameter("teamId");
        String managerId = request.getParameter("managerId");

        if (teamId == null || teamId.trim().isEmpty()
                || managerId == null || managerId.trim().isEmpty()) {

            response.sendRedirect(
                "assignTeam.jsp?message=Please select Team and Manager"
            );

            return;
        }

        Connection con = null;
        PreparedStatement teamPs = null;
        PreparedStatement managerPs = null;
        PreparedStatement updatePs = null;

        ResultSet teamRs = null;
        ResultSet managerRs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                    "assignTeam.jsp?message=Database connection failed"
                );

                return;
            }


            // Check Team

            String teamSql =
                "SELECT team_id FROM teams WHERE team_id = ?";

            teamPs = con.prepareStatement(teamSql);

            teamPs.setString(1, teamId);

            teamRs = teamPs.executeQuery();

            if (!teamRs.next()) {

                response.sendRedirect(
                    "assignTeam.jsp?message=Team not found"
                );

                return;
            }


            // Check Manager

            String managerSql =
                "SELECT employee_id FROM managers " +
                "WHERE employee_id = ? " +
                "AND status = 'ACTIVE'";

            managerPs = con.prepareStatement(managerSql);

            managerPs.setString(1, managerId);

            managerRs = managerPs.executeQuery();

            if (!managerRs.next()) {

                response.sendRedirect(
                    "assignTeam.jsp?message=Active Manager not found"
                );

                return;
            }


            // Assign Manager

            String updateSql =
                "UPDATE teams " +
                "SET manager_id = ?, " +
                "updated_at = CURRENT_TIMESTAMP " +
                "WHERE team_id = ?";

            updatePs = con.prepareStatement(updateSql);

            updatePs.setString(1, managerId);
            updatePs.setString(2, teamId);

            int rows = updatePs.executeUpdate();

            if (rows > 0) {

                response.sendRedirect(
                    "assignTeam.jsp?message=Manager assigned successfully"
                );

            } else {

                response.sendRedirect(
                    "assignTeam.jsp?message=Manager assignment failed"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "assignTeam.jsp?message=Error assigning manager"
            );

        } finally {

            try {
                if (teamRs != null) teamRs.close();
            } catch (Exception e) {}

            try {
                if (managerRs != null) managerRs.close();
            } catch (Exception e) {}

            try {
                if (teamPs != null) teamPs.close();
            } catch (Exception e) {}

            try {
                if (managerPs != null) managerPs.close();
            } catch (Exception e) {}

            try {
                if (updatePs != null) updatePs.close();
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

        response.sendRedirect("assignTeam.jsp");
    }
}