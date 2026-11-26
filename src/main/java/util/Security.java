package util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

/**
 * Session helpers shared by the audit module: who is logged in, CSRF tokens,
 * client IP / browser capture.
 *
 * The existing login code stores the role in session attribute "role"
 * (ADMIN / HR / MANAGER / EMPLOYEE) and the ID under a role-specific key.
 */
public final class Security {

    public static final String CSRF_PARAM = "csrfToken";
    private static final String CSRF_ATTR = "auditCsrfToken";
    private static final SecureRandom RANDOM = new SecureRandom();

    private Security() { }

    public static String role(HttpSession s) {
        if (s == null) return null;
        Object r = s.getAttribute("role");
        return r == null ? null : String.valueOf(r).toUpperCase();
    }

    public static String userId(HttpSession s) {
        if (s == null) return null;
        for (String key : new String[] { "adminId", "hrId", "managerId", "employeeId" }) {
            Object v = s.getAttribute(key);
            if (v != null && !String.valueOf(v).isEmpty()) return String.valueOf(v);
        }
        return null;
    }

    public static String userName(HttpSession s) {
        if (s == null) return null;
        for (String key : new String[] { "adminName", "hrName", "managerName", "employeeName", "name" }) {
            Object v = s.getAttribute(key);
            if (v != null) return String.valueOf(v);
        }
        return null;
    }

    public static String email(HttpSession s) {
        if (s == null) return null;
        for (String key : new String[] { "adminEmail", "hrEmail", "managerEmail", "email" }) {
            Object v = s.getAttribute(key);
            if (v != null) return String.valueOf(v);
        }
        return null;
    }

    public static boolean hasRole(HttpSession s, String... roles) {
        String r = role(s);
        if (r == null) return false;
        for (String x : roles) if (x.equals(r)) return true;
        return false;
    }

    // ---- CSRF ----

    public static synchronized String csrfToken(HttpSession s) {
        Object t = s.getAttribute(CSRF_ATTR);
        if (t == null) {
            byte[] b = new byte[32];
            RANDOM.nextBytes(b);
            t = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
            s.setAttribute(CSRF_ATTR, t);
        }
        return String.valueOf(t);
    }

    public static boolean validCsrf(HttpServletRequest req) {
        HttpSession s = req.getSession(false);
        if (s == null) return false;
        Object expected = s.getAttribute(CSRF_ATTR);
        String given = req.getParameter(CSRF_PARAM);
        if (given == null) given = req.getHeader("X-CSRF-Token");
        if (expected == null || given == null) return false;
        return MessageDigest.isEqual(
                String.valueOf(expected).getBytes(StandardCharsets.UTF_8),
                given.getBytes(StandardCharsets.UTF_8));
    }

    // ---- client info ----

    /**
     * Uses the socket address on purpose: X-Forwarded-For can be forged by the
     * client. If the app is later put behind a trusted reverse proxy, change this
     * to read the proxy's header.
     */
    public static String clientIp(HttpServletRequest req) {
        String ip = req.getRemoteAddr();
        return ip == null ? null : (ip.length() > 45 ? ip.substring(0, 45) : ip);
    }

    public static String userAgent(HttpServletRequest req) {
        String ua = req.getHeader("User-Agent");
        return ua == null ? null : (ua.length() > 500 ? ua.substring(0, 500) : ua);
    }
}
