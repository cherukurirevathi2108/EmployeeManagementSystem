package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.util.List;

import DAO.TeamDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import model.DBcConnection;
import model.Team;

@WebServlet("/ManageTeamsServlet")
public class ManageTeamsServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        try {

            DBcConnection db = new DBcConnection();

            Connection connection = db.getConnection();

            TeamDAO teamDAO = new TeamDAO(connection);

            List<Team> teams = teamDAO.getAllTeams();

            request.setAttribute("teams", teams);

            request.getRequestDispatcher("manageTeams.jsp")
                   .forward(request, response);

            connection.close();

        } catch (Exception e) {

            e.printStackTrace();

            response.setContentType("text/html");

            response.getWriter().println(
                "<h3>Error loading teams</h3>"
            );
        }
    }

    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        doGet(request, response);
    }
}