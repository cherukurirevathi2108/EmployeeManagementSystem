package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;

import model.Attendance;
import model.DBcConnection;

public class AttendenceDAO {

    // =====================================================
    // GET TODAY ATTENDANCE
    // =====================================================

    public Attendance getTodayAttendance(String employeeId) {

        Attendance attendance = null;

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT attendance_id, employee_id, date, " +
                    "check_in_time, check_out_time, status, " +
                    "leave_type, reason " +
                    "FROM attendance " +
                    "WHERE employee_id = ? " +
                    "AND date = CURDATE()";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(1, employeeId);

            ResultSet result =
                    statement.executeQuery();

            if (result.next()) {

                attendance =
                        new Attendance();

                attendance.setAttendanceId(
                        result.getInt("attendance_id")
                );

                attendance.setEmployeeId(
                        result.getString("employee_id")
                );

                if (result.getDate("date") != null) {

                    attendance.setDate(
                            result.getDate("date")
                                    .toLocalDate()
                    );
                }

                if (result.getTime("check_in_time") != null) {

                    attendance.setCheckInTime(
                            result.getTime(
                                    "check_in_time"
                            ).toLocalTime()
                    );
                }

                if (result.getTime("check_out_time") != null) {

                    attendance.setCheckOutTime(
                            result.getTime(
                                    "check_out_time"
                            ).toLocalTime()
                    );
                }

                attendance.setStatus(
                        result.getString("status")
                );

                attendance.setLeaveType(
                        result.getString("leave_type")
                );

                attendance.setReason(
                        result.getString("reason")
                );
            }

        } catch (Exception e) {

            e.printStackTrace();
        }

        return attendance;
    }


    // =====================================================
    // MARK ATTENDANCE
    // =====================================================

    public boolean markAttendance(
            Attendance attendance) {

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "INSERT INTO attendance " +
                    "(employee_id, date, status) " +
                    "VALUES (?, ?, ?) " +
                    "ON DUPLICATE KEY UPDATE " +
                    "status = VALUES(status)";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    attendance.getEmployeeId()
            );

            statement.setDate(
                    2,
                    java.sql.Date.valueOf(
                            attendance.getDate()
                    )
            );

            statement.setString(
                    3,
                    attendance.getStatus()
            );

            return statement.executeUpdate() > 0;

        } catch (Exception e) {

            e.printStackTrace();
        }

        return false;
    }


    // =====================================================
    // CHECK IN
    // =====================================================

    public boolean checkIn(String employeeId) {

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "INSERT INTO attendance " +
                    "(employee_id, date, check_in_time, status) " +
                    "VALUES (?, CURDATE(), CURTIME(), 'PRESENT')";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    employeeId
            );

            return statement.executeUpdate() > 0;

        } catch (Exception e) {

            e.printStackTrace();
        }

        return false;
    }


    // =====================================================
    // CHECK OUT
    // =====================================================

    public boolean checkOut(
            String employeeId,
            String status) {

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "UPDATE attendance " +
                    "SET check_out_time = CURTIME(), " +
                    "status = ? " +
                    "WHERE employee_id = ? " +
                    "AND date = CURDATE()";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    status
            );

            statement.setString(
                    2,
                    employeeId
            );

            return statement.executeUpdate() > 0;

        } catch (Exception e) {

            e.printStackTrace();
        }

        return false;
    }


    // =====================================================
    // GET ALL ATTENDANCE OF EMPLOYEE
    // =====================================================

    public ArrayList<Attendance>
    getAttendanceByEmployee(
            String employeeId) {

        ArrayList<Attendance> list =
                new ArrayList<>();

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT attendance_id, employee_id, date, " +
                    "check_in_time, check_out_time, status, " +
                    "leave_type, reason " +
                    "FROM attendance " +
                    "WHERE employee_id = ? " +
                    "ORDER BY date DESC";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    employeeId
            );

            ResultSet result =
                    statement.executeQuery();

            while (result.next()) {

                Attendance attendance =
                        new Attendance();

                attendance.setAttendanceId(
                        result.getInt(
                                "attendance_id"
                        )
                );

                attendance.setEmployeeId(
                        result.getString(
                                "employee_id"
                        )
                );

                if (result.getDate("date") != null) {

                    attendance.setDate(
                            result.getDate("date")
                                    .toLocalDate()
                    );
                }

                if (result.getTime(
                        "check_in_time"
                ) != null) {

                    attendance.setCheckInTime(
                            result.getTime(
                                    "check_in_time"
                            ).toLocalTime()
                    );
                }

                if (result.getTime(
                        "check_out_time"
                ) != null) {

                    attendance.setCheckOutTime(
                            result.getTime(
                                    "check_out_time"
                            ).toLocalTime()
                    );
                }

                attendance.setStatus(
                        result.getString(
                                "status"
                        )
                );

                attendance.setLeaveType(
                        result.getString(
                                "leave_type"
                        )
                );

                attendance.setReason(
                        result.getString(
                                "reason"
                        )
                );

                list.add(attendance);
            }

        } catch (Exception e) {

            e.printStackTrace();
        }

        return list;
    }


    // =====================================================
    // GET ATTENDANCE BY EMPLOYEE + MONTH + YEAR
    // =====================================================

    public ArrayList<Attendance>
    getAttendanceByEmployeeAndMonth(
            String employeeId,
            int month,
            int year) {

        ArrayList<Attendance> list =
                new ArrayList<>();

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT attendance_id, employee_id, date, " +
                    "check_in_time, check_out_time, status, " +
                    "leave_type, reason " +
                    "FROM attendance " +
                    "WHERE employee_id = ? " +
                    "AND MONTH(date) = ? " +
                    "AND YEAR(date) = ? " +
                    "ORDER BY date ASC";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    employeeId
            );

            statement.setInt(
                    2,
                    month
            );

            statement.setInt(
                    3,
                    year
            );

            ResultSet result =
                    statement.executeQuery();

            while (result.next()) {

                Attendance attendance =
                        new Attendance();

                attendance.setAttendanceId(
                        result.getInt(
                                "attendance_id"
                        )
                );

                attendance.setEmployeeId(
                        result.getString(
                                "employee_id"
                        )
                );

                if (result.getDate("date") != null) {

                    attendance.setDate(
                            result.getDate("date")
                                    .toLocalDate()
                    );
                }

                if (result.getTime(
                        "check_in_time"
                ) != null) {

                    attendance.setCheckInTime(
                            result.getTime(
                                    "check_in_time"
                            ).toLocalTime()
                    );
                }

                if (result.getTime(
                        "check_out_time"
                ) != null) {

                    attendance.setCheckOutTime(
                            result.getTime(
                                    "check_out_time"
                            ).toLocalTime()
                    );
                }

                attendance.setStatus(
                        result.getString(
                                "status"
                        )
                );

                attendance.setLeaveType(
                        result.getString(
                                "leave_type"
                        )
                );

                attendance.setReason(
                        result.getString(
                                "reason"
                        )
                );

                list.add(attendance);
            }

        } catch (Exception e) {

            e.printStackTrace();
        }

        return list;
    }
}