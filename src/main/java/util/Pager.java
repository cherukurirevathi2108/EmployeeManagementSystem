package util;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;

/** Builds filter query strings and a simple pagination bar for the admin pages. */
public final class Pager {
    private Pager() { }

    /** query("user", u, "module", m) -> "user=..&module=.." skipping blank values. */
    public static String query(String... kv) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i + 1 < kv.length; i += 2) {
            if (kv[i + 1] == null || kv[i + 1].trim().isEmpty()) continue;
            try {
                if (sb.length() > 0) sb.append('&');
                sb.append(kv[i]).append('=').append(URLEncoder.encode(kv[i + 1].trim(), "UTF-8"));
            } catch (UnsupportedEncodingException e) { /* UTF-8 always exists */ }
        }
        return sb.toString();
    }

    public static String render(String base, String query, int page, int pages) {
        if (pages <= 1) return "";
        String q = query == null || query.isEmpty() ? "" : query + "&";
        StringBuilder sb = new StringBuilder("<div class='pager'>");
        int from = Math.max(1, page - 3), to = Math.min(pages, page + 3);
        if (page > 1) link(sb, base, q, page - 1, "&laquo; Prev", false);
        if (from > 1) { link(sb, base, q, 1, "1", false); if (from > 2) sb.append("<span>&hellip;</span>"); }
        for (int p = from; p <= to; p++) link(sb, base, q, p, String.valueOf(p), p == page);
        if (to < pages) { if (to < pages - 1) sb.append("<span>&hellip;</span>"); link(sb, base, q, pages, String.valueOf(pages), false); }
        if (page < pages) link(sb, base, q, page + 1, "Next &raquo;", false);
        return sb.append("</div>").toString();
    }

    private static void link(StringBuilder sb, String base, String q, int p, String label, boolean current) {
        sb.append("<a").append(current ? " class='cur'" : "").append(" href='")
          .append(Html.esc(base)).append('?').append(Html.esc(q)).append("page=").append(p).append("'>")
          .append(label).append("</a>");
    }
}
