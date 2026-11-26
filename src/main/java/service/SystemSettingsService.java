package service;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

import DAO.SystemSettingsDAO;
import jakarta.servlet.http.HttpServletRequest;
import model.SystemSetting;

/**
 * Application-wide settings with validation, caching and auditing.
 * Other modules read values with get()/getInt()/getBool(); the cache refreshes
 * immediately after an update and at most every 60 seconds otherwise.
 */
public final class SystemSettingsService {

    private static final String[] DAYS = { "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" };
    private static final Pattern HHMM = Pattern.compile("^([01]\\d|2[0-3]):[0-5]\\d$");
    private static final Set<String> DATE_FORMATS = new HashSet<>(Arrays.asList("dd MMM yyyy", "dd/MM/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "dd-MMM-yyyy"));
    private static final Set<String> TIME_FORMATS = new HashSet<>(Arrays.asList("HH:mm", "hh:mm a", "HH:mm:ss"));

    /** key -> {default value, description}. Order = display order. */
    public static final Map<String, String[]> DEFINITIONS = new LinkedHashMap<>();
    static {
        d("company_name", "SmartOffice", "Company name");
        d("company_email", "", "Company contact email");
        d("company_phone", "", "Company contact phone");
        d("company_address", "", "Company address");
        d("company_logo", "", "Company logo (https URL or a path starting with /)");
        d("working_days", "MON,TUE,WED,THU,FRI", "Official working days (comma separated)");
        d("working_hours_start", "09:00", "Default working hours start (HH:mm)");
        d("working_hours_end", "18:00", "Default working hours end (HH:mm)");
        d("working_hours_per_day", "8.0", "Default working hours per day (0.5-24)");
        d("attendance_grace_minutes", "15", "Attendance grace period in minutes (0-120)");
        d("leave_annual_days", "18", "Default annual leave days per year (0-365)");
        d("leave_sick_days", "10", "Default sick leave days per year (0-365)");
        d("leave_casual_days", "8", "Default casual leave days per year (0-365)");
        d("session_timeout_minutes", "30", "Session timeout in minutes (5-480)");
        d("notify_email", "true", "Send email notifications");
        d("notify_in_app", "true", "Show in-app notifications");
        d("date_format", "dd/MM/yyyy", "Date format");
        d("time_format", "HH:mm", "Time format");
    }

    private static void d(String k, String v, String desc) { DEFINITIONS.put(k, new String[] { v, desc }); }

    private static volatile Map<String, String> cache = null;
    private static volatile long cacheAt = 0;

    private SystemSettingsService() { }

    private static volatile boolean seeded = false;

    /** Seeds missing defaults (once per application start). */
    public static synchronized void ensureDefaults() throws SQLException {
        if (seeded) return;
        new SystemSettingsDAO().insertDefaults(DEFINITIONS);
        seeded = true;
    }

    public static List<SystemSetting> all() throws SQLException {
        ensureDefaults();
        List<SystemSetting> list = new SystemSettingsDAO().getAllSettings();
        List<SystemSetting> ordered = new ArrayList<>();
        for (String k : DEFINITIONS.keySet()) {
            for (SystemSetting s : list) if (s.getSettingKey().equals(k)) ordered.add(s);
        }
        return ordered;
    }

    // ---------------------------------------------------------------- reading

    public static String get(String key, String def) {
        try {
            Map<String, String> m = cache;
            if (m == null || System.currentTimeMillis() - cacheAt > 60_000) m = reload();
            String v = m.get(key);
            return v == null ? def : v;
        } catch (Exception e) {
            return def;
        }
    }

    public static int getInt(String key, int def) {
        try { return Integer.parseInt(get(key, String.valueOf(def)).trim()); }
        catch (NumberFormatException e) { return def; }
    }

    public static boolean getBool(String key, boolean def) {
        return "true".equalsIgnoreCase(get(key, String.valueOf(def)));
    }

    private static synchronized Map<String, String> reload() throws SQLException {
        ensureDefaults();
        Map<String, String> m = new LinkedHashMap<>();
        for (SystemSetting s : new SystemSettingsDAO().getAllSettings()) m.put(s.getSettingKey(), s.getSettingValue());
        cache = m;
        cacheAt = System.currentTimeMillis();
        return m;
    }

    // ---------------------------------------------------------------- validation

    /** Returns an error message, or null if the value is acceptable. */
    public static String validate(String key, String value) {
        String v = value == null ? "" : value.trim();
        switch (key) {
            case "company_name":
                return v.isEmpty() || v.length() > 100 ? "Company name is required (max 100 characters)." : null;
            case "company_email":
                return v.isEmpty() || v.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$") && v.length() <= 150
                        ? null : "Company email is not a valid address.";
            case "company_phone":
                return v.isEmpty() || v.matches("^[0-9+()\\-\\s]{5,20}$") ? null : "Company phone is not valid.";
            case "company_address":
                return v.length() > 255 ? "Company address is too long (max 255)." : null;
            case "company_logo":
                if (v.isEmpty()) return null;
                if (v.length() > 255) return "Logo path is too long.";
                boolean urlOk = v.startsWith("https://") || (v.startsWith("/") && !v.startsWith("//"));
                boolean extOk = v.toLowerCase().matches(".*\\.(png|jpg|jpeg|gif|svg|webp)$");
                return urlOk && extOk && !v.contains("..") ? null
                        : "Logo must be an https:// URL or a /path to a png, jpg, gif, svg or webp image.";
            case "working_days":
                if (v.isEmpty()) return "Select at least one working day.";
                for (String day : v.split(",")) {
                    if (!Arrays.asList(DAYS).contains(day.trim())) return "Unknown working day: " + day.trim();
                }
                return null;
            case "working_hours_start":
            case "working_hours_end":
                return HHMM.matcher(v).matches() ? null : "Working hours must be in HH:mm format.";
            case "working_hours_per_day":
                try {
                    double h = Double.parseDouble(v);
                    return h < 0.5 || h > 24 ? "Working hours per day must be between 0.5 and 24." : null;
                } catch (NumberFormatException e) {
                    return "Working hours per day must be a number.";
                }
            case "attendance_grace_minutes":
                return range(v, 0, 120, "Attendance grace period");
            case "leave_annual_days":
            case "leave_sick_days":
            case "leave_casual_days":
                return range(v, 0, 365, "Leave days");
            case "session_timeout_minutes":
                return range(v, 5, 480, "Session timeout");
            case "notify_email":
            case "notify_in_app":
                return v.equals("true") || v.equals("false") ? null : "Notification option must be true or false.";
            case "date_format":
                return DATE_FORMATS.contains(v) ? null : "Unsupported date format.";
            case "time_format":
                return TIME_FORMATS.contains(v) ? null : "Unsupported time format.";
            default:
                return "Unknown setting: " + key;
        }
    }

    /** Cross-field rules, checked on the final merged set of values. */
    private static String crossCheck(Map<String, String> merged) {
        String s = merged.get("working_hours_start"), e = merged.get("working_hours_end");
        if (s != null && e != null && HHMM.matcher(s).matches() && HHMM.matcher(e).matches()
                && s.compareTo(e) >= 0) {
            return "Working hours end must be later than start.";
        }
        return null;
    }

    private static String range(String v, int min, int max, String label) {
        try {
            int n = Integer.parseInt(v);
            return n < min || n > max ? label + " must be between " + min + " and " + max + "." : null;
        } catch (NumberFormatException e) {
            return label + " must be a whole number.";
        }
    }

    // ---------------------------------------------------------------- updating

    public static class Result {
        public final List<String> errors = new ArrayList<>();
        public int changed = 0;
        public boolean ok() { return errors.isEmpty(); }
    }

    /**
     * Validates every submitted value; if all pass, saves the changed ones in one
     * transaction and writes a single audit entry with old and new values.
     */
    public static Result update(Map<String, String> submitted, String adminId, HttpServletRequest req)
            throws SQLException {
        Result r = new Result();
        ensureDefaults();

        Map<String, String> current = new LinkedHashMap<>();
        for (SystemSetting s : new SystemSettingsDAO().getAllSettings()) current.put(s.getSettingKey(), s.getSettingValue());

        Map<String, String> changes = new LinkedHashMap<>();
        Map<String, String> merged = new LinkedHashMap<>(current);

        for (Map.Entry<String, String> e : submitted.entrySet()) {
            if (!DEFINITIONS.containsKey(e.getKey())) continue;   // ignore anything not whitelisted
            String v = e.getValue() == null ? "" : e.getValue().trim();
            String err = validate(e.getKey(), v);
            if (err != null) { r.errors.add(err); continue; }
            merged.put(e.getKey(), v);
            if (!v.equals(current.get(e.getKey()) == null ? "" : current.get(e.getKey()))) changes.put(e.getKey(), v);
        }
        if (r.errors.isEmpty()) {
            String cross = crossCheck(merged);
            if (cross != null) r.errors.add(cross);
        }
        if (!r.ok() || changes.isEmpty()) return r;

        new SystemSettingsDAO().updateSettings(changes, adminId);

        Map<String, Object> oldV = new LinkedHashMap<>(), newV = new LinkedHashMap<>();
        for (Map.Entry<String, String> c : changes.entrySet()) {
            oldV.put(c.getKey(), current.get(c.getKey()));
            newV.put(c.getKey(), c.getValue());
        }
        AuditService.log(req, "SYSTEM_SETTINGS", "UPDATE", String.join(",", changes.keySet()),
                "Updated " + changes.size() + " system setting(s)", oldV, newV);

        r.changed = changes.size();
        try { reload(); } catch (SQLException ignore) { cache = null; }
        return r;
    }
}
