package servlet;

import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.Collections;

import DAO.SystemErrorDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import model.SystemError;
import util.SystemLogger;
import util.Web;

@WebServlet("/system/errors")
public class SystemErrorServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        SystemErrorDAO.Criteria cr = new SystemErrorDAO.Criteria();
        String error = null;

        String sev = Web.str(req, "severity", 20);
        if (sev != null && sev.matches("LOW|MEDIUM|HIGH|CRITICAL")) cr.severity = sev;
        cr.moduleName = Web.str(req, "module", 100);
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

        int size = Web.intParam(req, "size", 25, 10, 100);
        int page = Web.intParam(req, "page", 1, 1, 1_000_000);

        try {
            SystemErrorDAO dao = new SystemErrorDAO();
            if (error == null) {
                long total = dao.count(cr);
                int pages = (int) Math.max(1, (total + size - 1) / size);
                if (page > pages) page = pages;
                req.setAttribute("rows", dao.search(cr, size, (page - 1) * size));
                req.setAttribute("total", total);
                req.setAttribute("pages", pages);
            } else {
                req.setAttribute("rows", Collections.<SystemError>emptyList());
                req.setAttribute("total", 0L);
            }
            req.setAttribute("modules", dao.distinctModules());
        } catch (SQLException e) {
            // do not call SystemLogger here: if the DB is down it would just fail again
            e.printStackTrace();
            error = "Errors could not be loaded right now.";
            req.setAttribute("rows", Collections.<SystemError>emptyList());
            req.setAttribute("total", 0L);
        }

        req.setAttribute("error", error);
        req.setAttribute("page", page);
        req.setAttribute("size", size);
        req.setAttribute("fSeverity", req.getParameter("severity"));
        req.setAttribute("fModule", req.getParameter("module"));
        req.setAttribute("fQ", req.getParameter("q"));
        req.setAttribute("fFrom", fromText);
        req.setAttribute("fTo", toText);
        req.getRequestDispatcher("/WEB-INF/admin/system-errors.jsp").forward(req, res);
    }
}
