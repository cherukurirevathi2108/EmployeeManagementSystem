package servlet;

import java.io.IOException;
import java.sql.Connection;

import DAO.TeamDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import model.DBcConnection;
import model.Team;

@WebServlet("/ViewTeamServlet")
public class ViewTeamServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        String idString =
                request.getParameter("id");

        if (idString == null ||
            idString.trim().isEmpty()) {

            response.sendRedirect(
                "ManageTeamsServlet"
            );

            return;
        }

        try {

            int id =
                Integer.parseInt(idString);

            DBcConnection db =
                new DBcConnection();

            Connection connection =
                db.getConnection();

            TeamDAO teamDAO =
                new TeamDAO(connection);

            Team team =
                teamDAO.getTeamById(id);

            if (team == null) {

                response.sendRedirect(
                    "ManageTeamsServlet"
                );

                return;
            }

            request.setAttribute(
                "team",
                team
            );

            request.getRequestDispatcher(
                "viewTeam.jsp"
            ).forward(
                request,
                response
            );

        } catch (NumberFormatException e) {

            response.sendRedirect(
                "ManageTeamsServlet"
            );

        } catch (Exception e) {

            e.printStackTrace();

            response.setContentType(
                "text/html;charset=UTF-8"
            );

            response.getWriter().println(
                "<h3>Error loading team details</h3>"
            );
        }
    }


    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        doGet(request, response);
    }
}