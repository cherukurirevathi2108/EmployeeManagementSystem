package util;

import service.SystemSettingsService;

/**
 * Company name and logo (System Settings) as used by every dashboard and the login page.
 * Values come from the cached system settings, so a change shows up immediately.
 */
public final class Branding {

    private Branding() { }

    /** Company name, never empty. */
    public static String name() {
        String n = SystemSettingsService.get("company_name", "SmartOffice");
        return n == null || n.trim().isEmpty() ? "SmartOffice" : n.trim();
    }

    /** Logo URL (https:// or /path), or "" when no logo has been uploaded. */
    public static String logo() {
        String l = SystemSettingsService.get("company_logo", "");
        if (l == null) return "";
        l = l.trim();
        return (l.startsWith("https://") || (l.startsWith("/") && !l.startsWith("//"))) ? l : "";
    }

    private static final String STYLE =
            "<style>"
            + ".sx-brand{display:flex;align-items:center;gap:11px;padding:10px 12px 20px;margin:0 0 6px;"
            + "border-bottom:1px solid rgba(255,255,255,.08);min-width:0;text-align:left}"
            + ".sx-brand-img{width:40px;height:40px;border-radius:11px;object-fit:contain;background:#fff;padding:3px;flex:none}"
            + ".sx-brand-mark{width:40px;height:40px;border-radius:11px;display:grid;place-items:center;flex:none;"
            + "background:linear-gradient(135deg,#6366f1,#4338ca);color:#fff;font-weight:700;font-size:18px}"
            + ".sx-brand-txt{display:flex;flex-direction:column;min-width:0;line-height:1.25}"
            + ".sx-brand-txt strong{color:#fff;font-size:15px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}"
            + ".sx-brand-txt small{color:#94a3b8;font-size:10.5px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;margin-top:3px}"
            + "</style>";

    /** The sidebar brand block: logo (or the company's initial) + company name + the role label. */
    public static String sidebar(String roleLabel) {
        String n = name();
        String logo = logo();
        StringBuilder sb = new StringBuilder(STYLE);
        sb.append("<div class=\"sx-brand\" title=\"").append(Html.esc(n)).append("\">");
        if (!logo.isEmpty()) {
            sb.append("<img class=\"sx-brand-img\" src=\"").append(Html.esc(logo)).append("\" alt=\"\">");
        } else {
            String initial = n.substring(0, n.offsetByCodePoints(0, 1)).toUpperCase();
            sb.append("<span class=\"sx-brand-mark\">").append(Html.esc(initial)).append("</span>");
        }
        sb.append("<span class=\"sx-brand-txt\"><strong>").append(Html.esc(n)).append("</strong><small>")
          .append(Html.esc(roleLabel)).append("</small></span></div>");
        return sb.toString();
    }
}
