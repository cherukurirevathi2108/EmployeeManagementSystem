
package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/managerTeams")
public class ManagerTeamServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private static final String DB_URL =
            "jdbc:mysql://localhost:3306/employee_db";
    private static final String DB_USER = "root";
    private static final String DB_PASSWORD = "root";

    private Connection getConnection() throws Exception {
        Class.forName("com.mysql.cj.jdbc.Driver");
        return DriverManager.getConnection(
                DB_URL, DB_USER, DB_PASSWORD);
    }

    @Override
    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        HttpSession session = request.getSession(false);

        if (session == null ||
                session.getAttribute("managerId") == null) {
            response.sendRedirect(
                    request.getContextPath() + "/managerLogin.jsp");
            return;
        }

        String managerId =
                String.valueOf(session.getAttribute("managerId"));

        String action = request.getParameter("action");

        String teamName = request.getParameter("teamName");
        String description = request.getParameter("description");
        String department = request.getParameter("department");
        String status = request.getParameter("status");
        String teamIdText = request.getParameter("teamId");

        if (teamName != null) teamName = teamName.trim();
        if (description != null) description = description.trim();
        if (department != null) department = department.trim();

        String message = "teamOperationFailed";

        try {
            if ("create".equals(action)) {

                if (teamName == null || teamName.isEmpty()) {
                    message = "teamNameRequired";
                } else {
                    String sql =
                        "INSERT INTO teams " +
                        "(team_name, description, department, " +
                        "manager_id, status) " +
                        "VALUES (?, ?, ?, ?, ?)";

                    try (Connection con = getConnection();
                         PreparedStatement ps =
                             con.prepareStatement(sql)) {

                        ps.setString(1, teamName);
                        ps.setString(2,
                                description == null ? "" : description);
                        ps.setString(3,
                                department == null ? "" : department);
                        ps.setString(4, managerId);
                        ps.setString(5, "ACTIVE");

                        if (ps.executeUpdate() > 0) {
                            message = "teamCreated";
                        }
                    }
                }

            } else if ("update".equals(action)) {

                int teamId = Integer.parseInt(teamIdText);

                if (teamName == null || teamName.isEmpty()) {
                    message = "teamNameRequired";
                } else if (!"ACTIVE".equals(status)
                        && !"INACTIVE".equals(status)) {
                    message = "invalidTeamStatus";
                } else {
                    String sql =
                        "UPDATE teams SET team_name=?, description=?, " +
                        "department=?, status=?, updated_at=CURRENT_TIMESTAMP " +
                        "WHERE team_id=? AND manager_id=?";

                    try (Connection con = getConnection();
                         PreparedStatement ps =
                             con.prepareStatement(sql)) {

                        ps.setString(1, teamName);
                        ps.setString(2,
                                description == null ? "" : description);
                        ps.setString(3,
                                department == null ? "" : department);
                        ps.setString(4, status);
                        ps.setInt(5, teamId);
                        ps.setString(6, managerId);

                        if (ps.executeUpdate() > 0) {
                            message = "teamUpdated";
                        } else {
                            message = "teamNotFound";
                        }
                    }
                }

            } else if ("delete".equals(action)) {

                int teamId = Integer.parseInt(teamIdText);

                try (Connection con = getConnection()) {
                    con.setAutoCommit(false);

                    try {
                        // Verify that this team belongs to this manager.
                        boolean ownsTeam = false;

                        try (PreparedStatement check =
                            con.prepareStatement(
                                "SELECT team_id FROM teams " +
                                "WHERE team_id=? AND manager_id=?")) {

                            check.setInt(1, teamId);
                            check.setString(2, managerId);

                            try (ResultSet rs = check.executeQuery()) {
                                ownsTeam = rs.next();
                            }
                        }

                        if (!ownsTeam) {
                            con.rollback();
                            message = "teamNotFound";
                        } else {
                            // Remove memberships before deleting the team.
                            try (PreparedStatement members =
                                con.prepareStatement(
                                    "DELETE FROM team_members WHERE team_id=?")) {
                                members.setInt(1, teamId);
                                members.executeUpdate();
                            }

                            try (PreparedStatement delete =
                                con.prepareStatement(
                                    "DELETE FROM teams " +
                                    "WHERE team_id=? AND manager_id=?")) {
                                delete.setInt(1, teamId);
                                delete.setString(2, managerId);

                                if (delete.executeUpdate() > 0) {
                                    con.commit();
                                    message = "teamDeleted";
                                } else {
                                    con.rollback();
                                    message = "teamNotFound";
                                }
                            }
                        }

                    } catch (Exception ex) {
                        con.rollback();
                        throw ex;
                    } finally {
                        con.setAutoCommit(true);
                    }
                }

            } else {
                message = "invalidTeamAction";
            }

        } catch (NumberFormatException e) {
            message = "invalidTeamId";
        } catch (Exception e) {
            getServletContext().log(
                    "Manager team operation failed", e);
            message = "teamOperationFailed";
        }

        response.sendRedirect(
                request.getContextPath()
                + "/managerDashboard.jsp?message="
                + message + "#myTeams");
    }
}

