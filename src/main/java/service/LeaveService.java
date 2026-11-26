package service;

import java.util.ArrayList;

import DAO.LeaveDAO;
import model.LeaveRequest;

public class LeaveService {

    private LeaveDAO leaveDAO;

    public LeaveService() {

        leaveDAO =
                new LeaveDAO();
    }

    public boolean applyLeave(
            LeaveRequest leave) {

        return leaveDAO.applyLeave(
                leave
        );
    }

    public ArrayList<LeaveRequest> getLeavesByEmployee(
            String employeeId) {

        return leaveDAO.getLeavesByEmployee(
                employeeId
        );
    }

    public ArrayList<LeaveRequest> getAllLeaveRequests() {

        return leaveDAO.getAllLeaveRequests();
    }

    public LeaveRequest getLeaveById(
            int leaveId) {

        return leaveDAO.getLeaveById(
                leaveId
        );
    }

    public boolean approveLeave(
            int leaveId) {

        return leaveDAO.approveLeave(
                leaveId
        );
    }

    public boolean rejectLeave(
            int leaveId) {

        return leaveDAO.rejectLeave(
                leaveId
        );
    }
}