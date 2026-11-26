package util;

import DAO.SystemErrorDAO;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import model.SystemError;

/**
 * Records application errors in system_errors. Never throws: logging a failure
 * must not cause a second failure.
 *
 * Usage in any catch block:
 *     SystemLogger.error("Payroll", e, request);
 */
public final class SystemLogger {

    private SystemLogger() { }

    public static long error(String module, Throwable t, HttpServletRequest req) {
        return error(module, t, req, "HIGH");
    }

    public static long error(String module, Throwable t, HttpServletRequest req, String severity) {
        try {
            HttpSession s = req == null ? null : req.getSession(false);
            return record(module, t.getClass().getName(), t.getMessage(), severity, Security.userId(s));
        } catch (Throwable ignore) {
            return -1;
        }
    }

    public static long record(String module, String type, String message, String severity, String userId) {
        try {
            SystemError e = new SystemError();
            e.setModuleName(trunc(module, 100));
            e.setErrorType(trunc(type, 150));
            e.setErrorMessage(trunc(message, 2000));
            e.setSeverity(normalise(severity));
            e.setUserId(trunc(userId, 50));
            return new SystemErrorDAO().recordSystemError(e);
        } catch (Throwable ignore) {
            System.err.println("[SystemLogger] could not record error: " + message);
            return -1;
        }
    }

    private static String normalise(String s) {
        if (s == null) return "MEDIUM";
        s = s.toUpperCase();
        return (s.equals("LOW") || s.equals("MEDIUM") || s.equals("HIGH") || s.equals("CRITICAL")) ? s : "MEDIUM";
    }

    private static String trunc(String s, int n) {
        if (s == null) return null;
        return s.length() > n ? s.substring(0, n) : s;
    }
}
