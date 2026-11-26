package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

import model.AuditLog;
import util.Web;

/**
 * Append-only: there is intentionally no update or delete method.
 * Corrections are recorded as new audit events.
 */
public class AuditLogDAO {

    /** Search filters. Any field may be null. */
    public static class Criteria {
        public String userId, moduleName, actionType, keyword;
        public Timestamp from, toExclusive;
        /** When non-null, results are limited to these user IDs (manager / employee scope). */
        public List<String> scopeUserIds;
    }

    // ---------- insert ----------

    public void insertAuditLog(AuditLog a) throws SQLException {
        String sql = "INSERT INTO audit_logs (user_id, user_role, module_name, action_type, "
                + "record_id, description, old_values, new_values, ip_address) "
                + "VALUES (?,?,?,?,?,?,?,?,?)";
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, a.getUserId());
            ps.setString(2, a.getUserRole());
            ps.setString(3, a.getModuleName());
            ps.setString(4, a.getActionType());
            ps.setString(5, a.getRecordId());
            ps.setString(6, a.getDescription());
            ps.setString(7, a.getOldValues());
            ps.setString(8, a.getNewValues());
            ps.setString(9, a.getIpAddress());
            ps.executeUpdate();
        }
    }

    // ---------- the retrieval methods named in the module plan ----------

    public List<AuditLog> getAllAuditLogs(int limit, int offset) throws SQLException {
        return search(new Criteria(), limit, offset);
    }

    public List<AuditLog> getAuditLogsByUser(String userId, int limit, int offset) throws SQLException {
        Criteria c = new Criteria();
        c.userId = userId;
        return search(c, limit, offset);
    }

    public List<AuditLog> getAuditLogsByModule(String module, int limit, int offset) throws SQLException {
        Criteria c = new Criteria();
        c.moduleName = module;
        return search(c, limit, offset);
    }

    public List<AuditLog> getAuditLogsByDateRange(Timestamp from, Timestamp toExclusive,
                                                  int limit, int offset) throws SQLException {
        Criteria c = new Criteria();
        c.from = from;
        c.toExclusive = toExclusive;
        return search(c, limit, offset);
    }

    // ---------- combined search ----------

    public List<AuditLog> search(Criteria cr, int limit, int offset) throws SQLException {
        List<Object> params = new ArrayList<>();
        String where = where(cr, params);
        String sql = "SELECT id, user_id, user_role, module_name, action_type, record_id, description, "
                + "old_values, new_values, ip_address, created_at FROM audit_logs" + where
                + " ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?";
        params.add(limit);
        params.add(offset);
        List<AuditLog> out = new ArrayList<>();
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(map(rs));
            }
        }
        return out;
    }

    public long count(Criteria cr) throws SQLException {
        List<Object> params = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM audit_logs" + where(cr, params);
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            bind(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0;
            }
        }
    }

    public long countAll() throws SQLException {
        return count(new Criteria());
    }

    public List<String> distinctModules() throws SQLException {
        List<String> out = new ArrayList<>();
        try (Connection c = Db.open(); PreparedStatement ps =
                     c.prepareStatement("SELECT DISTINCT module_name FROM audit_logs ORDER BY module_name");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) out.add(rs.getString(1));
        }
        return out;
    }

    public List<AuditLog> recent(int n, boolean securityOnly) throws SQLException {
        Criteria c = new Criteria();
        if (securityOnly) c.moduleName = "SECURITY";
        return search(c, n, 0);
    }

    // ---------- internals ----------

    private String where(Criteria cr, List<Object> p) {
        StringBuilder sb = new StringBuilder();
        add(sb, cr.userId != null, "user_id = ?", p, cr.userId);
        add(sb, cr.moduleName != null, "module_name = ?", p, cr.moduleName);
        add(sb, cr.actionType != null, "action_type = ?", p, cr.actionType);
        add(sb, cr.from != null, "created_at >= ?", p, cr.from);
        add(sb, cr.toExclusive != null, "created_at < ?", p, cr.toExclusive);
        if (cr.keyword != null) {
            add(sb, true, "description LIKE ? ESCAPE '\\\\'", p, "%" + Web.likeEscape(cr.keyword) + "%");
        }
        if (cr.scopeUserIds != null) {
            if (cr.scopeUserIds.isEmpty()) {
                sb.append(sb.length() == 0 ? " WHERE " : " AND ").append("1 = 0");
            } else {
                StringBuilder in = new StringBuilder("user_id IN (");
                for (int i = 0; i < cr.scopeUserIds.size(); i++) {
                    in.append(i == 0 ? "?" : ",?");
                    p.add(cr.scopeUserIds.get(i));
                }
                add(sb, true, in.append(")").toString(), p, null);
            }
        }
        return sb.toString();
    }

    private void add(StringBuilder sb, boolean cond, String clause, List<Object> p, Object val) {
        if (!cond) return;
        sb.append(sb.length() == 0 ? " WHERE " : " AND ").append(clause);
        if (val != null) p.add(val);
    }

    static void bind(PreparedStatement ps, List<Object> params) throws SQLException {
        for (int i = 0; i < params.size(); i++) {
            Object o = params.get(i);
            if (o instanceof Timestamp) ps.setTimestamp(i + 1, (Timestamp) o);
            else if (o instanceof Integer) ps.setInt(i + 1, (Integer) o);
            else ps.setString(i + 1, String.valueOf(o));
        }
    }

    private AuditLog map(ResultSet rs) throws SQLException {
        AuditLog a = new AuditLog();
        a.setId(rs.getLong("id"));
        a.setUserId(rs.getString("user_id"));
        a.setUserRole(rs.getString("user_role"));
        a.setModuleName(rs.getString("module_name"));
        a.setActionType(rs.getString("action_type"));
        a.setRecordId(rs.getString("record_id"));
        a.setDescription(rs.getString("description"));
        a.setOldValues(rs.getString("old_values"));
        a.setNewValues(rs.getString("new_values"));
        a.setIpAddress(rs.getString("ip_address"));
        a.setCreatedAt(rs.getTimestamp("created_at"));
        return a;
    }
}
