package filter;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.annotation.WebFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import service.AuditService;
import util.Security;

/**
 * Server-side authorization for every /system/* page:
 *  - must be logged in
 *  - role must be allowed for that specific page (unknown pages are denied)
 *  - every POST must carry a valid CSRF token
 * Denials and CSRF failures are recorded as SECURITY events.
 */
@WebFilter("/system/*")
public class SystemAccessFilter implements Filter {

    private static final Map<String, Set<String>> ALLOWED = new HashMap<>();
    static {
        // ADMIN is the application's top-level account, so it plays the "Super Admin" role.
        // HR is the next level and gets read-only monitoring. MANAGER / EMPLOYEE only reach
        // the audit page, where the servlet narrows results to their own (or team) activity.
        allow("/system/dashboard", "ADMIN", "HR");
        allow("/system/audit-logs", "ADMIN", "HR", "MANAGER", "EMPLOYEE");
        allow("/system/login-history", "ADMIN", "HR");
        allow("/system/errors", "ADMIN", "HR");
        allow("/system/users", "ADMIN");
        allow("/system/settings", "ADMIN");
        allow("/system/backups", "ADMIN");
    }

    private static void allow(String path, String... roles) {
        ALLOWED.put(path, new HashSet<>(Arrays.asList(roles)));
    }

    @Override
    public void doFilter(ServletRequest sreq, ServletResponse sres, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest req = (HttpServletRequest) sreq;
        HttpServletResponse res = (HttpServletResponse) sres;

        String path = req.getServletPath();
        HttpSession session = req.getSession(false);
        String role = Security.role(session);

        if (role == null || Security.userId(session) == null) {
            res.sendRedirect(req.getContextPath() + "/login.html");
            return;
        }

        Set<String> roles = ALLOWED.get(path);
        if (roles == null || !roles.contains(role)) {
            AuditService.logSecurity(req, "ACCESS_DENIED",
                    role + " tried to open restricted page " + path);
            res.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }

        if ("POST".equalsIgnoreCase(req.getMethod()) && !Security.validCsrf(req)) {
            AuditService.logSecurity(req, "CSRF_FAILURE", "POST to " + path + " rejected: missing or invalid CSRF token");
            res.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }

        // admin data should never be cached by the browser or a proxy
        res.setHeader("Cache-Control", "no-store");
        res.setHeader("X-Content-Type-Options", "nosniff");
        chain.doFilter(sreq, sres);
    }
}
