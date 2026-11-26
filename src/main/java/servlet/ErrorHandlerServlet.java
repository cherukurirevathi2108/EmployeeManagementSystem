package servlet;

import java.io.IOException;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import util.Security;
import util.SystemLogger;

/**
 * Target of the <error-page> entries in web.xml. Any uncaught exception or
 * HTTP 500 is recorded in system_errors, and the visitor only sees a generic
 * page with a reference number. Stack traces are never shown to users.
 */
@WebServlet("/error-handler")
public class ErrorHandlerServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        handle(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        handle(req, res);
    }

    private void handle(HttpServletRequest req, HttpServletResponse res) throws IOException {
        Integer status = (Integer) req.getAttribute(RequestDispatcher.ERROR_STATUS_CODE);
        Throwable t = (Throwable) req.getAttribute(RequestDispatcher.ERROR_EXCEPTION);
        String uri = (String) req.getAttribute(RequestDispatcher.ERROR_REQUEST_URI);
        int code = status == null ? 500 : status;

        long ref = -1;
        if (code >= 500) {
            String module = uri == null ? "Application" : uri.replaceAll("^/[^/]+", "").replaceAll("[?;].*$", "");
            if (module.isEmpty()) module = "Application";
            String userId = Security.userId(req.getSession(false));
            ref = SystemLogger.record(module,
                    t != null ? t.getClass().getName() : "HTTP " + code,
                    t != null ? t.getMessage() : "Server error at " + uri,
                    t != null ? "HIGH" : "MEDIUM", userId);
        }

        res.setStatus(code);
        res.setContentType("text/html; charset=UTF-8");
        String title = code == 403 ? "Access denied" : code == 404 ? "Page not found" : "Something went wrong";
        String body = code == 403 ? "You do not have permission to view this page."
                : code == 404 ? "The page you asked for does not exist."
                : "An unexpected error occurred. Please try again, or contact an administrator"
                  + (ref > 0 ? " and quote reference <b>#" + ref + "</b>" : "") + ".";
        res.getWriter().write("<!DOCTYPE html><html><head><meta charset='UTF-8'><title>" + title
                + "</title><style>body{font-family:Segoe UI,Arial,sans-serif;background:#f4f6fb;display:flex;"
                + "align-items:center;justify-content:center;height:100vh;margin:0}.b{background:#fff;padding:40px 48px;"
                + "border-radius:14px;box-shadow:0 8px 30px rgba(0,0,0,.08);max-width:460px;text-align:center}"
                + "h1{margin:0 0 10px;color:#1e293b}p{color:#475569}a{color:#4f46e5}</style></head><body><div class='b'><h1>"
                + title + "</h1><p>" + body + "</p><a href='" + req.getContextPath()
                + "/login.html'>Back to SmartOffice</a></div></body></html>");
    }
}
