package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.util.List;

import DAO.TeamDAO;
import DAO.TeamMemberDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.DBcConnection;
import model.Team;
import model.TeamMember;

@WebServlet("/TeamMembersServlet")
public class TeamMembersServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        String idString = request.getParameter("id");

        if (idString == null || idString.trim().isEmpty()) {
            response.sendRedirect("ManageTeamsServlet");
            return;
        }

        try {

            int teamId = Integer.parseInt(idString);

            Connection connection =
                    DBcConnection.getConnection();

            TeamDAO teamDAO =
                    new TeamDAO(connection);

            TeamMemberDAO teamMemberDAO =
                    new TeamMemberDAO(connection);

            // Get team
            Team team =
                    teamDAO.getTeamById(teamId);

            if (team == null) {
                response.sendRedirect("ManageTeamsServlet");
                return;
            }

            // Get team members
            List<TeamMember> members =
                    teamMemberDAO.getTeamMembers(teamId);

            // Send data to JSP
            request.setAttribute("team", team);
            request.setAttribute("members", members);

            request.getRequestDispatcher("teamMembers.jsp")
                   .forward(request, response);

        } catch (NumberFormatException e) {

            response.sendRedirect("ManageTeamsServlet");

        } catch (Exception e) {

            e.printStackTrace();

            response.setContentType("text/html");

            response.getWriter().println(
                "<h3>Error loading team members</h3>"
            );
        }
    }

    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        doGet(request, response);
    }
}