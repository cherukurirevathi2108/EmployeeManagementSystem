package util;

import java.util.Map;

/** Tiny JSON writer so audit old/new values are always valid JSON. */
public final class Json {
    private Json() { }

    public static String of(Map<String, ?> map) {
        if (map == null) return null;
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, ?> e : map.entrySet()) {
            if (!first) sb.append(',');
            first = false;
            quote(sb, e.getKey());
            sb.append(':');
            value(sb, e.getValue());
        }
        return sb.append('}').toString();
    }

    @SuppressWarnings("unchecked")
    private static void value(StringBuilder sb, Object v) {
        if (v == null) sb.append("null");
        else if (v instanceof Number || v instanceof Boolean) sb.append(v);
        else if (v instanceof Map) sb.append(of((Map<String, ?>) v));
        else quote(sb, String.valueOf(v));
    }

    private static void quote(StringBuilder sb, String s) {
        sb.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (c < 0x20) sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
            }
        }
        sb.append('"');
    }
}
