package util;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import jakarta.servlet.http.HttpServletRequest;

/** Request parameter helpers with validation. */
public final class Web {
    private Web() { }

    /** Trimmed parameter, or null if blank. Truncated to maxLen. */
    public static String str(HttpServletRequest r, String name, int maxLen) {
        String v = r.getParameter(name);
        if (v == null) return null;
        v = v.trim();
        if (v.isEmpty()) return null;
        return v.length() > maxLen ? v.substring(0, maxLen) : v;
    }

    public static int intParam(HttpServletRequest r, String name, int def, int min, int max) {
        try {
            int v = Integer.parseInt(r.getParameter(name).trim());
            return Math.max(min, Math.min(max, v));
        } catch (Exception e) {
            return def;
        }
    }

    /** Parses yyyy-MM-dd. Returns null for blank; throws IllegalArgumentException for bad input. */
    public static LocalDate date(String v) {
        if (v == null || v.trim().isEmpty()) return null;
        try {
            return LocalDate.parse(v.trim());
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("Invalid date: " + v);
        }
    }

    public static Timestamp startOf(LocalDate d) {
        return d == null ? null : Timestamp.valueOf(d.atStartOfDay());
    }

    /** Exclusive upper bound: midnight of the day after d. */
    public static Timestamp endExclusive(LocalDate d) {
        return d == null ? null : Timestamp.valueOf(d.plusDays(1).atStartOfDay());
    }

    /** Escapes LIKE wildcards so user text is matched literally. */
    public static String likeEscape(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    /** Neutralises spreadsheet formula injection in CSV exports. */
    public static String csv(Object v) {
        String s = v == null ? "" : String.valueOf(v);
        if (!s.isEmpty() && "=+-@\t\r".indexOf(s.charAt(0)) >= 0) s = "'" + s;
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }
}
