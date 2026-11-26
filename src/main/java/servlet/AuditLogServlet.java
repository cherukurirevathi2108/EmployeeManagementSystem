package servlet;

import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import DAO.AuditLogDAO;
import DAO.UserMonitorDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import model.AuditLog;
import service.AuditService;
import util.Security;
import util.SystemLogger;
import util.Web;

/**
 * Audit log viewer. Access to the page is enforced by SystemAccessFilter; this servlet
 * additionally narrows WHAT each role can see:
 *   ADMIN, HR  - everything
 *   MANAGER    - own actions + actions by members of teams they lead
 *   EMPLOYEE   - own actions only
 */
@WebServlet("/system/audit-logs")
public class AuditLogServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private static final int MAX_EXPORT = 10_000;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        HttpSession session = req.getSession(false);
        String role = Security.role(session);
        String me = Security.userId(session);
        boolean fullAccess = "ADMIN".equals(role) || "HR".equals(role);

        AuditLogDAO.Criteria cr = new AuditLogDAO.Criteria();
        String error = null;

        cr.userId = Web.str(req, "user", 50);
        cr.moduleName = Web.str(req, "module", 100);
        cr.actionType = Web.str(req, "action", 50);
        cr.keyword = Web.str(req, "q", 100);

        String fromText = Web.str(req, "from", 10), toText = Web.str(req, "to", 10);
        try {
            LocalDate from = Web.date(fromText), to = Web.date(toText);
            if (from != null && to != null && from.isAfter(to)) {
                error = "Invalid date filter: the 'from' date must not be after the 'to' date.";
            } else {
                cr.from = Web.startOf(from);
                cr.toExclusive = Web.endExclusive(to);
            }
        } catch (IllegalArgumentException e) {
            error = "Invalid date filter: use the format yyyy-mm-dd.";
        }

        // ----- scope by role -----
        if (!fullAccess) {
            List<String> scope = new ArrayList<>();
            scope.add(me);
            if ("MANAGER".equals(role)) {
                for (String id : new UserMonitorDAO().teamMemberIds(me)) if (!scope.contains(id)) scope.add(id);
            }
            cr.scopeUserIds = scope;
            req.setAttribute("scopeUsers", scope);   // lets the manager pick "me" or one team member
            // a user filter may only narrow within the allowed set
            if (cr.userId != null && !scope.contains(cr.userId)) cr.userId = "\u0000none";
        }

        int size = Web.intParam(req, "size", 25, 10, 100);
        int page = Web.intParam(req, "page", 1, 1, 1_000_000);

        try {
            if (error != null) {
                // show the validation message, with an empty result set
                req.setAttribute("logs", Collections.<AuditLog>emptyList());
                req.setAttribute("total", 0L);
            } else if ("csv".equals(req.getParameter("export")) && fullAccess) {   // employees / managers: view only, no export
                export(req, res, cr, role);
                return;
            } else {
                long total = new AuditLogDAO().count(cr);
                int pages = (int) Math.max(1, (total + size - 1) / size);
                if (page > pages) page = pages;
                req.setAttribute("logs", new AuditLogDAO().search(cr, size, (page - 1) * size));
                req.setAttribute("total", total);
                req.setAttribute("pages", pages);
            }
            req.setAttribute("modules", new AuditLogDAO().distinctModules());
        } catch (SQLException e) {
            SystemLogger.error("Audit", e, req);
            error = "The audit records could not be loaded. The problem has been logged.";
            req.setAttribute("logs", Collections.<AuditLog>emptyList());
            req.setAttribute("total", 0L);
        }

        req.setAttribute("error", error);
        req.setAttribute("page", page);
        req.setAttribute("size", size);
        req.setAttribute("fullAccess", fullAccess);
        req.setAttribute("fUser", req.getParameter("user"));
        req.setAttribute("fModule", req.getParameter("module"));
        req.setAttribute("fAction", req.getParameter("action"));
        req.setAttribute("fQ", req.getParameter("q"));
        req.setAttribute("fFrom", fromText);
        req.setAttribute("fTo", toText);
        req.getRequestDispatcher("/WEB-INF/admin/audit-logs.jsp").forward(req, res);
    }

    private void export(HttpServletRequest req, HttpServletResponse res, AuditLogDAO.Criteria cr, String role)
            throws IOException, SQLException {
        // exporting is an action worth auditing in itself
        AuditService.log(req, "AUDIT", "EXPORT", null, "Exported audit log as CSV", null, null);

        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader("Content-Disposition", "attachment; filename=\"audit-report.csv\"");
        StringBuilder sb = new StringBuilder("\uFEFFId,Time,User,Role,Module,Action,Record,Description,IP\r\n");
        for (AuditLog a : new AuditLogDAO().search(cr, MAX_EXPORT, 0)) {
            sb.append(a.getId()).append(',')
              .append(Web.csv(a.getCreatedAt())).append(',')
              .append(Web.csv(a.getUserId())).append(',')
              .append(Web.csv(a.getUserRole())).append(',')
              .append(Web.csv(a.getModuleName())).append(',')
              .append(Web.csv(a.getActionType())).append(',')
              .append(Web.csv(a.getRecordId())).append(',')
              .append(Web.csv(a.getDescription())).append(',')
              .append(Web.csv(a.getIpAddress())).append("\r\n");
        }
        res.getWriter().write(sb.toString());
    }
}
