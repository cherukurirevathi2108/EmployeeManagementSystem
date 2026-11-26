package service;

import java.util.ArrayList;

import DAO.AttendenceDAO;
import model.Attendance;

public class AttendanceService {

    private AttendenceDAO attendenceDAO;


    // =====================================================
    // CONSTRUCTOR
    // =====================================================

    public AttendanceService() {

        attendenceDAO =
                new AttendenceDAO();
    }


    // =====================================================
    // GET TODAY ATTENDANCE
    // =====================================================

    public Attendance getTodayAttendance(
            String employeeId) {

        return attendenceDAO
                .getTodayAttendance(
                        employeeId
                );
    }


    // =====================================================
    // MARK ATTENDANCE
    // =====================================================

    public boolean markAttendance(
            Attendance attendance) {

        return attendenceDAO
                .markAttendance(
                        attendance
                );
    }


    // =====================================================
    // CHECK IN
    // =====================================================

    public boolean checkIn(
            String employeeId) {

        return attendenceDAO
                .checkIn(
                        employeeId
                );
    }


    // =====================================================
    // CHECK OUT
    // =====================================================

    public boolean checkOut(
            String employeeId,
            String status) {

        return attendenceDAO
                .checkOut(
                        employeeId,
                        status
                );
    }


    // =====================================================
    // GET ALL ATTENDANCE
    // =====================================================

    public ArrayList<Attendance>
    getAttendanceByEmployee(
            String employeeId) {

        return attendenceDAO
                .getAttendanceByEmployee(
                        employeeId
                );
    }


    // =====================================================
    // GET ATTENDANCE BY MONTH
    // =====================================================

    public ArrayList<Attendance>
    getAttendanceByEmployeeAndMonth(
            String employeeId,
            int month,
            int year) {

        return attendenceDAO
                .getAttendanceByEmployeeAndMonth(
                        employeeId,
                        month,
                        year
                );
    }
}