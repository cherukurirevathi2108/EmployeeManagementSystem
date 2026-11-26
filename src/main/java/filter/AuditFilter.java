package filter;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

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
 * Records create / update / delete activity from the existing modules without
 * editing each servlet: every state-changing request (POST, plus the GET URLs
 * listed in MUTATING_GET) that finishes with an HTTP status below 400 is logged
 * with the user, module, record ID and the submitted parameters.
 *
 * LIMITATION: this logs that a request was made and the server did not error.
 * These servlets answer failures with a redirect too, so a rejected request can
 * still appear here. Use AuditService.log(...) inside a servlet when you need
 * exact old/new values (see DeleteEmployeeServlet for an example).
 *
 * Passwords, tokens and similar fields are never stored.
 */
@WebFilter("/*")
public class AuditFilter implements Filter {

    private static final Set<String> EXCLUDED = new HashSet<>(Arrays.asList(
            "/login", "/logout", "/managerLogout", "/error-handler",
            "/DeleteEmployeeServlet"));          // these record themselves with richer detail

    private static final Set<String> MUTATING_GET = new HashSet<>(Arrays.asList(
            "/DeleteTeamServlet", "/RemoveTeamMemberServlet", "/ManagerRemoveTeamMemberServlet"));

    private static final Map<String, String> MODULES = new HashMap<>();
    static {
        m("Employee", "/AddEmployeeServlet", "/employee", "/employees", "/employeeDetails");
        m("Manager", "/AddManagerServlet", "/manager");
        m("Team", "/CreateTeamServlet", "/EditTeamServlet", "/DeleteTeamServlet", "/ManageTeamsServlet",
                "/ManagerEditTeamServlet", "/AssignTeamServlet", "/AddTeamMemberServlet",
                "/ManagerAddTeamMembersServlet", "/RemoveTeamMemberServlet", "/ManagerRemoveTeamMemberServlet");
        m("Leave", "/leave");
        m("Payroll", "/payroll");
        m("Task", "/tasks", "/managerTask", "/workProof");
        m("Overtime", "/overtime");
        m("HR", "/hr");
        m("Admin", "/admin");
        m("Registration", "/register");
    }

    private static void m(String module, String... paths) {
        for (String p : paths) MODULES.put(p, module);
    }

    private static final Pattern SECRET_NAME =
            Pattern.compile(".*(pass|pwd|secret|token|csrf|otp|pin|card).*", Pattern.CASE_INSENSITIVE);
    private static final Pattern SENSITIVE =
            Pattern.compile(".*(salary|payroll|approve|reject|decid|leave|overtime).*", Pattern.CASE_INSENSITIVE);
    private static final String[] ID_PARAMS =
            { "employeeId", "managerId", "hrId", "teamId", "taskId", "leaveId", "otId", "id" };

    @Override
    public void doFilter(ServletRequest sreq, ServletResponse sres, FilterChain chain)
            throws IOException, ServletException {

        if (!(sreq instanceof HttpServletRequest) || !(sres instanceof HttpServletResponse)) {
            chain.doFilter(sreq, sres);
            return;
        }
        HttpServletRequest req = (HttpServletRequest) sreq;
        HttpServletResponse res = (HttpServletResponse) sres;

        String path = req.getServletPath();
        boolean post = "POST".equalsIgnoreCase(req.getMethod());
        boolean candidate = !path.startsWith("/system/") && !EXCLUDED.contains(path)
                && (post || ("GET".equalsIgnoreCase(req.getMethod()) && MUTATING_GET.contains(path)));

        // Anonymous POSTs (e.g. /register) are logged too, with a null user.
        chain.doFilter(sreq, sres);

        if (!candidate || res.getStatus() >= 400) return;

        try {
            record(req, res, path);
        } catch (Throwable ignore) {
            // auditing must never break the response that was already produced
        }
    }

    private void record(HttpServletRequest req, HttpServletResponse res, String path) {
        HttpSession session = req.getSession(false);

        String action = req.getParameter("action");
        if (action != null && !action.matches("[A-Za-z0-9_\\-]{1,40}")) action = null;

        String label = (action != null ? action : path.substring(1));
        String module = MODULES.getOrDefault(path, path.substring(1));

        String recordId = null;
        for (String p : ID_PARAMS) {
            String v = req.getParameter(p);
            if (v != null && !v.trim().isEmpty()) {
                recordId = v.trim().length() > 100 ? v.trim().substring(0, 100) : v.trim();
                break;
            }
        }

        Map<String, Object> params = new LinkedHashMap<>();
        int n = 0;
        for (Map.Entry<String, String[]> e : req.getParameterMap().entrySet()) {
            if (n++ >= 25) break;
            String name = e.getKey();
            if (SECRET_NAME.matcher(name).matches()) continue;
            String v = e.getValue().length == 0 ? "" : e.getValue()[0];
            params.put(name, v != null && v.length() > 200 ? v.substring(0, 200) + "..." : v);
        }
        Map<String, Object> newValues = new LinkedHashMap<>();
        newValues.put("request_params", params);

        boolean sensitive = SENSITIVE.matcher(label).matches() || SENSITIVE.matcher(path).matches();
        String desc = (sensitive ? "[SENSITIVE] " : "") + req.getMethod() + " " + path
                + (action != null ? " action=" + action : "") + " (HTTP " + res.getStatus() + ")";

        AuditService.logAs(Security.userId(session), Security.role(session), Security.clientIp(req),
                module, actionType(label), recordId, desc, null, newValues);
    }

    private static String actionType(String label) {
        String l = label.toLowerCase();
        if (l.contains("delete") || l.contains("remove")) return "DELETE";
        if (l.contains("add") || l.contains("create") || l.contains("apply") || l.contains("register")
                || l.contains("assign") || l.contains("recruit") || l.contains("submit")) return "CREATE";
        return "UPDATE";
    }
}
