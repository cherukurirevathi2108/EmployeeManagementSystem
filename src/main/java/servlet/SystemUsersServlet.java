package servlet;

import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import DAO.LoginHistoryDAO;
import DAO.UserMonitorDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import util.Security;
import util.SystemLogger;
import util.Web;

/**
 * Read-only user / role monitoring panel (ADMIN only): accounts by role and a
 * filterable user list. Role and CSRF checks are done by SystemAccessFilter;
 * the role is re-checked here as defence in depth.
 */
@WebServlet("/system/users")
public class SystemUsersServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if (!Security.hasRole(req.getSession(false), "ADMIN")) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }
        List<String> errors = new ArrayList<>();
        try {
            UserMonitorDAO users = new UserMonitorDAO();
            Map<String, Map<String, Long>> counts = users.countsByRoleAndStatus();
            req.setAttribute("counts", counts);

            String role = Web.str(req, "role", 20), status = Web.str(req, "status", 20);
            if (role != null && !role.matches("ADMIN|HR|MANAGER|EMPLOYEE")) role = null;
            if (status != null) status = status.toUpperCase();
            if (status != null && !status.matches("[A-Z_]{1,20}")) status = null;

            List<UserMonitorDAO.UserRow> list = users.listUsers(role, status, 200);
            Map<String, java.sql.Timestamp> last = new LoginHistoryDAO().lastLogins();
            for (UserMonitorDAO.UserRow u : list) u.lastLogin = last.get(u.role + ":" + u.id);
            req.setAttribute("users", list);
            req.setAttribute("fRole", role);
            req.setAttribute("fStatus", status);
        } catch (SQLException e) {
            SystemLogger.error("SystemUsers", e, req);
            errors.add("Some data could not be loaded. The problem has been logged.");
        }
        req.setAttribute("errors", errors);
        req.getRequestDispatcher("/WEB-INF/admin/system-users.jsp").forward(req, res);
    }
}
