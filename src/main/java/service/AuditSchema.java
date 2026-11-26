package service;

import java.sql.Connection;
import java.sql.Statement;

import model.DBcConnection;

/** Creates the audit-module tables if missing (same approach as HrSchema). */
public final class AuditSchema {

    private static volatile boolean done = false;

    private AuditSchema() { }

    public static synchronized void ensure() {
        if (done) return;

        String[] ddl = {
            "CREATE TABLE IF NOT EXISTS audit_logs ("
            + "id BIGINT AUTO_INCREMENT PRIMARY KEY,"
            + "user_id VARCHAR(50) NULL, user_role VARCHAR(20) NULL,"
            + "module_name VARCHAR(100) NOT NULL, action_type VARCHAR(50) NOT NULL,"
            + "record_id VARCHAR(100) NULL, description TEXT NULL,"
            + "old_values JSON NULL, new_values JSON NULL, ip_address VARCHAR(45) NULL,"
            + "created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            + "KEY idx_audit_user (user_id), KEY idx_audit_module (module_name),"
            + "KEY idx_audit_action (action_type), KEY idx_audit_created (created_at))",

            "CREATE TABLE IF NOT EXISTS login_history ("
            + "id BIGINT AUTO_INCREMENT PRIMARY KEY,"
            + "user_id VARCHAR(50) NULL, user_role VARCHAR(20) NULL, email VARCHAR(150) NULL,"
            + "activity_type VARCHAR(30) NOT NULL, ip_address VARCHAR(45) NULL, user_agent TEXT NULL,"
            + "created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            + "KEY idx_login_user (user_id), KEY idx_login_email (email),"
            + "KEY idx_login_type_time (activity_type, created_at),"
            + "KEY idx_login_ip_time (ip_address, created_at))",

            "CREATE TABLE IF NOT EXISTS system_settings ("
            + "id INT AUTO_INCREMENT PRIMARY KEY,"
            + "setting_key VARCHAR(100) NOT NULL UNIQUE, setting_value TEXT NULL,"
            + "description VARCHAR(255) NULL, updated_by VARCHAR(50) NULL,"
            + "updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)",

            "CREATE TABLE IF NOT EXISTS system_errors ("
            + "id BIGINT AUTO_INCREMENT PRIMARY KEY,"
            + "module_name VARCHAR(100) NULL, error_type VARCHAR(150) NULL, error_message TEXT NULL,"
            + "severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM', user_id VARCHAR(50) NULL,"
            + "created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            + "KEY idx_err_sev_time (severity, created_at), KEY idx_err_module (module_name),"
            + "KEY idx_err_created (created_at))",

            "CREATE TABLE IF NOT EXISTS backup_history ("
            + "id BIGINT AUTO_INCREMENT PRIMARY KEY,"
            + "backup_file VARCHAR(255) NOT NULL, backup_type VARCHAR(30) NOT NULL DEFAULT 'FULL',"
            + "status VARCHAR(30) NOT NULL, file_size BIGINT NOT NULL DEFAULT 0,"
            + "created_by VARCHAR(50) NULL,"
            + "created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            + "remarks TEXT NULL, checksum_sha256 VARCHAR(64) NULL,"
            + "KEY idx_backup_created (created_at))"
        };

        try (Connection con = DBcConnection.getConnection();
             Statement st = con.createStatement()) {
            for (String sql : ddl) st.executeUpdate(sql);
            done = true;
        } catch (Exception e) {
            System.err.println("[AuditSchema] could not create tables: " + e.getMessage());
        }
    }
}
