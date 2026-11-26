package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import model.DBcConnection;

@WebServlet("/manager")
public class ManagerServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;


    // =====================================================
    // GET
    // =====================================================

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session =
                request.getSession(false);

        if (session == null ||
                session.getAttribute("managerId") == null) {

            response.sendRedirect(
                    request.getContextPath()
                    + "/managerLogin.jsp"
            );

            return;
        }

        // Salary slip: the manager can view / download only his own PAID slips
        if ("salarySlip".equals(request.getParameter("action"))) {
            salarySlip(request, response,
                    (String) session.getAttribute("managerId"));
            return;
        }

        request.getRequestDispatcher(
                "/managerDashboard.jsp"
        ).forward(
                request,
                response
        );
    }


    // =====================================================
    // POST
    // =====================================================

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session =
                request.getSession(false);

        if (session == null ||
                session.getAttribute("managerId") == null) {

            response.sendRedirect(
                    request.getContextPath()
                    + "/managerLogin.jsp"
            );
            return;
        }
        String managerId =
                (String) session.getAttribute(
                        "managerId"
                );

        String action =
                request.getParameter("action");


        System.out.println(
                "================================"
        );

        System.out.println(
                "MANAGER ID = " + managerId
        );

        System.out.println(
                "ACTION = " + action
        );

        System.out.println(
                "================================"
        );


        // CHECK IN
        if ("checkIn".equals(action)) {

            checkIn(managerId);

            response.sendRedirect(
                    request.getContextPath()
                    + "/manager"
            );

            return;
        }


        // CHECK OUT
        if ("checkOut".equals(action)) {

            checkOut(managerId);

            // approved overtime today: check-out becomes 6:10 PM + OT hours
            service.OvertimeService.applyApprovedForToday(managerId);

            response.sendRedirect(
                    request.getContextPath()
                    + "/manager"
            );

            return;
        }


        // START BREAK
        if ("startBreak".equals(action)) {

            startBreak(managerId);

            response.sendRedirect(
                    request.getContextPath()
                    + "/manager"
            );

            return;
        }


        // END BREAK
        if ("endBreak".equals(action)) {

            endBreak(managerId);

            response.sendRedirect(
                    request.getContextPath()
                    + "/manager"
            );

            return;
        }


        // APPLY LEAVE
        if ("applyLeave".equals(action)) {

            applyLeave(
                    request,
                    response,
                    managerId
            );

            return;
        }


        response.sendRedirect(
                request.getContextPath()
                + "/manager"
        );
    }


    // =====================================================
    // APPLY LEAVE
    // =====================================================

    private void applyLeave(
            HttpServletRequest request,
            HttpServletResponse response,
            String managerId)
            throws IOException {

        String leaveType =
                request.getParameter("leaveType");

        String fromDateText =
                request.getParameter("fromDate");

        String toDateText =
                request.getParameter("toDate");

        String reason =
                request.getParameter("reason");


        if (leaveType == null ||
                leaveType.trim().isEmpty() ||
                fromDateText == null ||
                toDateText == null ||
                reason == null ||
                reason.trim().isEmpty()) {

            response.sendRedirect(
                    request.getContextPath()
                    + "/manager"
            );

            return;
        }


        try {

            LocalDate fromDate =
                    LocalDate.parse(fromDateText);

            LocalDate toDate =
                    LocalDate.parse(toDateText);


            if (toDate.isBefore(fromDate)) {

                response.sendRedirect(
                        request.getContextPath()
                        + "/manager"
                );

                return;
            }


            Connection con =
                    DBcConnection.getConnection();


            if (con == null) {

                response.sendRedirect(
                        request.getContextPath()
                        + "/manager"
                );

                return;
            }


            String pendingSql =
                    "SELECT COUNT(*) " +
                    "FROM leave_requests " +
                    "WHERE employee_id = ? " +
                    "AND status = 'PENDING'";


            PreparedStatement pendingPs =
                    con.prepareStatement(
                            pendingSql
                    );

            pendingPs.setString(
                    1,
                    managerId
            );


            ResultSet pendingRs =
                    pendingPs.executeQuery();


            boolean hasPending = false;

            if (pendingRs.next()) {

                hasPending =
                        pendingRs.getInt(1) > 0;
            }


            pendingRs.close();
            pendingPs.close();


            if (hasPending) {

                con.close();

                response.sendRedirect(
                        request.getContextPath()
                        + "/manager"
                );

                return;
            }


            String sql =
                    "INSERT INTO leave_requests " +
                    "(employee_id, leave_type, from_date, " +
                    "to_date, reason, status, applied_date) " +
                    "VALUES (?, ?, ?, ?, ?, 'PENDING', CURDATE())";


            PreparedStatement ps =
                    con.prepareStatement(sql);


            ps.setString(
                    1,
                    managerId
            );

            ps.setString(
                    2,
                    leaveType
            );

            ps.setDate(
                    3,
                    java.sql.Date.valueOf(fromDate)
            );

            ps.setDate(
                    4,
                    java.sql.Date.valueOf(toDate)
            );

            ps.setString(
                    5,
                    reason
            );


            ps.executeUpdate();

            ps.close();
            con.close();


        } catch (Exception e) {

            e.printStackTrace();
        }


        response.sendRedirect(
                request.getContextPath()
                + "/manager"
        );
    }


    // =====================================================
    // CHECK IN
    // =====================================================

    private void checkIn(
            String managerId) {

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con =
                    DBcConnection.getConnection();


            // Check approved leave
            String leaveSql =
                    "SELECT COUNT(*) " +
                    "FROM leave_requests " +
                    "WHERE employee_id = ? " +
                    "AND status = 'APPROVED' " +
                    "AND CURDATE() BETWEEN from_date AND to_date";


            ps =
                    con.prepareStatement(
                            leaveSql
                    );

            ps.setString(
                    1,
                    managerId
            );

            rs =
                    ps.executeQuery();


            boolean onLeave = false;

            if (rs.next()) {

                onLeave =
                        rs.getInt(1) > 0;
            }


            rs.close();
            ps.close();


            if (onLeave) {

                con.close();
                return;
            }


            // Check today's attendance
            String checkSql =
                    "SELECT COUNT(*) " +
                    "FROM attendance " +
                    "WHERE employee_id = ? " +
                    "AND date = CURDATE()";


            ps =
                    con.prepareStatement(
                            checkSql
                    );

            ps.setString(
                    1,
                    managerId
            );

            rs =
                    ps.executeQuery();


            boolean alreadyExists = false;

            if (rs.next()) {

                alreadyExists =
                        rs.getInt(1) > 0;
            }


            rs.close();
            ps.close();


            if (alreadyExists) {

                con.close();
                return;
            }


            // ACTUAL CHECK IN
            String sql =
                    "INSERT INTO attendance " +
                    "(employee_id, date, check_in_time, status) " +
                    "VALUES (?, CURDATE(), CURTIME(), 'PRESENT')";


            ps =
                    con.prepareStatement(sql);

            ps.setString(
                    1,
                    managerId
            );

            ps.executeUpdate();


            System.out.println(
                    "MANAGER CHECK-IN SUCCESS : "
                    + managerId
            );


        } catch (Exception e) {

            e.printStackTrace();

        } finally {

            try {
                if (rs != null)
                    rs.close();
            } catch (Exception e) {}

            try {
                if (ps != null)
                    ps.close();
            } catch (Exception e) {}

            try {
                if (con != null)
                    con.close();
            } catch (Exception e) {}
        }
    }


    // =====================================================
    // CHECK OUT
    // =====================================================

    private void checkOut(
            String managerId) {

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con =
                    DBcConnection.getConnection();


            String getSql =
                    "SELECT check_in_time " +
                    "FROM attendance " +
                    "WHERE employee_id = ? " +
                    "AND date = CURDATE()";


            ps =
                    con.prepareStatement(
                            getSql
                    );

            ps.setString(
                    1,
                    managerId
            );


            rs =
                    ps.executeQuery();


            java.sql.Time checkIn = null;


            if (rs.next()) {

                checkIn =
                        rs.getTime(
                                "check_in_time"
                        );
            }


            rs.close();
            ps.close();


            if (checkIn == null) {

                con.close();
                return;
            }


            LocalTime inTime =
                    checkIn.toLocalTime();

            LocalTime outTime =
                    LocalTime.now();


            long workedMinutes =
                    Duration.between(
                            inTime,
                            outTime
                    ).toMinutes();


            String status;


            if (workedMinutes >= 480) {

                status = "PRESENT";

            } else if (workedMinutes > 240) {

                status = "HALF DAY";

            } else {

                status = "ABSENT";
            }


            String sql =
                    "UPDATE attendance " +
                    "SET check_out_time = CURTIME(), " +
                    "status = ? " +
                    "WHERE employee_id = ? " +
                    "AND date = CURDATE()";


            ps =
                    con.prepareStatement(sql);


            ps.setString(
                    1,
                    status
            );

            ps.setString(
                    2,
                    managerId
            );


            ps.executeUpdate();


            System.out.println(
                    "MANAGER CHECK-OUT SUCCESS : "
                    + managerId
            );


        } catch (Exception e) {

            e.printStackTrace();

        } finally {

            try {
                if (rs != null)
                    rs.close();
            } catch (Exception e) {}

            try {
                if (ps != null)
                    ps.close();
            } catch (Exception e) {}

            try {
                if (con != null)
                    con.close();
            } catch (Exception e) {}
        }
    }


    // =====================================================
    // START BREAK
    // =====================================================

    private void startBreak(
            String managerId) {

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con =
                    DBcConnection.getConnection();


            // Leave check
            String leaveSql =
                    "SELECT COUNT(*) " +
                    "FROM leave_requests " +
                    "WHERE employee_id = ? " +
                    "AND status = 'APPROVED' " +
                    "AND CURDATE() BETWEEN from_date AND to_date";


            ps =
                    con.prepareStatement(
                            leaveSql
                    );

            ps.setString(
                    1,
                    managerId
            );


            rs =
                    ps.executeQuery();


            boolean onLeave = false;


            if (rs.next()) {

                onLeave =
                        rs.getInt(1) > 0;
            }


            rs.close();
            ps.close();


            if (onLeave) {

                con.close();
                return;
            }


            // Count today's breaks
            String countSql =
                    "SELECT COUNT(*) " +
                    "FROM breaks " +
                    "WHERE employee_id = ? " +
                    "AND break_date = CURDATE()";


            ps =
                    con.prepareStatement(
                            countSql
                    );

            ps.setString(
                    1,
                    managerId
            );


            rs =
                    ps.executeQuery();


            int breakCount = 0;


            if (rs.next()) {

                breakCount =
                        rs.getInt(1);
            }


            rs.close();
            ps.close();


            if (breakCount >= 2) {

                con.close();
                return;
            }


            int breakNumber =
                    breakCount + 1;


            // Check running break
            String runningSql =
                    "SELECT COUNT(*) " +
                    "FROM breaks " +
                    "WHERE employee_id = ? " +
                    "AND break_date = CURDATE() " +
                    "AND break_start IS NOT NULL " +
                    "AND break_end IS NULL";


            ps =
                    con.prepareStatement(
                            runningSql
                    );

            ps.setString(
                    1,
                    managerId
            );


            rs =
                    ps.executeQuery();


            boolean running = false;


            if (rs.next()) {

                running =
                        rs.getInt(1) > 0;
            }


            rs.close();
            ps.close();


            if (running) {

                con.close();
                return;
            }


            String sql =
                    "INSERT INTO breaks " +
                    "(employee_id, break_number, break_date, break_start) " +
                    "VALUES (?, ?, CURDATE(), CURTIME())";


            ps =
                    con.prepareStatement(sql);


            ps.setString(
                    1,
                    managerId
            );

            ps.setInt(
                    2,
                    breakNumber
            );


            ps.executeUpdate();


        } catch (Exception e) {

            e.printStackTrace();

        } finally {

            try {
                if (rs != null)
                    rs.close();
            } catch (Exception e) {}

            try {
                if (ps != null)
                    ps.close();
            } catch (Exception e) {}

            try {
                if (con != null)
                    con.close();
            } catch (Exception e) {}
        }
    }


    // =====================================================
    // END BREAK
    // =====================================================

    private void endBreak(
            String managerId) {

        Connection con = null;
        PreparedStatement ps = null;

        try {

            con =
                    DBcConnection.getConnection();


            String sql =
                    "UPDATE breaks " +
                    "SET break_end = CURTIME() " +
                    "WHERE employee_id = ? " +
                    "AND break_date = CURDATE() " +
                    "AND break_end IS NULL " +
                    "ORDER BY break_number DESC " +
                    "LIMIT 1";


            ps =
                    con.prepareStatement(sql);


            ps.setString(
                    1,
                    managerId
            );


            ps.executeUpdate();


        } catch (Exception e) {

            e.printStackTrace();

        } finally {

            try {
                if (ps != null)
                    ps.close();
            } catch (Exception e) {}

            try {
                if (con != null)
                    con.close();
            } catch (Exception e) {}
        }
    }

    // =====================================================
    // SALARY SLIP (view / download) - only after admin has paid
    // =====================================================

    private void salarySlip(HttpServletRequest request,
                            HttpServletResponse response,
                            String managerId) throws IOException {

        int payrollId;
        try {
            payrollId = Integer.parseInt(request.getParameter("payrollId"));
        } catch (Exception e) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid payroll ID");
            return;
        }

        try {
            DAO.PayrollDAO payrollDAO = new DAO.PayrollDAO();
            model.Payroll p = payrollDAO.getPayrollDetailById(payrollId);

            // a manager can never open somebody else's slip
            if (p == null || p.getEmployeeId() == null
                    || !p.getEmployeeId().equals(managerId)) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND, "Salary slip not found");
                return;
            }

            String st = p.getStatus() == null ? "" : p.getStatus().trim().toUpperCase();
            if (!"PAID".equals(st)) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN,
                        "The salary slip is available only after the admin has paid the salary");
                return;
            }

            model.SalaryStructure structure =
                    new DAO.SalaryStructureDAO().getStructureForPayroll(
                            p.getEmployeeId(),
                            java.sql.Date.valueOf(java.time.YearMonth.of(
                                    p.getPayrollYear(), p.getPayrollMonth()).atEndOfMonth()));

            java.util.List<model.SalaryComponent> components = structure == null
                    ? new java.util.ArrayList<model.SalaryComponent>()
                    : new DAO.SalaryComponentDAO().getComponentsByStructureId(structure.getId());

            service.PayrollService.AttendanceSummary attendance = null;
            try {
                attendance = new service.PayrollService().getAttendanceSummary(
                        p.getEmployeeId(), p.getPayrollMonth(), p.getPayrollYear());
            } catch (Exception ignored) {
            }

            java.util.List<model.PayrollPayment> payments =
                    new DAO.PayrollPaymentDAO().getPaymentsByPayrollId(payrollId);

            String html = service.SalarySlipHtml.render(p, components, attendance, payments);

            response.setContentType("text/html; charset=UTF-8");
            response.setCharacterEncoding("UTF-8");

            if ("1".equals(request.getParameter("download"))) {
                String file = "salary_slip_" + p.getEmployeeId() + "_"
                        + p.getPayrollYear() + "_"
                        + (p.getPayrollMonth() < 10 ? "0" : "") + p.getPayrollMonth() + ".html";
                response.setHeader("Content-Disposition",
                        "attachment; filename=\"" + file + "\"");
            }

            response.getWriter().write(html);

        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    "Unable to generate the salary slip");
        }
    }
}