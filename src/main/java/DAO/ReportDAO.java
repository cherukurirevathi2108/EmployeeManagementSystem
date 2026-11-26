
package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import model.DBcConnection;

public class ReportDAO {

    public List<Map<String, String>> getReport(String type)
            throws Exception {

        String sql;

        switch (type) {
            case "attendance":
                sql = "SELECT a.employee_id AS `Employee ID`, " +
                      "e.name AS `Employee Name`, " +
                      "a.date AS `Date`, " +
                      "a.check_in_time AS `Check In`, " +
                      "a.check_out_time AS `Check Out`, " +
                      "a.status AS `Status` " +
                      "FROM attendance a " +
                      "LEFT JOIN employees e " +
                      "ON e.employee_id=a.employee_id " +
                      "ORDER BY a.date DESC";
                break;

            case "leaves":
                sql = "SELECT lr.leave_id AS `Leave ID`, " +
                      "lr.employee_id AS `Employee ID`, " +
                      "lr.leave_type AS `Leave Type`, " +
                      "lr.from_date AS `From Date`, " +
                      "lr.to_date AS `To Date`, " +
                      "lr.reason AS `Reason`, " +
                      "lr.status AS `Status` " +
                      "FROM leave_requests lr " +
                      "ORDER BY lr.from_date DESC";
                break;

            case "teams":
                sql = "SELECT t.team_id AS `Team ID`, " +
                      "t.team_name AS `Team Name`, " +
                      "t.department AS `Department`, " +
                      "t.manager_id AS `Manager ID`, " +
                      "m.name AS `Manager Name`, " +
                      "t.status AS `Status` " +
                      "FROM teams t " +
                      "LEFT JOIN managers m " +
                      "ON m.employee_id=t.manager_id " +
                      "ORDER BY t.team_id DESC";
                break;

            case "tasks":
            default:
                sql = "SELECT id AS `Task ID`, " +
                      "task_title AS `Task Title`, " +
                      "assigned_to AS `Employee ID`, " +
                      "status AS `Status`, " +
                      "due_date AS `Due Date` " +
                      "FROM tasks ORDER BY id DESC";
                break;
        }

        List<Map<String, String>> records = new ArrayList<>();

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            int columnCount = rs.getMetaData().getColumnCount();

            while (rs.next()) {
                Map<String, String> row = new LinkedHashMap<>();

                for (int i = 1; i <= columnCount; i++) {
                    String column = rs.getMetaData()
                                      .getColumnLabel(i);
                    String value = rs.getString(i);

                    row.put(column, value == null ? "" : value);
                }

                records.add(row);
            }
        }

        return records;
    }
}
