package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import model.BackupHistory;

public class BackupHistoryDAO {

    public long insert(BackupHistory b) throws SQLException {
        String sql = "INSERT INTO backup_history (backup_file, backup_type, status, file_size, created_by, "
                + "remarks, checksum_sha256) VALUES (?,?,?,?,?,?,?)";
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, b.getBackupFile());
            ps.setString(2, b.getBackupType());
            ps.setString(3, b.getStatus());
            ps.setLong(4, b.getFileSize());
            ps.setString(5, b.getCreatedBy());
            ps.setString(6, b.getRemarks());
            ps.setString(7, b.getChecksum());
            ps.executeUpdate();
            try (ResultSet k = ps.getGeneratedKeys()) {
                return k.next() ? k.getLong(1) : -1;
            }
        }
    }

    public List<BackupHistory> getAll(int limit) throws SQLException {
        List<BackupHistory> out = new ArrayList<>();
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "SELECT id, backup_file, backup_type, status, file_size, created_by, created_at, remarks, "
                     + "checksum_sha256 FROM backup_history ORDER BY created_at DESC, id DESC LIMIT ?")) {
            ps.setInt(1, limit);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) out.add(map(rs));
            }
        }
        return out;
    }

    public BackupHistory getById(long id) throws SQLException {
        try (Connection c = Db.open();
             PreparedStatement ps = c.prepareStatement(
                     "SELECT id, backup_file, backup_type, status, file_size, created_by, created_at, remarks, "
                     + "checksum_sha256 FROM backup_history WHERE id = ?")) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? map(rs) : null;
            }
        }
    }

    public BackupHistory latest() throws SQLException {
        List<BackupHistory> l = getAll(1);
        return l.isEmpty() ? null : l.get(0);
    }

    private BackupHistory map(ResultSet rs) throws SQLException {
        BackupHistory b = new BackupHistory();
        b.setId(rs.getLong("id"));
        b.setBackupFile(rs.getString("backup_file"));
        b.setBackupType(rs.getString("backup_type"));
        b.setStatus(rs.getString("status"));
        b.setFileSize(rs.getLong("file_size"));
        b.setCreatedBy(rs.getString("created_by"));
        b.setCreatedAt(rs.getTimestamp("created_at"));
        b.setRemarks(rs.getString("remarks"));
        b.setChecksum(rs.getString("checksum_sha256"));
        return b;
    }
}
