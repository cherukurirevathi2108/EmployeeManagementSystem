package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Read-only view across the four existing account tables
 * (admins, hr_users, managers, employees). Only columns the existing login
 * code already relies on are used: id, name, email, status.
 */
public class UserMonitorDAO {

    public static class UserRow {
        public String id, name, email, role, status;
        public Timestamp lastLogin;
    }

    private static final String[][] SOURCES = {
        { "ADMIN", "admins", "admin_id" },
        { "HR", "hr_users", "hr_id" },
        { "MANAGER", "managers", "employee_id" },
        { "EMPLOYEE", "employees", "employee_id" }
    };

    /** Counts per role and status, e.g. counts.get("EMPLOYEE").get("ACTIVE"). */
    public Map<String, Map<String, Long>> countsByRoleAndStatus() throws SQLException {
        Map<String, Map<String, Long>> out = new LinkedHashMap<>();
        try (Connection c = Db.open()) {
            for (String[] s : SOURCES) {
                Map<String, Long> m = new LinkedHashMap<>();
                // table/column names come from the constant array above, never from input
                String sql = "SELECT status, COUNT(*) FROM " + s[1] + " GROUP BY status";
                try (PreparedStatement ps = c.prepareStatement(sql); ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        String st = rs.getString(1) == null ? "UNKNOWN" : rs.getString(1).toUpperCase();
                        m.merge(st, rs.getLong(2), Long::sum);
                    }
                } catch (SQLException missingTable) {
                    // e.g. hr_users not created yet: report zero rather than failing the page
                }
                out.put(s[0], m);
            }
        }
        return out;
    }

    /** Users, optionally filtered by role and/or status, newest-listed order not guaranteed. */
    public List<UserRow> listUsers(String role, String status, int limit) throws SQLException {
        List<UserRow> out = new ArrayList<>();
        try (Connection c = Db.open()) {
            for (String[] s : SOURCES) {
                if (role != null && !role.equals(s[0])) continue;
                StringBuilder sql = new StringBuilder("SELECT " + s[2] + ", name, email, status FROM " + s[1]);
                if (status != null) sql.append(" WHERE UPPER(status) = ?");
                sql.append(" ORDER BY name LIMIT ?");
                try (PreparedStatement ps = c.prepareStatement(sql.toString())) {
                    int i = 1;
                    if (status != null) ps.setString(i++, status);
                    ps.setInt(i, limit);
                    try (ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            UserRow u = new UserRow();
                            u.id = rs.getString(1);
                            u.name = rs.getString(2);
                            u.email = rs.getString(3);
                            u.status = rs.getString(4);
                            u.role = s[0];
                            out.add(u);
                        }
                    }
                } catch (SQLException missingTable) {
                    // skip a table that does not exist yet
                }
            }
        }
        return out;
    }


    /** Finds the account a login ID (email or user id) belongs to, or null when nobody has it. */
    public UserRow findByLoginId(String loginId) throws SQLException {
        if (loginId == null || loginId.trim().isEmpty()) return null;
        try (Connection c = Db.open()) {
            for (String[] s : SOURCES) {
                // table/column names come from the constant array above, never from input
                String sql = "SELECT " + s[2] + ", name, email, status FROM " + s[1]
                        + " WHERE email = ? OR " + s[2] + " = ? LIMIT 1";
                try (PreparedStatement ps = c.prepareStatement(sql)) {
                    ps.setString(1, loginId.trim());
                    ps.setString(2, loginId.trim());
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            UserRow u = new UserRow();
                            u.id = rs.getString(1);
                            u.name = rs.getString(2);
                            u.email = rs.getString(3);
                            u.status = rs.getString(4);
                            u.role = s[0];
                            return u;
                        }
                    }
                } catch (SQLException missingTable) {
                    // skip a table that does not exist yet
                }
            }
        }
        return null;
    }

    /** IDs of employees on teams led by this manager. Falls back to empty on schema mismatch. */
    public List<String> teamMemberIds(String managerId) {
        String sql = "SELECT DISTINCT e.employee_id FROM teams t "
                + "JOIN team_members tm ON tm.team_id = t.id "
                + "JOIN employees e ON e.id = tm.employee_id "
                + "WHERE t.manager_id = ?";
        List<String> out = new ArrayList<>();
        try (Connection c = Db.open(); PreparedStatement ps = c.prepareStatement(sql)) {
            ps.setString(1, managerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(rs.getString(1));
            }
        } catch (SQLException e) {
            System.err.println("[UserMonitorDAO] team lookup failed, manager sees own activity only: " + e.getMessage());
        }
        return out;
    }
}
