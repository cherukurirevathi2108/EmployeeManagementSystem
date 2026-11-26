package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import model.LoginHistory;
import util.Web;

public class LoginHistoryDAO {

    public static class Criteria {
        public String email, activityType;
        public Timestamp from, toExclusive;
    }

    /** One row of the "suspicious activity" panel. */
    public static class Suspicious {
        public String email, ip;
        public long attempts;
        public Timestamp last;
    }

    // ---------- recording ----------

    public void recordLoginActivity(String userId, String role, String email, String ip, String ua) throws SQLException {
        insert(userId, role, email, "LOGIN", ip, ua);
    }

    public void recordLogoutActivity(String userId, String role, String email, String ip, String ua) throws SQLException {
        insert(userId, role, email, "LOGOUT", ip, ua);
    }

    public void recordFailedLogin(String email, String ip, String ua) throws SQLException {
        insert(null, null, email, "FAILED_LOGIN", ip, ua);
    }

    public void recordSessionExpired(String userId, String role, String email) throws SQLException {
        insert(userId, role, email, "SESSION_EXPIRED", null, null);
    }

    private void insert(String userId, String role, String email, String type, String ip, String ua) throws SQLException {
        String sql = "INSERT INTO login_history (user_id, user_role, email, activity_type, ip_address, user_agent) "
                + "VALUES (?,?,?,?,?,?)";
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, userId);
            ps.setString(2, role);
            ps.setString(3, email == null ? null : (email.length() > 150 ? email.substring(0, 150) : email));
            ps.setString(4, type);
            ps.setString(5, ip);
            ps.setString(6, ua);
            ps.executeUpdate();
        }
    }

    // ---------- queries ----------

    public List<LoginHistory> search(Criteria cr, int limit, int offset) throws SQLException {
        List<Object> p = new ArrayList<>();
        String sql = "SELECT id, user_id, user_role, email, activity_type, ip_address, user_agent, created_at "
                + "FROM login_history" + where(cr, p) + " ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?";
        p.add(limit);
        p.add(offset);
        List<LoginHistory> out = new ArrayList<>();
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            AuditLogDAO.bind(ps, p);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    LoginHistory h = new LoginHistory();
                    h.setId(rs.getLong("id"));
                    h.setUserId(rs.getString("user_id"));
                    h.setUserRole(rs.getString("user_role"));
                    h.setEmail(rs.getString("email"));
                    h.setActivityType(rs.getString("activity_type"));
                    h.setIpAddress(rs.getString("ip_address"));
                    h.setUserAgent(rs.getString("user_agent"));
                    h.setCreatedAt(rs.getTimestamp("created_at"));
                    out.add(h);
                }
            }
        }
        return out;
    }

    public long count(Criteria cr) throws SQLException {
        List<Object> p = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM login_history" + where(cr, p);
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            AuditLogDAO.bind(ps, p);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0;
            }
        }
    }

    public long countToday(String type) throws SQLException {
        String sql = "SELECT COUNT(*) FROM login_history WHERE activity_type = ? AND created_at >= CURDATE()";
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, type);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0;
            }
        }
    }

    /** Failed attempts by the same email + IP within the window. */
    public List<Suspicious> suspicious(int minAttempts, int windowMinutes) throws SQLException {
        String sql = "SELECT email, ip_address, COUNT(*) AS c, MAX(created_at) AS last_at "
                + "FROM login_history WHERE activity_type = 'FAILED_LOGIN' "
                + "AND created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE) "
                + "GROUP BY email, ip_address HAVING COUNT(*) >= ? ORDER BY c DESC LIMIT 50";
        List<Suspicious> out = new ArrayList<>();
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setInt(1, windowMinutes);
            ps.setInt(2, minAttempts);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Suspicious s = new Suspicious();
                    s.email = rs.getString(1);
                    s.ip = rs.getString(2);
                    s.attempts = rs.getLong(3);
                    s.last = rs.getTimestamp(4);
                    out.add(s);
                }
            }
        }
        return out;
    }

    /** Failed attempts for this email + IP in the window (used to raise a security event). */
    public long recentFailures(String email, String ip, int windowMinutes) throws SQLException {
        String sql = "SELECT COUNT(*) FROM login_history WHERE activity_type = 'FAILED_LOGIN' "
                + "AND email <=> ? AND ip_address <=> ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE)";
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, email);
            ps.setString(2, ip);
            ps.setInt(3, windowMinutes);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0;
            }
        }
    }

    /** key = ROLE:userId, value = latest successful login. Joined in Java to avoid collation clashes. */
    public Map<String, Timestamp> lastLogins() throws SQLException {
        String sql = "SELECT user_role, user_id, MAX(created_at) FROM login_history "
                + "WHERE activity_type = 'LOGIN' AND user_id IS NOT NULL GROUP BY user_role, user_id";
        Map<String, Timestamp> out = new HashMap<>();
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) out.put(rs.getString(1) + ":" + rs.getString(2), rs.getTimestamp(3));
        }
        return out;
    }

    private String where(Criteria cr, List<Object> p) {
        StringBuilder sb = new StringBuilder();
        if (cr.email != null) {
            sb.append(" WHERE email LIKE ? ESCAPE '\\\\'");
            p.add("%" + Web.likeEscape(cr.email) + "%");
        }
        if (cr.activityType != null) {
            sb.append(sb.length() == 0 ? " WHERE " : " AND ").append("activity_type = ?");
            p.add(cr.activityType);
        }
        if (cr.from != null) {
            sb.append(sb.length() == 0 ? " WHERE " : " AND ").append("created_at >= ?");
            p.add(cr.from);
        }
        if (cr.toExclusive != null) {
            sb.append(sb.length() == 0 ? " WHERE " : " AND ").append("created_at < ?");
            p.add(cr.toExclusive);
        }
        return sb.toString();
    }
}
