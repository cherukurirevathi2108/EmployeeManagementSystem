package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

import model.SystemError;
import util.Web;

public class SystemErrorDAO {

    public static class Criteria {
        public String severity, moduleName, keyword;
        public Timestamp from, toExclusive;
    }

    public long recordSystemError(SystemError e) throws SQLException {
        String sql = "INSERT INTO system_errors (module_name, error_type, error_message, severity, user_id) "
                + "VALUES (?,?,?,?,?)";
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, e.getModuleName());
            ps.setString(2, e.getErrorType());
            ps.setString(3, e.getErrorMessage());
            ps.setString(4, e.getSeverity());
            ps.setString(5, e.getUserId());
            ps.executeUpdate();
            try (ResultSet k = ps.getGeneratedKeys()) {
                return k.next() ? k.getLong(1) : -1;
            }
        }
    }

    public List<SystemError> getAllSystemErrors(int limit, int offset) throws SQLException {
        return search(new Criteria(), limit, offset);
    }

    public List<SystemError> search(Criteria cr, int limit, int offset) throws SQLException {
        List<Object> p = new ArrayList<>();
        String sql = "SELECT id, module_name, error_type, error_message, severity, user_id, created_at "
                + "FROM system_errors" + where(cr, p) + " ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?";
        p.add(limit);
        p.add(offset);
        List<SystemError> out = new ArrayList<>();
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            AuditLogDAO.bind(ps, p);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SystemError e = new SystemError();
                    e.setId(rs.getLong("id"));
                    e.setModuleName(rs.getString("module_name"));
                    e.setErrorType(rs.getString("error_type"));
                    e.setErrorMessage(rs.getString("error_message"));
                    e.setSeverity(rs.getString("severity"));
                    e.setUserId(rs.getString("user_id"));
                    e.setCreatedAt(rs.getTimestamp("created_at"));
                    out.add(e);
                }
            }
        }
        return out;
    }

    public long count(Criteria cr) throws SQLException {
        List<Object> p = new ArrayList<>();
        String sql = "SELECT COUNT(*) FROM system_errors" + where(cr, p);
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            AuditLogDAO.bind(ps, p);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getLong(1) : 0;
            }
        }
    }

    public List<String> distinctModules() throws SQLException {
        List<String> out = new ArrayList<>();
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "SELECT DISTINCT module_name FROM system_errors WHERE module_name IS NOT NULL ORDER BY module_name");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) out.add(rs.getString(1));
        }
        return out;
    }

    private String where(Criteria cr, List<Object> p) {
        StringBuilder sb = new StringBuilder();
        if (cr.severity != null) { sb.append(" WHERE severity = ?"); p.add(cr.severity); }
        if (cr.moduleName != null) {
            sb.append(sb.length() == 0 ? " WHERE " : " AND ").append("module_name = ?");
            p.add(cr.moduleName);
        }
        if (cr.keyword != null) {
            sb.append(sb.length() == 0 ? " WHERE " : " AND ")
              .append("(error_message LIKE ? ESCAPE '\\\\' OR error_type LIKE ? ESCAPE '\\\\')");
            String k = "%" + Web.likeEscape(cr.keyword) + "%";
            p.add(k);
            p.add(k);
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
