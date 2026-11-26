package util;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

import service.SystemSettingsService;

/**
 * Formats dates and times for display using System Settings (date_format / time_format).
 * Storage and HTML date inputs keep ISO values; only what the user READS goes through here.
 * Anything that cannot be parsed (e.g. "-", "Not checked in") is returned unchanged.
 */
public final class DateFmt {

    private DateFmt() { }

    private static DateTimeFormatter fmt(String key, String def) {
        String p = SystemSettingsService.get(key, def);
        try { return DateTimeFormatter.ofPattern(p, Locale.ENGLISH); }
        catch (IllegalArgumentException e) { return DateTimeFormatter.ofPattern(def, Locale.ENGLISH); }
    }

    private static DateTimeFormatter dateF() { return fmt("date_format", "dd/MM/yyyy"); }
    private static DateTimeFormatter timeF() { return fmt("time_format", "HH:mm"); }

    /** Date only, e.g. 11 Nov 2026. */
    public static String date(Object v) {
        if (v == null) return "";
        try {
            if (v instanceof java.sql.Timestamp) return ((java.sql.Timestamp) v).toLocalDateTime().toLocalDate().format(dateF());
            if (v instanceof java.sql.Date) return ((java.sql.Date) v).toLocalDate().format(dateF());
            if (v instanceof LocalDate) return ((LocalDate) v).format(dateF());
            if (v instanceof LocalDateTime) return ((LocalDateTime) v).toLocalDate().format(dateF());
            String s = String.valueOf(v).trim();
            if (s.length() >= 10 && s.charAt(4) == '-' && s.charAt(7) == '-')
                return LocalDate.parse(s.substring(0, 10)).format(dateF());
            return String.valueOf(v);
        } catch (Exception e) {
            return String.valueOf(v);
        }
    }

    /** Time only, e.g. 17:50 or 05:50 PM. */
    public static String time(Object v) {
        if (v == null) return "";
        try {
            if (v instanceof java.sql.Timestamp) return ((java.sql.Timestamp) v).toLocalDateTime().toLocalTime().format(timeF());
            if (v instanceof java.sql.Time) return ((java.sql.Time) v).toLocalTime().format(timeF());
            if (v instanceof LocalTime) return ((LocalTime) v).format(timeF());
            if (v instanceof LocalDateTime) return ((LocalDateTime) v).toLocalTime().format(timeF());
            String s = String.valueOf(v).trim();
            int t = Math.max(s.indexOf(' '), s.indexOf('T'));
            if (t > 0 && s.length() > 10 && s.charAt(4) == '-') s = s.substring(t + 1);   // "2026-11-11 17:50:00" -> time part
            if (s.matches("^\\d{1,2}:\\d{2}(:\\d{2})?(\\.\\d+)?$")) return LocalTime.parse(s.length() == 4 ? "0" + s : s).format(timeF());
            return String.valueOf(v);
        } catch (Exception e) {
            return String.valueOf(v);
        }
    }

    /** Date and time, e.g. 11 Nov 2026, 17:50. */
    public static String dateTime(Object v) {
        if (v == null) return "";
        try {
            LocalDateTime dt = null;
            if (v instanceof java.sql.Timestamp) dt = ((java.sql.Timestamp) v).toLocalDateTime();
            else if (v instanceof LocalDateTime) dt = (LocalDateTime) v;
            else {
                String s = String.valueOf(v).trim().replace('T', ' ');
                if (s.length() >= 16 && s.charAt(4) == '-') dt = LocalDateTime.parse(s.substring(0, 16).replace(' ', 'T'));
            }
            if (dt == null) return date(v);
            return dt.format(dateF()) + ", " + dt.format(timeF());
        } catch (Exception e) {
            return String.valueOf(v);
        }
    }
}
