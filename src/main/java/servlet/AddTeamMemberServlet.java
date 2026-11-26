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

@WebServlet("/AddTeamMemberServlet")
public class AddTeamMemberServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String teamId = request.getParameter("teamId");
        String employeeId = request.getParameter("employeeId");

        if (teamId == null || teamId.trim().isEmpty()) {

            response.sendRedirect(
                "teamMemberManagement.jsp?message=Team ID is required&type=error"
            );
            return;
        }

        if (employeeId == null || employeeId.trim().isEmpty()) {

            response.sendRedirect(
                "teamMemberManagement.jsp?teamId="
                + teamId
                + "&message=Employee must be selected&type=error"
            );
            return;
        }

        teamId = teamId.trim();
        employeeId = employeeId.trim();

        Connection con = null;

        PreparedStatement checkPs = null;
        PreparedStatement updatePs = null;
        PreparedStatement insertPs = null;

        ResultSet rs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId="
                    + teamId
                    + "&message=Database connection failed&type=error"
                );
                return;
            }

            // ------------------------------------------------
            // 1. Check ACTIVE membership
            // ------------------------------------------------

            String checkSql =
                "SELECT id FROM team_members " +
                "WHERE team_id = ? " +
                "AND employee_id = ? " +
                "AND status = 'ACTIVE'";

            checkPs = con.prepareStatement(checkSql);

            checkPs.setString(1, teamId);
            checkPs.setString(2, employeeId);

            rs = checkPs.executeQuery();

            if (rs.next()) {

                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId="
                    + teamId
                    + "&message=Employee is already a member of this team&type=error"
                );

                return;
            }

            rs.close();
            rs = null;

            checkPs.close();
            checkPs = null;


            // ------------------------------------------------
            // 2. Check whether an INACTIVE record already exists
            // ------------------------------------------------

            String inactiveSql =
                "SELECT id FROM team_members " +
                "WHERE team_id = ? " +
                "AND employee_id = ? " +
                "AND status = 'INACTIVE'";

            checkPs = con.prepareStatement(inactiveSql);

            checkPs.setString(1, teamId);
            checkPs.setString(2, employeeId);

            rs = checkPs.executeQuery();

            if (rs.next()) {

                int id = rs.getInt("id");

                rs.close();
                rs = null;

                checkPs.close();
                checkPs = null;


                // Reactivate existing member

                String updateSql =
                    "UPDATE team_members " +
                    "SET status = 'ACTIVE', " +
                    "joined_date = CURRENT_DATE " +
                    "WHERE id = ?";

                updatePs = con.prepareStatement(updateSql);

                updatePs.setInt(1, id);

                int rows = updatePs.executeUpdate();

                if (rows > 0) {

                    String message =
                        URLEncoder.encode(
                            "Employee added successfully",
                            "UTF-8"
                        );

                    response.sendRedirect(
                        "teamMemberManagement.jsp?teamId="
                        + teamId
                        + "&message="
                        + message
                        + "&type=success"
                    );

                } else {

                    response.sendRedirect(
                        "teamMemberManagement.jsp?teamId="
                        + teamId
                        + "&message=Employee could not be added&type=error"
                    );
                }

                return;
            }

            rs.close();
            rs = null;

            checkPs.close();
            checkPs = null;


            // ------------------------------------------------
            // 3. Insert new team member
            // ------------------------------------------------

            String insertSql =
                "INSERT INTO team_members " +
                "(team_id, employee_id, joined_date, status) " +
                "VALUES (?, ?, CURRENT_DATE, 'ACTIVE')";

            insertPs = con.prepareStatement(insertSql);

            insertPs.setString(1, teamId);
            insertPs.setString(2, employeeId);

            int rows = insertPs.executeUpdate();

            if (rows > 0) {

                String message =
                    URLEncoder.encode(
                        "Employee added successfully",
                        "UTF-8"
                    );

                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId="
                    + teamId
                    + "&message="
                    + message
                    + "&type=success"
                );

            } else {

                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId="
                    + teamId
                    + "&message=Employee could not be added&type=error"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "teamMemberManagement.jsp?teamId="
                + teamId
                + "&message=Error adding employee&type=error"
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
                if (insertPs != null) insertPs.close();
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

        response.sendRedirect("teamMemberManagement.jsp");
    }
}