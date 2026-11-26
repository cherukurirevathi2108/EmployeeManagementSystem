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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
import service.EmailService;
import service.HrSchema;
import service.PersonReportHtml;
import DAO.PayrollDAO;
import model.Payroll;

@WebServlet("/admin")
public class AdminServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private final TaskDAO taskDAO = new TaskDAO();

    @Override
    protected void doGet(HttpServletRequest request,
                         HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null ||
            !"ADMIN".equalsIgnoreCase(
                String.valueOf(session.getAttribute("role")))) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        try {
            loadDashboardCounts(request);
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("employeeCount", 0);
            request.setAttribute("managerCount", 0);
            request.setAttribute("teamCount", 0);
        }

        HrSchema.ensure();

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

                case "hrManagement":
                    loadHrList(request, response);
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

                case "managerOvertime":
                    managerOvertime(request, response);
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
                    + "/admin?action=personAttendance&reportPerson="
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
            !"ADMIN".equalsIgnoreCase(
                String.valueOf(session.getAttribute("role")))) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        // The admin only recruits / deactivates HR. Everything else
        // (employees, teams, tasks, leaves, payroll) is managed by HR at /hr.
        HrSchema.ensure();

        String action = request.getParameter("action");

        try {
            if ("addHr".equals(action)) {
                addHr(request, response);

            } else if ("setHrStatus".equals(action)) {
                setHrStatus(request, response);

            } else if ("resendHrCredentials".equals(action)) {
                resendHrCredentials(request, response);

            } else if ("decideManagerOt".equals(action)) {
                decideManagerOt(request, response);

            } else if ("approveHrLeave".equals(action)
                    || "rejectHrLeave".equals(action)) {
                setHrLeaveStatus(request, response,
                    "approveHrLeave".equals(action) ? "APPROVED" : "REJECTED");

            } else {
                response.sendRedirect(request.getContextPath() + "/admin");
            }

        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect(
                request.getContextPath()
                + "/admin?action=hrManagement&hrMessage=failed#hrManagement");
        }
    }

    private void forwardDashboard(HttpServletRequest request,
                                  HttpServletResponse response)
            throws ServletException, IOException {

        request.getRequestDispatcher("/admin_dashbaord.jsp")
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

            try {
                request.setAttribute(
                    "hrCount",
                    count(con, "SELECT COUNT(*) FROM hr_users")
                );
            } catch (Exception e) {
                request.setAttribute("hrCount", 0);
            }
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


    // ---------------- HR RECRUITMENT (admin only) ----------------

    private void loadHrList(HttpServletRequest request,
                           HttpServletResponse response)
            throws Exception {

        List<HrData> list = new ArrayList<>();

        String sql = "SELECT hr_id,name,email,phone,status,recruited_by,"
            + "recruited_at FROM hr_users ORDER BY recruited_at DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                HrData d = new HrData();
                d.hrId = rs.getString("hr_id");
                d.name = rs.getString("name");
                d.email = rs.getString("email");
                d.phone = rs.getString("phone");
                d.status = rs.getString("status");
                d.recruitedBy = rs.getString("recruited_by");
                d.recruitedAt = String.valueOf(rs.getTimestamp("recruited_at"));
                list.add(d);
            }
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("hrError",
                "Unable to load HR users. Has the hr_users table been created?");
        }

        request.setAttribute("hrList", list);
        request.setAttribute("action", "hrManagement");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    private void addHr(HttpServletRequest request,
                       HttpServletResponse response)
            throws Exception {

        String ctx = request.getContextPath();

        String name = trimmed(request.getParameter("name"));
        String email = trimmed(request.getParameter("email"));
        String phone = trimmed(request.getParameter("phone"));
        String password = request.getParameter("password");

        boolean invalid = name.isEmpty()
            || !email.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
            || (!phone.isEmpty() && !phone.matches("^[0-9+\\- ]{7,15}$"))
            || password == null || password.length() < 6;

        if (invalid) {
            response.sendRedirect(ctx
                + "/admin?action=hrManagement&hrMessage=invalid#hrManagement");
            return;
        }

        HttpSession session = request.getSession(false);
        Object by = session == null ? null : session.getAttribute("adminId");
        if (by == null && session != null) by = session.getAttribute("adminEmail");
        if (by == null && session != null) by = session.getAttribute("adminName");

        String newId;

        try (Connection con = DBcConnection.getConnection()) {

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT CONCAT('HR',LPAD(COALESCE(MAX(CAST(SUBSTRING(hr_id,3) AS UNSIGNED)),0)+1,3,'0')) FROM hr_users");
                 ResultSet rs = ps.executeQuery()) {
                rs.next();
                newId = rs.getString(1);
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO hr_users (hr_id,name,email,phone,password,status,recruited_by,recruited_at) "
                    + "VALUES (?,?,?,?,?,'ACTIVE',?,NOW())")) {

                ps.setString(1, newId);
                ps.setString(2, name);
                ps.setString(3, email);
                ps.setString(4, phone);
                ps.setString(5, password);
                ps.setString(6, by == null ? null : by.toString());
                ps.executeUpdate();
            }

        } catch (java.sql.SQLIntegrityConstraintViolationException dup) {
            response.sendRedirect(ctx
                + "/admin?action=hrManagement&hrMessage=duplicate#hrManagement");
            return;
        }

        // e-mail the login details (HR ID, e-mail, password and the login link)
        boolean mailed = sendHrCredentials(email, name, newId, password);

        response.sendRedirect(ctx
            + "/admin?action=hrManagement&hrMessage=recruited&newId=" + newId
            + mailParams(mailed) + "#hrManagement");
    }

    private boolean sendHrCredentials(String email, String name, String hrId,
                                      String password) {
        try {
            return EmailService.sendCredentials(email, name, hrId, password, "HR");
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

    /** Re-sends the login details of an existing HR user (e.g. after a failed e-mail). */
    private void resendHrCredentials(HttpServletRequest request,
                                     HttpServletResponse response)
            throws Exception {

        String ctx = request.getContextPath();
        String hrId = trimmed(request.getParameter("hrId"));

        String name = null, email = null, password = null;

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                 "SELECT name,email,password FROM hr_users WHERE hr_id=?")) {
            ps.setString(1, hrId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    name = rs.getString("name");
                    email = rs.getString("email");
                    password = rs.getString("password");
                }
            }
        }

        String back = ctx + "/admin?action=hrManagement&hrMessage=resent&newId=" + hrId;

        if (email == null || email.trim().isEmpty()) {
            response.sendRedirect(back + "&mail=failed&mailErr="
                + java.net.URLEncoder.encode("HR user or e-mail not found", "UTF-8")
                + "#hrManagement");
            return;
        }

        boolean mailed = sendHrCredentials(email, name, hrId, password);

        response.sendRedirect(back + mailParams(mailed) + "#hrManagement");
    }

    private Map<String, String> hrNames(Connection con) {
        Map<String, String> names = new HashMap<>();
        try (PreparedStatement ps = con.prepareStatement("SELECT hr_id,name FROM hr_users");
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                names.put(rs.getString(1), rs.getString(2));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return names;
    }

    /** The admin decides HR leave requests (and only those). */
    // ---------------- MANAGER OVERTIME (admin approves) ----------------

    private void managerOvertime(HttpServletRequest request,
                                 HttpServletResponse response)
            throws Exception {

        List<service.OvertimeService.OtRequest> pending =
            new ArrayList<service.OvertimeService.OtRequest>();
        List<service.OvertimeService.OtRequest> decided =
            new ArrayList<service.OvertimeService.OtRequest>();

        try {
            for (service.OvertimeService.OtRequest r : service.OvertimeService.forAdmin("")) {
                if ("PENDING".equals(r.status)) pending.add(r); else decided.add(r);
            }
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("mgrOtError",
                "Unable to load manager overtime requests: " + e.getMessage());
        }

        request.setAttribute("mgrOtPending", pending);
        request.setAttribute("mgrOtDecided", decided);
        request.setAttribute("action", "managerOvertime");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
    }

    private void decideManagerOt(HttpServletRequest request,
                                 HttpServletResponse response)
            throws Exception {

        HttpSession session = request.getSession(false);
        String message;
        boolean ok = true;

        try {
            int id = Integer.parseInt(request.getParameter("otId"));
            boolean approve = "approve".equals(request.getParameter("decision"));

            Object by = session == null ? null : session.getAttribute("adminId");
            message = service.OvertimeService.decideAsAdmin(
                id, by == null ? "ADMIN" : by.toString(), approve,
                request.getParameter("otNote"));

        } catch (IllegalArgumentException e) {
            message = e.getMessage() == null ? "Invalid request." : e.getMessage();
            ok = false;
        } catch (Exception e) {
            e.printStackTrace();
            message = "Something went wrong. Please try again.";
            ok = false;
        }

        if (session != null) {
            session.setAttribute("mgrOtFlashMsg", message);
            session.setAttribute("mgrOtFlashOk", ok ? "1" : "0");
        }

        response.sendRedirect(request.getContextPath()
            + "/admin?action=managerOvertime#managerOvertime");
    }

    private void setHrLeaveStatus(HttpServletRequest request,
                                  HttpServletResponse response,
                                  String status)
            throws Exception {

        String leaveId = trimmed(request.getParameter("leaveId"));
        int rows = 0;

        if (!leaveId.isEmpty()) {
            String sql = "UPDATE hr_leave_requests SET status=?,decided_by=?,"
                + "decided_at=NOW() WHERE leave_id=? AND status='PENDING'";

            HttpSession session = request.getSession(false);
            Object by = session == null ? null : session.getAttribute("adminId");
            if (by == null && session != null) by = session.getAttribute("adminEmail");
            if (by == null && session != null) by = session.getAttribute("adminName");

            try (Connection con = DBcConnection.getConnection();
                 PreparedStatement ps = con.prepareStatement(sql)) {
                ps.setString(1, status);
                ps.setString(2, by == null ? null : by.toString());
                ps.setString(3, leaveId);
                rows = ps.executeUpdate();
            }
        }

        response.sendRedirect(request.getContextPath()
            + "/admin?action=viewLeaves&leaveMessage="
            + (rows > 0 ? status.toLowerCase() : "notfound") + "#leaveManagement");
    }

    private void setHrStatus(HttpServletRequest request,
                             HttpServletResponse response)
            throws Exception {

        String hrId = trimmed(request.getParameter("hrId"));
        String status = trimmed(request.getParameter("status")).toUpperCase();

        if (hrId.isEmpty()
                || !("ACTIVE".equals(status) || "INACTIVE".equals(status))) {
            response.sendRedirect(request.getContextPath()
                + "/admin?action=hrManagement&hrMessage=invalid#hrManagement");
            return;
        }

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                 "UPDATE hr_users SET status=? WHERE hr_id=?")) {
            ps.setString(1, status);
            ps.setString(2, hrId);
            ps.executeUpdate();
        }

        response.sendRedirect(request.getContextPath()
            + "/admin?action=hrManagement&hrMessage=updated#hrManagement");
    }

    private static String trimmed(String v) {
        return v == null ? "" : v.trim();
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

            // HR users keep their attendance in hr_attendance
            Map<String, String> hrNames = hrNames(con);

            String hrSql = today
                ? "SELECT hr_id,att_date,check_in_time,check_out_time,status "
                  + "FROM hr_attendance WHERE att_date=CURDATE() ORDER BY hr_id"
                : "SELECT hr_id,att_date,check_in_time,check_out_time,status "
                  + "FROM hr_attendance WHERE MONTH(att_date)=MONTH(CURDATE()) "
                  + "AND YEAR(att_date)=YEAR(CURDATE()) ORDER BY hr_id,att_date";

            try (PreparedStatement hp = con.prepareStatement(hrSql);
                 ResultSet hrs = hp.executeQuery()) {

                while (hrs.next()) {
                    AttendanceData data = new AttendanceData();

                    String hid = hrs.getString("hr_id");
                    data.employeeId = hid;
                    data.name = (hrNames.get(hid) == null ? "" : hrNames.get(hid)) + " (HR)";
                    data.date = String.valueOf(hrs.getDate("att_date"));

                    Time hin = hrs.getTime("check_in_time");
                    Time hout = hrs.getTime("check_out_time");

                    data.checkIn = hin == null ? "-" : hin.toString();
                    data.checkOut = hout == null ? "-" : hout.toString();
                    data.status = hrs.getString("status");

                    list.add(data);
                }
            } catch (Exception e) {
                e.printStackTrace();
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

        // HR leave requests live in hr_leave_requests - the admin decides them
        List<LeaveData> hrLeaves = new ArrayList<>();

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                "SELECT leave_id,hr_id,leave_type,from_date,to_date,reason,"
                + "status,applied_date FROM hr_leave_requests "
                + "ORDER BY applied_date DESC, leave_id DESC");
             ResultSet rs = ps.executeQuery()) {

            Map<String, String> hrNames = hrNames(con);

            while (rs.next()) {
                LeaveData d = new LeaveData();

                d.leaveId = rs.getString("leave_id");
                d.employeeId = rs.getString("hr_id");
                d.name = hrNames.get(d.employeeId);
                d.hr = true;
                d.leaveType = rs.getString("leave_type");
                d.fromDate = String.valueOf(rs.getDate("from_date"));
                d.toDate = String.valueOf(rs.getDate("to_date"));
                d.reason = rs.getString("reason");
                d.status = rs.getString("status");
                d.appliedDate = String.valueOf(rs.getDate("applied_date"));

                hrLeaves.add(d);
            }
        } catch (Exception e) {
            e.printStackTrace();
            request.setAttribute("hrLeaveError",
                "Unable to load HR leave requests: " + e.getMessage());
        }

        request.setAttribute("hrLeaveData", hrLeaves);
        request.setAttribute("leaveData", list);
        request.setAttribute("action", "viewLeaves");

        loadDashboardCounts(request);
        loadDefaultTaskCounts(request);
        forwardDashboard(request, response);
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

        // View-only: the admin sees payroll history & reports only.
        // Salary structures and payroll processing belong to HR.
        String tab = "history";

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

    public static class HrData {
        public String hrId;
        public String name;
        public String email;
        public String phone;
        public String status;
        public String recruitedBy;
        public String recruitedAt;
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