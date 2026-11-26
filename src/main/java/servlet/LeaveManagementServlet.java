package servlet;

import java.io.IOException;
import java.time.LocalDate;
import java.util.ArrayList;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import model.LeaveRequest;
import service.LeaveService;

@WebServlet("/leave")
public class LeaveManagementServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private LeaveService leaveService;

    @Override
    public void init() {
        leaveService = new LeaveService();
    }

    // =========================
    // GET
    // =========================
    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session =
                request.getSession(false);

        if (session == null) {

            response.sendRedirect(
                    request.getContextPath()
                            + "/login.html"
            );

            return;
        }

        String employeeId =
                (String) session.getAttribute(
                        "employeeId"
                );

        if (employeeId == null ||
                employeeId.trim().isEmpty()) {

            response.sendRedirect(
                    request.getContextPath()
                            + "/login.html"
            );

            return;
        }

        // Load employee leave requests
        loadEmployeeLeaves(
                request,
                employeeId
        );

        request.getRequestDispatcher(
                "/leave-management.jsp"
        ).forward(
                request,
                response
        );
    }

    // =========================
    // POST
    // =========================
    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session =
                request.getSession(false);

        if (session == null) {

            response.sendRedirect(
                    request.getContextPath()
                            + "/login.html"
            );

            return;
        }

        String employeeId =
                (String) session.getAttribute(
                        "employeeId"
                );

        if (employeeId == null ||
                employeeId.trim().isEmpty()) {

            response.sendRedirect(
                    request.getContextPath()
                            + "/login.html"
            );

            return;
        }

        String action =
                request.getParameter("action");

        // =========================
        // APPLY LEAVE
        // =========================
        if ("applyLeave".equals(action)) {

            try {

                String leaveType =
                        request.getParameter(
                                "leaveType"
                        );

                String fromDateText =
                        request.getParameter(
                                "fromDate"
                        );

                String toDateText =
                        request.getParameter(
                                "toDate"
                        );

                String reason =
                        request.getParameter(
                                "reason"
                        );

                if (leaveType == null ||
                        leaveType.trim().isEmpty() ||
                        fromDateText == null ||
                        toDateText == null ||
                        reason == null ||
                        reason.trim().isEmpty()) {

                    request.setAttribute(
                            "error",
                            "Please fill all leave details."
                    );

                    loadEmployeeLeaves(
                            request,
                            employeeId
                    );

                    forwardToLeavePage(
                            request,
                            response
                    );

                    return;
                }

                LocalDate fromDate =
                        LocalDate.parse(
                                fromDateText
                        );

                LocalDate toDate =
                        LocalDate.parse(
                                toDateText
                        );

                if (toDate.isBefore(fromDate)) {

                    request.setAttribute(
                            "error",
                            "To date cannot be before from date."
                    );

                    loadEmployeeLeaves(
                            request,
                            employeeId
                    );

                    forwardToLeavePage(
                            request,
                            response
                    );

                    return;
                }

                LeaveRequest leave =
                        new LeaveRequest();

                leave.setEmployeeId(
                        employeeId
                );

                leave.setLeaveType(
                        leaveType
                );

                leave.setFromDate(
                        fromDate
                );

                leave.setToDate(
                        toDate
                );

                leave.setReason(
                        reason
                );

                // Always PENDING when employee applies
                leave.setStatus(
                        "PENDING"
                );

                leave.setAppliedDate(
                        LocalDate.now()
                );

                boolean success =
                        leaveService.applyLeave(
                                leave
                        );

                if (success) {

                    request.setAttribute(
                            "success",
                            "Leave applied successfully. Waiting for admin approval."
                    );

                } else {

                    request.setAttribute(
                            "error",
                            "Leave application failed."
                    );
                }

            } catch (Exception e) {

                e.printStackTrace();

                request.setAttribute(
                        "error",
                        "Invalid leave details."
                );
            }

            /*
             * IMPORTANT:
             * Load leaves again after applying.
             * This makes the newly created PENDING
             * leave immediately visible.
             */
            loadEmployeeLeaves(
                    request,
                    employeeId
            );

            forwardToLeavePage(
                    request,
                    response
            );

            return;
        }

        response.sendRedirect(
                request.getContextPath()
                        + "/leave"
        );
    }

    // =========================
    // LOAD EMPLOYEE LEAVES
    // =========================
    private void loadEmployeeLeaves(
            HttpServletRequest request,
            String employeeId) {

        ArrayList<LeaveRequest> leaves =
                leaveService.getLeavesByEmployee(
                        employeeId
                );

        request.setAttribute(
                "leaves",
                leaves
        );
    }

    // =========================
    // FORWARD
    // =========================
    private void forwardToLeavePage(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        request.getRequestDispatcher(
                "/leave-management.jsp"
        ).forward(
                request,
                response
        );
    }
}