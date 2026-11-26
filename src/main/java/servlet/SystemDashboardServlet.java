package servlet;

import java.io.IOException;
import java.sql.SQLException;
import java.util.Map;

import DAO.AuditLogDAO;
import DAO.BackupHistoryDAO;
import DAO.LoginHistoryDAO;
import DAO.SystemErrorDAO;
import DAO.UserMonitorDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import service.AuditService;
import service.SystemSettingsService;
import util.SystemLogger;

/** Dashboard: ADMIN and HR (SystemAccessFilter). Every figure comes from the database. */
@WebServlet("/system/dashboard")
public class SystemDashboardServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            Map<String, Map<String, Long>> counts = new UserMonitorDAO().countsByRoleAndStatus();
            long total = 0, active = 0;
            for (Map<String, Long> byStatus : counts.values()) {
                for (Map.Entry<String, Long> e : byStatus.entrySet()) {
                    total += e.getValue();
                    if ("ACTIVE".equals(e.getKey())) active += e.getValue();
                }
            }
            req.setAttribute("totalUsers", total);
            req.setAttribute("activeUsers", active);
            req.setAttribute("inactiveUsers", total - active);

            AuditLogDAO audit = new AuditLogDAO();
            req.setAttribute("auditTotal", audit.countAll());
            req.setAttribute("recentActivity", audit.recent(8, false));
            req.setAttribute("recentSecurity", audit.recent(5, true));

            LoginHistoryDAO login = new LoginHistoryDAO();
            req.setAttribute("loginsToday", login.countToday("LOGIN"));
            req.setAttribute("failedToday", login.countToday("FAILED_LOGIN"));
            LoginHistoryDAO.Criteria none = new LoginHistoryDAO.Criteria();
            req.setAttribute("recentLogins", login.search(none, 8, 0));
            req.setAttribute("suspicious", login.suspicious(AuditService.FAILED_LOGIN_THRESHOLD,
                    AuditService.FAILED_LOGIN_WINDOW_MIN));

            req.setAttribute("recentErrors", new SystemErrorDAO().getAllSystemErrors(5, 0));
            req.setAttribute("latestBackup", new BackupHistoryDAO().latest());
            req.setAttribute("companyName", SystemSettingsService.get("company_name", "SmartOffice"));
            req.setAttribute("sessionTimeout", SystemSettingsService.getInt("session_timeout_minutes", 30));
        } catch (SQLException e) {
            SystemLogger.error("Dashboard", e, req);
            req.setAttribute("error", "Some dashboard figures could not be loaded. The problem has been logged.");
        }
        req.getRequestDispatcher("/WEB-INF/admin/system-dashboard.jsp").forward(req, res);
    }
}
