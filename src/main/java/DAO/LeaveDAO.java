package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;

import model.DBcConnection;
import model.LeaveRequest;

public class LeaveDAO {

    // =========================================
    // APPLY LEAVE
    // =========================================
    public boolean applyLeave(LeaveRequest leave) {

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "INSERT INTO leave_requests " +
                    "(employee_id, leave_type, from_date, " +
                    "to_date, reason, status, applied_date) " +
                    "VALUES (?, ?, ?, ?, ?, 'PENDING', CURDATE())";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    leave.getEmployeeId()
            );

            statement.setString(
                    2,
                    leave.getLeaveType()
            );

            statement.setDate(
                    3,
                    java.sql.Date.valueOf(
                            leave.getFromDate()
                    )
            );

            statement.setDate(
                    4,
                    java.sql.Date.valueOf(
                            leave.getToDate()
                    )
            );

            statement.setString(
                    5,
                    leave.getReason()
            );

            int result =
                    statement.executeUpdate();

            return result > 0;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }

    // =========================================
    // GET LEAVES BY EMPLOYEE
    // =========================================
    public ArrayList<LeaveRequest> getLeavesByEmployee(
            String employeeId) {

        ArrayList<LeaveRequest> list =
                new ArrayList<>();

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT leave_id, employee_id, " +
                    "leave_type, from_date, to_date, " +
                    "reason, status, applied_date " +
                    "FROM leave_requests " +
                    "WHERE employee_id = ? " +
                    "ORDER BY leave_id DESC";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setString(
                    1,
                    employeeId
            );

            ResultSet result =
                    statement.executeQuery();

            while (result.next()) {

                LeaveRequest leave =
                        new LeaveRequest();

                leave.setLeaveId(
                        result.getInt(
                                "leave_id"
                        )
                );

                leave.setEmployeeId(
                        result.getString(
                                "employee_id"
                        )
                );

                leave.setLeaveType(
                        result.getString(
                                "leave_type"
                        )
                );

                if (result.getDate(
                        "from_date"
                ) != null) {

                    leave.setFromDate(
                            result.getDate(
                                    "from_date"
                            ).toLocalDate()
                    );
                }

                if (result.getDate(
                        "to_date"
                ) != null) {

                    leave.setToDate(
                            result.getDate(
                                    "to_date"
                            ).toLocalDate()
                    );
                }

                leave.setReason(
                        result.getString(
                                "reason"
                        )
                );

                leave.setStatus(
                        result.getString(
                                "status"
                        )
                );

                if (result.getDate(
                        "applied_date"
                ) != null) {

                    leave.setAppliedDate(
                            result.getDate(
                                    "applied_date"
                            ).toLocalDate()
                    );
                }

                list.add(leave);
            }

        } catch (Exception e) {

            e.printStackTrace();

        }

        return list;
    }

    // =========================================
    // GET ALL LEAVE REQUESTS - ADMIN
    // =========================================
    public ArrayList<LeaveRequest> getAllLeaveRequests() {

        ArrayList<LeaveRequest> list =
                new ArrayList<>();

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT leave_id, employee_id, " +
                    "leave_type, from_date, to_date, " +
                    "reason, status, applied_date " +
                    "FROM leave_requests " +
                    "ORDER BY leave_id DESC";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            ResultSet result =
                    statement.executeQuery();

            while (result.next()) {

                LeaveRequest leave =
                        new LeaveRequest();

                leave.setLeaveId(
                        result.getInt("leave_id")
                );

                leave.setEmployeeId(
                        result.getString("employee_id")
                );

                leave.setLeaveType(
                        result.getString("leave_type")
                );

                if (result.getDate("from_date") != null) {

                    leave.setFromDate(
                            result.getDate(
                                    "from_date"
                            ).toLocalDate()
                    );
                }

                if (result.getDate("to_date") != null) {

                    leave.setToDate(
                            result.getDate(
                                    "to_date"
                            ).toLocalDate()
                    );
                }

                leave.setReason(
                        result.getString("reason")
                );

                leave.setStatus(
                        result.getString("status")
                );

                if (result.getDate("applied_date") != null) {

                    leave.setAppliedDate(
                            result.getDate(
                                    "applied_date"
                            ).toLocalDate()
                    );
                }

                list.add(leave);
            }

        } catch (Exception e) {

            e.printStackTrace();

        }

        return list;
    }

    // =========================================
    // GET LEAVE BY ID
    // =========================================
    public LeaveRequest getLeaveById(
            int leaveId) {

        LeaveRequest leave = null;

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "SELECT leave_id, employee_id, " +
                    "leave_type, from_date, to_date, " +
                    "reason, status, applied_date " +
                    "FROM leave_requests " +
                    "WHERE leave_id = ?";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setInt(
                    1,
                    leaveId
            );

            ResultSet result =
                    statement.executeQuery();

            if (result.next()) {

                leave =
                        new LeaveRequest();

                leave.setLeaveId(
                        result.getInt("leave_id")
                );

                leave.setEmployeeId(
                        result.getString("employee_id")
                );

                leave.setLeaveType(
                        result.getString("leave_type")
                );

                if (result.getDate("from_date") != null) {

                    leave.setFromDate(
                            result.getDate(
                                    "from_date"
                            ).toLocalDate()
                    );
                }

                if (result.getDate("to_date") != null) {

                    leave.setToDate(
                            result.getDate(
                                    "to_date"
                            ).toLocalDate()
                    );
                }

                leave.setReason(
                        result.getString("reason")
                );

                leave.setStatus(
                        result.getString("status")
                );

                if (result.getDate("applied_date") != null) {

                    leave.setAppliedDate(
                            result.getDate(
                                    "applied_date"
                            ).toLocalDate()
                    );
                }
            }

        } catch (Exception e) {

            e.printStackTrace();

        }

        return leave;
    }

    // =========================================
    // APPROVE LEAVE
    // =========================================
    public boolean approveLeave(
            int leaveId) {

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "UPDATE leave_requests " +
                    "SET status = 'APPROVED' " +
                    "WHERE leave_id = ? " +
                    "AND status = 'PENDING'";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setInt(
                    1,
                    leaveId
            );

            int result =
                    statement.executeUpdate();

            return result > 0;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }

    // =========================================
    // REJECT LEAVE
    // =========================================
    public boolean rejectLeave(
            int leaveId) {

        try {

            Connection connection =
                    DBcConnection.getConnection();

            String sql =
                    "UPDATE leave_requests " +
                    "SET status = 'REJECTED' " +
                    "WHERE leave_id = ? " +
                    "AND status = 'PENDING'";

            PreparedStatement statement =
                    connection.prepareStatement(sql);

            statement.setInt(
                    1,
                    leaveId
            );

            int result =
                    statement.executeUpdate();

            return result > 0;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }
}