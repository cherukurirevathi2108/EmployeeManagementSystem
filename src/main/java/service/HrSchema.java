package service;

import java.sql.Connection;
import java.sql.Statement;

import model.DBcConnection;

/**
 * Creates the tables used by the HR role if they do not exist yet.
 * HR keeps its own attendance / break / leave tables, so nothing depends on
 * foreign keys or collations of the employee tables.
 */
public final class HrSchema {

    private static volatile boolean done = false;

    private HrSchema() { }

    public static synchronized void ensure() {

        if (done) {
            return;
        }

        String[] ddl = {

            "CREATE TABLE IF NOT EXISTS hr_users ("
            + "hr_id VARCHAR(20) NOT NULL PRIMARY KEY,"
            + "name VARCHAR(100) NOT NULL,"
            + "email VARCHAR(100) NOT NULL UNIQUE,"
            + "phone VARCHAR(15),"
            + "password VARCHAR(255) NOT NULL,"
            + "status VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',"
            + "recruited_by VARCHAR(100),"
            + "recruited_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)",

            "CREATE TABLE IF NOT EXISTS hr_attendance ("
            + "id INT AUTO_INCREMENT PRIMARY KEY,"
            + "hr_id VARCHAR(20) NOT NULL,"
            + "att_date DATE NOT NULL,"
            + "check_in_time TIME NULL,"
            + "check_out_time TIME NULL,"
            + "status VARCHAR(20) NOT NULL DEFAULT 'PRESENT',"
            + "UNIQUE KEY uq_hr_att (hr_id, att_date))",

            "CREATE TABLE IF NOT EXISTS hr_breaks ("
            + "id INT AUTO_INCREMENT PRIMARY KEY,"
            + "hr_id VARCHAR(20) NOT NULL,"
            + "break_number INT NOT NULL,"
            + "break_date DATE NOT NULL,"
            + "break_start TIME NOT NULL,"
            + "break_end TIME NULL,"
            + "KEY idx_hr_breaks (hr_id, break_date))",

            "CREATE TABLE IF NOT EXISTS hr_leave_requests ("
            + "leave_id INT AUTO_INCREMENT PRIMARY KEY,"
            + "hr_id VARCHAR(20) NOT NULL,"
            + "leave_type VARCHAR(20) NOT NULL,"
            + "from_date DATE NOT NULL,"
            + "to_date DATE NOT NULL,"
            + "reason VARCHAR(500) NOT NULL,"
            + "status VARCHAR(20) NOT NULL DEFAULT 'PENDING',"
            + "applied_date DATE NOT NULL,"
            + "decided_by VARCHAR(100) NULL,"
            + "decided_at TIMESTAMP NULL,"
            + "KEY idx_hr_leave (hr_id, status))"
        };

        try (Connection con = DBcConnection.getConnection();
             Statement st = con.createStatement()) {

            for (String sql : ddl) {
                st.executeUpdate(sql);
            }

            done = true;

        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
