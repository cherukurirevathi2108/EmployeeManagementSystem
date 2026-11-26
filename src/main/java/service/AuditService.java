package service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import DAO.AuditLogDAO;
import DAO.LoginHistoryDAO;
import DAO.UserMonitorDAO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import model.AuditLog;
import util.Json;
import util.Security;
import util.SystemLogger;

/**
 * Single entry point for recording audit and login events.
 *
 * Writes happen on a background thread so audit recording never slows the
 * request that triggered it. Request data (user, IP) is captured on the
 * calling thread first, because the request object is recycled afterwards.
 * If the queue is full the caller thread does the write itself (no event is dropped).
 *
 * Never put passwords, tokens or other secrets into the values passed in here.
 */
public final class AuditService {

    /** Failed logins (same email + IP) within the window that raise a security event. */
    public static final int FAILED_LOGIN_THRESHOLD = 5;
    public static final int FAILED_LOGIN_WINDOW_MIN = 1;

    private static final ThreadPoolExecutor EXEC = new ThreadPoolExecutor(
            1, 1, 0L, TimeUnit.MILLISECONDS, new LinkedBlockingQueue<>(5000),
            r -> {
                Thread t = new Thread(r, "audit-writer");
                t.setDaemon(true);
                return t;
            },
            new ThreadPoolExecutor.CallerRunsPolicy());

    private AuditService() { }

    // ------------------------------------------------------------ audit log

    /** Logs an action by whoever is logged in on this request. */
    public static void log(HttpServletRequest req, String module, String action, String recordId,
                           String description, Map<String, ?> oldValues, Map<String, ?> newValues) {
        HttpSession s = req == null ? null : req.getSession(false);
        logAs(Security.userId(s), Security.role(s), req == null ? null : Security.clientIp(req),
              module, action, recordId, description, oldValues, newValues);
    }

    public static void logAs(String userId, String role, String ip, String module, String action,
                             String recordId, String description,
                             Map<String, ?> oldValues, Map<String, ?> newValues) {
        final AuditLog a = new AuditLog();
        a.setUserId(userId);
        a.setUserRole(role);
        a.setIpAddress(ip);
        a.setModuleName(module);
        a.setActionType(action);
        a.setRecordId(recordId);
        a.setDescription(description);
        a.setOldValues(Json.of(oldValues));
        a.setNewValues(Json.of(newValues));
        submit(() -> new AuditLogDAO().insertAuditLog(a));
    }

    /** Security events (access denied, CSRF failure, repeated failed logins ...) live under module SECURITY. */
    public static void logSecurity(HttpServletRequest req, String eventType, String description) {
        log(req, "SECURITY", eventType, null, description, null, null);
    }

    // ------------------------------------------------------------ login history

    public static void recordLogin(HttpServletRequest req, HttpSession session) {
        final String uid = Security.userId(session), role = Security.role(session),
                email = Security.email(session), ip = Security.clientIp(req), ua = Security.userAgent(req);
        submit(() -> new LoginHistoryDAO().recordLoginActivity(uid, role, email, ip, ua));
    }

    public static void recordFailedLogin(HttpServletRequest req, String enteredLoginId) {
        final String ip = Security.clientIp(req), ua = Security.userAgent(req);
        String t = enteredLoginId == null ? null : enteredLoginId.trim();
        final String entered = t != null && t.length() > 100 ? t.substring(0, 100) : t;
        submit(() -> {
            LoginHistoryDAO dao = new LoginHistoryDAO();
            dao.recordFailedLogin(entered, ip, ua);

            // Is this login ID a real account? If not, the attempt is from an unknown user.
            UserMonitorDAO.UserRow known = new UserMonitorDAO().findByLoginId(entered);
            AuditLogDAO audit = new AuditLogDAO();
            if (known == null) {
                audit.insertAuditLog(securityEvent("UNKNOWN_USER_LOGIN", ip,
                        "Login attempt by an unknown user (login ID '" + entered + "' does not exist)"));
            }

            // exactly == so a burst raises ONE suspicious-login event, not one per extra attempt
            if (dao.recentFailures(entered, ip, FAILED_LOGIN_WINDOW_MIN) == FAILED_LOGIN_THRESHOLD) {
                AuditLog a = securityEvent("REPEATED_FAILED_LOGIN", ip,
                        "Suspicious user login: " + FAILED_LOGIN_THRESHOLD + " failed login attempts within "
                        + FAILED_LOGIN_WINDOW_MIN + (FAILED_LOGIN_WINDOW_MIN == 1 ? " minute" : " minutes") + " for login ID '" + entered + "'"
                        + (known == null ? " (unknown user)" : ""));
                if (known != null) {            // a real account is being attacked: show who
                    a.setUserId(known.id);
                    a.setUserRole(known.role);
                }
                audit.insertAuditLog(a);
            }
        });
    }

    /** Call BEFORE invalidating the session. Marks it so the expiry listener does not log it twice. */
    public static void recordLogout(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        if (session == null || Security.userId(session) == null) return;
        session.setAttribute("auditLogoutRecorded", Boolean.TRUE);
        final String uid = Security.userId(session), role = Security.role(session),
                email = Security.email(session), ip = Security.clientIp(req), ua = Security.userAgent(req);
        submit(() -> new LoginHistoryDAO().recordLogoutActivity(uid, role, email, ip, ua));
    }

    public static void recordSessionExpired(HttpSession session) {
        if (session == null || Security.userId(session) == null) return;
        if (session.getAttribute("auditLogoutRecorded") != null) return;
        final String uid = Security.userId(session), role = Security.role(session), email = Security.email(session);
        submit(() -> new LoginHistoryDAO().recordSessionExpired(uid, role, email));
    }

    // ------------------------------------------------------------ helpers

    private static AuditLog securityEvent(String type, String ip, String description) {
        AuditLog a = new AuditLog();
        a.setModuleName("SECURITY");
        a.setActionType(type);
        a.setIpAddress(ip);
        a.setDescription(description);
        return a;
    }

    /** Helper for building old/new value maps in call sites. */
    public static Map<String, Object> map(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i + 1 < kv.length; i += 2) m.put(String.valueOf(kv[i]), kv[i + 1]);
        return m;
    }

    private interface Job { void run() throws Exception; }

    private static void submit(Job job) {
        EXEC.execute(() -> {
            try {
                job.run();
            } catch (Exception e) {
                // an audit failure must never break the application; surface it in the error log
                SystemLogger.record("Audit", e.getClass().getName(), e.getMessage(), "MEDIUM", null);
            }
        });
    }

    /** Called when the web app stops so queued events are flushed. */
    public static void shutdown() {
        EXEC.shutdown();
        try {
            EXEC.awaitTermination(5, TimeUnit.SECONDS);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }
}
