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

@WebServlet("/managerTask")
public class ManagerTaskServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null ||
            session.getAttribute("managerId") == null) {

            response.sendRedirect("managerLogin.jsp");
            return;
        }

        String managerId =
                (String) session.getAttribute("managerId");

        String action = request.getParameter("action");

        if ("addTask".equals(action)) {

            addTask(request, response, managerId);

        } else {

            response.sendRedirect(
                "managerDashboard.jsp?error=invalidAction"
            );
        }
    }


    private void addTask(HttpServletRequest request,
                          HttpServletResponse response,
                          String managerId)
            throws IOException {

        String teamId =
                request.getParameter("teamId");

        String employeeId =
                request.getParameter("employeeId");

        String taskTitle =
                request.getParameter("taskTitle");

        String taskDescription =
                request.getParameter("taskDescription");

        String dueDate =
                request.getParameter("dueDate");


        /* ================= VALIDATION ================= */

        if (teamId == null ||
            employeeId == null ||
            taskTitle == null ||
            taskDescription == null ||
            dueDate == null ||
            teamId.trim().isEmpty() ||
            employeeId.trim().isEmpty() ||
            taskTitle.trim().isEmpty() ||
            taskDescription.trim().isEmpty() ||
            dueDate.trim().isEmpty()) {

            response.sendRedirect(
                "managerAssignTask.jsp?teamId="
                + teamId
                + "&error=missing"
            );

            return;
        }


        Connection con = null;

        PreparedStatement ps = null;

        ResultSet rs = null;


        try {

            con = DBcConnection.getConnection();


            /* ================= CHECK TEAM ================= */

            String checkTeam =
                "SELECT team_id " +
                "FROM teams " +
                "WHERE team_id = ? " +
                "AND manager_id = ?";


            ps = con.prepareStatement(checkTeam);

            ps.setString(1, teamId);
            ps.setString(2, managerId);

            rs = ps.executeQuery();


            if (!rs.next()) {

                rs.close();
                rs = null;

                ps.close();
                ps = null;

                response.sendRedirect(
                    "managerDashboard.jsp?error=unauthorized"
                );

                return;
            }


            rs.close();
            rs = null;

            ps.close();
            ps = null;


            /* ================= CHECK EMPLOYEE ================= */

            String checkEmployee =
                "SELECT employee_id " +
                "FROM team_members " +
                "WHERE team_id = ? " +
                "AND employee_id = ? " +
                "AND status = 'ACTIVE'";


            ps = con.prepareStatement(checkEmployee);

            ps.setString(1, teamId);
            ps.setString(2, employeeId);

            rs = ps.executeQuery();


            if (!rs.next()) {

                rs.close();
                rs = null;

                ps.close();
                ps = null;

                response.sendRedirect(
                    "managerAssignTask.jsp?teamId="
                    + teamId
                    + "&error=employee"
                );

                return;
            }


            rs.close();
            rs = null;

            ps.close();
            ps = null;


            /* ================= INSERT TASK ================= */

            String insertTask =
                "INSERT INTO tasks " +
                "(team_id, employee_id, manager_id, " +
                "task_title, task_description, due_date, status) " +
                "VALUES (?, ?, ?, ?, ?, ?, 'PENDING')";


            ps = con.prepareStatement(insertTask);

            ps.setString(1, teamId);
            ps.setString(2, employeeId);
            ps.setString(3, managerId);
            ps.setString(4, taskTitle.trim());
            ps.setString(5, taskDescription.trim());
            ps.setString(6, dueDate);


            int result = ps.executeUpdate();


            if (result > 0) {

                response.sendRedirect(
                    "managerAssignTask.jsp?teamId="
                    + teamId
                    + "&success=taskAssigned"
                );

            } else {

                response.sendRedirect(
                    "managerAssignTask.jsp?teamId="
                    + teamId
                    + "&error=failed"
                );
            }


        } catch (Exception e) {

            e.printStackTrace();

            response.sendRedirect(
                "managerAssignTask.jsp?teamId="
                + teamId
                + "&error=failed"
            );


        } finally {

            try {
                if (rs != null) {
                    rs.close();
                }
            } catch (Exception e) {
            }

            try {
                if (ps != null) {
                    ps.close();
                }
            } catch (Exception e) {
            }

            try {
                if (con != null) {
                    con.close();
                }
            } catch (Exception e) {
            }
        }
    }
}