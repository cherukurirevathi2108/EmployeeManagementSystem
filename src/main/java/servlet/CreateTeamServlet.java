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

@WebServlet("/CreateTeamServlet")
public class CreateTeamServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        String teamName = request.getParameter("teamName");
        String department = request.getParameter("department");
        String managerId = request.getParameter("managerId");
        String description = request.getParameter("description");


        // Remove extra spaces
        if (teamName != null) {
            teamName = teamName.trim();
        }

        if (department != null) {
            department = department.trim();
        }

        if (managerId != null) {
            managerId = managerId.trim();
        }

        if (description != null) {
            description = description.trim();
        }


        // 1. Team Name validation
        if (teamName == null || teamName.trim().isEmpty()) {

            response.sendRedirect(
                "createTeam.jsp?message=Team Name is required"
            );

            return;
        }


        // 2. Department validation
        if (department == null || department.trim().isEmpty()) {

            response.sendRedirect(
                "createTeam.jsp?message=Department must be selected"
            );

            return;
        }


        // 3. Manager validation
        if (managerId == null || managerId.trim().isEmpty()) {

            response.sendRedirect(
                "createTeam.jsp?message=Team Manager must be selected"
            );

            return;
        }


        // 4. Description validation
        if (description != null && description.length() > 500) {

            response.sendRedirect(
                "createTeam.jsp?message=Description should not exceed 500 characters"
            );

            return;
        }


        Connection con = null;
        PreparedStatement checkPs = null;
        PreparedStatement insertPs = null;
        PreparedStatement idPs = null;

        ResultSet rs = null;
        ResultSet idRs = null;


        try {

            con = DBcConnection.getConnection();

            if (con == null) {

                response.sendRedirect(
                    "createTeam.jsp?message=Database connection failed"
                );

                return;
            }


            // 5. Check duplicate team name
            String checkSql =
                "SELECT team_id " +
                "FROM teams " +
                "WHERE LOWER(team_name) = LOWER(?)";


            checkPs = con.prepareStatement(checkSql);

            checkPs.setString(1, teamName);

            rs = checkPs.executeQuery();


            if (rs.next()) {

                response.sendRedirect(
                    "createTeam.jsp?message=Team Name already exists"
                );

                return;
            }


            // Close duplicate check
            rs.close();
            rs = null;

            checkPs.close();
            checkPs = null;


            // 6. Generate Team ID
            String teamId = "TEAM001";


            String idSql =
                "SELECT team_id " +
                "FROM teams " +
                "ORDER BY id DESC " +
                "LIMIT 1";


            idPs = con.prepareStatement(idSql);

            idRs = idPs.executeQuery();


            if (idRs.next()) {

                String lastId = idRs.getString("team_id");

                try {

                    int number =
                        Integer.parseInt(lastId.substring(4));

                    number++;

                    teamId =
                        String.format("TEAM%03d", number);

                } catch (Exception e) {

                    teamId = "TEAM001";
                }
            }


            // Close ID query
            idRs.close();
            idRs = null;

            idPs.close();
            idPs = null;


            // 7. Insert Team
            String insertSql =
                "INSERT INTO teams " +
                "(team_id, team_name, description, department, manager_id, status) " +
                "VALUES (?, ?, ?, ?, ?, 'ACTIVE')";


            insertPs = con.prepareStatement(insertSql);


            insertPs.setString(1, teamId);
            insertPs.setString(2, teamName);


            if (description == null ||
                description.trim().isEmpty()) {

                insertPs.setNull(
                    3,
                    java.sql.Types.VARCHAR
                );

            } else {

                insertPs.setString(
                    3,
                    description
                );
            }


            insertPs.setString(4, department);
            insertPs.setString(5, managerId);


            int rows =
                insertPs.executeUpdate();


            if (rows > 0) {

                response.sendRedirect(
                    "createTeam.jsp?message=Team created successfully&type=success"
                );

            } else {

                response.sendRedirect(
                    "createTeam.jsp?message=Team creation failed"
                );
            }


        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "createTeam.jsp?message=Error creating team"
            );


        } finally {

            try {
                if (rs != null) rs.close();
            } catch (Exception e) {}

            try {
                if (idRs != null) idRs.close();
            } catch (Exception e) {}

            try {
                if (checkPs != null) checkPs.close();
            } catch (Exception e) {}

            try {
                if (idPs != null) idPs.close();
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

        response.sendRedirect("createTeam.jsp");
    }
}