package util;

/** Output escaping for JSP pages. */
public final class Html {
    private Html() { }

    public static String esc(Object value) {
        if (value == null) return "";
        String s = String.valueOf(value);
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '&': sb.append("&amp;"); break;
                case '<': sb.append("&lt;"); break;
                case '>': sb.append("&gt;"); break;
                case '"': sb.append("&quot;"); break;
                case '\'': sb.append("&#39;"); break;
                default: sb.append(c);
            }
        }
        return sb.toString();
    }

    /** A timestamp for display: "2026-11-10 11:12:15" (drops the ".0" fraction), HTML-escaped. */
    public static String ts(Object value) {
        if (value == null) return "";
        return esc(String.valueOf(value).replaceAll("\\.\\d+$", ""));
    }

    /** Action code for display: "CSRF_FAILURE" -> "CSRF FAILURE"; repeated failed logins read "SUSPICIOUS LOGIN". */
    public static String label(Object value) {
        if (value == null) return "";
        String v = String.valueOf(value);
        if ("REPEATED_FAILED_LOGIN".equals(v)) v = "SUSPICIOUS_LOGIN";
        return esc(v.replace('_', ' '));
    }
}
