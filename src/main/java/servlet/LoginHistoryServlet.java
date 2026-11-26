package servlet;

import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.Collections;

import DAO.LoginHistoryDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import model.LoginHistory;
import service.AuditService;
import util.SystemLogger;
import util.Web;

@WebServlet("/system/login-history")
public class LoginHistoryServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        LoginHistoryDAO.Criteria cr = new LoginHistoryDAO.Criteria();
        String error = null;

        cr.email = Web.str(req, "email", 150);
        String type = Web.str(req, "type", 30);
        if (type != null && type.matches("LOGIN|LOGOUT|FAILED_LOGIN|SESSION_EXPIRED")) cr.activityType = type;

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

        int size = Web.intParam(req, "size", 25, 10, 100);
        int page = Web.intParam(req, "page", 1, 1, 1_000_000);

        try {
            LoginHistoryDAO dao = new LoginHistoryDAO();
            req.setAttribute("suspicious", dao.suspicious(AuditService.FAILED_LOGIN_THRESHOLD,
                    AuditService.FAILED_LOGIN_WINDOW_MIN));
            if (error == null) {
                long total = dao.count(cr);
                int pages = (int) Math.max(1, (total + size - 1) / size);
                if (page > pages) page = pages;
                req.setAttribute("rows", dao.search(cr, size, (page - 1) * size));
                req.setAttribute("total", total);
                req.setAttribute("pages", pages);
            } else {
                req.setAttribute("rows", Collections.<LoginHistory>emptyList());
                req.setAttribute("total", 0L);
            }
        } catch (SQLException e) {
            SystemLogger.error("LoginHistory", e, req);
            error = "Login history could not be loaded. The problem has been logged.";
            req.setAttribute("rows", Collections.<LoginHistory>emptyList());
            req.setAttribute("total", 0L);
        }

        req.setAttribute("error", error);
        req.setAttribute("page", page);
        req.setAttribute("size", size);
        req.setAttribute("fEmail", req.getParameter("email"));
        req.setAttribute("fType", req.getParameter("type"));
        req.setAttribute("fFrom", fromText);
        req.setAttribute("fTo", toText);
        req.setAttribute("threshold", AuditService.FAILED_LOGIN_THRESHOLD);
        req.setAttribute("window", AuditService.FAILED_LOGIN_WINDOW_MIN);
        req.getRequestDispatcher("/WEB-INF/admin/login-history.jsp").forward(req, res);
    }
}
