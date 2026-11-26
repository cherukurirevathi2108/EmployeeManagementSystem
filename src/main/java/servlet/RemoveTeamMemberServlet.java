package servlet;

import java.io.IOException;
import java.net.URLEncoder;
import java.sql.Connection;
import java.sql.PreparedStatement;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.DBcConnection;

@WebServlet("/RemoveTeamMemberServlet")
public class RemoveTeamMemberServlet extends HttpServlet {

    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        String teamId =
            request.getParameter("teamId");

        String employeeId =
            request.getParameter("employeeId");


        if (teamId == null ||
            teamId.trim().isEmpty() ||
            employeeId == null ||
            employeeId.trim().isEmpty()) {

            response.sendRedirect(
                "teamMemberManagement.jsp" +
                "?message=Invalid team or employee&type=error"
            );

            return;
        }


        teamId = teamId.trim();
        employeeId = employeeId.trim();


        Connection con = null;
        PreparedStatement ps = null;


        try {

            con = DBcConnection.getConnection();


            if (con == null) {

                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId=" +
                    teamId +
                    "&message=Database connection failed&type=error"
                );

                return;
            }


            /*
             * Set member status to INACTIVE
             */

            String sql =
                "UPDATE team_members " +
                "SET status = 'INACTIVE' " +
                "WHERE team_id = ? " +
                "AND employee_id = ? " +
                "AND status = 'ACTIVE'";


            ps =
                con.prepareStatement(sql);

            ps.setString(1, teamId);
            ps.setString(2, employeeId);


            int rows =
                ps.executeUpdate();


            if (rows > 0) {

                String message =
                    "Employee removed from team successfully";


                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId=" +
                    teamId +
                    "&message=" +
                    URLEncoder.encode(message, "UTF-8") +
                    "&type=success"
                );

            } else {

                response.sendRedirect(
                    "teamMemberManagement.jsp?teamId=" +
                    teamId +
                    "&message=Employee is not an active member of this team&type=error"
                );
            }


        } catch (Exception e) {

            e.printStackTrace();


            response.sendRedirect(
                "teamMemberManagement.jsp?teamId=" +
                teamId +
                "&message=Error removing employee&type=error"
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


    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        doGet(request, response);
    }
}