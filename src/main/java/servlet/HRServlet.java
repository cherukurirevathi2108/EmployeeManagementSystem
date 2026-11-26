package servlet;

import java.io.IOException;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Time;
import java.sql.Types;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import model.DBcConnection;
import model.Employe;
import model.Task;
import DAO.TaskDAO;
import service.PersonReportHtml;
import DAO.PayrollDAO;
import model.Payroll;
import service.EmailService;
import service.HrSchema;

@WebServlet("/hr")
public class HRServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private final TaskDAO taskDAO = new TaskDAO();

    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null ||
            !"HR".equalsIgnoreCase(
                String.valueOf(session.getAttribute("role")))) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        HrSchema.ensure();

        try {
            loadDashboardCounts(request);
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("employeeCount", 0);
            request.setAttribute("managerCount", 0);
            request.setAttribute("teamCount", 0);
        }

        String action = request.getParameter("action");

        try {
            if (action == null || action.trim().isEmpty()) {
                loadDefaultTaskCounts(request);
                forwardDashboard(request, response);
                return;
            }

            switch (action) {
                case "searchEmployee":
                    searchEmployee(request, response);
                    break;

                case "viewEmployees":
                    viewEmployees(request, response);
                    break;

                case "viewManagers":
                    viewManagers(request, response);
                    break;

                case "myAttendance":
                    loadMyAttendance(request, response);
                    break;

                case "personAttendance":
                    personAttendance(request, response);
                    return;

                case "todayAttendance":
                    attendanceReport(request, response, true);
                    break;

                case "monthlyAttendance":
                    attendanceReport(request, response, false);
                    break;

                case "viewLeaves":
                    viewLeaves(request, response);
                    break;

                case "taskManagement":
                case "searchTasks":
                case "editTask":
                    loadTasks(request, response);
                    break;

                case "reports":
                    loadReports(request, response);
                    break;

                case "payroll":
                    loadPayroll(request, response);
                    break;

                case "payrollCsv":
                    payrollCsv(request, response);
                    return;

                case "salarySlip":
                    salarySlip(request, response);
                    return;

                case "emailSlip":
                    emailSlip(request, response);
                    return;

                default:
                    loadDefaultTaskCounts(request);
                    forwardDashboard(request, response);
                    break;
            }

        } catch (Exception e) {
            e.printStackTrace();

            request.setAttribute(
                "pageError",
                "Unable to load this section: " + e.getMessage()
            );

            loadDefaultTaskCounts(request);
            forwardDashboard(request, response);
        }
    }

    /** View (printable page) or Download (CSV) of one person's attendance report. */
    private void personAttendance(HttpServletRequest request,
                                  HttpServletResponse response)
            throws IOException {

        String id = request.getParameter("reportPerson");
        String kind = request.getParameter("personKind");
        String from = request.getParameter("fromDate");
        String to = request.getParameter("toDate");
        String mode = request.getParameter("mode");

        if (id == null || id.trim().isEmpty()) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Person ID is required");
            return;
        }

        try {
            PersonReportHtml.AttendanceData data =
                PersonReportHtml.attendanceData(id, kind, from, to);

            if (!data.found) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND, "Person not found");
                return;
            }

            if ("csv".equalsIgnoreCase(mode)) {
                String fileName = "attendance_"
                    + data.id.replaceAll("[^A-Za-z0-9_-]", "_") + "_"
                    + data.from + "_to_" + data.to + ".csv";
                response.setContentType("text/csv; charset=UTF-8");
                response.setCharacterEncoding("UTF-8");
                response.setHeader("Content-Disposition",
                    "attachment; filename=\"" + fileName + "\"");
                response.getWriter().write(PersonReportHtml.attendanceCsv(data));
            } else {
                String downloadUrl = request.getContextPath()
                    + "/hr?action=personAttendance&reportPerson="
                    + java.net.URLEncoder.encode(data.id, "UTF-8")
                    + "&personKind=" + data.type
                    + "&fromDate=" + data.from + "&toDate=" + data.to
                    + "&mode=csv";
                response.setContentType("text/html; charset=UTF-8");
                response.setCharacterEncoding("UTF-8");
                response.getWriter().write(
                    PersonReportHtml.attendanceViewHtml(data, downloadUrl));
            }

        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                "Unable to generate the attendance report");
        }
    }

    @Override
    protected void doPost(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null ||
            !"HR".equalsIgnoreCase(
                String.valueOf(session.getAttribute("role")))) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        HrSchema.ensure();

        String action = request.getParameter("action");

        try {
            if ("addEmployee".equals(action)) {
                addEmployee(request, response);

            } else if ("addManager".equals(action)) {
                addManager(request, response);

            } else if ("resendCredentials".equals(action)) {
                resendCredentials(request, response);

            } else if (action != null && action.startsWith("my")) {
                handleMyAction(request, response, action);

            } else if ("approveLeave".equals(action)) {
                updateLeaveStatus(
                    request.getParameter("leaveId"), "APPROVED"
                );

                response.sendRedirect(
                    request.getContextPath()
                    + "/hr?action=viewLeaves#leaveManagement"
                );

            } else if ("rejectLeave".equals(action)) {
                updateLeaveStatus(
                    request.getParameter("leaveId"), "REJECTED"
                );

                response.sendRedirect(
                    request.getContextPath()
                    + "/hr?action=viewLeaves#leaveManagement"
                );

            } else if ("createTask".equals(action)) {
                createTask(request, response);

            } else if ("updateTask".equals(action)) {
                updateTask(request, response);

            } else if ("deleteTask".equals(action)) {
                deleteTask(request, response);

            } else {
                response.sendRedirect(request.getContextPath() + "/hr");
            }

        } catch (Exception e) {
            e.printStackTrace();

            if ("createTask".equals(action) || "updateTask".equals(action)) {
                request.setAttribute(
                    "taskError", "Unable to save task: " + e.getMessage()
                );

                try {
                    loadTasks(request, response);
                } catch (Exception ex) {
                    ex.printStackTrace();

                    response.sendRedirect(
                        request.getContextPath() + "/hr?error=failed"
                    );
                }
            } else {
                response.sendRedirect(
                    request.getContextPath() + "/hr?error=failed"
                );
            }
        }
    }

    private void forwardDashboard(HttpServletRequest request,
                                  HttpServletResponse response)
            throws ServletException, IOException {

        request.getRequestDispatcher("/hr_dashboard.jsp")
               .forward(request, response);
    }

    // ---------------- DASHBOARD COUNTS ----------------

    private void loadDashboardCounts(HttpServletRequest request)
            throws Exception {

        try (Connection con = DBcConnection.getConnection()) {
            request.setAttribute(
                "employeeCount",
                count(con, "SELECT COUNT(*) FROM employees")
            );

            request.setAttribute(
                "managerCount",
                count(con, "SELECT COUNT(*) FROM managers")
            );

            request.setAttribute(
                "teamCount",
                count(con, "SELECT COUNT(*) FROM teams")
            );
        }
    }

    private int count(Connection con, String sql) throws Exception {
        try (PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    private void loadDefaultTaskCounts(HttpServletRequest request) {
        try {
            List<Task> allTasks = taskDAO.getAllTasks();

            int pending = 0;
            int progress = 0;
            int completed = 0;

            for (Task task : allTasks) {
                String status = task.getStatus();

                if ("PENDING".equalsIgnoreCase(status)) {
                    pending++;
                } else if ("IN_PROGRESS".equalsIgnoreCase(status)) {
                    progress++;
                } else if ("COMPLETED".equalsIgnoreCase(status)) {
                    completed++;
                }
            }

            request.setAttribute("tasks", allTasks);
            request.setAttribute("taskCount", allTasks.size());
            request.setAttribute("pendingCount", pending);
            request.setAttribute("inProgressCount", progress);
            request.setAttribute("completedCount", completed);
            request.setAttribute("taskSearch", "");
            request.setAttribute("taskStatusFilter", "ALL");

        } catch (Exception e) {
            request.setAttribute("tasks", new ArrayList<Task>());
            request.setAttribute("taskCount", 0);
            request.setAttribute("pendingCount", 0);
            request.setAttribute("inProgressCount", 0);
            request.setAttribute("completedCount", 0);
            request.setAttribute("taskSearch", "");
            request.setAttribute("taskStatusFilter", "ALL");
        }
    }

    // ---------------- ADD EMPLOYEE / ADD MANAGER ----------------

    /** Next EMP### id; unique across employees AND managers. */
    private String nextPersonId(Connection con) throws Exception {
        String sql = "SELECT COALESCE(MAX(n),0) FROM ("
            + "SELECT CAST(SUBSTRING(employee_id,4) AS UNSIGNED) AS n "
            + "FROM employees WHERE employee_id LIKE 'EMP%' "
            + "UNION ALL "
            + "SELECT CAST(SUBSTRING(employee_id,4) AS UNSIGNED) AS n "
            + "FROM managers WHERE employee_id LIKE 'EMP%') t";

        try (PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            rs.next();
            return String.format("EMP%03d", rs.getInt(1) + 1);
        }
    }

    private boolean emailInUse(Connection con, String email) throws Exception {
        String sql = "SELECT 1 FROM employees WHERE email=? "
            + "UNION SELECT 1 FROM managers WHERE email=? "
            + "UNION SELECT 1 FROM hr_users WHERE email=?";

        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, email);
            ps.setString(2, email);
            ps.setString(3, email);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        }
    }

    private boolean sendCredentials(String email, String name, String id,
                                    String password, String role) {
        try {
            return EmailService.sendCredentials(email, name, id, password, role);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /** "&mail=sent" or "&mail=failed&mailErr=<reason>" for the redirect URL. */
    private String mailParams(boolean mailed) {
        if (mailed) {
            return "&mail=sent";
        }
        String why = EmailService.getLastError();
        try {
            why = java.net.URLEncoder.encode(why, "UTF-8");
        } catch (Exception ignored) {
            why = "";
        }
        return "&mail=failed&mailErr=" + why;
    }

    /** Re-sends the login ID, password and link of an existing employee / manager. */
    private void resendCredentials(HttpServletRequest request,
                                   HttpServletResponse response)
            throws Exception {

        String ctx = request.getContextPath();
        String id = trim(request.getParameter("personId"));
        boolean manager = "MANAGER".equalsIgnoreCase(request.getParameter("personType"));
        String table = manager ? "managers" : "employees";

        String name = null, email = null, password = null;

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                 "SELECT name,email,password FROM " + table + " WHERE employee_id=?")) {
            ps.setString(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    name = rs.getString("name");
                    email = rs.getString("email");
                    password = rs.getString("password");
                }
            }
        }

        String back = manager
            ? ctx + "/hr?action=viewManagers&mgrMessage=resent"
            : ctx + "/hr?action=viewEmployees&empMessage=resent";
        String anchor = manager ? "#addManager" : "#viewEmployees";

        if (email == null || email.trim().isEmpty()) {
            response.sendRedirect(back + "&newId=" + id
                + "&mail=failed&mailErr=" + java.net.URLEncoder.encode("Person or email not found", "UTF-8")
                + anchor);
            return;
        }

        boolean mailed = sendCredentials(email, name, id, password,
                                         manager ? "Manager" : "Employee");

        response.sendRedirect(back + "&newId=" + id + mailParams(mailed) + anchor);
    }

    private static final String EMAIL_REGEX = "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$";

    private void addEmployee(HttpServletRequest request,
                             HttpServletResponse response)
            throws Exception {

        String ctx = request.getContextPath();

        String name = trim(request.getParameter("name"));
        String email = trim(request.getParameter("email"));
        String phone = trim(request.getParameter("phone"));
        String department = trim(request.getParameter("department"));
        String designation = trim(request.getParameter("designation"));
        String password = request.getParameter("password");
        String status = trim(request.getParameter("status"));

        double salary;
        try {
            salary = Double.parseDouble(trim(request.getParameter("salary")));
        } catch (Exception e) {
            salary = -1;
        }

        if (name.isEmpty() || !email.matches(EMAIL_REGEX)
                || department.isEmpty() || designation.isEmpty()
                || salary < 0
                || password == null || password.length() < 6) {
            response.sendRedirect(ctx + "/hr?empMessage=invalid#addEmployee");
            return;
        }

        if (!"INACTIVE".equalsIgnoreCase(status)) {
            status = "ACTIVE";
        }

        String newId;

        try (Connection con = DBcConnection.getConnection()) {

            if (emailInUse(con, email)) {
                response.sendRedirect(ctx + "/hr?empMessage=duplicate#addEmployee");
                return;
            }

            newId = nextPersonId(con);

            String sql = "INSERT INTO employees "
                + "(employee_id,name,email,phone,department,designation,"
                + "salary,password,status) VALUES (?,?,?,?,?,?,?,?,?)";

            try (PreparedStatement ps = con.prepareStatement(sql)) {
                ps.setString(1, newId);
                ps.setString(2, name);
                ps.setString(3, email);
                ps.setString(4, phone);
                ps.setString(5, department);
                ps.setString(6, designation);
                ps.setDouble(7, salary);
                ps.setString(8, password);
                ps.setString(9, status.toUpperCase());
                ps.executeUpdate();
            }

        } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
            response.sendRedirect(ctx + "/hr?empMessage=duplicate#addEmployee");
            return;
        }

        boolean mailed = sendCredentials(email, name, newId, password, "Employee");

        response.sendRedirect(ctx + "/hr?action=viewEmployees&empMessage=created"
            + "&newId=" + newId + mailParams(mailed)
            + "#viewEmployees");
    }

    private void addManager(HttpServletRequest request,
                            HttpServletResponse response)
            throws Exception {

        String ctx = request.getContextPath();

        String name = trim(request.getParameter("name"));
        String email = trim(request.getParameter("email"));
        String phone = trim(request.getParameter("phone"));
        String department = trim(request.getParameter("department"));
        String designation = trim(request.getParameter("designation"));
        String password = request.getParameter("password");
        String status = trim(request.getParameter("status"));

        if (name.isEmpty() || !email.matches(EMAIL_REGEX)
                || department.isEmpty() || designation.isEmpty()
                || password == null || password.length() < 6) {
            response.sendRedirect(ctx + "/hr?action=viewManagers&mgrMessage=invalid#addManager");
            return;
        }

        if (!"INACTIVE".equalsIgnoreCase(status)) {
            status = "ACTIVE";
        }

        String newId;

        try (Connection con = DBcConnection.getConnection()) {

            if (emailInUse(con, email)) {
                response.sendRedirect(ctx + "/hr?action=viewManagers&mgrMessage=duplicate#addManager");
                return;
            }

            newId = nextPersonId(con);

            String sql = "INSERT INTO managers "
                + "(employee_id,name,email,phone,department,designation,"
                + "status,password) VALUES (?,?,?,?,?,?,?,?)";

            try (PreparedStatement ps = con.prepareStatement(sql)) {
                ps.setString(1, newId);
                ps.setString(2, name);
                ps.setString(3, email);
                ps.setString(4, phone);
                ps.setString(5, department);
                ps.setString(6, designation);
                ps.setString(7, status.toUpperCase());
                ps.setString(8, password);
                ps.executeUpdate();
            }

        } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
            response.sendRedirect(ctx + "/hr?action=viewManagers&mgrMessage=duplicate#addManager");
            return;
        }

        boolean mailed = sendCredentials(email, name, newId, password, "Manager");

        response.sendRedirect(ctx + "/hr?action=viewManagers&mgrMessage=created"
            + "&newId=" + newId + mailParams(mailed)
            + "#addManager");
    }

    private void viewManagers(HttpServletRequest request,
                              HttpServletResponse response)
            throws Exception {

        List<String[]> list = new ArrayList<>();

        String sql = "SELECT employee_id,name,email,phone,department,"
            + "designation,status FROM managers ORDER BY employee_id";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                list.add(new String[] {
                    rs.getString("employee_id"), rs.getString("name"),
                    rs.getString("email"), rs.getString("phone"),
                    rs.getString("department"), rs.getString("designation"),
                    rs.getString("status")
                });
            }
        }

        request.setAttribute("managerList", list);
        request.setAttribute("action", "viewManagers");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    private static String trim(String v) {
        return v == null ? "" : v.trim();
    }

    // ---------------- EMPLOYEE LIST (shared by view / search) ----------------

    private List<Employe> fetchEmployees(String search) throws Exception {
        List<Employe> results = new ArrayList<>();
        String value = "%" + (search == null ? "" : search.trim()) + "%";

        String sql = "SELECT employee_id,name,email,phone,department,"
            + "designation,salary,status FROM employees "
            + "WHERE employee_id LIKE ? OR name LIKE ? "
            + "ORDER BY employee_id";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, value);
            ps.setString(2, value);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Employe emp = new Employe();
                    emp.setEmployeeId(rs.getString("employee_id"));
                    emp.setName(rs.getString("name"));
                    emp.setEmail(rs.getString("email"));
                    emp.setPhone(rs.getString("phone"));
                    emp.setDepartment(rs.getString("department"));
                    emp.setDesignation(rs.getString("designation"));
                    emp.setSalary(rs.getDouble("salary"));
                    emp.setStatus(rs.getString("status"));
                    results.add(emp);
                }
            }
        }
        return results;
    }

    private void viewEmployees(HttpServletRequest request,
                               HttpServletResponse response)
            throws Exception {

        request.setAttribute("employeeList", fetchEmployees(""));
        request.setAttribute("action", "viewEmployees");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }


    // =====================================================================
    //  MY ATTENDANCE & LEAVES  (HR is an employee of the admin)
    //  Same rules as the employee dashboard, but stored in HR's own tables:
    //  hr_attendance, hr_breaks (max 2 a day) and hr_leave_requests.
    // =====================================================================

    private String currentHrId(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        Object id = session == null ? null : session.getAttribute("hrId");
        if (id == null || id.toString().trim().isEmpty()) {
            throw new IllegalStateException("HR id not found in session. Please log in again.");
        }
        return id.toString();
    }

    private void handleMyAction(HttpServletRequest request,
                                HttpServletResponse response,
                                String action)
            throws Exception {

        String ctx = request.getContextPath();
        String code;

        try {
            String hrId = currentHrId(request);

            switch (action) {
                case "myCheckIn":    code = myCheckIn(hrId); break;
                case "myCheckOut":   code = myCheckOut(hrId); break;
                case "myStartBreak": code = myStartBreak(hrId); break;
                case "myEndBreak":   code = myEndBreak(hrId); break;
                case "myApplyLeave": code = myApplyLeave(request, hrId); break;
                default:
                    response.sendRedirect(ctx + "/hr");
                    return;
            }

        } catch (Exception e) {
            // show the real reason on the page instead of a silent failure
            e.printStackTrace();
            Throwable root = e;
            while (root.getCause() != null) root = root.getCause();

            HttpSession session = request.getSession(false);
            if (session != null) {
                session.setAttribute("hrFlashError", root.getClass().getSimpleName() + ": " + root.getMessage());
            }
            code = "error";
        }

        String target = "myApplyLeave".equals(action) ? "myLeaves" : "myAttendance";

        response.sendRedirect(ctx + "/hr?action=myAttendance&myMsg=" + code + "#" + target);
    }

    private boolean onApprovedLeave(Connection con, String id) throws Exception {
        String sql = "SELECT COUNT(*) FROM hr_leave_requests WHERE hr_id=? "
            + "AND status='APPROVED' AND CURDATE() BETWEEN from_date AND to_date";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) > 0;
            }
        }
    }

    /** Today's attendance row: {checkIn, checkOut} or null when there is none. */
    private Time[] todayTimes(Connection con, String id) throws Exception {
        String sql = "SELECT check_in_time,check_out_time FROM hr_attendance "
            + "WHERE hr_id=? AND att_date=CURDATE()";
        try (PreparedStatement ps = con.prepareStatement(sql)) {
            ps.setString(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) return null;
                return new Time[] { rs.getTime(1), rs.getTime(2) };
            }
        }
    }

    private String myCheckIn(String id) throws Exception {
        try (Connection con = DBcConnection.getConnection()) {
            if (onApprovedLeave(con, id)) return "onLeave";
            if (todayTimes(con, id) != null) return "alreadyIn";

            try (PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO hr_attendance (hr_id,att_date,check_in_time,status) "
                    + "VALUES (?,CURDATE(),CURTIME(),'PRESENT')")) {
                ps.setString(1, id);
                ps.executeUpdate();
            }
            return "checkedIn";
        }
    }

    private String myCheckOut(String id) throws Exception {
        try (Connection con = DBcConnection.getConnection()) {
            Time[] t = todayTimes(con, id);

            if (t == null || t[0] == null) return "notCheckedIn";
            if (t[1] != null) return "alreadyOut";

            long worked = java.time.Duration.between(
                t[0].toLocalTime(), java.time.LocalTime.now()).toMinutes();

            // same thresholds as the employee dashboard
            String status = worked >= 480 ? "PRESENT"
                          : worked > 240 ? "HALF DAY" : "ABSENT";

            try (PreparedStatement ps = con.prepareStatement(
                    "UPDATE hr_attendance SET check_out_time=CURTIME(),status=? "
                    + "WHERE hr_id=? AND att_date=CURDATE()")) {
                ps.setString(1, status);
                ps.setString(2, id);
                ps.executeUpdate();
            }
            return "checkedOut";
        }
    }

    private String myStartBreak(String id) throws Exception {
        try (Connection con = DBcConnection.getConnection()) {
            if (onApprovedLeave(con, id)) return "onLeave";

            Time[] t = todayTimes(con, id);
            if (t == null || t[0] == null) return "notCheckedIn";
            if (t[1] != null) return "alreadyOut";

            int count = 0;
            boolean running = false;

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT COUNT(*), COALESCE(SUM(break_end IS NULL),0) FROM hr_breaks "
                    + "WHERE hr_id=? AND break_date=CURDATE()")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        count = rs.getInt(1);
                        running = rs.getInt(2) > 0;
                    }
                }
            }

            if (count >= 2) return "breakLimit";
            if (running) return "breakRunning";

            try (PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO hr_breaks (hr_id,break_number,break_date,break_start) "
                    + "VALUES (?,?,CURDATE(),CURTIME())")) {
                ps.setString(1, id);
                ps.setInt(2, count + 1);
                ps.executeUpdate();
            }
            return "breakStarted";
        }
    }

    private String myEndBreak(String id) throws Exception {
        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                "UPDATE hr_breaks SET break_end=CURTIME() "
                + "WHERE hr_id=? AND break_date=CURDATE() "
                + "AND break_end IS NULL ORDER BY break_number DESC LIMIT 1")) {
            ps.setString(1, id);
            return ps.executeUpdate() > 0 ? "breakEnded" : "noBreak";
        }
    }

    private String myApplyLeave(HttpServletRequest request, String id)
            throws Exception {

        String type = trim(request.getParameter("leaveType")).toUpperCase();
        String reason = trim(request.getParameter("reason"));

        LocalDate from;
        LocalDate to;
        try {
            from = LocalDate.parse(trim(request.getParameter("fromDate")));
            to = LocalDate.parse(trim(request.getParameter("toDate")));
        } catch (Exception e) {
            return "leaveInvalid";
        }

        if (!("CASUAL".equals(type) || "SICK".equals(type) || "PERSONAL".equals(type))
                || reason.isEmpty() || to.isBefore(from)) {
            return "leaveInvalid";
        }
        if (reason.length() > 500) {
            reason = reason.substring(0, 500);
        }

        try (Connection con = DBcConnection.getConnection()) {

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT COUNT(*) FROM hr_leave_requests "
                    + "WHERE hr_id=? AND status='PENDING'")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next() && rs.getInt(1) > 0) return "leavePending";
                }
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO hr_leave_requests "
                    + "(hr_id,leave_type,from_date,to_date,reason,status,applied_date) "
                    + "VALUES (?,?,?,?,?,'PENDING',CURDATE())")) {
                ps.setString(1, id);
                ps.setString(2, type);
                ps.setDate(3, Date.valueOf(from));
                ps.setDate(4, Date.valueOf(to));
                ps.setString(5, reason);
                ps.executeUpdate();
            }
        }
        return "leaveApplied";
    }

    private void loadMyAttendance(HttpServletRequest request,
                                  HttpServletResponse response)
            throws Exception {

        String id = currentHrId(request);

        List<String[]> breaks = new ArrayList<>();
        List<String[]> history = new ArrayList<>();
        List<LeaveData> leaves = new ArrayList<>();

        String in = null, out = null, status = "ABSENT";
        boolean hasIn = false, hasOut = false, onLeave;

        try (Connection con = DBcConnection.getConnection()) {

            onLeave = onApprovedLeave(con, id);

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT check_in_time,check_out_time,status FROM hr_attendance "
                    + "WHERE hr_id=? AND att_date=CURDATE()")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        in = rs.getString("check_in_time");
                        out = rs.getString("check_out_time");
                        status = rs.getString("status");
                        hasIn = in != null && !in.trim().isEmpty();
                        hasOut = out != null && !out.trim().isEmpty();
                    }
                }
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT break_number,break_start,break_end FROM hr_breaks "
                    + "WHERE hr_id=? AND break_date=CURDATE() ORDER BY break_number")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        breaks.add(new String[] {
                            String.valueOf(rs.getInt("break_number")),
                            rs.getString("break_start"), rs.getString("break_end")
                        });
                    }
                }
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT att_date,check_in_time,check_out_time,status FROM hr_attendance "
                    + "WHERE hr_id=? AND att_date>=CURDATE()-INTERVAL 30 DAY "
                    + "ORDER BY att_date DESC")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        history.add(new String[] {
                            String.valueOf(rs.getDate("att_date")),
                            rs.getString("check_in_time"),
                            rs.getString("check_out_time"),
                            rs.getString("status")
                        });
                    }
                }
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT leave_id,leave_type,from_date,to_date,reason,status,applied_date "
                    + "FROM hr_leave_requests WHERE hr_id=? ORDER BY leave_id DESC")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        LeaveData d = new LeaveData();
                        d.leaveId = rs.getString("leave_id");
                        d.employeeId = id;
                        d.leaveType = rs.getString("leave_type");
                        d.fromDate = String.valueOf(rs.getDate("from_date"));
                        d.toDate = String.valueOf(rs.getDate("to_date"));
                        d.reason = rs.getString("reason");
                        d.status = rs.getString("status");
                        d.appliedDate = String.valueOf(rs.getDate("applied_date"));
                        leaves.add(d);
                    }
                }
            }
        }

        request.setAttribute("myIn", in);
        request.setAttribute("myOut", out);
        request.setAttribute("myStatus", status);
        request.setAttribute("myHasIn", hasIn);
        request.setAttribute("myHasOut", hasOut);
        request.setAttribute("myOnLeave", onLeave);
        request.setAttribute("myBreaks", breaks);
        request.setAttribute("myHistory", history);
        request.setAttribute("myLeaves", leaves);
        request.setAttribute("action", "myAttendance");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    // ---------------- EMPLOYEE SEARCH ----------------

    private void searchEmployee(HttpServletRequest request,
                                HttpServletResponse response)
            throws Exception {

        List<Employe> results = new ArrayList<>();

        String search = request.getParameter("search");
        String value = "%" + (search == null ? "" : search.trim()) + "%";

        String sql = "SELECT employee_id,name,email,phone,department,"
            + "designation,salary,status FROM employees "
            + "WHERE employee_id LIKE ? OR name LIKE ? "
            + "ORDER BY employee_id";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, value);
            ps.setString(2, value);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Employe emp = new Employe();

                    emp.setEmployeeId(rs.getString("employee_id"));
                    emp.setName(rs.getString("name"));
                    emp.setEmail(rs.getString("email"));
                    emp.setPhone(rs.getString("phone"));
                    emp.setDepartment(rs.getString("department"));
                    emp.setDesignation(rs.getString("designation"));
                    emp.setSalary(rs.getDouble("salary"));
                    emp.setStatus(rs.getString("status"));

                    results.add(emp);
                }
            }
        }

        request.setAttribute("searchResults", results);
        request.setAttribute("action", "searchEmployee");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    // ---------------- ATTENDANCE PAGE ----------------

    private void attendanceReport(HttpServletRequest request,
                                  HttpServletResponse response,
                                  boolean today)
            throws Exception {

        List<AttendanceData> list = new ArrayList<>();

        String sql;

        if (today) {
            sql = "SELECT a.employee_id,COALESCE(e.name,m.name) AS person_name,a.date,"
                + "a.check_in_time,a.check_out_time,a.status "
                + "FROM attendance a "
                + "LEFT JOIN employees e ON e.employee_id=a.employee_id "
                + "LEFT JOIN managers m ON m.employee_id=a.employee_id "
                + "WHERE a.date=CURDATE() ORDER BY a.employee_id";
        } else {
            sql = "SELECT a.employee_id,COALESCE(e.name,m.name) AS person_name,a.date,"
                + "a.check_in_time,a.check_out_time,a.status "
                + "FROM attendance a "
                + "LEFT JOIN employees e ON e.employee_id=a.employee_id "
                + "LEFT JOIN managers m ON m.employee_id=a.employee_id "
                + "WHERE MONTH(a.date)=MONTH(CURDATE()) AND YEAR(a.date)=YEAR(CURDATE()) "
                + "ORDER BY a.employee_id,a.date";
        }

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                AttendanceData data = new AttendanceData();

                data.employeeId = rs.getString("employee_id");
                data.name = rs.getString("person_name") == null ? "" : rs.getString("person_name");
                data.date = String.valueOf(rs.getDate("date"));

                Time in = rs.getTime("check_in_time");
                Time out = rs.getTime("check_out_time");

                data.checkIn = in == null ? "-" : in.toString();
                data.checkOut = out == null ? "-" : out.toString();
                data.status = rs.getString("status");

                list.add(data);
            }
        }

        request.setAttribute("attendanceData", list);
        request.setAttribute(
            "action", today ? "todayAttendance" : "monthlyAttendance"
        );

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    // ---------------- LEAVES ----------------

    private void viewLeaves(HttpServletRequest request,
                            HttpServletResponse response)
            throws Exception {

        List<LeaveData> list = new ArrayList<>();

        // HR's own leave is kept in hr_leave_requests (approved by the admin).
        String sql = "SELECT l.leave_id,l.employee_id,"
            + "COALESCE(e.name,m.name) AS person_name,l.leave_type,l.from_date,"
            + "l.to_date,l.reason,l.status,l.applied_date FROM leave_requests l "
            + "LEFT JOIN employees e ON e.employee_id=l.employee_id "
            + "LEFT JOIN managers m ON m.employee_id=l.employee_id "
            + "ORDER BY l.applied_date DESC, l.leave_id DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                LeaveData d = new LeaveData();

                d.leaveId = rs.getString("leave_id");
                d.employeeId = rs.getString("employee_id");
                d.name = rs.getString("person_name");
                d.leaveType = rs.getString("leave_type");
                d.fromDate = String.valueOf(rs.getDate("from_date"));
                d.toDate = String.valueOf(rs.getDate("to_date"));
                d.reason = rs.getString("reason");
                d.status = rs.getString("status");
                d.appliedDate = String.valueOf(
                    rs.getTimestamp("applied_date")
                );

                list.add(d);
            }
        }

        request.setAttribute("leaveData", list);
        request.setAttribute("action", "viewLeaves");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    private void updateLeaveStatus(String leaveId, String status)
            throws Exception {

        String sql = "UPDATE leave_requests SET status=? WHERE leave_id=?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, status);
            ps.setString(2, leaveId);
            ps.executeUpdate();
        }
    }

    // ---------------- TASK MANAGEMENT ----------------

    private void loadTasks(HttpServletRequest request,
                           HttpServletResponse response)
            throws ServletException, IOException {

        List<Task> allTasks = taskDAO.getAllTasks();
        List<Task> filtered = new ArrayList<>();

        String search = request.getParameter("search");
        String statusFilter = request.getParameter("status");
        String editId = request.getParameter("editId");

        int pending = 0;
        int progress = 0;
        int completed = 0;

        for (Task task : allTasks) {
            String status = task.getStatus();

            if ("PENDING".equalsIgnoreCase(status)) pending++;
            if ("IN_PROGRESS".equalsIgnoreCase(status)) progress++;
            if ("COMPLETED".equalsIgnoreCase(status)) completed++;

            boolean matchSearch =
                search == null || search.trim().isEmpty()
                || contains(task.getTaskTitle(), search)
                || contains(task.getAssignedTo(), search)
                || contains(task.getDepartment(), search)
                || contains(task.getDescription(), search);

            boolean matchStatus =
                statusFilter == null
                || statusFilter.trim().isEmpty()
                || "ALL".equalsIgnoreCase(statusFilter)
                || statusFilter.equalsIgnoreCase(status);

            if (matchSearch && matchStatus) {
                filtered.add(task);
            }
        }

        Task editTask = null;

        if (editId != null && !editId.trim().isEmpty()) {
            try {
                editTask = taskDAO.getTaskById(Integer.parseInt(editId));
            } catch (NumberFormatException ignored) {
                editTask = null;
            }
        }

        request.setAttribute("tasks", filtered);
        request.setAttribute("editTask", editTask);
        request.setAttribute("taskCount", allTasks.size());
        request.setAttribute("pendingCount", pending);
        request.setAttribute("inProgressCount", progress);
        request.setAttribute("completedCount", completed);
        request.setAttribute("taskSearch", search == null ? "" : search);
        request.setAttribute(
            "taskStatusFilter",
            statusFilter == null ? "ALL" : statusFilter
        );
        request.setAttribute("action", "taskManagement");

        try {
            loadDashboardCounts(request);
        } catch (Exception e) {
            e.printStackTrace();
        }

        forwardDashboard(request, response);
    }

    private boolean contains(String value, String search) {
        return value != null
            && value.toLowerCase().contains(search.trim().toLowerCase());
    }

    private String validateTask(String title, String assignedTo,
                                String priority, String startDate,
                                String dueDate, String description) {

        if (title == null || title.trim().isEmpty()) {
            return "Task title is required.";
        }

        if (assignedTo == null || assignedTo.trim().isEmpty()) {
            return "Please select an employee.";
        }

        if (priority == null || priority.trim().isEmpty()) {
            return "Please select task priority.";
        }

        if (startDate == null || startDate.trim().isEmpty()) {
            return "Start date is required.";
        }

        if (dueDate == null || dueDate.trim().isEmpty()) {
            return "Due date is required.";
        }

        if (description != null && description.length() > 1000) {
            return "Description cannot exceed 1000 characters.";
        }

        try {
            if (Date.valueOf(dueDate).before(Date.valueOf(startDate))) {
                return "Due date cannot be before start date.";
            }
        } catch (IllegalArgumentException e) {
            return "Please enter valid start and due dates.";
        }

        return null;
    }

    private void createTask(HttpServletRequest request,
                            HttpServletResponse response)
            throws Exception {

        String title = request.getParameter("taskTitle");
        String assigned = request.getParameter("assignedTo");
        String priority = request.getParameter("priority");
        String start = request.getParameter("startDate");
        String due = request.getParameter("dueDate");
        String description = request.getParameter("description");

        String error = validateTask(
            title, assigned, priority, start, due, description
        );

        if (error != null) {
            request.setAttribute("taskError", error);
            loadTasks(request, response);
            return;
        }

        Task task = new Task();

        task.setTaskTitle(title.trim());
        task.setAssignedTo(assigned);
        task.setPriority(priority);
        task.setStartDate(Date.valueOf(start));
        task.setDueDate(Date.valueOf(due));
        task.setDescription(description);
        task.setDepartment(request.getParameter("department"));

        String status = request.getParameter("status");

        task.setStatus(
            status == null || status.trim().isEmpty()
                ? "PENDING" : status
        );

        HttpSession session = request.getSession(false);
        Object creator = session == null
            ? null : session.getAttribute("employeeId");

        if (creator == null && session != null) {
            creator = session.getAttribute("hrId");
        }

        if (creator == null && session != null) {
            creator = session.getAttribute("hrEmail");
        }

        task.setCreatedBy(creator == null ? null : creator.toString());

        boolean saved = taskDAO.addTask(task);

        response.sendRedirect(
            request.getContextPath() + "/hr?taskMessage="
            + (saved ? "created" : "createFailed") + "#taskManagement"
        );
    }

    private void updateTask(HttpServletRequest request,
                            HttpServletResponse response)
            throws Exception {

        int id;

        try {
            id = Integer.parseInt(request.getParameter("id"));
        } catch (Exception e) {
            request.setAttribute("taskError", "Invalid task ID.");
            loadTasks(request, response);
            return;
        }

        Task task = taskDAO.getTaskById(id);

        if (task == null) {
            request.setAttribute("taskError", "Task was not found.");
            loadTasks(request, response);
            return;
        }

        String title = request.getParameter("taskTitle");
        String assigned = request.getParameter("assignedTo");
        String priority = request.getParameter("priority");
        String start = request.getParameter("startDate");
        String due = request.getParameter("dueDate");
        String description = request.getParameter("description");

        String error = validateTask(
            title, assigned, priority, start, due, description
        );

        if (error != null) {
            request.setAttribute("taskError", error);
            loadTasks(request, response);
            return;
        }

        task.setTaskTitle(title.trim());
        task.setAssignedTo(assigned);
        task.setPriority(priority);
        task.setStartDate(Date.valueOf(start));
        task.setDueDate(Date.valueOf(due));
        task.setDescription(description);
        task.setDepartment(request.getParameter("department"));

        String status = request.getParameter("status");

        task.setStatus(
            status == null || status.trim().isEmpty()
                ? "PENDING" : status
        );

        boolean updated = taskDAO.updateTask(task);

        response.sendRedirect(
            request.getContextPath() + "/hr?taskMessage="
            + (updated ? "updated" : "updateFailed") + "#taskManagement"
        );
    }

    private void deleteTask(HttpServletRequest request,
                            HttpServletResponse response)
            throws Exception {

        int id = Integer.parseInt(request.getParameter("id"));
        boolean deleted = taskDAO.deleteTask(id);

        response.sendRedirect(
            request.getContextPath() + "/hr?taskMessage="
            + (deleted ? "deleted" : "deleteFailed") + "#taskManagement"
        );
    }

    // ---------------- PAYROLL MODULE ----------------

    private int payrollIntParam(HttpServletRequest request, String name,
                                int fallback, int min, int max) {
        try {
            String v = request.getParameter(name);
            if (v != null && !v.trim().isEmpty()) {
                int parsed = Integer.parseInt(v.trim());
                if (parsed >= min && parsed <= max) {
                    return parsed;
                }
            }
        } catch (NumberFormatException ignored) {
        }
        return fallback;
    }

    private String payrollText(HttpServletRequest request, String name, int max) {
        String v = request.getParameter(name);
        if (v == null) return "";
        v = v.trim();
        return v.length() > max ? v.substring(0, max) : v;
    }

    /**
     * Payroll Operations Hub, rendered inside the admin dashboard.
     * tab = structures | process | history (default: process)
     */
    private void loadPayroll(HttpServletRequest request,
                             HttpServletResponse response)
            throws Exception {

        LocalDate now = LocalDate.now();
        int month = payrollIntParam(request, "month", now.getMonthValue(), 1, 12);
        int year = payrollIntParam(request, "year", now.getYear(), 2000, 9999);

        String tab = request.getParameter("tab");
        if (!("structures".equals(tab) || "process".equals(tab) || "history".equals(tab))) {
            tab = "process";
        }

        PayrollDAO payrollDAO = new PayrollDAO();
        service.PayrollService payrollService = new service.PayrollService();

        // Show filter: All / Managers / Employees (remembered in the session)
        String personType;
        String typeParam = request.getParameter("personType");
        if (typeParam != null) {
            personType = PayrollDAO.normalizeType(typeParam);
            request.getSession().setAttribute("payrollPersonType", personType);
        } else {
            Object savedType = request.getSession().getAttribute("payrollPersonType");
            personType = PayrollDAO.normalizeType(
                    savedType == null ? null : String.valueOf(savedType));
        }
        request.setAttribute("payrollPersonType", personType);

        // Automatic payroll follows the saved schedule (PayrollScheduler), not page loads.

        request.setAttribute("payrollTab", tab);
        request.setAttribute("payrollMonth", month);
        request.setAttribute("payrollYear", year);
        request.setAttribute("payrollCsrf",
                PayrollServlet.csrfToken(request.getSession()));

        try {
            DAO.SalaryStructureDAO structureDAO = new DAO.SalaryStructureDAO();
            request.setAttribute("payrollActiveStructures",
                    structureDAO.countActiveStructures());
            request.setAttribute("payrollEligibleCount",
                    payrollDAO.getEligibleEmployees().size());
            request.setAttribute("payrollSchedule", new DAO.PayrollSettingsDAO().get());

            if ("structures".equals(tab)) {
                List<model.SalaryStructure> structures =
                        new ArrayList<>(structureDAO.getStructureOverview());
                // hard-coded: hide structures that ended before 1 Oct 2026
                structures.removeIf(st -> st.getEffectiveTo() != null
                        && st.getEffectiveTo().isBefore(PAYROLL_CUTOFF));
                DAO.SalaryComponentDAO componentDAO = new DAO.SalaryComponentDAO();
                java.util.Map<Integer, List<model.SalaryComponent>> components =
                        new java.util.HashMap<>();
                for (model.SalaryStructure st : structures) {
                    components.put(st.getId(),
                            componentDAO.getComponentsByStructureId(st.getId()));
                }
                request.setAttribute("payrollStructures", structures);
                request.setAttribute("payrollComponents", components);
                request.setAttribute("payrollEmployees", payrollDAO.getEligibleEmployees());

            } else if ("process".equals(tab)) {
                request.setAttribute("payrollPreview",
                        payrollService.previewPayroll(month, year, personType));

            } else {
                int hMonth = payrollIntParam(request, "histMonth", 0, 0, 12);
                int hYear = payrollIntParam(request, "histYear", 0, 0, 9999);
                if (hYear != 0 && hYear < 2000) hYear = 0;
                String dept = payrollText(request, "dept", 100);
                String status = payrollText(request, "status", 20).toUpperCase();
                String empId = payrollText(request, "empId", 40);

                List<Payroll> list = payrollFromCutoff(
                        payrollDAO.searchPayroll(hMonth, hYear, dept, status, empId, personType));
                request.setAttribute("payrollList", list);
                setPayrollTotals(request, list);
                request.setAttribute("payrollDepartments", payrollDAO.getDepartments());
                request.setAttribute("histMonth", hMonth);
                request.setAttribute("histYear", hYear);
                request.setAttribute("histDept", dept);
                request.setAttribute("histStatus", status);
                request.setAttribute("histEmp", empId);
            }

        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("payrollError",
                    "Unable to load payroll data. Check the database tables and connection.");
        }

        request.setAttribute("action", "payroll");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    /**
     * HARD-CODED CUT-OFF: payroll / salary-structure records older than this month
     * (before October 2026) are not shown anywhere in the admin payroll screens.
     */
    private static final LocalDate PAYROLL_CUTOFF = LocalDate.of(2026, 10, 1);

    private static List<Payroll> payrollFromCutoff(List<Payroll> in) {
        List<Payroll> out = new ArrayList<>();
        if (in == null) return out;
        int min = PAYROLL_CUTOFF.getYear() * 100 + PAYROLL_CUTOFF.getMonthValue();
        for (Payroll p : in) {
            if (p.getPayrollYear() * 100 + p.getPayrollMonth() >= min) out.add(p);
        }
        return out;
    }

    private void setPayrollTotals(HttpServletRequest request, List<Payroll> list) {

        java.math.BigDecimal gross = java.math.BigDecimal.ZERO;
        java.math.BigDecimal deductions = java.math.BigDecimal.ZERO;
        java.math.BigDecimal net = java.math.BigDecimal.ZERO;
        int pending = 0, paid = 0;

        for (Payroll p : list) {
            String st = p.getStatus() == null ? "" : p.getStatus().toUpperCase();

            if ("CANCELLED".equals(st)) {
                continue; // cancelled payroll is not part of the totals
            }

            if (p.getGrossSalary() != null) gross = gross.add(p.getGrossSalary());
            if (p.getTotalDeductions() != null) deductions = deductions.add(p.getTotalDeductions());
            if (p.getNetSalary() != null) net = net.add(p.getNetSalary());

            if ("PAID".equals(st)) paid++;
            else pending++;
        }

        request.setAttribute("payrollGross", gross);
        request.setAttribute("payrollDeductions", deductions);
        request.setAttribute("payrollNet", net);
        request.setAttribute("payrollPendingCount", pending);
        request.setAttribute("payrollPaidCount", paid);
    }

    private static String payrollCsvCell(Object value) {
        String v = value == null ? "" : String.valueOf(value);
        // stop spreadsheet formula injection
        if (!v.isEmpty() && "=+-@".indexOf(v.charAt(0)) >= 0) {
            v = "'" + v;
        }
        return "\"" + v.replace("\"", "\"\"") + "\"";
    }

    /** Download (CSV) of the payroll report, using the same filters as the History tab. */
    private void payrollCsv(HttpServletRequest request,
                            HttpServletResponse response)
            throws IOException {

        int hMonth = payrollIntParam(request, "histMonth", 0, 0, 12);
        int hYear = payrollIntParam(request, "histYear", 0, 0, 9999);
        if (hYear != 0 && hYear < 2000) hYear = 0;

        try {
            List<Payroll> list = payrollFromCutoff(new PayrollDAO().searchPayroll(
                    hMonth, hYear,
                    payrollText(request, "dept", 100),
                    payrollText(request, "status", 20),
                    payrollText(request, "empId", 40),
                    payrollText(request, "personType", 20)));

            StringBuilder sb = new StringBuilder();
            sb.append("Employee ID,Name,Department,Month,Year,Basic Salary,Gross Salary,")
              .append("Total Deductions,Net Salary,Status,Amount Paid,Processed By,Processed At\r\n");

            for (Payroll p : list) {
                sb.append(payrollCsvCell(p.getEmployeeId())).append(',')
                  .append(payrollCsvCell(p.getEmployeeName())).append(',')
                  .append(payrollCsvCell(p.getDepartment())).append(',')
                  .append(p.getPayrollMonth()).append(',')
                  .append(p.getPayrollYear()).append(',')
                  .append(payrollCsvCell(p.getBasicSalary())).append(',')
                  .append(payrollCsvCell(p.getGrossSalary())).append(',')
                  .append(payrollCsvCell(p.getTotalDeductions())).append(',')
                  .append(payrollCsvCell(p.getNetSalary())).append(',')
                  .append(payrollCsvCell(p.getStatus())).append(',')
                  .append(payrollCsvCell(p.getPaidAmount())).append(',')
                  .append(payrollCsvCell(p.getProcessedBy())).append(',')
                  .append(payrollCsvCell(p.getProcessedAt())).append("\r\n");
            }

            response.setContentType("text/csv; charset=UTF-8");
            response.setCharacterEncoding("UTF-8");
            response.setHeader("Content-Disposition",
                "attachment; filename=\"payroll_report.csv\"");
            response.getWriter().write(sb.toString());

        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                "Unable to generate the payroll report");
        }
    }

    /** Printable salary slip (only for processed / paid payroll). */
    private void salarySlip(HttpServletRequest request,
                            HttpServletResponse response)
            throws IOException {

        int payrollId = payrollIntParam(request, "payrollId", 0, 1, Integer.MAX_VALUE);

        if (payrollId == 0) {
            response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid payroll ID");
            return;
        }

        try {
            PayrollDAO payrollDAO = new PayrollDAO();
            Payroll p = payrollDAO.getPayrollDetailById(payrollId);

            if (p == null) {
                response.sendError(HttpServletResponse.SC_NOT_FOUND, "Payroll record not found");
                return;
            }

            String st = p.getStatus() == null ? "" : p.getStatus().toUpperCase();
            if (!("PROCESSED".equals(st) || "PAID".equals(st))) {
                response.sendError(HttpServletResponse.SC_BAD_REQUEST,
                    "A salary slip is available only after the payroll is processed");
                return;
            }

            model.SalaryStructure structure =
                new DAO.SalaryStructureDAO().getStructureForPayroll(
                    p.getEmployeeId(),
                    Date.valueOf(java.time.YearMonth.of(
                        p.getPayrollYear(), p.getPayrollMonth()).atEndOfMonth()));

            List<model.SalaryComponent> components = structure == null
                ? new ArrayList<model.SalaryComponent>()
                : new DAO.SalaryComponentDAO().getComponentsByStructureId(structure.getId());

            service.PayrollService.AttendanceSummary attendance = null;
            try {
                attendance = new service.PayrollService().getAttendanceSummary(
                    p.getEmployeeId(), p.getPayrollMonth(), p.getPayrollYear());
            } catch (Exception ignored) {
            }

            List<model.PayrollPayment> payments =
                new DAO.PayrollPaymentDAO().getPaymentsByPayrollId(payrollId);

            response.setContentType("text/html; charset=UTF-8");
            response.setCharacterEncoding("UTF-8");
            response.getWriter().write(
                service.SalarySlipHtml.render(p, components, attendance, payments));

        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                "Unable to generate the salary slip");
        }
    }

    /** HR presses "Email" on a PAID payroll: (re)sends the salary slip to the person's mail. */
    private void emailSlip(HttpServletRequest request,
                           HttpServletResponse response)
            throws IOException {

        int payrollId = payrollIntParam(request, "payrollId", 0, 1, Integer.MAX_VALUE);

        String msg;
        boolean ok;

        if (payrollId == 0) {
            ok = false;
            msg = "Invalid payroll ID.";
        } else {
            try {
                service.SalarySlipMailer.Result r =
                        service.SalarySlipMailer.send(payrollId, true);
                ok = r.sent;
                msg = r.message;
            } catch (Exception e) {
                e.printStackTrace();
                ok = false;
                msg = "Unable to email the salary slip.";
            }
        }

        String safe = msg.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");

        response.setContentType("text/html; charset=UTF-8");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(
            "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>Email salary slip</title></head>"
            + "<body style=\"font-family:Segoe UI,Arial,sans-serif;background:#eef2f7;display:flex;"
            + "align-items:center;justify-content:center;height:100vh;margin:0\">"
            + "<div style=\"background:#fff;padding:28px 34px;border-radius:12px;max-width:460px;"
            + "border:1px solid #dbe3ee;text-align:center\">"
            + "<h2 style=\"margin:0 0 10px;color:" + (ok ? "#166534" : "#b91c1c") + "\">"
            + (ok ? "&#10004; Done" : "&#10008; Not sent") + "</h2>"
            + "<p style=\"color:#334155\">" + safe + "</p>"
            + "<button onclick=\"window.close()\" style=\"border:0;background:#2563eb;color:#fff;"
            + "padding:9px 18px;border-radius:8px;font-weight:600;cursor:pointer\">Close</button>"
            + "</div></body></html>");
    }

    // ---------------- REPORTS MODULE ----------------

    private void loadReports(HttpServletRequest request,
                             HttpServletResponse response)
            throws Exception {

        String reportType = request.getParameter("reportType");
        String fromDate = request.getParameter("fromDate");
        String toDate = request.getParameter("toDate");
        String reportSearch = request.getParameter("reportSearch");
        String personType = request.getParameter("personType");
        String attendanceStatus = request.getParameter("attendanceStatus");

        // The admin Reports page now only lists all employees and managers;
        // each person's full report opens when they are clicked.
        reportType = "employees";

        // Search by name / ID (e-mail also matches)
        reportSearch = reportSearch == null ? "" : reportSearch.trim();
        if (reportSearch.length() > 60) {
            reportSearch = reportSearch.substring(0, 60);
        }

        // Only filter: All / Employees only / Managers only
        if (personType == null
                || !(personType.equalsIgnoreCase("EMPLOYEE")
                  || personType.equalsIgnoreCase("MANAGER"))) {
            personType = "ALL";
        } else {
            personType = personType.toUpperCase();
        }

        if (attendanceStatus == null || attendanceStatus.trim().isEmpty()) {
            attendanceStatus = "ALL";
        }

        request.setAttribute("reportType", reportType);
        request.setAttribute("fromDate", fromDate == null ? "" : fromDate);
        request.setAttribute("toDate", toDate == null ? "" : toDate);
        request.setAttribute("reportSearch", reportSearch);
        request.setAttribute("personType", personType);
        request.setAttribute("attendanceStatus", attendanceStatus);

        List<ReportRow> rows = new ArrayList<>();
        int reportTotal = 0;

        try (Connection con = DBcConnection.getConnection()) {

            switch (reportType) {

                // Employee and manager details only.
                case "employees": {
                    loadPeopleDetailsRows(
                        con, rows, reportSearch, personType
                    );
                    break;
                }

                // Attendance report remains separate.
                case "attendance": {
                    loadPeopleAttendanceRows(
                        con,
                        rows,
                        fromDate,
                        toDate,
                        reportSearch,
                        personType,
                        attendanceStatus,
                        false
                    );
                    break;
                }

                case "tasks": {
                    String sql =
                        "SELECT id,task_title,assigned_to,department,"
                        + "priority,start_date,due_date,status FROM tasks "
                        + "WHERE (? IS NULL OR start_date >= ?) "
                        + "AND (? IS NULL OR start_date <= ?) "
                        + "ORDER BY start_date DESC";

                    try (PreparedStatement ps = con.prepareStatement(sql)) {
                        setDateFilter(ps, fromDate, 1, 2);
                        setDateFilter(ps, toDate, 3, 4);

                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                ReportRow r = new ReportRow();

                                r.one = String.valueOf(rs.getInt("id"));
                                r.two = rs.getString("task_title");
                                r.three = rs.getString("assigned_to");
                                r.four = rs.getString("department");
                                r.five = rs.getString("priority");
                                r.six = String.valueOf(rs.getDate("start_date"));
                                r.seven = String.valueOf(rs.getDate("due_date"));
                                r.eight = rs.getString("status");

                                rows.add(r);
                            }
                        }
                    }
                    break;
                }

                case "leaves": {
                    String sql =
                        "SELECT leave_id,employee_id,leave_type,from_date,"
                        + "to_date,reason,status,applied_date "
                        + "FROM leave_requests "
                        + "WHERE (? IS NULL OR DATE(applied_date) >= ?) "
                        + "AND (? IS NULL OR DATE(applied_date) <= ?) "
                        + "ORDER BY applied_date DESC";

                    try (PreparedStatement ps = con.prepareStatement(sql)) {
                        setDateFilter(ps, fromDate, 1, 2);
                        setDateFilter(ps, toDate, 3, 4);

                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                ReportRow r = new ReportRow();

                                r.one = rs.getString("leave_id");
                                r.two = rs.getString("employee_id");
                                r.three = rs.getString("leave_type");
                                r.four = String.valueOf(rs.getDate("from_date"));
                                r.five = String.valueOf(rs.getDate("to_date"));
                                r.six = rs.getString("reason");
                                r.seven = rs.getString("status");
                                r.eight = String.valueOf(
                                    rs.getTimestamp("applied_date")
                                );

                                rows.add(r);
                            }
                        }
                    }
                    break;
                }

                case "teams": {
                    String sql =
                        "SELECT t.team_id,t.team_name,t.department,"
                        + "t.manager_id,COALESCE(m.name,'Not assigned') "
                        + "AS manager_name,t.status,"
                        + "COUNT(DISTINCT tm.employee_id) AS member_count "
                        + "FROM teams t "
                        + "LEFT JOIN managers m ON m.employee_id=t.manager_id "
                        + "LEFT JOIN team_members tm ON tm.team_id=t.team_id "
                        + "GROUP BY t.team_id,t.team_name,t.department,"
                        + "t.manager_id,m.name,t.status ORDER BY t.team_id";

                    try (PreparedStatement ps = con.prepareStatement(sql);
                         ResultSet rs = ps.executeQuery()) {

                        while (rs.next()) {
                            ReportRow r = new ReportRow();

                            r.one = rs.getString("team_id");
                            r.two = rs.getString("team_name");
                            r.three = rs.getString("department");
                            r.four = rs.getString("manager_name");
                            r.five = rs.getString("manager_id");
                            r.six = rs.getString("status");
                            r.seven = String.valueOf(
                                rs.getInt("member_count")
                            );

                            rows.add(r);
                        }
                    }
                    break;
                }

                default:
                    reportType = "employees";
                    request.setAttribute("reportType", reportType);

                    loadPeopleDetailsRows(
                        con, rows, reportSearch, personType
                    );
                    break;
            }

            reportTotal = rows.size();

            request.setAttribute("reportRows", rows);
            request.setAttribute("reportTotal", reportTotal);
            request.setAttribute("reportError", null);

            request.setAttribute(
                "reportEmployeeCount",
                count(con, "SELECT COUNT(*) FROM employees")
            );

            request.setAttribute(
                "reportAttendanceCount",
                count(con, "SELECT COUNT(*) FROM attendance")
            );

            request.setAttribute(
                "reportTaskCount",
                count(con, "SELECT COUNT(*) FROM tasks")
            );

            request.setAttribute(
                "reportLeaveCount",
                count(con, "SELECT COUNT(*) FROM leave_requests")
            );

        } catch (Exception e) {
            e.printStackTrace();

            request.setAttribute("reportRows", rows);
            request.setAttribute("reportTotal", reportTotal);
            request.setAttribute(
                "reportError",
                "Unable to load report. Please check database table/column names: "
                + e.getMessage()
            );

            request.setAttribute("reportEmployeeCount", 0);
            request.setAttribute("reportAttendanceCount", 0);
            request.setAttribute("reportTaskCount", 0);
            request.setAttribute("reportLeaveCount", 0);
        }

        request.setAttribute("action", "reports");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    /*
     * EMPLOYEES & MANAGERS REPORT
     *
     * Columns:
     * one   = Employee/Manager ID
     * two   = Name
     * three = Email
     * four  = Department
     * five  = Active/Inactive status
     *
     * This report does not query attendance, check-in/check-out times,
     * dates, or attendance statuses.
     */
    private void loadPeopleDetailsRows(
            Connection con,
            List<ReportRow> rows,
            String search,
            String personType) throws Exception {

        String safeSearch = search == null ? "" : search.trim();

        if (!"MANAGER".equalsIgnoreCase(personType)) {

            String employeeSql =
                "SELECT employee_id,name,email,department,status "
                + "FROM employees "
                + "WHERE (?='' OR employee_id LIKE ? OR name LIKE ? "
                + "OR email LIKE ?) "
                + "ORDER BY name";

            try (PreparedStatement ps =
                    con.prepareStatement(employeeSql)) {

                ps.setString(1, safeSearch);
                ps.setString(2, "%" + safeSearch + "%");
                ps.setString(3, "%" + safeSearch + "%");
                ps.setString(4, "%" + safeSearch + "%");

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        ReportRow row = new ReportRow();

                        row.one = rs.getString("employee_id");
                        row.two = rs.getString("name");
                        row.three = rs.getString("email");
                        row.four = rs.getString("department");
                        row.five = normalizePersonStatus(
                            rs.getString("status")
                        );
                        row.six = "EMPLOYEE";

                        rows.add(row);
                    }
                }
            }
        }

        if (!"EMPLOYEE".equalsIgnoreCase(personType)) {

            String managerSql =
                "SELECT employee_id,name,email,department,status "
                + "FROM managers "
                + "WHERE (?='' OR employee_id LIKE ? OR name LIKE ? "
                + "OR email LIKE ?) "
                + "ORDER BY name";

            try (PreparedStatement ps =
                    con.prepareStatement(managerSql)) {

                ps.setString(1, safeSearch);
                ps.setString(2, "%" + safeSearch + "%");
                ps.setString(3, "%" + safeSearch + "%");
                ps.setString(4, "%" + safeSearch + "%");

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        ReportRow row = new ReportRow();

                        row.one = rs.getString("employee_id");
                        row.two = rs.getString("name");
                        row.three = rs.getString("email");
                        row.four = rs.getString("department");
                        row.five = normalizePersonStatus(
                            rs.getString("status")
                        );
                        row.six = "MANAGER";

                        rows.add(row);
                    }
                }
            }
        }

        rows.sort((a, b) -> {
            String nameA = a.two == null ? "" : a.two;
            String nameB = b.two == null ? "" : b.two;
            return nameA.compareToIgnoreCase(nameB);
        });
    }

    private String normalizePersonStatus(String status) {
        if (status == null || status.trim().isEmpty()) {
            return "INACTIVE";
        }

        String value = status.trim().toUpperCase();

        if ("ACTIVE".equals(value)) {
            return "ACTIVE";
        }

        return "INACTIVE";
    }

    /*
     * ATTENDANCE REPORT
     *
     * The attendance report is separate from Employees & Managers.
     * Monday-Friday are treated as working days.
     * Approved leave shows as LEAVE unless the person checked in that day.
     */
    private void loadPeopleAttendanceRows(
            Connection con,
            List<ReportRow> rows,
            String fromDateValue,
            String toDateValue,
            String search,
            String personType,
            String statusFilter,
            boolean includePersonDetails) throws Exception {

        LocalDate today = LocalDate.now();

        LocalDate from = parseDate(fromDateValue);
        LocalDate to = parseDate(toDateValue);

        if (from == null && to == null) {
            from = today;
            to = today;
        } else if (from == null) {
            from = to;
        } else if (to == null) {
            to = today;
        }

        if (from.isAfter(to)) {
            throw new IllegalArgumentException(
                "From Date cannot be after To Date."
            );
        }

        String safeSearch = search == null ? "" : search.trim();
        String safeStatus = statusFilter == null
            ? "ALL" : statusFilter.trim().toUpperCase();

        List<PersonData> people = new ArrayList<>();

        if (!"MANAGER".equalsIgnoreCase(personType)) {

            String employeeSql =
                "SELECT employee_id,name,designation,department,'EMPLOYEE' "
                + "AS person_type FROM employees "
                + "WHERE (?='' OR employee_id LIKE ? OR name LIKE ?) "
                + "ORDER BY name";

            try (PreparedStatement ps =
                    con.prepareStatement(employeeSql)) {

                ps.setString(1, safeSearch);
                ps.setString(2, "%" + safeSearch + "%");
                ps.setString(3, "%" + safeSearch + "%");

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        people.add(new PersonData(
                            rs.getString("employee_id"),
                            rs.getString("name"),
                            rs.getString("designation"),
                            rs.getString("department"),
                            rs.getString("person_type")
                        ));
                    }
                }
            }
        }

        if (!"EMPLOYEE".equalsIgnoreCase(personType)) {

            String managerSql =
                "SELECT employee_id,name,designation,department,'MANAGER' "
                + "AS person_type FROM managers "
                + "WHERE (?='' OR employee_id LIKE ? OR name LIKE ?) "
                + "ORDER BY name";

            try (PreparedStatement ps =
                    con.prepareStatement(managerSql)) {

                ps.setString(1, safeSearch);
                ps.setString(2, "%" + safeSearch + "%");
                ps.setString(3, "%" + safeSearch + "%");

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        people.add(new PersonData(
                            rs.getString("employee_id"),
                            rs.getString("name"),
                            rs.getString("designation"),
                            rs.getString("department"),
                            rs.getString("person_type")
                        ));
                    }
                }
            }
        }

        String attendanceSql =
            "SELECT check_in_time,check_out_time,status "
            + "FROM attendance WHERE employee_id=? AND date=? "
            + "ORDER BY attendance_id DESC LIMIT 1";

        String leaveSql =
            "SELECT COUNT(*) FROM leave_requests "
            + "WHERE employee_id=? AND UPPER(status)='APPROVED' "
            + "AND from_date<=? AND to_date>=?";

        try (PreparedStatement attendancePs =
                    con.prepareStatement(attendanceSql);
             PreparedStatement leavePs =
                    con.prepareStatement(leaveSql)) {

            for (PersonData person : people) {
                LocalDate date = from;

                while (!date.isAfter(to)) {

                    DayOfWeek day = date.getDayOfWeek();

                    if (day != DayOfWeek.SATURDAY
                            && day != DayOfWeek.SUNDAY) {

                        Date sqlDate = Date.valueOf(date);

                        attendancePs.setString(1, person.id);
                        attendancePs.setDate(2, sqlDate);

                        String checkIn = "-";
                        String checkOut = "-";
                        String status = null;
                        boolean attendanceFound = false;

                        try (ResultSet ars =
                                attendancePs.executeQuery()) {

                            if (ars.next()) {
                                attendanceFound = true;

                                Time in = ars.getTime("check_in_time");
                                Time out = ars.getTime("check_out_time");

                                checkIn = in == null ? "-" : in.toString();
                                checkOut = out == null ? "-" : out.toString();
                                status = ars.getString("status");
                            }
                        }

                        leavePs.setString(1, person.id);
                        leavePs.setDate(2, sqlDate);
                        leavePs.setDate(3, sqlDate);

                        boolean approvedLeave = false;

                        try (ResultSet lrs = leavePs.executeQuery()) {
                            if (lrs.next()) {
                                approvedLeave = lrs.getInt(1) > 0;
                            }
                        }

                        // Approved leave always shows as LEAVE, unless the
                        // person actually checked in on that day.
                        if (approvedLeave && "-".equals(checkIn)) {
                            status = "LEAVE";
                            checkOut = "-";
                        } else if (attendanceFound) {
                            if (status == null || status.trim().isEmpty()) {
                                status = "-".equals(checkIn)
                                    ? "ABSENT" : "PRESENT";
                            }
                        } else {
                            status = "ABSENT";
                        }

                        if (date.isAfter(today) && !attendanceFound
                                && !approvedLeave) {
                            date = date.plusDays(1);
                            continue;
                        }

                        if ("ALL".equals(safeStatus)
                                || safeStatus.equalsIgnoreCase(status)) {

                            ReportRow row = new ReportRow();

                            if (includePersonDetails) {
                                row.one = person.id;
                                row.two = person.name;
                                row.three = person.designation == null
                                    ? "" : person.designation;
                                row.four = person.department == null
                                    ? "" : person.department;
                                row.five = person.type;
                                row.six = date.toString();
                                row.seven = checkIn;
                                row.eight = checkOut;
                                row.nine = status;
                            } else {
                                row.one = person.id;
                                row.two = date.toString();
                                row.three = checkIn;
                                row.four = checkOut;
                                row.five = status;
                                row.six = person.name;
                                row.seven = person.type;
                            }

                            rows.add(row);
                        }
                    }

                    date = date.plusDays(1);
                }
            }
        }

        rows.sort((a, b) -> {
            String dateA = includePersonDetails ? a.six : a.two;
            String dateB = includePersonDetails ? b.six : b.two;

            int compareDate = dateB.compareTo(dateA);

            if (compareDate != 0) {
                return compareDate;
            }

            String nameA = includePersonDetails ? a.two : a.one;
            String nameB = includePersonDetails ? b.two : b.one;

            return nameA.compareToIgnoreCase(nameB);
        });
    }

    private LocalDate parseDate(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }

        return LocalDate.parse(value.trim());
    }

    private void setDateFilter(PreparedStatement ps,
                               String dateValue,
                               int nullIndex,
                               int dateIndex) throws Exception {

        if (dateValue == null || dateValue.trim().isEmpty()) {
            ps.setNull(nullIndex, Types.DATE);
            ps.setNull(dateIndex, Types.DATE);
        } else {
            Date date = Date.valueOf(dateValue);
            ps.setDate(nullIndex, date);
            ps.setDate(dateIndex, date);
        }
    }

    // ---------------- DATA CLASSES ----------------

    private static class PersonData {
        String id;
        String name;
        String designation;
        String department;
        String type;

        PersonData(String id, String name, String designation,
                   String department, String type) {

            this.id = id;
            this.name = name;
            this.designation = designation;
            this.department = department;
            this.type = type;
        }
    }

    public static class ReportRow {
        public String one = "";
        public String two = "";
        public String three = "";
        public String four = "";
        public String five = "";
        public String six = "";
        public String seven = "";
        public String eight = "";
        public String nine = "";
    }

    public static class AttendanceData {
        public String employeeId;
        public String name = "";
        public String date;
        public String checkIn;
        public String checkOut;
        public String status;
    }

    public static class LeaveData {
        public String leaveId;
        public String employeeId;
        public String name;
        public boolean hr;
        public String leaveType;
        public String fromDate;
        public String toDate;
        public String reason;
        public String status;
        public String appliedDate;
    }
}