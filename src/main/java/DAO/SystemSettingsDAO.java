package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import model.SystemSetting;

public class SystemSettingsDAO {

    public List<SystemSetting> getAllSettings() throws SQLException {
        List<SystemSetting> out = new ArrayList<>();
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "SELECT id, setting_key, setting_value, description, updated_by, updated_at "
                     + "FROM system_settings ORDER BY setting_key");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) out.add(map(rs));
        }
        return out;
    }

    public SystemSetting getSettingByKey(String key) throws SQLException {
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "SELECT id, setting_key, setting_value, description, updated_by, updated_at "
                     + "FROM system_settings WHERE setting_key = ?")) {
            ps.setString(1, key);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public boolean updateSetting(String key, String value, String updatedBy) throws SQLException {
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "UPDATE system_settings SET setting_value = ?, updated_by = ? WHERE setting_key = ?")) {
            ps.setString(1, value);
            ps.setString(2, updatedBy);
            ps.setString(3, key);
            return ps.executeUpdate() > 0;
        }
    }

    /** Applies several changes atomically: either every setting is saved or none. */
    public void updateSettings(Map<String, String> changes, String updatedBy) throws SQLException {
        try (Connection c = Db.open()) {
            c.setAutoCommit(false);
            try (PreparedStatement ps = c.prepareStatement(
                    "UPDATE system_settings SET setting_value = ?, updated_by = ? WHERE setting_key = ?")) {
                for (Map.Entry<String, String> e : changes.entrySet()) {
                    ps.setString(1, e.getValue());
                    ps.setString(2, updatedBy);
                    ps.setString(3, e.getKey());
                    ps.addBatch();
                }
                ps.executeBatch();
                c.commit();
            } catch (SQLException ex) {
                c.rollback();
                throw ex;
            }
        }
    }

    /** Seeds defaults on one connection without touching values an administrator already set. */
    public void insertDefaults(Map<String, String[]> defaults) throws SQLException {
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "INSERT IGNORE INTO system_settings (setting_key, setting_value, description) VALUES (?,?,?)")) {
            for (Map.Entry<String, String[]> e : defaults.entrySet()) {
                ps.setString(1, e.getKey());
                ps.setString(2, e.getValue()[0]);
                ps.setString(3, e.getValue()[1]);
                ps.addBatch();
            }
            ps.executeBatch();
        }
    }

    private SystemSetting map(ResultSet rs) throws SQLException {
        SystemSetting s = new SystemSetting();
        s.setId(rs.getInt("id"));
        s.setSettingKey(rs.getString("setting_key"));
        s.setSettingValue(rs.getString("setting_value"));
        s.setDescription(rs.getString("description"));
        s.setUpdatedBy(rs.getString("updated_by"));
        s.setUpdatedAt(rs.getTimestamp("updated_at"));
        return s;
    }
}
