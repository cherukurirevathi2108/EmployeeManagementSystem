<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.*" %>
<%@ page import="DAO.TaskDAO" %>
<%@ page import="model.Task" %>
<%!
    public String safe(Object value) {
        if (value == null) return "";
        String s = String.valueOf(value);
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }
    public String statusClass(String status) {
        if (status == null) return "pending";
        if ("COMPLETED".equalsIgnoreCase(status)
                || "APPROVED".equalsIgnoreCase(status)
                || "PRESENT".equalsIgnoreCase(status)) {
            return "completed";
        }
        if ("IN_PROGRESS".equalsIgnoreCase(status)) return "progress";
        if ("REJECTED".equalsIgnoreCase(status)
                || "ABSENT".equalsIgnoreCase(status)) {
            return "rejected";
        }
        return "pending";
    }
    public String displayStatus(String status) {
        if (status == null || status.trim().isEmpty()) return "ASSIGNED";
        return status.replace("_", " ");
    }
%>
<%
    String managerId = (String) session.getAttribute("managerId");
    String managerName = (String) session.getAttribute("managerName");
    if (managerId == null) {
        response.sendRedirect(request.getContextPath() + "/login.html");
        return;
    }
    String contextPath = request.getContextPath();

    /* ---------- Overtime approve / reject (posted from the Overtime Approvals page of this dashboard) ---------- */
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        request.setCharacterEncoding("UTF-8");

        /* ---------- Manager's OWN overtime request (goes to the admin) ---------- */
        if ("request".equals(request.getParameter("moAction"))) {
            String moMsg;
            boolean moOk = true;
            try {
                java.time.LocalDate moDate = java.time.LocalDate.parse(request.getParameter("moDate"));
                double moHours = Double.parseDouble(request.getParameter("moHours"));
                service.OvertimeService.request(managerId, moDate, moHours, request.getParameter("moReason"));
                moMsg = "Overtime request sent to the admin.";
            } catch (IllegalArgumentException moEx) {
                moMsg = (moEx.getMessage() == null || moEx.getMessage().isEmpty()) ? "Invalid request." : moEx.getMessage();
                moOk = false;
            } catch (Exception moEx) {
                application.log("Manager overtime request error", moEx);
                moMsg = "Something went wrong. Please try again.";
                moOk = false;
            }
            session.setAttribute("moFlashMsg", moMsg);
            session.setAttribute("moFlashOk", moOk ? "1" : "0");
            response.sendRedirect(contextPath + "/managerDashboard.jsp#myOvertime");
            return;
        }

        if ("decide".equals(request.getParameter("otAction"))) {
            String otMsg;
            boolean otOk = true;
            try {
                int otReqId = Integer.parseInt(request.getParameter("otId"));
                boolean otApprove = "approve".equals(request.getParameter("decision"));
                otMsg = service.OvertimeService.decide(otReqId, managerId, otApprove, request.getParameter("otNote"));
            } catch (IllegalArgumentException otEx) {
                otMsg = (otEx.getMessage() == null || otEx.getMessage().isEmpty()) ? "Invalid request." : otEx.getMessage();
                otOk = false;
            } catch (Exception otEx) {
                application.log("Overtime decision error", otEx);
                otMsg = "Something went wrong. Please try again.";
                otOk = false;
            }
            session.setAttribute("otFlashMsg", otMsg);
            session.setAttribute("otFlashOk", otOk ? "1" : "0");
            response.sendRedirect(contextPath + "/managerDashboard.jsp#overtimeApprovals");
            return;
        }
    }

    /* =========================================================
       MY ATTENDANCE REPORT - View page / CSV download (own data only)
       ========================================================= */
    if ("1".equals(request.getParameter("myAtt")) && request.getParameter("mode") != null) {
        try {
            service.PersonReportHtml.AttendanceData myAd =
                service.PersonReportHtml.attendanceData(
                    managerId, "MANAGER",
                    request.getParameter("fromDate"),
                    request.getParameter("toDate"));
            out.clear();
            if ("csv".equals(request.getParameter("mode"))) {
                response.setContentType("text/csv; charset=UTF-8");
                response.setHeader("Content-Disposition",
                    "attachment; filename=\"my_attendance_report.csv\"");
                out.print(service.PersonReportHtml.attendanceCsv(myAd));
            } else {
                response.setContentType("text/html; charset=UTF-8");
                out.print(service.PersonReportHtml.attendanceViewHtml(myAd,
                    contextPath + "/managerDashboard.jsp?myAtt=1&mode=csv&fromDate="
                    + myAd.from + "&toDate=" + myAd.to));
            }
            return;
        } catch (Exception myAttEx) {
            application.log("My attendance report error", myAttEx);
        }
    }

    String todayStatus = "Not Checked In";
    String checkInTime = "--";
    String checkOutTime = "--";
    int breakCount = 0;
    List<Task> managerTasks = new ArrayList<Task>();
    Map<String, List<Task>> groupedTasks =
            new LinkedHashMap<String, List<Task>>();
    Map<String, String> employeeNames =
            new HashMap<String, String>();
    int totalTasks = 0;
    int pendingTasks = 0;
    int inProgressTasks = 0;
    int completedTasks = 0;
    int rejectedTasks = 0;
    String currentDate =
            new java.text.SimpleDateFormat("dd-MM-yyyy")
                    .format(new java.util.Date());
    String todayISO =
            new java.text.SimpleDateFormat("yyyy-MM-dd")
                    .format(new java.util.Date());
    Map<String, String> managerReportTeams =
            new LinkedHashMap<String, String>();
    Map<String, Set<String>> employeeTeamIds =
            new HashMap<String, Set<String>>();
    Set<String> managerTeamEmployeeIds =
            new LinkedHashSet<String>();
    List<Task> reportTasks = new ArrayList<Task>();
    String reportTeamFilter = request.getParameter("reportTeam");
    String reportFromDate = request.getParameter("reportFromDate");
    String reportToDate = request.getParameter("reportToDate");
    if (reportTeamFilter == null) reportTeamFilter = "";
    if (reportFromDate == null) reportFromDate = "";
    if (reportToDate == null) reportToDate = "";
    if (!reportFromDate.matches("\\d{4}-\\d{2}-\\d{2}")) {
        reportFromDate = "";
    }
    if (!reportToDate.matches("\\d{4}-\\d{2}-\\d{2}")) {
        reportToDate = "";
    }
    try {
        if (!reportFromDate.isEmpty()) {
            java.sql.Date.valueOf(reportFromDate);
        }
        if (!reportToDate.isEmpty()) {
            java.sql.Date.valueOf(reportToDate);
        }
        if (!reportFromDate.isEmpty()
                && !reportToDate.isEmpty()
                && reportFromDate.compareTo(reportToDate) > 0) {
            String temp = reportFromDate;
            reportFromDate = reportToDate;
            reportToDate = temp;
        }

    } catch (Exception invalidDate) {
        reportFromDate = "";
        reportToDate = "";
    }
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try (Connection con = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/employee_db",
                "root", "root")) {
            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT check_in_time, check_out_time, status " +
                    "FROM attendance WHERE employee_id=? AND `date`=CURDATE()")) {
                ps.setString(1, managerId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        checkInTime = rs.getString("check_in_time");
                        checkOutTime = rs.getString("check_out_time");
                        todayStatus = rs.getString("status");
                        if (checkInTime == null || checkInTime.trim().isEmpty()
                                || "null".equalsIgnoreCase(checkInTime)) {
                            checkInTime = "--";
                        }
                        if (checkOutTime == null || checkOutTime.trim().isEmpty()
                                || "null".equalsIgnoreCase(checkOutTime)) {
                            checkOutTime = "--";
                        }
                        if (todayStatus == null || todayStatus.trim().isEmpty()) {
                            todayStatus = "Not Checked In";
                        }
                    }
                }
            }
            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT COUNT(*) FROM breaks " +
                    "WHERE employee_id=? AND break_date=CURDATE()")) {
                ps.setString(1, managerId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        breakCount = rs.getInt(1);
                    }
                }
            }
        }
    } catch (Exception e) {
        application.log("Dashboard attendance loading error", e);
    }
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try (Connection con = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/employee_db",
                "root", "root");
             PreparedStatement ps = con.prepareStatement(
                "SELECT t.team_id, t.team_name, tm.employee_id " +
                "FROM teams t " +
                "LEFT JOIN team_members tm " +
                "ON tm.team_id=t.team_id AND tm.status='ACTIVE' " +
                "WHERE t.manager_id=? AND t.status='ACTIVE' " +
                "ORDER BY t.team_name, tm.employee_id")) {
            ps.setString(1, managerId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    String teamId = rs.getString("team_id");
                    String teamName = rs.getString("team_name");
                    String empId = rs.getString("employee_id");
                    if (teamId != null) {
                        managerReportTeams.put(teamId, teamName);
                    }
                    if (empId != null && !empId.trim().isEmpty()) {
                        managerTeamEmployeeIds.add(empId);
                        if (!employeeTeamIds.containsKey(empId)) {
                            employeeTeamIds.put(
                                empId,
                                new LinkedHashSet<String>()
                            );
                        }
                        employeeTeamIds.get(empId).add(teamId);
                    }
                }
            }
        }
    } catch (Exception e) {
        application.log("Manager report team loading error", e);
    }
    if (!reportTeamFilter.isEmpty()
            && !managerReportTeams.containsKey(reportTeamFilter)) {
        reportTeamFilter = "";
    }

    /* =========================
       LOAD AND GROUP TASKS
       ========================= */

    try {
        managerTasks = new TaskDAO().getTasksByManager(managerId);

        if (managerTasks == null) {
            managerTasks = new ArrayList<Task>();
        }

        for (Task task : managerTasks) {
            String groupId = task.getTaskGroupId();

            if (groupId == null || groupId.trim().isEmpty()) {
                groupId = "LEGACY-" + task.getId();
            }

            if (!groupedTasks.containsKey(groupId)) {
                groupedTasks.put(groupId, new ArrayList<Task>());
            }

            groupedTasks.get(groupId).add(task);
        }

        totalTasks = groupedTasks.size();

        for (List<Task> group : groupedTasks.values()) {
            boolean allCompleted = !group.isEmpty();
            boolean hasInProgress = false;
            boolean hasRejected = false;

            for (Task task : group) {
                String status = task.getStatus();

                if ("IN_PROGRESS".equalsIgnoreCase(status)) {
                    hasInProgress = true;
                    allCompleted = false;
                } else if ("REJECTED".equalsIgnoreCase(status)) {
                    hasRejected = true;
                    allCompleted = false;
                } else if (!"COMPLETED".equalsIgnoreCase(status)) {
                    allCompleted = false;
                }
            }

            if (allCompleted) {
                completedTasks++;
            } else if (hasInProgress) {
                inProgressTasks++;
            } else if (hasRejected) {
                rejectedTasks++;
            } else {
                pendingTasks++;
            }
        }

    } catch (Exception e) {
        application.log("Dashboard task loading error", e);
    }

    /* =========================
       LOAD EMPLOYEE NAMES
       ========================= */

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");

        try (Connection con = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/employee_db",
                "root", "root");

             PreparedStatement ps = con.prepareStatement(
                "SELECT employee_id, name FROM employees");

             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                employeeNames.put(
                    rs.getString("employee_id"),
                    rs.getString("name")
                );
            }
        }
    } catch (Exception e) {
        application.log("Employee name loading error", e);
    }

    /* =========================
       PREPARE TEAM-ONLY TASK REPORT
       ========================= */

    for (Task task : managerTasks) {
        String assignedEmployee = task.getAssignedTo();

        /*
         * Do not show tasks assigned to the manager or unrelated employees.
         * Only active members of the manager's own teams are included.
         */

        if (assignedEmployee == null
                || !managerTeamEmployeeIds.contains(assignedEmployee)) {
            continue;
        }

        Set<String> employeeTeams = employeeTeamIds.get(assignedEmployee);

        if (employeeTeams == null || employeeTeams.isEmpty()) {
            continue;
        }

        if (!reportTeamFilter.isEmpty()
                && !employeeTeams.contains(reportTeamFilter)) {
            continue;
        }

        /*
         * Task date filter uses the task START DATE.
         */

        String taskStartDate = "";

        if (task.getStartDate() != null) {
            taskStartDate = String.valueOf(task.getStartDate());
        }

        if (!reportFromDate.isEmpty()
                && (taskStartDate.isEmpty()
                    || taskStartDate.compareTo(reportFromDate) < 0)) {
            continue;
        }

        if (!reportToDate.isEmpty()
                && (taskStartDate.isEmpty()
                    || taskStartDate.compareTo(reportToDate) > 0)) {
            continue;
        }

        reportTasks.add(task);
    }

    String messageCode = request.getParameter("message");
    String message = "";

    if (messageCode != null) {
        switch (messageCode) {
            case "taskCreated":
                message = "Task assigned successfully to all selected employees.";
                break;
            case "taskPartiallyCreated":
                message = "Some tasks were assigned, but one or more failed.";
                break;
            case "taskCreateFailed":
                message = "Task assignment failed.";
                break;
            case "taskUpdated":
                message = "Task updated successfully.";
                break;
            case "taskUpdateFailed":
                message = "Task update failed.";
                break;
            case "taskDeleted":
                message = "Task assignment deleted successfully.";
                break;
            case "taskDeleteFailed":
                message = "Task deletion failed.";
                break;
            case "reviewSaved":
                message = "Employee review saved successfully.";
                break;
            case "reviewFailed":
                message = "Unable to save the review.";
                break;
            case "missingFields":
                message = "Please fill all required fields and select at least one employee.";
                break;
            case "invalidDates":
                message = "Due date cannot be earlier than the start date.";
                break;
            case "invalidRating":
                message = "Please select a rating between 1 and 5.";
                break;
            case "invalidStatus":
                message = "Please select a valid task status.";
                break;
            case "invalidInput":
                message = "Please check the entered values.";
                break;
            case "error":
                message = "An error occurred while processing your request.";
                break;
            default:
                message = messageCode;
        }
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Manager Dashboard - <%= util.Html.esc(util.Branding.name()) %></title>

<style>
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
    font-family: "Segoe UI", Arial, sans-serif;
}

html { scroll-behavior: smooth; }

body {
    background: #f5f7fb;
    color: #1e293b;
}

body.modal-open { overflow: hidden; }

/* SIDEBAR */

.sidebar {
    position: fixed;
    left: 0;
    top: 0;
    width: 255px;
    height: 100vh;
    background: #0f172a;
    padding: 25px 15px;
    overflow-y: auto;
    z-index: 100;
}

.sidebar h2 {
    color: white;
    text-align: center;
    font-size: 21px;
    margin-bottom: 25px;
}

.sidebar a {
    display: block;
    text-decoration: none;
    color: #cbd5e1;
    padding: 12px 14px;
    margin-bottom: 5px;
    border-radius: 8px;
    font-size: 14px;
    transition: .2s;
}

.sidebar a:hover {
    background: #1e293b;
    color: white;
}

/* MAIN */

.main {
    margin-left: 255px;
    padding: 28px;
    min-height: 100vh;
}

.header, .card, .section {
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 12px;
    box-shadow: 0 4px 15px rgba(15,23,42,.04);
}

.header {
    padding: 25px;
    margin-bottom: 25px;
}

.header h1 {
    font-size: 26px;
    color: #0f172a;
    margin-bottom: 7px;
}

.header p {
    color: #64748b;
    font-size: 14px;
}

/* SUMMARY CARDS */

.cards {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
    margin-bottom: 25px;
}

.card { padding: 22px; }

.card h3 {
    color: #64748b;
    font-size: 13px;
    margin-bottom: 10px;
    text-transform: uppercase;
}

.card h2 {
    color: #0f172a;
    font-size: 25px;
    overflow-wrap: anywhere;
}

/* SECTIONS */

.section {
    padding: 25px;
    margin-bottom: 25px;
    scroll-margin-top: 20px;
}

.section h2 {
    color: #0f172a;
    font-size: 20px;
    padding-bottom: 13px;
    margin-bottom: 20px;
    border-bottom: 1px solid #e2e8f0;
}

.info-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 15px;
}

.info-box {
    padding: 17px;
    border-radius: 8px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    font-weight: 600;
    overflow-wrap: anywhere;
}

.info-box strong {
    display: block;
    font-size: 12px;
    color: #64748b;
    margin-bottom: 8px;
}

/* FORMS */

.form-row {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 18px;
}

.form-group {
    margin-bottom: 17px;
    min-width: 0;
}

label {
    display: block;
    color: #334155;
    font-size: 13px;
    font-weight: 600;
    margin-bottom: 7px;
}

input, select, textarea {
    width: 100%;
    padding: 11px 12px;
    border: 1px solid #cbd5e1;
    border-radius: 7px;
    background: white;
    color: #1e293b;
    font-size: 14px;
}

input:focus, select:focus, textarea:focus {
    outline: none;
    border-color: #4f46e5;
    box-shadow: 0 0 0 3px rgba(79,70,229,.10);
}

textarea {
    min-height: 90px;
    resize: vertical;
}

input[type="checkbox"] {
    width: 17px;
    height: 17px;
}

/* BUTTONS */

.btn {
    display: inline-block;
    border: none;
    border-radius: 7px;
    background: #4f46e5;
    color: white;
    padding: 10px 15px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    text-decoration: none;
    transition: .2s;
}

.btn:hover {
    background: #4338ca;
    transform: translateY(-1px);
}

.btn:disabled {
    opacity: .6;
    cursor: not-allowed;
    transform: none;
}

.btn-success { background: #15803d; }
.btn-success:hover { background: #166534; }

.btn-danger { background: #dc2626; }
.btn-danger:hover { background: #b91c1c; }

.btn-outline {
    background: white;
    color: #334155;
    border: 1px solid #cbd5e1;
}

.btn-outline:hover {
    background: #f1f5f9;
    color: #0f172a;
}

.btn-light {
    background: #eef2ff;
    color: #3730a3;
}

.btn-light:hover { background: #e0e7ff; }

.btn-cancel {
    background: #e2e8f0;
    color: #334155;
}

.btn-cancel:hover {
    background: #cbd5e1;
    color: #0f172a;
}

.btn-small {
    padding: 7px 10px;
    font-size: 11px;
}

/* TASK DASHBOARD */

.task-dashboard-cards {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 15px;
    margin-bottom: 22px;
}

.task-stat-card {
    padding: 19px;
    border: 1px solid #e2e8f0;
    border-radius: 10px;
    background: #f8fafc;
}

.task-stat-card h3 {
    font-size: 12px;
    color: #64748b;
    margin-bottom: 10px;
}

.task-stat-card h2 {
    font-size: 29px;
    color: #0f172a;
}

.task-stat-card p {
    color: #64748b;
    font-size: 12px;
    margin-top: 7px;
}

.feature-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
}

.feature-card {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 9px;
    padding: 20px;
}

.feature-card h3 {
    font-size: 16px;
    margin-bottom: 10px;
}

.feature-card p {
    font-size: 13px;
    line-height: 1.6;
    color: #64748b;
    margin-bottom: 15px;
}

/* TABLES */

.table-container {
    width: 100%;
    overflow-x: auto;
    border: 1px solid #e2e8f0;
    border-radius: 9px;
    background: white;
}

table {
    width: 100%;
    border-collapse: collapse;
    background: white;
}

th {
    background: #f1f5f9;
    color: #475569;
    padding: 13px;
    font-size: 12px;
    text-align: left;
    text-transform: uppercase;
    border-bottom: 1px solid #e2e8f0;
    white-space: nowrap;
}

td {
    padding: 13px;
    font-size: 13px;
    border-bottom: 1px solid #eef2f7;
    vertical-align: top;
}

tbody tr:last-child td { border-bottom: none; }
tbody tr:hover { background: #fafbff; }

td a:not(.btn) {
    color: #4f46e5;
    text-decoration: none;
    font-weight: 600;
}

td a:not(.btn):hover { text-decoration: underline; }

.status {
    display: inline-block;
    padding: 5px 9px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 700;
    white-space: nowrap;
}

.status-completed {
    background: #dcfce7;
    color: #166534;
}

.status-pending {
    background: #fef3c7;
    color: #92400e;
}

.status-progress {
    background: #dbeafe;
    color: #1d4ed8;
}

.status-rejected {
    background: #fee2e2;
    color: #991b1b;
}

.task-description {
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    max-width: 260px;
    margin-top: 7px;
    color: #64748b;
    line-height: 1.6;
    font-size: 12px;
}

.message {
    padding: 13px;
    margin-bottom: 20px;
    border-radius: 8px;
    background: #eef2ff;
    color: #4338ca;
    border: 1px solid #c7d2fe;
    overflow-wrap: anywhere;
}

/* GROUPED TASK TABLE */

.task-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 12px;
    margin-bottom: 17px;
}

.task-search {
    width: 270px;
    max-width: 100%;
}

.group-cell { min-width: 125px; }

.group-number {
    font-size: 13px;
    font-weight: 800;
    color: #1e293b;
}

.group-meta {
    color: #64748b;
    font-size: 11px;
    margin-top: 7px;
    line-height: 1.6;
}

.task-title {
    display: block;
    color: #0f172a;
    font-size: 13px;
    font-weight: 800;
    line-height: 1.5;
    max-width: 250px;
    overflow-wrap: anywhere;
}

.priority-badge {
    display: inline-block;
    padding: 5px 9px;
    border-radius: 6px;
    background: #eef2ff;
    color: #3730a3;
    font-weight: 800;
    font-size: 10px;
}

.group-summary { min-width: 190px; }

.member-count {
    font-weight: 700;
    font-size: 12px;
    color: #334155;
}

.member-preview {
    display: flex;
    align-items: center;
    margin-top: 9px;
}

.member-avatar {
    width: 29px;
    height: 29px;
    border-radius: 50%;
    border: 2px solid #fff;
    background: #e0e7ff;
    color: #3730a3;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 10px;
    font-weight: 800;
    margin-right: -5px;
}

.member-more {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 29px;
    height: 29px;
    border-radius: 50%;
    border: 2px solid #fff;
    background: #e2e8f0;
    color: #334155;
    font-size: 9px;
    font-weight: 800;
    position: relative;
}

.view-members-btn {
    margin-top: 11px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border: 1px solid #c7d2fe;
    border-radius: 7px;
    background: #eef2ff;
    color: #3730a3;
    padding: 8px 10px;
    font-size: 11px;
    font-weight: 800;
    cursor: pointer;
    transition: .2s;
}

.view-members-btn:hover {
    background: #e0e7ff;
    border-color: #a5b4fc;
}

.view-members-btn .arrow {
    display: inline-block;
    transition: transform .2s;
}

.view-members-btn.open .arrow { transform: rotate(180deg); }

.group-detail-row { display: none; }
.group-detail-row.show { display: table-row; }

.group-detail-row > td {
    background: #f8faff;
    padding: 18px;
    border-bottom: 2px solid #e0e7ff;
}

.group-detail-panel {
    border: 1px solid #dbe4f0;
    border-radius: 10px;
    background: white;
    overflow: hidden;
}

.group-detail-heading {
    background: #f1f5f9;
    padding: 13px 16px;
    border-bottom: 1px solid #e2e8f0;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
}

.group-detail-heading h3 {
    font-size: 13px;
    color: #0f172a;
}

.group-detail-heading p {
    font-size: 11px;
    color: #64748b;
    margin-top: 4px;
}

.member-table {
    width: 100%;
    min-width: 750px;
    border-collapse: collapse;
}

.member-table th {
    font-size: 10px;
    padding: 11px 12px;
    background: #fff;
}

.member-table td {
    font-size: 12px;
    padding: 12px;
}

.member-person {
    display: flex;
    align-items: center;
    gap: 9px;
    min-width: 155px;
}

.member-person .member-avatar {
    margin-right: 0;
    width: 34px;
    height: 34px;
    flex-shrink: 0;
}

.member-person strong {
    display: block;
    color: #0f172a;
    font-size: 12px;
}

.member-person small {
    display: block;
    color: #64748b;
    font-size: 10px;
    margin-top: 4px;
}

.member-actions {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 5px;
}

.member-actions .btn {
    padding: 7px 9px;
    font-size: 10px;
}

.member-actions form { display: inline; }

/* REPORTS */

.report-intro {
    color: #64748b;
    font-size: 13px;
    line-height: 1.7;
    margin-top: -7px;
    margin-bottom: 20px;
}

.report-cards {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 18px;
    margin-bottom: 22px;
}

.report-card {
    border: 1px solid #e0e7ff;
    border-radius: 11px;
    background: #f8fbff;
    padding: 20px;
}

.report-card h3 {
    font-size: 15px;
    color: #312e81;
    margin-bottom: 9px;
}

.report-card p {
    font-size: 12px;
    color: #64748b;
    line-height: 1.7;
}

.report-card .report-count {
    display: block;
    font-size: 27px;
    font-weight: 800;
    color: #0f172a;
    margin-top: 9px;
}

.report-filter {
    border: 1px solid #e2e8f0;
    background: #f8fafc;
    border-radius: 10px;
    padding: 17px;
    margin-bottom: 22px;
}

.report-filter-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 14px;
}

.report-filter-actions {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 9px;
    margin-top: 12px;
}

.report-subheading {
    font-size: 16px;
    color: #0f172a;
    margin: 20px 0 13px;
}

.report-note {
    padding: 12px 14px;
    border: 1px solid #c7d2fe;
    background: #eef2ff;
    color: #3730a3;
    border-radius: 8px;
    font-size: 12px;
    line-height: 1.7;
    margin-bottom: 15px;
}

.report-empty {
    text-align: center;
    color: #64748b;
    padding: 24px;
}

.report-table { min-width: 850px; }

.rp-stats {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 14px;
    margin-bottom: 22px;
}

.rp-stats .report-card { padding: 16px; }
.rp-stats .report-card .report-count { margin-top: 0; }

.report-members-panel {
    display: none;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 9px;
    padding: 15px;
    margin: 8px 0;
}

.report-members-panel h3 { font-size: 15px; margin-bottom: 10px; }
.report-member-toggle { min-width: 115px; }

@media (max-width: 1100px) {
    .rp-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}

@media (max-width: 760px) {
    .rp-stats { grid-template-columns: 1fr; }
}

/* MODALS */

.modal-overlay {
    display: none;
    position: fixed;
    inset: 0;
    z-index: 9999;
    background: rgba(15,23,42,.68);
    backdrop-filter: blur(4px);
    padding: 20px;
    align-items: center;
    justify-content: center;
}

.modal-overlay.show { display: flex; }

.task-modal {
    width: 100%;
    max-width: 780px;
    max-height: 92vh;
    overflow-y: auto;
    background: #fff;
    border-radius: 16px;
    box-shadow: 0 25px 80px rgba(0,0,0,.25);
}

.review-modal { max-width: 1050px; }

.modal-header {
    padding: 23px 25px;
    background: linear-gradient(135deg,#0f172a,#3730a3);
    color: white;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 15px;
    border-radius: 16px 16px 0 0;
    position: sticky;
    top: 0;
    z-index: 5;
}

.modal-header h2 {
    font-size: 20px;
    margin-bottom: 6px;
}

.modal-header p {
    font-size: 12px;
    color: #e0e7ff;
    line-height: 1.6;
}

.modal-close {
    border: none;
    color: white;
    background: rgba(255,255,255,.15);
    width: 38px;
    height: 38px;
    border-radius: 10px;
    font-size: 24px;
    cursor: pointer;
    flex-shrink: 0;
}

.modal-close:hover { background: rgba(255,255,255,.28); }

.modal-body { padding: 25px; }

.modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    flex-wrap: wrap;
    padding-top: 10px;
}

.file-input {
    padding: 11px;
    background: #f8fafc;
    border: 1px dashed #94a3b8;
}

/* EMPLOYEE PICKER */

.employee-picker {
    border: 1px solid #cbd5e1;
    border-radius: 9px;
    background: #fff;
    padding: 12px;
}

.employee-picker-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    flex-wrap: wrap;
    margin-bottom: 10px;
}

.employee-picker-toolbar strong { font-size: 12px; }

.employee-picker-toolbar button {
    border: 0;
    background: transparent;
    color: #4f46e5;
    font-size: 12px;
    font-weight: 700;
    cursor: pointer;
}

.employee-list {
    max-height: 220px;
    overflow-y: auto;
}

.employee-option {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px;
    border-bottom: 1px solid #eef2f7;
    cursor: pointer;
    margin: 0;
    font-weight: 500;
}

.employee-option:last-child { border-bottom: 0; }
.employee-option:hover { background: #f8fafc; }

.employee-option input {
    width: 17px;
    height: 17px;
    margin: 0;
    flex-shrink: 0;
}

.employee-option span { line-height: 1.5; }

.employee-message, .loading-text {
    color: #64748b;
    padding: 14px 8px;
    font-size: 12px;
}

.employee-count {
    color: #475569;
    font-size: 11px;
    margin-top: 9px;
}

/* REVIEW GROUPS */

.review-intro {
    padding: 14px 16px;
    border: 1px solid #c7d2fe;
    background: #eef2ff;
    border-radius: 9px;
    color: #3730a3;
    margin-bottom: 20px;
}

.review-intro strong {
    display: block;
    font-size: 13px;
    margin-bottom: 5px;
}

.review-intro p {
    font-size: 12px;
    line-height: 1.6;
}

.review-group {
    border: 1px solid #e2e8f0;
    border-radius: 11px;
    overflow: hidden;
    margin-bottom: 16px;
    background: white;
}

.review-group-header {
    background: #f8fafc;
    padding: 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 12px;
}

.review-group-header h3 {
    font-size: 15px;
    color: #0f172a;
    margin-bottom: 6px;
}

.review-group-header p {
    font-size: 12px;
    color: #64748b;
    line-height: 1.6;
}

.review-group-body {
    display: none;
    padding: 15px;
    border-top: 1px solid #e2e8f0;
}

.review-group-body.open { display: block; }

.review-employee-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
    padding: 13px;
    border: 1px solid #e2e8f0;
    border-radius: 9px;
    margin-bottom: 10px;
    flex-wrap: wrap;
}

.review-employee-row:last-of-type { margin-bottom: 0; }

.review-employee-left {
    display: flex;
    align-items: center;
    gap: 10px;
}

.review-employee-left h4 {
    font-size: 12px;
    color: #0f172a;
}

.review-employee-left p {
    font-size: 11px;
    color: #64748b;
    margin-top: 5px;
}

.employee-review-detail {
    display: none;
    padding: 16px;
    background: #fbfcff;
    border: 1px solid #e0e7ff;
    border-radius: 10px;
    margin: 10px 0 16px;
}

.employee-review-detail.open { display: block; }

.review-info-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 10px;
    margin-bottom: 15px;
}

.review-info {
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 12px;
    overflow-wrap: anywhere;
}

.review-info strong {
    display: block;
    font-size: 10px;
    color: #64748b;
    margin-bottom: 7px;
}

.review-info span {
    font-size: 12px;
    color: #0f172a;
}

.proof-box {
    background: white;
    border: 1px solid #e2e8f0;
    border-radius: 9px;
    padding: 14px;
    margin-bottom: 13px;
    overflow-wrap: anywhere;
}

.proof-box h4 {
    color: #334155;
    font-size: 12px;
    margin-bottom: 8px;
}

.proof-box p {
    color: #475569;
    font-size: 12px;
    line-height: 1.7;
    white-space: pre-wrap;
}

.review-form {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    padding: 16px;
    border-radius: 10px;
}

.review-form h4 {
    font-size: 14px;
    margin-bottom: 15px;
    color: #0f172a;
}

.empty-state {
    text-align: center;
    padding: 25px;
    color: #64748b;
}

/* RESPONSIVE */

@media(max-width:1200px) {
    .task-dashboard-cards {
        grid-template-columns: repeat(2,minmax(0,1fr));
    }

    .feature-grid {
        grid-template-columns: repeat(2,minmax(0,1fr));
    }
}

@media(max-width:950px) {
    .sidebar { width: 220px; }
    .main { margin-left: 220px; padding: 20px; }

    .cards, .info-grid {
        grid-template-columns: repeat(2,minmax(0,1fr));
    }
}

@media(max-width:700px) {
    .sidebar {
        position: relative;
        width: 100%;
        height: auto;
    }

    .main {
        margin-left: 0;
        padding: 14px;
    }

    .cards, .feature-grid, .info-grid, .task-dashboard-cards,
    .form-row, .review-info-grid, .report-cards, .report-filter-grid {
        grid-template-columns: 1fr;
    }

    .section { padding: 16px; }
    .modal-overlay { padding: 8px; }
    .modal-header, .modal-body { padding: 18px; }
}
</style>
<script>
/* highlight the sidebar link of the section being viewed */
(function(){
    function mark(){
        var links=document.querySelectorAll(".sidebar a[href]");
        var hash=window.location.hash;
        var best=null;
        links.forEach(function(a){
            a.classList.remove("active");
            var h=a.getAttribute("href")||"";
            var i=h.indexOf("#");
            if(i>-1 && hash && h.substring(i)===hash && !a.classList.contains("logout")){ best=a; }
        });
        if(!best){
            links.forEach(function(a){
                var h=a.getAttribute("href")||"";
                if(!best && !a.classList.contains("logout") && h==="#home"){ best=a; }
            });
        }
        if(best) best.classList.add("active");
    }
    window.addEventListener("hashchange",mark);
    document.addEventListener("DOMContentLoaded",mark);
})();
</script>

<script>
/* Reports open as their own page view (no other dashboard sections around them) */
(function(){
    var d=document.documentElement;
    function sync(){
        d.classList.toggle("reports-mode", window.location.hash==="#reports");
        d.classList.toggle("personal-mode", window.location.hash==="#personalReports");
    }
    window.addEventListener("hashchange",function(){
        sync();
        var h=window.location.hash;
        var el=h.length>1?document.getElementById(h.substring(1)):null;
        if(el&&h!=="#reports"&&h!=="#personalReports"){ el.scrollIntoView(); } else { window.scrollTo(0,0); }
    });
    sync();
})();
</script>
<style>
/* ===== My Overtime (manager's own request) ===== */
.mo-form{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin:8px 0 24px;max-width:720px}
.mo-form .wide{grid-column:1/-1}
.mo-form label{display:block;font-size:12px;font-weight:600;color:#475569;margin-bottom:5px}
.mo-form input,.mo-form select,.mo-form textarea{width:100%;padding:9px 11px;border:1px solid #cbd5e1;border-radius:9px;font-size:13px;font-family:inherit}
.mo-form textarea{min-height:76px;resize:vertical}
@media(max-width:640px){.mo-form{grid-template-columns:1fr}}
/* ===== Overtime Approvals page ===== */
.ot-msg{padding:12px 16px;border-radius:10px;font-size:13px;font-weight:600;margin-bottom:18px}
.ot-msg.ok{background:#dcfce7;color:#166534;border:1px solid #bbf7d0}
.ot-msg.err{background:#fee2e2;color:#991b1b;border:1px solid #fecaca}
.otm-sub{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:26px 0 12px}
.otm-sub h3{font-size:15px;font-weight:750;color:#0f172a}
.otm-sub p{font-size:12px;color:#64748b;margin-top:3px}
.otm-pill{display:inline-flex;align-items:center;background:#f1f5f9;color:#475569;border:1px solid #e2e8f0;border-radius:20px;padding:6px 12px;font-size:11px;font-weight:700}
.otm-chips{display:flex;gap:6px;background:#f1f5f9;padding:5px;border-radius:12px;width:max-content;max-width:100%;overflow-x:auto}
.otm-chips a{padding:8px 16px;border-radius:9px;font-size:12.5px;font-weight:600;color:#475569;text-decoration:none;white-space:nowrap;cursor:pointer}
.otm-chips a.active{background:#fff;color:#4338ca;box-shadow:0 1px 3px rgba(15,23,42,.12)}
.otm-tools{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:12px;margin-bottom:14px}
.otm-search{height:40px;min-width:240px;padding:8px 12px;border:1px solid #cbd5e1;border-radius:9px;font-size:13px;outline:none}
.otm-search:focus{border-color:#6366f1;box-shadow:0 0 0 3px rgba(99,102,241,.14)}
.otm-note{width:100%;min-width:170px;height:36px;padding:6px 10px;border:1px solid #cbd5e1;border-radius:8px;font-size:12px;outline:none}
.otm-actions{display:flex;gap:6px;align-items:center}
.otm-actions .btn{margin:0;padding:9px 14px}
.otm-empty{text-align:center;color:#94a3b8;padding:28px 12px}
.otm-emp small{display:block;color:#64748b;font-size:11px;margin-top:2px}
</style>
<style>
/* ===== Reports page view ===== */
.reports-pagebar{display:none;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:-4px 0 18px;padding-bottom:14px;border-bottom:1px solid #e2e8f0}
html.reports-mode .reports-pagebar{display:flex}
.reports-crumb{font-size:12.5px;color:#64748b}
.reports-crumb b{color:#0f172a}
.reports-back{display:inline-flex;align-items:center;gap:6px;padding:8px 14px;border-radius:9px;border:1px solid #cbd5e1;background:#fff;color:#1e293b;font-size:13px;font-weight:600;text-decoration:none}
.reports-back:hover{background:#f1f5f9}
html.reports-mode .content > :not(#reports){display:none!important}
html.personal-mode .reports-pagebar{display:flex}
html.personal-mode .content > :not(#personalReports){display:none!important}
</style>
<style>
/* =====================================================================
   Professional theme - matches the Admin dashboard
   (dark sidebar, indigo brand, sticky header, welcome banner, stat cards)
   ===================================================================== */
:root{--brand:#4f46e5;--brand-dark:#4338ca;--ink:#0f172a;--muted:#64748b;--line:#e2e8f0;--bg:#f1f5f9;--shadow:0 1px 2px rgba(15,23,42,.05),0 6px 20px rgba(15,23,42,.05)}
*{font-family:"Segoe UI",Arial,sans-serif}
html{scroll-padding-top:90px}
body{background:var(--bg);color:var(--ink);-webkit-font-smoothing:antialiased}

/* ---------- Sidebar ---------- */
.sidebar{position:fixed;left:0;top:0;width:235px;height:100vh;overflow-y:auto;background:linear-gradient(180deg,#0b1220 0%,#111c33 100%);padding:22px 15px;color:#fff;z-index:100;box-shadow:2px 0 18px rgba(15,23,42,.18)}
.sidebar::-webkit-scrollbar{width:6px}.sidebar::-webkit-scrollbar-thumb{background:#334155;border-radius:6px}
.logo{font-size:22px;font-weight:700;letter-spacing:.3px;text-align:left;color:#fff;padding:10px 12px 22px;margin-bottom:6px;border-bottom:1px solid rgba(255,255,255,.08)}
.logo span{display:inline;color:#818cf8;font-size:inherit;font-weight:700;opacity:1;margin:0}
.menu-title{font-size:11px;color:#64748b;font-weight:600;padding:15px 12px 8px;text-transform:uppercase;letter-spacing:1.2px}
.sidebar a{display:block;color:#d1d5db;text-decoration:none;padding:10px 12px;margin:4px 0;border-radius:8px;font-size:13px;border-left:3px solid transparent;background:transparent;transition:background .15s,color .15s,border-color .15s,padding-left .15s}
.sidebar a:hover{background:rgba(255,255,255,.07);color:#fff;padding-left:15px}
.sidebar a.active{background:rgba(99,102,241,.2);color:#fff;border-left-color:#818cf8;font-weight:600}
.sidebar a.logout{color:#fca5a5;margin-top:20px;background:rgba(248,113,113,.08)}
.sidebar a.logout:hover{background:rgba(248,113,113,.18)}

/* ---------- Main + sticky header ---------- */
.main{margin-left:235px;padding:0;min-height:100vh}
.header,.topbar{position:sticky;top:0;z-index:90;min-height:75px;display:flex;align-items:center;justify-content:space-between;gap:15px;padding:15px 28px;margin:0;background:rgba(255,255,255,.92);backdrop-filter:blur(8px);border:0;border-radius:0;box-shadow:0 1px 0 var(--line),0 4px 14px rgba(15,23,42,.04)}
.header h2,.topbar h2{font-size:22px;font-weight:700;letter-spacing:-.2px;color:var(--ink);border:0;padding:0;margin:0}
.header p,.topbar p{color:#6b7280;font-size:12px;margin-top:4px}
.admin-profile,.employee-info{display:flex;align-items:center;gap:10px}
.profile-circle{width:42px;height:42px;border-radius:50%;background:linear-gradient(135deg,#6366f1,#4338ca);box-shadow:0 4px 10px rgba(79,70,229,.35);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:17px;flex-shrink:0}
.profile-info,.employee-info-text{text-align:left}
.profile-info strong,.profile-info span,.employee-info-text strong,.employee-info-text span{display:block}
.profile-info strong,.employee-info-text strong{font-size:13px;color:var(--ink)}
.profile-info span,.employee-info-text span{color:#6b7280;font-size:12px;margin-top:3px}
.content{padding:24px 28px;max-width:1500px}

/* ---------- Welcome banner ---------- */
.welcome{position:relative;overflow:hidden;background:linear-gradient(120deg,#312e81 0%,#4f46e5 55%,#6366f1 100%);color:#fff;border-radius:16px;padding:26px 28px;margin-bottom:22px;box-shadow:0 12px 28px rgba(79,70,229,.25)}
.welcome::after{content:"";position:absolute;right:-60px;top:-60px;width:220px;height:220px;border-radius:50%;background:rgba(255,255,255,.08)}
.welcome h1{font-size:26px;font-weight:700;margin-bottom:8px}
.welcome p{font-size:13px;line-height:1.6;opacity:.95}
.welcome-meta{display:flex;flex-wrap:wrap;gap:10px;margin-top:16px;position:relative;z-index:1}
.welcome-chip{background:rgba(255,255,255,.16);border:1px solid rgba(255,255,255,.22);padding:7px 14px;border-radius:999px;font-size:12px;font-weight:600}

/* ---------- Stat cards ---------- */
.stats,.cards{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-bottom:22px}
.stat-card,.card{background:#fff;padding:18px 20px;border:1px solid var(--line);border-top:3px solid var(--brand);border-radius:14px;box-shadow:var(--shadow);transition:transform .15s,box-shadow .15s;min-width:0}
.stat-card:hover,.card:hover{transform:translateY(-2px);box-shadow:0 10px 26px rgba(15,23,42,.09)}
.stat-icon{width:42px;height:42px;border-radius:11px;background:#eef2ff;display:flex;align-items:center;justify-content:center;font-size:20px;flex-shrink:0}
.card .stat-icon{margin-bottom:10px}
.card h2{font-size:24px;font-weight:700;color:var(--ink);margin:0 0 4px;overflow-wrap:anywhere}
.card h3{font-size:12px;font-weight:500;color:var(--muted);text-transform:none;letter-spacing:0;margin:0}
.stat-card{display:flex;align-items:center;gap:14px}
.stat-card:nth-child(2) .stat-icon{background:#dcfce7}
.stat-card:nth-child(3) .stat-icon{background:#fef3c7}
.stat-text span{display:block;font-size:12px;color:var(--muted)}
.stat-text strong{display:block;margin-top:4px;color:var(--ink);font-size:21px;font-weight:700;overflow-wrap:anywhere}

/* task summary cards */
.task-stats,.task-dashboard-cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:22px}
.task-stat-card{background:#fff;border:1px solid var(--line);border-left:4px solid #64748b;border-radius:14px;padding:18px 20px;box-shadow:var(--shadow);transition:transform .15s,box-shadow .15s}
.task-stat-card:hover{transform:translateY(-2px);box-shadow:0 10px 26px rgba(15,23,42,.09)}
.task-stat-card h3{font-size:12px;font-weight:600;color:var(--muted);margin-bottom:10px}
.task-stat-card h2,.task-stat-card .task-count{font-size:28px;font-weight:700;color:var(--ink)}
.task-stat-card p{font-size:12px;color:var(--muted);margin-top:6px}
.task-dashboard-cards .task-stat-card:nth-child(1){border-left-color:#4f46e5}
.task-dashboard-cards .task-stat-card:nth-child(2),.task-stat-card.assigned{border-left-color:#f59e0b}
.task-dashboard-cards .task-stat-card:nth-child(3),.task-stat-card.progress{border-left-color:#2563eb}
.task-dashboard-cards .task-stat-card:nth-child(4),.task-stat-card.completed{border-left-color:#16a34a}

/* ---------- Section cards ---------- */
.section,.section-card{background:#fff;border:1px solid var(--line);border-radius:16px;box-shadow:var(--shadow);padding:24px;margin-bottom:22px;scroll-margin-top:90px}
.section>h2{font-size:19px;font-weight:700;letter-spacing:-.2px;color:var(--ink);padding-bottom:14px;margin-bottom:18px;border-bottom:1px solid var(--line)}
.section .task-stat-card h2,.section .card h2,.section .feature-card h2,.section .report-card h2{border:0;padding:0;margin:0}
.section-header{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;padding-bottom:14px;margin-bottom:18px;border-bottom:1px solid var(--line)}
.section-header h2{font-size:19px;font-weight:700;letter-spacing:-.2px;color:var(--ink)}
.section-header span{color:var(--muted);font-size:12px;margin:0}
.info-box,.feature-card{background:#f8fafc;border:1px solid var(--line);border-radius:12px}
.feature-card{transition:transform .15s,box-shadow .15s,border-color .15s,background .15s}
.feature-card:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(79,70,229,.12);border-color:#c7d2fe;background:#f5f7ff}
.feature-card h3{font-size:15px;font-weight:700;color:var(--ink)}
.info-box strong{text-transform:uppercase;letter-spacing:.6px;font-size:11px}

/* employee profile */
.profile-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.profile-item{background:#f8fafc;border:1px solid var(--line);border-radius:12px;padding:14px 16px;min-width:0}
.profile-item span{display:block;font-size:11px;font-weight:700;letter-spacing:.6px;text-transform:uppercase;color:var(--muted);margin-bottom:6px}
.profile-item strong{font-size:14px;color:var(--ink);overflow-wrap:anywhere}

/* ---------- Forms ---------- */
input,select,textarea{width:100%;padding:10px 12px;border:1.5px solid #dbe2ec;border-radius:9px;background:#fff;color:var(--ink);font-size:13px;font-family:inherit;transition:border-color .15s,box-shadow .15s}
input:focus,select:focus,textarea:focus{outline:none;border-color:var(--brand);box-shadow:0 0 0 4px rgba(79,70,229,.12)}
input[type="checkbox"],input[type="radio"]{width:17px;height:17px;accent-color:var(--brand)}
label{color:#334155;font-size:12px;font-weight:600}
.leave-form{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:0 16px;padding:18px;border:1px solid var(--line);border-radius:12px;background:linear-gradient(180deg,#fbfcff,#f6f8fc)}
.leave-form .form-group:nth-of-type(4),.leave-form .btn{grid-column:1/-1}
.leave-form .btn{justify-self:start;margin:0}
.apply-title{font-size:15px;font-weight:700;color:var(--ink);margin:26px 0 12px}

/* ---------- Buttons ---------- */
.btn{border:0;border-radius:9px;color:#fff;font-weight:600;font-size:12px;padding:10px 16px;letter-spacing:.2px;cursor:pointer;text-decoration:none;white-space:nowrap;transition:transform .1s,box-shadow .15s,filter .15s}
.btn{display:inline-block;background:linear-gradient(135deg,#4f46e5,#4338ca);box-shadow:0 4px 10px rgba(79,70,229,.25)}
.btn:hover{transform:translateY(-1px);filter:brightness(1.06)}
.btn-success,.checkin,.task-submit-btn{background:linear-gradient(135deg,#16a34a,#15803d);box-shadow:0 4px 10px rgba(22,163,74,.22)}
.btn-danger,.checkout{background:linear-gradient(135deg,#ef4444,#dc2626);box-shadow:0 4px 10px rgba(220,38,38,.22)}
.break-btn,.proof-btn,.report-reset{background:linear-gradient(135deg,#64748b,#475569);box-shadow:0 4px 10px rgba(71,85,105,.2)}
.task-open-btn,.report-submit{background:linear-gradient(135deg,#4f46e5,#4338ca);box-shadow:0 4px 10px rgba(79,70,229,.25)}
.btn-outline{background:#fff;color:#334155;border:1px solid #cbd5e1;box-shadow:none}
.btn-light{background:#eef2ff;color:#3730a3;box-shadow:none}
.btn-cancel{background:#e2e8f0;color:#334155;box-shadow:none}
.btn-outline:hover,.btn-light:hover,.btn-cancel:hover{filter:none}
.btn:disabled,.btn[disabled]{background:#e2e8f0;color:#94a3b8;box-shadow:none;cursor:not-allowed;transform:none;filter:none;opacity:1}
.slip-btn{display:inline-block;padding:6px 12px;margin-right:6px;border-radius:8px;border:1px solid #cbd5e1;background:#fff;color:#1e293b!important;font-size:12px;font-weight:700;text-decoration:none!important}
.slip-btn:hover{background:#f1f5f9}
.slip-btn-primary{background:var(--brand);border-color:var(--brand);color:#fff!important}
.slip-btn-primary:hover{background:var(--brand-dark)}
.action-row{display:flex;flex-wrap:wrap;gap:10px;margin-top:18px}
.action-row form{display:inline-block;margin:0}
.action-row .btn{margin:0}

/* ---------- Tables ---------- */
.table-container{width:100%;overflow-x:auto;border:1px solid var(--line);border-radius:12px;background:#fff}
table{border-collapse:separate;border-spacing:0;background:#fff}
th{background:#f8fafc;color:#475569;font-size:11px;font-weight:700;letter-spacing:.6px;text-transform:uppercase;text-align:left;padding:12px 14px;border-bottom:1px solid var(--line);white-space:nowrap}
td{padding:12px 14px;border-bottom:1px solid #eef2f7;font-size:13px;color:#334155;text-align:left;vertical-align:top}
tbody tr{transition:background .12s}
tbody tr:nth-child(even){background:#fcfdff}
tbody tr:hover{background:#f5f7ff}
tbody tr:last-child td{border-bottom:0}
td a:not(.btn){color:#4338ca;font-weight:600;text-decoration:none}
td a:not(.btn):hover{text-decoration:underline}
td[colspan]{text-align:center;color:#94a3b8;padding:28px 14px}
.empty,.empty-state{padding:30px;text-align:center;color:#94a3b8}

/* ---------- Status pills ---------- */
.status,.report-status{display:inline-block;padding:5px 11px;border-radius:20px;font-size:10px;font-weight:700;letter-spacing:.3px;text-transform:uppercase;white-space:nowrap}
.status-approved,.status-paid{background:#dcfce7;color:#166534}
.status-assigned{background:#fef3c7;color:#92400e}

/* ---------- Messages ---------- */
.message{padding:12px 14px;margin-bottom:18px;border-radius:10px;font-size:13px;background:#eef2ff;color:#3730a3;border:1px solid #c7d2fe;overflow-wrap:anywhere}

/* ---------- Reports ---------- */
.report-card,.report-panel{border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow)}
.report-card{border-top:3px solid var(--brand)}
.report-filter,.report-filter-area{border-radius:12px}
.report-employee-chip{background:#eef2ff;color:#4338ca;border-color:#c7d2fe}
.rtab.active{color:#4338ca}
.task-file-link{background:#eef2ff;color:#4338ca;border-color:#c7d2fe}
.report-filters input:focus,.report-filters select:focus{border-color:var(--brand);box-shadow:0 0 0 4px rgba(79,70,229,.12)}
.reports-back{border-radius:9px}

/* ---------- Modals ---------- */
.modal-overlay,.task-modal.show{backdrop-filter:blur(3px)}
.task-modal-content,.task-modal{border-radius:16px;box-shadow:0 24px 60px rgba(15,23,42,.35)}

/* ---------- Responsive ---------- */
@media(max-width:1100px){
  .task-stats,.task-dashboard-cards{grid-template-columns:repeat(2,minmax(0,1fr))}
  .profile-grid,.leave-form{grid-template-columns:repeat(2,minmax(0,1fr))}
}
@media(max-width:760px){
  .sidebar{position:relative;width:100%;height:auto}
  .main{margin-left:0}
  .header,.topbar{position:static;padding:15px}
  .content{padding:14px}
  .stats,.cards,.task-stats,.task-dashboard-cards,.profile-grid,.leave-form{grid-template-columns:1fr}
  .employee-info-text,.profile-info{display:none}
  .welcome h1{font-size:22px}
}
</style>
<script>
/* mark page-view as active as early as possible (prevents a flash of the long single page) */
(function(){
    var de=document.documentElement;
    de.classList.add("pv-on");
    var h=window.location.hash;
    if(h.length>1 && !/^#(home|dashboard)$/.test(h)) de.classList.add("pv-page");
})();
</script>
<style>
/* =====================================================================
   Unified page view - every sidebar item opens as its own page,
   exactly like Reports / Payroll (breadcrumb + Back to Dashboard)
   ===================================================================== */
html.pv-on .content > .section,
html.pv-on .content > .section-card{display:none}
html.pv-on.pv-page .content > .pv-active{display:block}
html.pv-on.pv-page .content > .welcome,
html.pv-on.pv-page .content > .stats,
html.pv-on.pv-page .content > .cards,
html.pv-on.pv-page .content > .footer,
html.pv-on.pv-page .content > .pv-home{display:none!important}
.pv-pagebar{display:flex;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:-4px 0 18px;padding-bottom:14px;border-bottom:1px solid #e2e8f0}
.pv-crumb{font-size:12.5px;color:#64748b}
.pv-crumb b{color:#0f172a}
.pv-back{display:inline-flex;align-items:center;gap:6px;padding:8px 14px;border-radius:9px;border:1px solid #cbd5e1;background:#fff;color:#1e293b;font-size:13px;font-weight:600;text-decoration:none}
.pv-back:hover{background:#f1f5f9}
html.pv-on .content > .section > h2{font-size:19px;font-weight:700;letter-spacing:-.2px;margin-bottom:16px}
/* Quick access (home view) */
.pv-home{background:#fff;border:1px solid #e2e8f0;border-radius:16px;box-shadow:0 1px 2px rgba(15,23,42,.05),0 6px 20px rgba(15,23,42,.05);padding:24px;margin-bottom:22px}
.pv-home > h2{font-size:19px;font-weight:700;letter-spacing:-.2px;color:#0f172a}
.pv-home > p{font-size:12px;color:#64748b;margin:5px 0 4px}
.pv-group{font-size:11px;font-weight:700;letter-spacing:1.1px;text-transform:uppercase;color:#64748b;margin:20px 0 10px}
.pv-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
.pv-grid a{display:block;padding:15px 16px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:12px;color:#1e293b;font-size:13px;font-weight:600;text-decoration:none;transition:transform .15s,box-shadow .15s,border-color .15s,background .15s}
.pv-grid a:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(79,70,229,.12);border-color:#c7d2fe;background:#f5f7ff}
@media(max-width:1100px){.pv-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:760px){.pv-grid{grid-template-columns:1fr}}
</style>
<script>
(function(){
    var HOME="#home";
    var SEL=".content > .section, .content > .section-card";
    var de=document.documentElement;

    function sections(){ return document.querySelectorAll(SEL); }

    function buildPageBars(){
        sections().forEach(function(s){
            /* Reports / Payroll already ship their own bar */
            if(s.querySelector(".reports-pagebar, .payroll-pagebar, .pv-pagebar")) return;
            var h=s.querySelector("h2");
            var title=h?h.textContent.replace(/\s+/g," ").trim():(s.id||"Page");
            var bar=document.createElement("div");
            bar.className="pv-pagebar";
            bar.innerHTML='<div class="pv-crumb">Dashboard &rsaquo; <b></b></div><a class="pv-back">&larr; Back to Dashboard</a>';
            bar.querySelector("b").textContent=title;
            bar.querySelector("a").setAttribute("href",HOME);
            s.insertBefore(bar,s.firstChild);
        });
    }

    function buildQuickAccess(){
        var content=document.querySelector(".content");
        var sidebar=document.querySelector(".sidebar");
        if(!content||!sidebar||content.querySelector(".pv-home")) return;
        var wrap=document.createElement("div");
        wrap.className="pv-home";
        wrap.innerHTML="<h2>Quick Access</h2><p>Pick an option to open it as its own page.</p>";
        var grid=null, count=0;
        Array.prototype.forEach.call(sidebar.children,function(n){
            if(n.classList.contains("menu-title")){
                var g=document.createElement("div");
                g.className="pv-group"; g.textContent=n.textContent.trim();
                grid=document.createElement("div"); grid.className="pv-grid";
                wrap.appendChild(g); wrap.appendChild(grid);
            }else if(n.tagName==="A" && grid && !n.classList.contains("logout")){
                var href=n.getAttribute("href")||"";
                if(href==="#home"||href==="#dashboard"||/\/admin$/.test(href)) return;
                var c=n.cloneNode(true);
                c.className=""; c.removeAttribute("style");
                grid.appendChild(c); count++;
            }
        });
        /* drop empty groups */
        Array.prototype.slice.call(wrap.querySelectorAll(".pv-grid")).forEach(function(gr){
            if(!gr.children.length){ var t=gr.previousElementSibling; if(t) t.remove(); gr.remove(); }
        });
        if(!count) return;
        var anchor=content.querySelector(":scope > .stats, :scope > .cards");
        if(anchor) anchor.insertAdjacentElement("afterend",wrap);
        else content.insertBefore(wrap,content.firstChild);
    }

    function sync(){
        var h=window.location.hash, el=null, sec=null;
        if(h.length>1){ try{ el=document.getElementById(decodeURIComponent(h.substring(1))); }catch(e){} }
        if(el){ sec=el.matches(SEL)?el:el.closest(SEL); }
        sections().forEach(function(s){ s.classList.toggle("pv-active", s===sec); });
        de.classList.toggle("pv-page", !!sec);
        return {sec:sec, el:el};
    }

    document.addEventListener("DOMContentLoaded",function(){
        buildPageBars();
        buildQuickAccess();
        sync();
    });
    window.addEventListener("hashchange",function(){
        var r=sync();
        if(r.sec && r.el && r.el!==r.sec){ r.el.scrollIntoView(); } else { window.scrollTo(0,0); }
    });
})();
</script>
</head>

<body>

<!-- SIDEBAR -->

<div class="sidebar">
    <%= util.Branding.sidebar("Manager Panel") %>

    <div class="menu-title">Overview</div>
    <a href="#home">🏠 Dashboard</a>

    <div class="menu-title">Attendance</div>
    <a href="#attendance">🕒 Attendance</a>
    <a href="#breaks">☕ Break Management</a>

    <div class="menu-title">Tasks</div>
    <a href="#taskDashboard">📋 Task Dashboard</a>
    <a href="#assignTasks">📝 Task Management</a>
    <a href="#" onclick="openReviewModal(); return false;">⭐ Review Employees</a>

    <div class="menu-title">Team</div>
    <a href="#teamMembers">👥 Team Members</a>
    <a href="#myTeams">🏢 My Teams</a>

    <div class="menu-title">Leave &amp; Payroll</div>
    <a href="#leave">🗓️ Apply Leave</a>
    <a href="#leaveStatus">📄 Leave Status</a>
    <a href="#myOvertime">🕕 My Overtime</a>
    <a href="#overtimeApprovals">⏱️ Overtime Approvals</a>
    <a href="#payslips">💰 My Payslips</a>

    <div class="menu-title">Reports</div>
    <a href="#reports">📈 Team Reports</a>
    <a href="<%=contextPath%>/managerDashboard.jsp?personal=1#personalReports">👤 Personal Reports</a>

    <div class="menu-title">Security</div>
    <a href="#auditLogs">🛡️ Audit Logs</a>

    <a class="logout" href="<%=contextPath%>/logout">🚪 Logout</a>
</div>

<div class="main">

    <!-- HEADER -->

    <div class="header">
        <div><h2>Manager Dashboard</h2><p>Employee Management System</p></div>
        <div class="admin-profile">
            <div class="profile-circle"><%=safe((managerName == null || managerName.trim().isEmpty()) ? "M" : managerName.trim().substring(0,1).toUpperCase())%></div>
            <div class="profile-info">
                <strong><%=safe(managerName == null ? "Manager" : managerName)%></strong>
                <span>Manager &middot; ID <%=safe(managerId)%></span>
            </div>
        </div>
    </div>

    <div class="content">

    <div class="welcome" id="home">
        <h1>Welcome, <%=safe(managerName == null ? "Manager" : managerName)%> 👋</h1>
        <p>Manage your team, tasks, attendance, leave and reports from one dashboard.</p>
        <div class="welcome-meta">
            <span class="welcome-chip">Employee ID: <%=safe(managerId)%></span>
        </div>
    </div>

    <% if (!message.isEmpty()) { %>
        <div class="message">🔔 <%=safe(message)%></div>
    <% } %>

    <!-- SUMMARY CARDS -->

    <div class="cards">
        <div class="card">
            <div class="stat-icon">🕒</div>
            <h2><%=safe(todayStatus)%></h2>
            <h3>Today's Attendance</h3>
        </div>

        <div class="card">
            <div class="stat-icon">⏰</div>
            <h2><%=safe(util.DateFmt.time(checkInTime))%></h2>
            <h3>Check In Time</h3>
        </div>

        <div class="card">
            <div class="stat-icon">☕</div>
            <h2><%=breakCount%></h2>
            <h3>Today's Breaks</h3>
        </div>
    </div>

    <!-- ATTENDANCE -->

    <div class="section" id="attendance">
        <h2>🕒 Attendance</h2>

        <div class="info-grid">
            <div class="info-box">
                <strong>📅 Date</strong>
                <%=safe(util.DateFmt.date(currentDate))%>
            </div>

            <div class="info-box">
                <strong>🟢 Check In</strong>
                <%=safe(util.DateFmt.time(checkInTime))%>
            </div>

            <div class="info-box">
                <strong>🔴 Check Out</strong>
                <%=safe(util.DateFmt.time(checkOutTime))%>
            </div>
        </div>

        <br>

        <div style="display:flex;gap:10px;flex-wrap:wrap;">
            <form action="<%=contextPath%>/manager" method="post">
                <input type="hidden" name="action" value="checkIn">
                <button type="submit" class="btn btn-success">✅ Check In</button>
            </form>

            <form action="<%=contextPath%>/manager" method="post">
                <input type="hidden" name="action" value="checkOut">
                <button type="submit" class="btn btn-danger">🚪 Check Out</button>
            </form>
        </div>
    </div>

    <!-- BREAKS -->

    <div class="section" id="breaks">
        <h2>☕ Break Management</h2>

        <div class="info-grid">
            <div class="info-box">
                <strong>☕ Breaks Taken</strong>
                <%=breakCount%>
            </div>

            <div class="info-box">
                <strong>🔢 Maximum Breaks</strong>
                2
            </div>

            <div class="info-box">
                <strong>⏳ Remaining Breaks</strong>
                <%=Math.max(0, 2 - breakCount)%>
            </div>
        </div>

        <br>

        <div style="display:flex;gap:10px;flex-wrap:wrap;">
            <form action="<%=contextPath%>/manager" method="post">
                <input type="hidden" name="action" value="startBreak">
                <button type="submit" class="btn">☕ Start Break</button>
            </form>

            <form action="<%=contextPath%>/manager" method="post">
                <input type="hidden" name="action" value="endBreak">
                <button type="submit" class="btn btn-outline">✅ End Break</button>
            </form>
        </div>
    </div>

    <!-- TASK DASHBOARD -->

    <div class="section" id="taskDashboard">
        <h2>📊 Task Dashboard</h2>

        <div class="task-dashboard-cards">
            <div class="task-stat-card">
                <h3>📋 Total Task Groups</h3>
                <h2><%=totalTasks%></h2>
                <p>Unique tasks created by you</p>
            </div>

            <div class="task-stat-card">
                <h3>🟡 Pending</h3>
                <h2><%=pendingTasks%></h2>
                <p>Groups waiting to start</p>
            </div>

            <div class="task-stat-card">
                <h3>🔵 In Progress</h3>
                <h2><%=inProgressTasks%></h2>
                <p>Groups with ongoing work</p>
            </div>

            <div class="task-stat-card">
                <h3>✅ Completed</h3>
                <h2><%=completedTasks%></h2>
                <p>All employees completed</p>
            </div>
        </div>

        <div class="feature-grid">
            <div class="feature-card">
                <h3>📝 Create a Task</h3>
                <p>Choose one team and assign a task to multiple employees.</p>
                <button type="button" class="btn" onclick="openTaskModal()">
                    ➕ Create Task
                </button>
            </div>

            <div class="feature-card">
                <h3>⭐ Review Employee Work</h3>
                <p>Open a task group to view employee submissions and review each employee.</p>
                <button type="button" class="btn" onclick="openReviewModal()">
                    👥 Review Employees
                </button>
            </div>

            <div class="feature-card">
                <h3>❌ Rejected Tasks</h3>
                <p>Groups with at least one rejected employee assignment.</p>
                <h2><%=rejectedTasks%></h2>
            </div>
        </div>
    </div>

    <!-- MY OVERTIME (manager requests, admin approves) -->
<%
    String moFlash = (String) session.getAttribute("moFlashMsg");
    String moFlashOk = (String) session.getAttribute("moFlashOk");
    session.removeAttribute("moFlashMsg");
    session.removeAttribute("moFlashOk");

    List<service.OvertimeService.OtRequest> moList = new ArrayList<service.OvertimeService.OtRequest>();
    List<String> moPays = new ArrayList<String>();
    int moPendingCount = 0, moRejectedCount = 0;
    java.math.BigDecimal moApprovedHours = java.math.BigDecimal.ZERO;
    java.math.BigDecimal moTotalPay = java.math.BigDecimal.ZERO;
    String moLoadError = null;
    try {
        moList = service.OvertimeService.forEmployee(managerId);
        for (service.OvertimeService.OtRequest moX : moList) {
            String moPayText = "-";
            if ("PENDING".equals(moX.status)) moPendingCount++;
            if ("REJECTED".equals(moX.status)) moRejectedCount++;
            if ("APPROVED".equals(moX.status)) {
                moApprovedHours = moApprovedHours.add(moX.hours);
                java.math.BigDecimal moAmt = moX.amount;
                boolean moEstimate = false;
                if (moAmt == null && moX.payMonth != null && moX.payYear != null) {
                    moAmt = service.OvertimeService.estimateAmount(managerId, moX.payMonth, moX.payYear, moX.hours);
                    moEstimate = moAmt != null;
                }
                if (moAmt != null) {
                    moTotalPay = moTotalPay.add(moAmt);
                    moPayText = (moEstimate ? "~ " : "") + "&#8377;" + String.format("%,.2f", moAmt)
                            + (moEstimate ? " <small>(estimate)</small>" : "");
                }
            }
            moPays.add(moPayText);
        }
    } catch (Exception moLoadEx) {
        application.log("Manager own overtime page error", moLoadEx);
        moLoadError = "Unable to load your overtime requests. Please check the server log for details.";
    }
    java.time.LocalDate moToday = java.time.LocalDate.now();
%>
    <div class="section" id="myOvertime">
        <h2>🕕 My Overtime</h2>
        <p class="report-intro">
            Request overtime for yourself. The <strong>admin</strong> approves it. When approved, your check-out becomes
            <strong><%=safe(service.AttendanceAutoCheckout.CUTOFF)%></strong> plus the OT hours and the OT pay is added to your salary and salary slip.
        </p>

        <% if (moFlash != null) { %>
            <div class="ot-msg <%= "1".equals(moFlashOk) ? "ok" : "err" %>"><%=safe(moFlash)%></div>
        <% } %>
        <% if (moLoadError != null) { %>
            <div class="ot-msg err"><%=safe(moLoadError)%></div>
        <% } %>

        <div class="rp-stats">
            <div class="report-card"><span class="report-count"><%=moPendingCount%></span><p>Pending Admin Approval</p></div>
            <div class="report-card"><span class="report-count"><%=safe(moApprovedHours.stripTrailingZeros().toPlainString())%> h</span><p>Approved Hours</p></div>
            <div class="report-card"><span class="report-count"><%=moRejectedCount%></span><p>Rejected</p></div>
            <div class="report-card"><span class="report-count">&#8377;<%=String.format("%,.2f", moTotalPay)%></span><p>Approved OT Pay</p></div>
        </div>

        <div class="otm-sub">
            <div><h3>Request Overtime</h3><p>You must have checked in that day and stayed past <%=safe(service.AttendanceAutoCheckout.CUTOFF)%>.</p></div>
            <span class="otm-pill">Last <%=service.OvertimeService.MAX_DAYS_BACK%> days allowed</span>
        </div>
        <form method="post" action="<%=contextPath%>/managerDashboard.jsp" class="mo-form">
            <input type="hidden" name="moAction" value="request">
            <div>
                <label for="moDate">Date</label>
                <input type="date" id="moDate" name="moDate" value="<%=moToday%>"
                       min="<%=moToday.minusDays(service.OvertimeService.MAX_DAYS_BACK)%>" max="<%=moToday%>" required>
            </div>
            <div>
                <label for="moHours">OT Hours</label>
                <select id="moHours" name="moHours">
                    <% for (double moH = 0.5; moH <= service.OvertimeService.MAX_HOURS; moH += 0.5) { %>
                        <option value="<%=moH%>" <%= moH == 2.0 ? "selected" : "" %>><%=moH%> h</option>
                    <% } %>
                </select>
            </div>
            <div class="wide">
                <label for="moReason">Reason</label>
                <textarea id="moReason" name="moReason" maxlength="500" required placeholder="What did you work on?"></textarea>
            </div>
            <div class="wide"><button type="submit" class="btn">📨 Send to Admin</button></div>
        </form>

        <div class="otm-sub">
            <div><h3>My Overtime Requests</h3><p>Status, check-out time, admin note and the salary month each request is paid in.</p></div>
            <span class="otm-pill"><%=moList.size()%> Records</span>
        </div>
        <div class="table-container">
            <table class="report-table" style="min-width:900px">
                <thead><tr><th>Date</th><th>Hours</th><th>Reason</th><th>Status</th><th>Check-out</th><th>Admin Note</th><th>Paid In Salary</th><th>OT Pay</th></tr></thead>
                <tbody>
                <% if (moList.isEmpty()) { %>
                    <tr><td colspan="8" class="otm-empty">No overtime requests yet.</td></tr>
                <% }
                   for (int moI = 0; moI < moList.size(); moI++) {
                       service.OvertimeService.OtRequest moR = moList.get(moI);
                       String moCls = "APPROVED".equals(moR.status) ? "approved" : ("REJECTED".equals(moR.status) ? "rejected" : "pending");
                       String moPaid = (moR.payMonth != null && moR.payYear != null && "APPROVED".equals(moR.status))
                               ? java.time.Month.of(moR.payMonth).getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.ENGLISH) + " " + moR.payYear
                               : "-"; %>
                    <tr>
                        <td><%=safe(util.DateFmt.date(moR.otDate))%></td>
                        <td><%=safe(moR.hours.stripTrailingZeros().toPlainString())%> h</td>
                        <td><%=safe(moR.reason)%></td>
                        <td><span class="status status-<%=moCls%>"><%=safe(moR.status)%></span></td>
                        <td><%="APPROVED".equals(moR.status) ? safe(util.DateFmt.time(moR.checkOutTime)) : "-"%></td>
                        <td><%=safe(moR.managerNote == null || moR.managerNote.isEmpty() ? "-" : moR.managerNote)%></td>
                        <td><%=safe(moPaid)%></td>
                        <td><%=moPays.get(moI)%></td>
                    </tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- OVERTIME APPROVALS -->
<%
    String otFlash = (String) session.getAttribute("otFlashMsg");
    String otFlashOk = (String) session.getAttribute("otFlashOk");
    session.removeAttribute("otFlashMsg");
    session.removeAttribute("otFlashOk");

    List<service.OvertimeService.OtRequest> otPending = new ArrayList<service.OvertimeService.OtRequest>();
    List<service.OvertimeService.OtRequest> otDecided = new ArrayList<service.OvertimeService.OtRequest>();
    java.math.BigDecimal otApprovedHours = java.math.BigDecimal.ZERO;
    int otRejectedCount = 0;
    String otLoadError = null;
    try {
        for (service.OvertimeService.OtRequest otX : service.OvertimeService.forManager(managerId, "")) {
            if ("PENDING".equals(otX.status)) {
                otPending.add(otX);
            } else {
                otDecided.add(otX);
                if ("APPROVED".equals(otX.status)) otApprovedHours = otApprovedHours.add(otX.hours);
                if ("REJECTED".equals(otX.status)) otRejectedCount++;
            }
        }
    } catch (Exception otLoadEx) {
        application.log("Manager overtime approvals error", otLoadEx);
        otLoadError = "Unable to load overtime requests. Please check the server log for details.";
    }
%>
    <div class="section" id="overtimeApprovals">
        <h2>⏱️ Overtime Approvals</h2>
        <p class="report-intro">
            Review overtime requests from your team. On approval the employee's check-out becomes
            <strong><%=safe(service.AttendanceAutoCheckout.CUTOFF)%></strong> plus the OT hours, and the OT pay is added to the salary.
        </p>

        <% if (otFlash != null) { %>
            <div class="ot-msg <%= "1".equals(otFlashOk) ? "ok" : "err" %>"><%=safe(otFlash)%></div>
        <% } %>
        <% if (otLoadError != null) { %>
            <div class="ot-msg err"><%=safe(otLoadError)%></div>
        <% } %>

        <div class="rp-stats">
            <div class="report-card"><span class="report-count"><%=otPending.size()%></span><p>Waiting For Approval</p></div>
            <div class="report-card"><span class="report-count"><%=otDecided.size()%></span><p>Decided Requests</p></div>
            <div class="report-card"><span class="report-count"><%=safe(otApprovedHours.stripTrailingZeros().toPlainString())%> h</span><p>Approved Hours</p></div>
            <div class="report-card"><span class="report-count"><%=otRejectedCount%></span><p>Rejected</p></div>
        </div>

        <div class="otm-sub">
            <div><h3>Waiting For Your Approval</h3><p>Add an optional note, then approve or reject.</p></div>
            <span class="otm-pill"><%=otPending.size()%> Pending</span>
        </div>
        <div class="table-container">
            <table class="report-table" style="min-width:900px">
                <thead><tr><th>Employee</th><th>Date</th><th>Hours</th><th>Reason</th><th>Note (optional)</th><th>Decision</th></tr></thead>
                <tbody>
                <% if (otPending.isEmpty()) { %>
                    <tr><td colspan="6" class="otm-empty">🎉 No pending overtime requests.</td></tr>
                <% }
                   for (service.OvertimeService.OtRequest otP : otPending) { %>
                    <tr>
                        <td class="otm-emp"><%=safe(otP.employeeName)%><small><%=safe(otP.employeeId)%></small></td>
                        <td><%=safe(util.DateFmt.date(otP.otDate))%></td>
                        <td><%=safe(otP.hours.stripTrailingZeros().toPlainString())%> h</td>
                        <td><%=safe(otP.reason)%></td>
                        <td colspan="2">
                            <form method="post" action="<%=contextPath%>/managerDashboard.jsp" style="display:flex;gap:8px;align-items:center;margin:0">
                                <input type="hidden" name="otAction" value="decide">
                                <input type="hidden" name="otId" value="<%=otP.id%>">
                                <input type="text" class="otm-note" name="otNote" maxlength="300" placeholder="Note to employee">
                                <div class="otm-actions">
                                    <button type="submit" name="decision" value="approve" class="btn">✔ Approve</button>
                                    <button type="submit" name="decision" value="reject" class="btn btn-danger"
                                            onclick="return confirm('Reject this overtime request?');">✖ Reject</button>
                                </div>
                            </form>
                        </td>
                    </tr>
                <% } %>
                </tbody>
            </table>
        </div>

        <div class="otm-sub">
            <div><h3>Decided Requests</h3><p>History of approved and rejected overtime of your team.</p></div>
            <span class="otm-pill"><%=otDecided.size()%> Records</span>
        </div>
        <div class="otm-tools">
            <div class="otm-chips" id="otmChips">
                <a class="active" data-f="">All</a>
                <a data-f="APPROVED">Approved</a>
                <a data-f="REJECTED">Rejected</a>
            </div>
            <input type="search" class="otm-search" id="otmSearch" placeholder="🔍 Search employee or reason...">
        </div>
        <div class="table-container">
            <table class="report-table" style="min-width:900px">
                <thead><tr><th>Employee</th><th>Date</th><th>Hours</th><th>Reason</th><th>Status</th><th>Check-out</th><th>Note</th><th>Paid In Salary</th></tr></thead>
                <tbody id="otmBody">
                <% if (otDecided.isEmpty()) { %>
                    <tr><td colspan="8" class="otm-empty">Nothing decided yet.</td></tr>
                <% }
                   for (service.OvertimeService.OtRequest otD : otDecided) {
                       String otCls = "APPROVED".equals(otD.status) ? "approved" : "rejected";
                       String otPaid = (otD.payMonth != null && otD.payYear != null)
                               ? java.time.Month.of(otD.payMonth).getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.ENGLISH) + " " + otD.payYear
                               : "-"; %>
                    <tr data-status="<%=safe(otD.status)%>">
                        <td class="otm-emp"><%=safe(otD.employeeName)%><small><%=safe(otD.employeeId)%></small></td>
                        <td><%=safe(util.DateFmt.date(otD.otDate))%></td>
                        <td><%=safe(otD.hours.stripTrailingZeros().toPlainString())%> h</td>
                        <td><%=safe(otD.reason)%></td>
                        <td><span class="status status-<%=otCls%>"><%=safe(otD.status)%></span></td>
                        <td><%="APPROVED".equals(otD.status) ? safe(util.DateFmt.time(otD.checkOutTime)) : "-"%></td>
                        <td><%=safe(otD.managerNote == null || otD.managerNote.isEmpty() ? "-" : otD.managerNote)%></td>
                        <td><%=safe(otPaid)%></td>
                    </tr>
                <% } %>
                    <tr id="otmNoMatch" style="display:none"><td colspan="8" class="otm-empty">No requests match your filters.</td></tr>
                </tbody>
            </table>
        </div>
    </div>
    <script>
    (function(){
        var chips=document.getElementById("otmChips"), body=document.getElementById("otmBody"), q=document.getElementById("otmSearch");
        if(!chips||!body) return;
        var f="";
        function apply(){
            var term=(q.value||"").toLowerCase(), shown=0, any=false;
            body.querySelectorAll("tr[data-status]").forEach(function(tr){
                any=true;
                var on=(!f||tr.getAttribute("data-status")===f)&&(!term||tr.textContent.toLowerCase().indexOf(term)>-1);
                tr.style.display=on?"":"none"; if(on) shown++;
            });
            document.getElementById("otmNoMatch").style.display=(any&&shown===0)?"":"none";
        }
        chips.addEventListener("click",function(ev){
            var a=ev.target.closest("a"); if(!a) return;
            chips.querySelectorAll("a").forEach(function(c){c.classList.toggle("active",c===a);});
            f=a.getAttribute("data-f"); apply();
        });
        q.addEventListener("input",apply);
    })();
    </script>

    <!-- =================================================
         REPORTS DASHBOARD (team members list, filtered only by team)
         ================================================= -->

<%
{
    List<String[]> rpRows = new ArrayList<String[]>();   // id, name, email, dept, designation, teams, status
    String rpError = null;
    int rpTeamCount = reportTeamFilter.isEmpty() ? managerReportTeams.size() : 1;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try (Connection rpCon = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/employee_db", "root", "root")) {

            Map<String, String[]> rpMembers = new LinkedHashMap<String, String[]>();

            StringBuilder rpMemberSql = new StringBuilder(
                "SELECT t.team_name, e.employee_id, e.name, e.email, e.department, e.designation, e.status " +
                "FROM teams t " +
                "JOIN team_members tm ON tm.team_id=t.team_id AND tm.status='ACTIVE' " +
                "JOIN employees e ON e.employee_id=tm.employee_id " +
                "WHERE t.manager_id=? AND t.status='ACTIVE' ");
            if (!reportTeamFilter.isEmpty()) rpMemberSql.append("AND t.team_id=? ");
            rpMemberSql.append("ORDER BY e.name, t.team_name");

            try (PreparedStatement ps = rpCon.prepareStatement(rpMemberSql.toString())) {
                int p = 1;
                ps.setString(p++, managerId);
                if (!reportTeamFilter.isEmpty()) ps.setString(p++, reportTeamFilter);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        String id = rs.getString("employee_id");
                        String teamName = rs.getString("team_name");
                        String st = rs.getString("status");
                        st = (st != null && "ACTIVE".equalsIgnoreCase(st.trim())) ? "ACTIVE" : "INACTIVE";
                        String[] m = rpMembers.get(id);
                        if (m == null) {
                            rpMembers.put(id, new String[]{
                                id,
                                rs.getString("name") == null ? "" : rs.getString("name"),
                                rs.getString("email") == null ? "" : rs.getString("email"),
                                rs.getString("department") == null ? "" : rs.getString("department"),
                                rs.getString("designation") == null ? "" : rs.getString("designation"),
                                teamName, st});
                        } else if (!m[5].contains(teamName)) {
                            m[5] = m[5] + ", " + teamName;
                        }
                    }
                }
            }
            rpRows.addAll(rpMembers.values());
        }
    } catch (Exception rpEx) {
        application.log("Manager report loading error", rpEx);
        rpError = "Unable to load report. Please check the server log for details.";
    }

    String rpPerson = request.getParameter("reportPerson");
    if (rpPerson != null) rpPerson = rpPerson.trim();
    if (rpPerson != null && rpPerson.isEmpty()) rpPerson = null;
    String rpTeamQs = reportTeamFilter.isEmpty() ? "" : "&reportTeam=" + java.net.URLEncoder.encode(reportTeamFilter, "UTF-8");
%>

    <div class="section" id="reports">
    <div class="reports-pagebar">
        <div class="reports-crumb">Dashboard &rsaquo; <b>Reports</b></div>
        <a class="reports-back" href="#home">&larr; Back to Dashboard</a>
    </div>
        <h2>📈 Reports Dashboard</h2>

        <p class="report-intro">
            Your active team members are listed below. Click an employee (or <strong>View Report</strong>)
            to see their details, attendance, leave, task and team reports.
        </p>

        <div class="rp-stats">
            <div class="report-card"><span class="report-count"><%=rpRows.size()%></span><p>Team Members</p></div>
            <div class="report-card"><span class="report-count"><%=rpTeamCount%></span><p>My Teams</p></div>
        </div>

<% if (rpPerson != null) { %>
        <%= service.PersonReportHtml.render(
                rpPerson, "EMPLOYEE", managerId, reportFromDate, reportToDate,
                contextPath + "/managerDashboard.jsp?reportType=employees" + rpTeamQs + "#reports",
                contextPath + "/managerDashboard.jsp#reports",
                contextPath + "/managerDashboard.jsp?reportType=employees&reportPerson="
                    + java.net.URLEncoder.encode(rpPerson, "UTF-8") + rpTeamQs + "#reports",
                new String[][]{{"reportType","employees"},{"reportPerson", rpPerson},{"reportTeam", reportTeamFilter}},
                "reportFromDate", "reportToDate") %>
<% } else { %>

        <form action="<%=contextPath%>/managerDashboard.jsp#reports" method="get" class="report-filter" id="reportFilterForm">
            <input type="hidden" name="reportType" value="employees">
            <div class="form-group" style="margin-bottom:0;max-width:320px;">
                <label for="reportTeam">Team</label>
                <select name="reportTeam" id="reportTeam" onchange="this.form.submit()">
                    <option value="">All My Teams</option>
                    <% for (Map.Entry<String, String> teamEntry : managerReportTeams.entrySet()) { %>
                        <option value="<%=safe(teamEntry.getKey())%>"
                            <%=teamEntry.getKey().equals(reportTeamFilter) ? "selected" : ""%>>
                            <%=safe(teamEntry.getValue())%>
                        </option>
                    <% } %>
                </select>
            </div>
            <noscript><button type="submit" class="btn">Apply</button></noscript>
        </form>

        <% if (rpError != null) { %>
            <div class="message message-error"><%=safe(rpError)%></div>
        <% } %>

        <div class="table-container">
            <table class="report-table">
                <thead>
                    <tr>
                        <th>Employee ID</th><th>Name</th><th>Email</th><th>Department</th>
                        <th>Designation</th><th>Team</th><th>Status</th><th>Report</th>
                    </tr>
                </thead>
                <tbody>
                <% if (rpRows.isEmpty()) { %>
                    <tr><td colspan="8" class="report-empty">No team members found.</td></tr>
                <% }
                   for (String[] rrow : rpRows) {
                       String pLink = contextPath + "/managerDashboard.jsp?reportType=employees&reportPerson="
                           + java.net.URLEncoder.encode(rrow[0], "UTF-8") + rpTeamQs + "#reports"; %>
                    <tr>
                        <td><a href="<%=safe(pLink)%>"><%=safe(rrow[0])%></a></td>
                        <td><a href="<%=safe(pLink)%>"><%=safe(rrow[1])%></a></td>
                        <td><%=safe(rrow[2])%></td>
                        <td><%=safe(rrow[3])%></td>
                        <td><%=safe(rrow[4])%></td>
                        <td><%=safe(rrow[5])%></td>
                        <td><span class="status status-<%="ACTIVE".equalsIgnoreCase(rrow[6]) ? "completed" : "rejected"%>"><%=safe(rrow[6])%></span></td>
                        <td><a class="btn" style="text-decoration:none;display:inline-block" href="<%=safe(pLink)%>">View Report</a></td>
                    </tr>
                <% } %>
                </tbody>
            </table>
        </div>
<% } %>
    </div>
<% } %>
<!-- END REPORTS DASHBOARD -->

<!-- =================================================
     PERSONAL REPORTS (manager's own attendance, leaves, tasks, teams)
     ================================================= -->
<%
    String myFromDate = request.getParameter("myFromDate");
    String myToDate = request.getParameter("myToDate");
    if (myFromDate == null || !myFromDate.matches("\\d{4}-\\d{2}-\\d{2}")) myFromDate = "";
    if (myToDate == null || !myToDate.matches("\\d{4}-\\d{2}-\\d{2}")) myToDate = "";
    boolean showPersonal = "1".equals(request.getParameter("personal"));
    String personalUrl = contextPath + "/managerDashboard.jsp?personal=1#personalReports";
%>
    <div class="section" id="personalReports">
        <div class="reports-pagebar">
            <div class="reports-crumb">Dashboard &rsaquo; <b>Personal Reports</b></div>
            <a class="reports-back" href="#home">&larr; Back to Dashboard</a>
        </div>
        <h2>👤 My Personal Reports</h2>

<% if (showPersonal) { %>
        <p class="report-intro">
            Your own reports. <strong>Attendance</strong> opens first; use the tabs for your
            <strong>Leaves</strong> (filter by Pending / Approved / Rejected),
            <strong>Tasks</strong> and <strong>Teams</strong>.
        </p>

        <%= service.PersonReportHtml.render(
                managerId, "MANAGER", null, myFromDate, myToDate,
                null,
                contextPath + "/managerDashboard.jsp#personalReports",
                personalUrl,
                new String[][]{{"personal", "1"}},
                "myFromDate", "myToDate",
                contextPath + "/managerDashboard.jsp?myAtt=1",
                null) %>
<% } else { %>
        <p class="report-intro">View your own attendance, leave, task and team reports.</p>
        <a class="btn" style="text-decoration:none" href="<%=safe(personalUrl)%>">Open My Reports</a>
<% } %>
    </div>
<!-- END PERSONAL REPORTS -->


    <!-- PROFESSIONAL GROUPED TASK MANAGEMENT -->

    <div class="section" id="assignTasks">
        <h2>📝 Task Management</h2>

        <p style="color:#64748b;font-size:13px;line-height:1.7;margin-top:-10px;margin-bottom:18px;">
            📌 Each task is shown once. Click <strong>👥 View Members</strong>
            to see the employees assigned to that task.
        </p>

        <div class="task-toolbar">
            <input type="search"
                   id="taskSearch"
                   class="task-search"
                   placeholder="🔍 Search task or employee..."
                   oninput="filterTaskGroups()">

            <div style="display:flex;gap:10px;flex-wrap:wrap;">
                <button type="button" class="btn" onclick="openTaskModal()">
                    ➕ Assign New Task
                </button>

                <button type="button" class="btn btn-outline" onclick="openReviewModal()">
                    ⭐ Review Employees
                </button>
            </div>
        </div>

        <div class="table-container">
            <table style="min-width:950px;">
                <thead>
                    <tr>
                        <th>📋 Task Group</th>
                        <th>📝 Task Details</th>
                        <th>👥 Assigned Members</th>
                        <th>🔥 Priority</th>
                        <th>📅 Timeline</th>
                        <th>📎 Instructions</th>
                    </tr>
                </thead>

                <tbody id="groupedTasksTableBody">

                <% if (groupedTasks.isEmpty()) { %>
                    <tr>
                        <td colspan="6" style="text-align:center;padding:30px;">
                            📭 No tasks assigned yet. Click "Assign New Task" to get started.
                        </td>
                    </tr>
                <% } %>

                <%
                    int groupNumber = 0;

                    for (Map.Entry<String, List<Task>> entry : groupedTasks.entrySet()) {

                        List<Task> group = entry.getValue();

                        if (group == null || group.isEmpty()) {
                            continue;
                        }

                        groupNumber++;

                        Task firstTask = group.get(0);

                        String searchText = firstTask.getTaskTitle() == null
                                ? "" : firstTask.getTaskTitle();

                        boolean allComplete = !group.isEmpty();
                        boolean hasProgress = false;
                        boolean hasRejection = false;

                        for (Task item : group) {
                            String st = item.getStatus();

                            if ("IN_PROGRESS".equalsIgnoreCase(st)) {
                                hasProgress = true;
                                allComplete = false;
                            } else if ("REJECTED".equalsIgnoreCase(st)) {
                                hasRejection = true;
                                allComplete = false;
                            } else if (!"COMPLETED".equalsIgnoreCase(st)) {
                                allComplete = false;
                            }

                            if (item.getAssignedTo() != null) {
                                searchText += " " + item.getAssignedTo();
                            }

                            String nameForSearch = employeeNames.get(item.getAssignedTo());
                            if (nameForSearch != null) {
                                searchText += " " + nameForSearch;
                            }
                        }

                        String groupStatus = "PENDING";

                        if (allComplete) {
                            groupStatus = "COMPLETED";
                        } else if (hasProgress) {
                            groupStatus = "IN_PROGRESS";
                        } else if (hasRejection) {
                            groupStatus = "REJECTED";
                        }
                %>

                    <tr class="task-group-main-row"
                        data-search="<%=safe(searchText.toLowerCase())%>">

                        <td class="group-cell">
                            <div class="group-number">
                                📋 Group <%=groupNumber%>
                            </div>

                            <div class="group-meta">
                                <%=group.size()%> employee assignment<%=group.size() == 1 ? "" : "s"%>
                            </div>

                            <div style="margin-top:8px;">
                                <span class="status status-<%=statusClass(groupStatus)%>">
                                    <%=safe(displayStatus(groupStatus))%>
                                </span>
                            </div>
                        </td>

                        <td>
                            <strong class="task-title">
                                <%=safe(firstTask.getTaskTitle())%>
                            </strong>

                            <div class="task-description">
                                <%=safe(firstTask.getDescription())%>
                            </div>
                        </td>

                        <td class="group-summary">
                            <div class="member-count">
                                👥 <%=group.size()%> Member<%=group.size() == 1 ? "" : "s"%>
                            </div>

                            <div class="member-preview">
                                <%
                                    int avatarCount = 0;

                                    for (Task memberTask : group) {
                                        if (avatarCount >= 4) break;

                                        String memberIdForAvatar = memberTask.getAssignedTo();
                                        String memberNameForAvatar = employeeNames.get(memberIdForAvatar);

                                        String initials = memberNameForAvatar != null
                                                && !memberNameForAvatar.trim().isEmpty()
                                                ? memberNameForAvatar.substring(0, 1).toUpperCase()
                                                : "E";
                                %>
                                    <span class="member-avatar"
                                          title="<%=safe(memberNameForAvatar == null ? memberIdForAvatar : memberNameForAvatar)%>">
                                        <%=safe(initials)%>
                                    </span>
                                <%
                                        avatarCount++;
                                    }

                                    if (group.size() > 4) {
                                %>
                                    <span class="member-more">+<%=group.size() - 4%></span>
                                <% } %>
                            </div>

                            <button type="button"
                                    class="view-members-btn"
                                    id="viewMembersButton-<%=groupNumber%>"
                                    onclick="toggleTaskMembers('<%=groupNumber%>', this)">
                                👥 View Members
                                <span class="arrow">▼</span>
                            </button>
                        </td>

                        <td>
                            <span class="priority-badge">
                                🔥 <%=safe(firstTask.getPriority())%>
                            </span>
                        </td>

                        <td>
                            <div style="font-size:12px;line-height:1.8;">
                                <div>🟢 <strong>Start:</strong>
                                    <%=safe(util.DateFmt.date(firstTask.getStartDate()))%>
                                </div>

                                <div>🔴 <strong>Due:</strong>
                                    <%=safe(util.DateFmt.date(firstTask.getDueDate()))%>
                                </div>
                            </div>
                        </td>

                        <td>
                            <% if (firstTask.getInstructionFile() != null
                                    && !firstTask.getInstructionFile().trim().isEmpty()) { %>

                                <a href="<%=contextPath%>/task-file?id=<%=firstTask.getId()%>&amp;type=instruction"
                                   target="_blank"
                                   rel="noopener noreferrer">
                                    📎 View File
                                </a>

                            <% } else { %>
                                <span style="color:#94a3b8;">No file</span>
                            <% } %>
                        </td>
                    </tr>

                    <tr class="group-detail-row"
                        id="taskMembersRow-<%=groupNumber%>">

                        <td colspan="6">
                            <div class="group-detail-panel">

                                <div class="group-detail-heading">
                                    <div>
                                        <h3>👥 Employees Assigned to: <%=safe(firstTask.getTaskTitle())%></h3>
                                        <p>Each employee's assignment, status and actions are managed separately.</p>
                                    </div>

                                    <span class="status status-pending">
                                        <%=group.size()%> Member<%=group.size() == 1 ? "" : "s"%>
                                    </span>
                                </div>

                                <div style="overflow-x:auto;">
                                    <table class="member-table">
                                        <thead>
                                            <tr>
                                                <th>Employee</th>
                                                <th>Assignment ID</th>
                                                <th>Individual Status</th>
                                                <th>⭐ Rating</th>
                                                <th>Actions</th>
                                            </tr>
                                        </thead>

                                        <tbody>

                                        <% for (Task employeeTask : group) {
                                            String empId = employeeTask.getAssignedTo();
                                            String empName = employeeNames.get(empId);

                                            String individualStatus = employeeTask.getStatus();

                                            if (individualStatus == null ||
                                                    individualStatus.trim().isEmpty()) {
                                                individualStatus = "ASSIGNED";
                                            }

                                            String initials = empName != null
                                                    && !empName.trim().isEmpty()
                                                    ? empName.substring(0,1).toUpperCase()
                                                    : "E";
                                        %>

                                            <tr>
                                                <td>
                                                    <div class="member-person">
                                                        <span class="member-avatar">
                                                            <%=safe(initials)%>
                                                        </span>

                                                        <span>
                                                            <strong>
                                                                <%=safe(empName == null ? empId : empName)%>
                                                            </strong>

                                                            <small>
                                                                ID: <%=safe(empId)%>
                                                            </small>
                                                        </span>
                                                    </div>
                                                </td>

                                                <td>
                                                    <strong>#<%=safe(employeeTask.getId())%></strong>
                                                </td>

                                                <td>
                                                    <span class="status status-<%=statusClass(individualStatus)%>">
                                                        <%=safe(displayStatus(individualStatus))%>
                                                    </span>
                                                </td>

                                                <td>
                                                    <%=employeeTask.getManagerRating() == null
                                                            ? "—"
                                                            : "⭐ " + safe(employeeTask.getManagerRating())%>
                                                </td>

                                                <td>
                                                    <div class="member-actions">

                                                        <button type="button"
                                                                class="btn btn-light"
                                                                onclick="openEditTaskModal(this)"
                                                                data-id="<%=safe(employeeTask.getId())%>"
                                                                data-title="<%=safe(employeeTask.getTaskTitle())%>"
                                                                data-description="<%=safe(employeeTask.getDescription())%>"
                                                                data-employee="<%=safe(employeeTask.getAssignedTo())%>"
                                                                data-department="<%=safe(employeeTask.getDepartment())%>"
                                                                data-priority="<%=safe(employeeTask.getPriority())%>"
                                                                data-start="<%=safe(employeeTask.getStartDate())%>"
                                                                data-due="<%=safe(employeeTask.getDueDate())%>">
                                                            ✏️ Edit
                                                        </button>

                                                        <button type="button"
                                                                class="btn"
                                                                onclick="openReviewModal(); openReviewGroupForEmployee('<%=groupNumber%>', '<%=safe(employeeTask.getId())%>')">
                                                            🔍 Review
                                                        </button>

                                                        <form action="<%=contextPath%>/tasks"
                                                              method="post"
                                                              onsubmit="return confirm('Delete this assignment for <%=safe(empId)%>? Other employee assignments will remain.');">

                                                            <input type="hidden" name="action" value="delete">
                                                            <input type="hidden" name="id"
                                                                   value="<%=safe(employeeTask.getId())%>">

                                                            <button type="submit" class="btn btn-danger">
                                                                🗑️ Delete
                                                            </button>
                                                        </form>
                                                    </div>
                                                </td>
                                            </tr>

                                        <% } %>

                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </td>
                    </tr>

                <% } %>

                </tbody>
            </table>
        </div>
    </div>

    <!-- TEAM MEMBERS -->

    <div class="section" id="teamMembers">
        <h2>👥 View Team Members</h2>

        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Employee ID</th>
                        <th>Name</th>
                        <th>Designation</th>
                        <th>Department</th>
                        <th>Status</th>
                    </tr>
                </thead>

                <tbody>
                <%
                try (Connection memberCon = DriverManager.getConnection(
                        "jdbc:mysql://localhost:3306/employee_db", "root", "root");
                     PreparedStatement memberPs = memberCon.prepareStatement(
                        "SELECT DISTINCT e.employee_id, e.name, e.designation, " +
                        "e.department, e.status " +
                        "FROM team_members tm " +
                        "JOIN employees e ON tm.employee_id=e.employee_id " +
                        "JOIN teams t ON tm.team_id=t.team_id " +
                        "WHERE t.manager_id=? AND tm.status='ACTIVE' " +
                        "ORDER BY e.name")) {

                    memberPs.setString(1, managerId);

                    try (ResultSet memberRs = memberPs.executeQuery()) {
                        boolean found = false;

                        while (memberRs.next()) {
                            found = true;
                            String memberStatus = memberRs.getString("status");
                %>

                    <tr>
                        <td><%=safe(memberRs.getString("employee_id"))%></td>
                        <td><%=safe(memberRs.getString("name"))%></td>
                        <td><%=safe(memberRs.getString("designation"))%></td>
                        <td><%=safe(memberRs.getString("department"))%></td>
                        <td>
                            <span class="status status-<%=statusClass(memberStatus)%>">
                                <%=safe(displayStatus(memberStatus))%>
                            </span>
                        </td>
                    </tr>

                <%
                        }

                        if (!found) {
                %>
                    <tr><td colspan="5">No team members found.</td></tr>
                <%
                        }
                    }
                } catch (Exception e) {
                    application.log("Error loading team members", e);
                }
                %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- APPLY LEAVE -->

    <div class="section" id="leave">
        <h2>🗓️ Apply Leave</h2>

        <form action="<%=contextPath%>/manager" method="post">
            <input type="hidden" name="action" value="applyLeave">

            <div class="form-row">
                <div class="form-group">
                    <label>Leave Type *</label>
                    <select name="leaveType" required>
                        <option value="">Select Leave Type</option>
                        <option value="CASUAL">CASUAL</option>
                        <option value="SICK">SICK</option>
                        <option value="PERSONAL">PERSONAL</option>
                    </select>
                </div>

                <div class="form-group">
                    <label>From Date *</label>
                    <input type="date" name="fromDate" required>
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label>To Date *</label>
                    <input type="date" name="toDate" required>
                </div>

                <div class="form-group">
                    <label>Reason *</label>
                    <input type="text" name="reason" required>
                </div>
            </div>

            <button type="submit" class="btn">📨 Apply Leave</button>
        </form>
    </div>

    <!-- LEAVE STATUS -->

    <div class="section" id="leaveStatus">
        <h2>📄 Leave Status</h2>

        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Leave ID</th>
                        <th>Leave Type</th>
                        <th>From Date</th>
                        <th>To Date</th>
                        <th>Reason</th>
                        <th>Status</th>
                        <th>Applied Date</th>
                    </tr>
                </thead>

                <tbody>
                <%
                try (Connection leaveCon = DriverManager.getConnection(
                        "jdbc:mysql://localhost:3306/employee_db", "root", "root");
                     PreparedStatement leavePs = leaveCon.prepareStatement(
                        "SELECT leave_id, leave_type, from_date, to_date, reason, " +
                        "status, applied_date FROM leave_requests " +
                        "WHERE employee_id=? ORDER BY applied_date DESC")) {

                    leavePs.setString(1, managerId);

                    try (ResultSet leaveRs = leavePs.executeQuery()) {
                        boolean found = false;

                        while (leaveRs.next()) {
                            found = true;
                            String leaveStatus = leaveRs.getString("status");
                %>

                    <tr>
                        <td><%=leaveRs.getInt("leave_id")%></td>
                        <td><%=safe(leaveRs.getString("leave_type"))%></td>
                        <td><%=safe(util.DateFmt.date(leaveRs.getDate("from_date")))%></td>
                        <td><%=safe(util.DateFmt.date(leaveRs.getDate("to_date")))%></td>
                        <td><%=safe(leaveRs.getString("reason"))%></td>
                        <td>
                            <span class="status status-<%=statusClass(leaveStatus)%>">
                                <%=safe(displayStatus(leaveStatus))%>
                            </span>
                        </td>
                        <td><%=safe(util.DateFmt.date(leaveRs.getDate("applied_date")))%></td>
                    </tr>

                <%
                        }

                        if (!found) {
                %>
                    <tr><td colspan="7">No leave requests found.</td></tr>
                <%
                        }
                    }
                } catch (Exception e) {
                    application.log("Error loading leave status", e);
                }
                %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- MY PAYSLIPS: visible only after the admin has marked the salary PAID -->

    <div class="section" id="payslips">
        <h2>💰 My Payslips</h2>
        <p style="color:#64748b;font-size:13px;margin:0 0 12px">
            A payslip appears here as soon as the admin pays your salary. You can view it or download it.
        </p>

        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Pay Period</th>
                        <th>Gross Salary</th>
                        <th>Net Salary</th>
                        <th>Status</th>
                        <th>Payslip</th>
                    </tr>
                </thead>
                <tbody>
                <%
                String[] slipMonths = {"January","February","March","April","May","June",
                    "July","August","September","October","November","December"};
                try {
                    java.util.List<model.Payroll> slips =
                        new DAO.PayrollDAO().searchPayroll(0, 0, "", "PAID", managerId);
                    if (slips.isEmpty()) {
                %>
                    <tr><td colspan="5" style="text-align:center">No paid payslips yet.</td></tr>
                <%
                    }
                    for (model.Payroll sp : slips) {
                        String slipUrl = contextPath + "/manager?action=salarySlip&payrollId=" + sp.getId();
                %>
                    <tr>
                        <td><strong><%=slipMonths[sp.getPayrollMonth() - 1]%> <%=sp.getPayrollYear()%></strong></td>
                        <td>&#8377;<%=sp.getGrossSalary() == null ? "0.00" : String.format("%,.2f", sp.getGrossSalary())%></td>
                        <td><strong>&#8377;<%=sp.getNetSalary() == null ? "0.00" : String.format("%,.2f", sp.getNetSalary())%></strong></td>
                        <td><span class="status status-completed">PAID</span></td>
                        <td>
                            <a class="slip-btn" href="<%=slipUrl%>" target="_blank">👁 View</a>
                            <a class="slip-btn slip-btn-primary" href="<%=slipUrl%>&download=1">⬇ Download</a>
                        </td>
                    </tr>
                <%
                    }
                } catch (Exception e) {
                    application.log("Error loading payslips", e);
                %>
                    <tr><td colspan="5">Unable to load payslips.</td></tr>
                <%
                }
                %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- AUDIT LOGS (view only: the manager's own activity + team members' activity) -->

    <div class="section" id="auditLogs">
        <h2>🛡️ Audit Logs</h2>
        <p style="margin:4px 0 16px;color:#64748b;font-size:13px">A read-only record of your activity and the activity of the members of your teams.</p>
<%@ include file="/WEB-INF/admin/_audit_embed.jspf" %>
    </div>

    <!-- MY TEAMS -->

    <div class="section" id="myTeams">
        <h2>🏢 My Teams</h2>

        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Team ID</th>
                        <th>Team Name</th>
                        <th>Department</th>
                        <th>Manager</th>
                        <th>Status</th>
                    </tr>
                </thead>

                <tbody>
                <%
                try (Connection myTeamCon = DriverManager.getConnection(
                        "jdbc:mysql://localhost:3306/employee_db", "root", "root");
                     PreparedStatement myTeamPs = myTeamCon.prepareStatement(
                        "SELECT t.team_id, t.team_name, t.department, t.manager_id, " +
                        "e.name AS manager_name, t.status " +
                        "FROM teams t LEFT JOIN employees e " +
                        "ON t.manager_id=e.employee_id " +
                        "WHERE t.manager_id=? ORDER BY t.team_id DESC")) {

                    myTeamPs.setString(1, managerId);

                    try (ResultSet myTeamRs = myTeamPs.executeQuery()) {
                        boolean found = false;

                        while (myTeamRs.next()) {
                            found = true;
                            String teamStatus = myTeamRs.getString("status");
                %>

                    <tr>
                        <td><%=myTeamRs.getInt("team_id")%></td>
                        <td><%=safe(myTeamRs.getString("team_name"))%></td>
                        <td><%=safe(myTeamRs.getString("department"))%></td>
                        <td><%=safe(myTeamRs.getString("manager_name"))%></td>
                        <td>
                            <span class="status status-<%=statusClass(teamStatus)%>">
                                <%=safe(displayStatus(teamStatus))%>
                            </span>
                        </td>
                    </tr>

                <%
                        }

                        if (!found) {
                %>
                    <tr><td colspan="5">No teams assigned to you.</td></tr>
                <%
                        }
                    }
                } catch (Exception e) {
                    application.log("Error loading manager teams", e);
                }
                %>
                </tbody>
            </table>
        </div>
    </div>

    </div><!-- /.content -->

</div>

<!-- =========================
     CREATE TASK MODAL
     ========================= -->

<div class="modal-overlay" id="taskModal"
     onclick="closeTaskModalOutside(event)">

    <div class="task-modal" role="dialog" aria-modal="true">

        <div class="modal-header">
            <div>
                <h2 id="taskModalTitle">📝 Create &amp; Assign Task</h2>
                <p>Select a team first, then choose one or more employees.</p>
            </div>

            <button type="button" class="modal-close"
                    onclick="closeTaskModal()" aria-label="Close">&times;</button>
        </div>

        <div class="modal-body">
            <form action="<%=contextPath%>/tasks"
                  method="post"
                  enctype="multipart/form-data"
                  id="createTaskForm">

                <input type="hidden" name="action" value="create">

                <div class="form-group">
                    <label>📝 Task Title *</label>
                    <input type="text" name="taskTitle" maxlength="150"
                           placeholder="Enter task title" required>
                </div>

                <div class="form-group">
                    <label>🏢 Select Team *</label>
                    <select name="teamId" id="taskTeamSelect" required>
                        <option value="">Loading your teams...</option>
                    </select>
                    <p id="teamLoadMessage" class="loading-text"></p>
                </div>

                <div class="form-group">
                    <label>👥 Select Employees *</label>

                    <div class="employee-picker">
                        <div class="employee-picker-toolbar">
                            <strong id="employeeHeading">Select a team first</strong>

                            <div>
                                <button type="button" id="selectAllEmployees">Select All</button>
                                &nbsp;|&nbsp;
                                <button type="button" id="clearEmployees">Clear</button>
                            </div>
                        </div>

                        <div class="employee-list" id="employeeList">
                            <div class="employee-message">
                                Choose a team to load its employees.
                            </div>
                        </div>

                        <div class="employee-count" id="employeeCount">
                            0 employees selected
                        </div>
                    </div>
                </div>

                <div class="form-group">
                    <label>📄 Task Description *</label>
                    <textarea name="description" maxlength="1000"
                              placeholder="Describe the task and expected result"
                              required></textarea>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label>🏷️ Department</label>
                        <input type="text" name="department" maxlength="100">
                    </div>

                    <div class="form-group">
                        <label>🔥 Priority *</label>
                        <select name="priority" required>
                            <option value="LOW">LOW</option>
                            <option value="MEDIUM" selected>MEDIUM</option>
                            <option value="HIGH">HIGH</option>
                        </select>
                    </div>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label>📅 Start Date *</label>
                        <input type="date" name="startDate"
                               id="createStartDate" required>
                    </div>

                    <div class="form-group">
                        <label>⏳ Due Date *</label>
                        <input type="date" name="dueDate"
                               id="createDueDate" required>
                    </div>
                </div>

                <div class="form-group">
                    <label>📎 Instruction File (PDF, DOC, DOCX)</label>
                    <input class="file-input" type="file" name="instructionFile"
                           accept=".pdf,.doc,.docx">
                </div>

                <div class="modal-footer">
                    <button type="button" class="btn btn-cancel"
                            onclick="closeTaskModal()">Cancel</button>

                    <button type="submit" class="btn" id="createTaskButton">
                        ✅ Create &amp; Assign Task
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- =========================
     EDIT TASK MODAL
     ========================= -->

<div class="modal-overlay" id="editTaskModal"
     onclick="closeEditTaskModalOutside(event)">

    <div class="task-modal" role="dialog" aria-modal="true">

        <div class="modal-header">
            <div>
                <h2>✏️ Edit Task Assignment</h2>
                <p>Update the selected employee's assignment.</p>
            </div>

            <button type="button" class="modal-close"
                    onclick="closeEditTaskModal()" aria-label="Close">&times;</button>
        </div>

        <div class="modal-body">
            <form action="<%=contextPath%>/tasks"
                  method="post"
                  enctype="multipart/form-data"
                  id="editTaskForm">

                <input type="hidden" name="action" value="update">
                <input type="hidden" name="id" id="editTaskId">

                <div class="form-group">
                    <label>📝 Task Title *</label>
                    <input type="text" name="taskTitle"
                           id="editTaskTitle" maxlength="150" required>
                </div>

                <div class="form-group">
                    <label>👤 Employee ID *</label>
                    <input type="text" name="assignedTo"
                           id="editTaskEmployee" required>
                </div>

                <div class="form-group">
                    <label>📄 Task Description *</label>
                    <textarea name="description"
                              id="editTaskDescription"
                              maxlength="1000" required></textarea>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label>🏷️ Department</label>
                        <input type="text" name="department"
                               id="editTaskDepartment" maxlength="100">
                    </div>

                    <div class="form-group">
                        <label>🔥 Priority *</label>
                        <select name="priority" id="editTaskPriority" required>
                            <option value="LOW">LOW</option>
                            <option value="MEDIUM">MEDIUM</option>
                            <option value="HIGH">HIGH</option>
                        </select>
                    </div>
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label>📅 Start Date *</label>
                        <input type="date" name="startDate"
                               id="editTaskStart" required>
                    </div>

                    <div class="form-group">
                        <label>⏳ Due Date *</label>
                        <input type="date" name="dueDate"
                               id="editTaskDue" required>
                    </div>
                </div>

                <div class="form-group">
                    <label>📎 Replace Instruction File</label>
                    <input class="file-input" type="file"
                           name="instructionFile" accept=".pdf,.doc,.docx">
                </div>

                <div class="modal-footer">
                    <button type="button" class="btn btn-cancel"
                            onclick="closeEditTaskModal()">Cancel</button>

                    <button type="submit" class="btn">💾 Save Changes</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- =========================
     REVIEW EMPLOYEES MODAL
     ========================= -->

<div class="modal-overlay" id="reviewModal"
     onclick="closeReviewModalOutside(event)">

    <div class="task-modal review-modal" role="dialog" aria-modal="true">

        <div class="modal-header">
            <div>
                <h2>⭐ Review Employee Work</h2>
                <p>Open a task group, choose an employee, and review their submission.</p>
            </div>

            <button type="button" class="modal-close"
                    onclick="closeReviewModal()" aria-label="Close">&times;</button>
        </div>

        <div class="modal-body">

            <div class="review-intro">
                <strong>📌 Review instructions</strong>
                <p>
                    Each task group contains the employees assigned to that task.
                    Open the group and select an employee to view their own work proof,
                    task status, rating and manager remarks.
                </p>
            </div>

            <% if (groupedTasks.isEmpty()) { %>
                <div class="empty-state">
                    📭 No tasks are available to review yet.
                </div>
            <% } %>

            <%
                int reviewGroupNumber = 0;

                for (Map.Entry<String, List<Task>> entry : groupedTasks.entrySet()) {
                    List<Task> reviewGroup = entry.getValue();

                    if (reviewGroup == null || reviewGroup.isEmpty()) {
                        continue;
                    }

                    reviewGroupNumber++;

                    Task groupFirstTask = reviewGroup.get(0);

                    String groupStatus = "PENDING";
                    boolean allReviewCompleted = true;
                    boolean reviewHasProgress = false;
                    boolean reviewHasRejected = false;

                    for (Task groupTask : reviewGroup) {
                        String st = groupTask.getStatus();

                        if ("IN_PROGRESS".equalsIgnoreCase(st)) {
                            reviewHasProgress = true;
                            allReviewCompleted = false;
                        } else if ("REJECTED".equalsIgnoreCase(st)) {
                            reviewHasRejected = true;
                            allReviewCompleted = false;
                        } else if (!"COMPLETED".equalsIgnoreCase(st)) {
                            allReviewCompleted = false;
                        }
                    }

                    if (allReviewCompleted) {
                        groupStatus = "COMPLETED";
                    } else if (reviewHasProgress) {
                        groupStatus = "IN_PROGRESS";
                    } else if (reviewHasRejected) {
                        groupStatus = "REJECTED";
                    }
            %>

                <div class="review-group"
                     id="reviewGroup-<%=reviewGroupNumber%>">

                    <div class="review-group-header">
                        <div>
                            <h3>📋 <%=safe(groupFirstTask.getTaskTitle())%></h3>

                            <p>
                                Task Group <%=reviewGroupNumber%>
                                &nbsp;|&nbsp;
                                👥 <%=reviewGroup.size()%> employee assignment(s)
                            </p>

                            <div style="margin-top:8px;">
                                <span class="status status-<%=statusClass(groupStatus)%>">
                                    <%=safe(displayStatus(groupStatus))%>
                                </span>
                            </div>
                        </div>

                        <button type="button"
                                class="btn btn-outline"
                                id="groupButton-<%=reviewGroupNumber%>"
                                onclick="toggleReviewGroup('<%=reviewGroupNumber%>')">
                            👥 View Employees ▼
                        </button>
                    </div>

                    <div class="review-group-body"
                         id="reviewGroupBody-<%=reviewGroupNumber%>">

                        <p style="font-size:12px;color:#64748b;margin-bottom:13px;">
                            Select the employee whose work you want to review.
                        </p>

                        <%
                            int employeeReviewNumber = 0;

                            for (Task task : reviewGroup) {
                                employeeReviewNumber++;

                                String employeeStatus = task.getStatus();

                                if (employeeStatus == null ||
                                        employeeStatus.trim().isEmpty()) {
                                    employeeStatus = "ASSIGNED";
                                }

                                String employeeId = task.getAssignedTo();
                                String employeeName = employeeNames.get(employeeId);

                                String detailId =
                                        "reviewDetail-" + reviewGroupNumber +
                                        "-" + employeeReviewNumber;

                                String employeeInitial =
                                        employeeName != null &&
                                        !employeeName.trim().isEmpty()
                                        ? employeeName.substring(0, 1).toUpperCase()
                                        : "E";
                        %>

                            <div class="review-employee-row"
                                 data-task-id="<%=safe(task.getId())%>">

                                <div class="review-employee-left">
                                    <span class="member-avatar">
                                        <%=safe(employeeInitial)%>
                                    </span>

                                    <div>
                                        <h4>
                                            👤 <%=safe(employeeName == null
                                                    ? employeeId
                                                    : employeeName)%>
                                        </h4>

                                        <p>
                                            Employee ID: <%=safe(employeeId)%>
                                            &nbsp;|&nbsp;
                                            Task ID: <%=safe(task.getId())%>
                                        </p>

                                        <div style="margin-top:7px;">
                                            <span class="status status-<%=statusClass(employeeStatus)%>">
                                                <%=safe(displayStatus(employeeStatus))%>
                                            </span>
                                        </div>
                                    </div>
                                </div>

                                <button type="button"
                                        class="btn"
                                        onclick="toggleEmployeeReview('<%=detailId%>', this)">
                                    🔍 Review Work
                                </button>
                            </div>

                            <div class="employee-review-detail" id="<%=detailId%>">

                                <h3 style="font-size:15px;margin-bottom:14px;">
                                    ⭐ Employee Review Details
                                </h3>

                                <div class="review-info-grid">
                                    <div class="review-info">
                                        <strong>👤 Employee ID</strong>
                                        <span><%=safe(employeeId)%></span>
                                    </div>

                                    <div class="review-info">
                                        <strong>🔥 Priority</strong>
                                        <span><%=safe(task.getPriority())%></span>
                                    </div>

                                    <div class="review-info">
                                        <strong>📅 Start Date</strong>
                                        <span><%=safe(util.DateFmt.date(task.getStartDate()))%></span>
                                    </div>

                                    <div class="review-info">
                                        <strong>⏳ Due Date</strong>
                                        <span><%=safe(util.DateFmt.date(task.getDueDate()))%></span>
                                    </div>

                                    <div class="review-info">
                                        <strong>📊 Status</strong>
                                        <span><%=safe(displayStatus(employeeStatus))%></span>
                                    </div>

                                    <div class="review-info">
                                        <strong>🏷️ Department</strong>
                                        <span><%=safe(task.getDepartment())%></span>
                                    </div>
                                </div>

                                <div class="proof-box">
                                    <h4>📄 Task Description</h4>
                                    <p><%=safe(task.getDescription())%></p>
                                </div>

                                <div class="proof-box">
                                    <h4>💬 Employee Comment / Work Summary</h4>
                                    <p><%=task.getEmployeeComment() == null ||
                                            task.getEmployeeComment().trim().isEmpty()
                                            ? "Employee has not submitted a comment yet."
                                            : safe(task.getEmployeeComment())%></p>
                                </div>

                                <div class="proof-box">
                                    <h4>📎 Employee Work Proof</h4>

                                    <%
                                        String proofFiles = task.getWorkProofFile();
                                        List<String> uploadedProofFiles =
                                                new ArrayList<String>();

                                        if (proofFiles != null &&
                                                !proofFiles.trim().isEmpty()) {
                                            String[] proofArray = proofFiles.split("\\|");

                                            for (String proofFile : proofArray) {
                                                if (proofFile != null &&
                                                        !proofFile.trim().isEmpty()) {
                                                    uploadedProofFiles.add(proofFile.trim());
                                                }
                                            }
                                        }
                                    %>

                                    <% if (!uploadedProofFiles.isEmpty()) { %>
                                        <p>
                                            Total uploaded files:
                                            <strong><%=uploadedProofFiles.size()%></strong>
                                        </p>

                                        <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:12px;">
                                            <% for (int i = 0; i < uploadedProofFiles.size(); i++) { %>

                                                <a class="btn btn-light"
                                                   href="<%=contextPath%>/task-file?id=<%=task.getId()%>&amp;type=proof&amp;fileIndex=<%=i%>"
                                                   target="_blank"
                                                   rel="noopener noreferrer">
                                                    📄 View Proof <%=i + 1%>
                                                </a>

                                            <% } %>
                                        </div>
                                    <% } else { %>
                                        <p>No work proof has been uploaded by this employee yet.</p>
                                    <% } %>
                                </div>

                                <div class="proof-box">
                                    <h4>📘 Task Instructions</h4>

                                    <% if (task.getInstructionFile() != null &&
                                            !task.getInstructionFile().trim().isEmpty()) { %>

                                        <a href="<%=contextPath%>/task-file?id=<%=task.getId()%>&amp;type=instruction"
                                           target="_blank"
                                           rel="noopener noreferrer">
                                            📎 Download Instructions
                                        </a>

                                    <% } else { %>
                                        <p>No instruction file attached.</p>
                                    <% } %>
                                </div>

                                <div class="proof-box">
                                    <h4>⭐ Previous Manager Review</h4>

                                    <p>
                                        Rating:
                                        <strong>
                                            <%=task.getManagerRating() == null
                                                    ? "Not rated"
                                                    : safe(task.getManagerRating())%>
                                        </strong>
                                    </p>

                                    <p style="margin-top:6px;">
                                        Remarks:
                                        <%=task.getManagerRemarks() == null ||
                                                task.getManagerRemarks().trim().isEmpty()
                                                ? "No remarks yet."
                                                : safe(task.getManagerRemarks())%>
                                    </p>
                                </div>

                                <form class="review-form"
                                      action="<%=contextPath%>/tasks"
                                      method="post">

                                    <h4>⭐ Manager Review &amp; Remarks</h4>

                                    <input type="hidden" name="action" value="review">
                                    <input type="hidden" name="id"
                                           value="<%=safe(task.getId())%>">

                                    <div class="form-row">
                                        <div class="form-group">
                                            <label>📊 Update Task Status *</label>

                                            <select name="status" required>
                                                <option value="IN_PROGRESS"
                                                    <%= "IN_PROGRESS".equalsIgnoreCase(employeeStatus)
                                                            ? "selected" : "" %>>
                                                    IN PROGRESS
                                                </option>

                                                <option value="COMPLETED"
                                                    <%= "COMPLETED".equalsIgnoreCase(employeeStatus)
                                                            ? "selected" : "" %>>
                                                    COMPLETED
                                                </option>

                                                <option value="REJECTED"
                                                    <%= "REJECTED".equalsIgnoreCase(employeeStatus)
                                                            ? "selected" : "" %>>
                                                    REJECTED
                                                </option>
                                            </select>
                                        </div>

                                        <div class="form-group">
                                            <label>⭐ Manager Rating *</label>

                                            <select name="managerRating" required>
                                                <option value="">Select Rating</option>

                                                <% for (int rating = 1; rating <= 5; rating++) { %>
                                                    <option value="<%=rating%>"
                                                        <%=task.getManagerRating() != null &&
                                                            task.getManagerRating().intValue() == rating
                                                            ? "selected" : ""%>>
                                                        <%=rating%> Star<%=rating == 1 ? "" : "s"%>
                                                    </option>
                                                <% } %>
                                            </select>
                                        </div>
                                    </div>

                                    <div class="form-group">
                                        <label>💬 Manager Remarks</label>
                                        <textarea name="managerRemarks"
                                                  maxlength="2000"
                                                  placeholder="Enter feedback, corrections or remarks"><%=safe(task.getManagerRemarks())%></textarea>
                                    </div>

                                    <div style="display:flex;gap:10px;flex-wrap:wrap;">
                                        <button type="submit" class="btn">
                                            💾 Save Review
                                        </button>

                                        <button type="button"
                                                class="btn btn-outline"
                                                onclick="toggleEmployeeReview('<%=detailId%>', this)">
                                            ✖ Close
                                        </button>
                                    </div>
                                </form>
                            </div>

                        <% } %>
                    </div>
                </div>

            <% } %>
        </div>
    </div>
</div>

<script>
const tasksUrl = "<%=contextPath%>/tasks";

/* =========================
   TASK MEMBERS EXPANSION
   ========================= */

function toggleTaskMembers(groupNumber, button) {
    const row = document.getElementById(
        "taskMembersRow-" + groupNumber
    );

    if (!row) return;

    const isOpen = row.classList.toggle("show");

    if (button) {
        button.classList.toggle("open", isOpen);

        button.innerHTML = isOpen
            ? "👥 Hide Members <span class='arrow'>▼</span>"
            : "👥 View Members <span class='arrow'>▼</span>";
    }
}

function filterTaskGroups() {
    const search = document.getElementById("taskSearch");
    const query = search.value.trim().toLowerCase();

    document.querySelectorAll(".task-group-main-row").forEach(function(row) {
        const content = row.getAttribute("data-search") || "";
        const detailRow = row.nextElementSibling;

        const matches = content.indexOf(query) !== -1;

        row.style.display = matches ? "" : "none";

        if (detailRow && detailRow.classList.contains("group-detail-row")) {
            if (!matches) {
                detailRow.classList.remove("show");
            }

            detailRow.style.display = matches ? "" : "none";

            if (!matches) {
                const groupButton = row.querySelector(".view-members-btn");

                if (groupButton) {
                    groupButton.classList.remove("open");
                    groupButton.innerHTML =
                        "👥 View Members <span class='arrow'>▼</span>";
                }
            }
        }
    });
}

/* =========================
   MODAL OPEN / CLOSE
   ========================= */

function openTaskModal() {
    closeReviewModal(false);
    closeEditTaskModal(false);

    document.getElementById("taskModal").classList.add("show");
    document.body.classList.add("modal-open");

    document.getElementById("createTaskForm").reset();

    document.getElementById("createTaskButton").disabled = false;
    document.getElementById("createTaskButton").textContent =
        "✅ Create & Assign Task";

    document.getElementById("taskTeamSelect").innerHTML =
        '<option value="">Loading your teams...</option>';

    document.getElementById("teamLoadMessage").textContent = "";

    document.getElementById("employeeHeading").textContent =
        "Select a team first";

    document.getElementById("employeeList").innerHTML =
        '<div class="employee-message">Choose a team to load its employees.</div>';

    document.getElementById("employeeCount").textContent =
        "0 employees selected";

    loadManagerTeams();
}

function closeTaskModal() {
    document.getElementById("taskModal").classList.remove("show");
    updateBodyScroll();
}

function closeTaskModalOutside(event) {
    if (event.target.id === "taskModal") closeTaskModal();
}

function openReviewModal() {
    closeTaskModal();
    closeEditTaskModal(false);

    document.getElementById("reviewModal").classList.add("show");
    document.body.classList.add("modal-open");
}

function closeReviewModal(updateScroll) {
    document.getElementById("reviewModal").classList.remove("show");

    if (updateScroll !== false) updateBodyScroll();
}

function closeReviewModalOutside(event) {
    if (event.target.id === "reviewModal") closeReviewModal();
}

function openEditTaskModal(button) {
    closeTaskModal();
    closeReviewModal(false);

    document.getElementById("editTaskId").value =
        button.getAttribute("data-id") || "";

    document.getElementById("editTaskTitle").value =
        button.getAttribute("data-title") || "";

    document.getElementById("editTaskDescription").value =
        button.getAttribute("data-description") || "";

    document.getElementById("editTaskEmployee").value =
        button.getAttribute("data-employee") || "";

    document.getElementById("editTaskDepartment").value =
        button.getAttribute("data-department") || "";

    document.getElementById("editTaskPriority").value =
        button.getAttribute("data-priority") || "MEDIUM";

    document.getElementById("editTaskStart").value =
        button.getAttribute("data-start") || "";

    document.getElementById("editTaskDue").value =
        button.getAttribute("data-due") || "";

    document.getElementById("editTaskModal").classList.add("show");
    document.body.classList.add("modal-open");
}

function closeEditTaskModal(updateScroll) {
    document.getElementById("editTaskModal").classList.remove("show");

    if (updateScroll !== false) updateBodyScroll();
}

function closeEditTaskModalOutside(event) {
    if (event.target.id === "editTaskModal") closeEditTaskModal();
}

function updateBodyScroll() {
    const taskOpen =
        document.getElementById("taskModal").classList.contains("show");

    const reviewOpen =
        document.getElementById("reviewModal").classList.contains("show");

    const editOpen =
        document.getElementById("editTaskModal").classList.contains("show");

    if (!taskOpen && !reviewOpen && !editOpen) {
        document.body.classList.remove("modal-open");
    }
}

/* =========================
   REVIEW GROUP EXPANSION
   ========================= */

function toggleReviewGroup(groupNumber) {
    const body = document.getElementById(
        "reviewGroupBody-" + groupNumber
    );

    const button = document.getElementById(
        "groupButton-" + groupNumber
    );

    if (!body) return;

    const isOpen = body.classList.toggle("open");

    if (button) {
        button.textContent = isOpen
            ? "👥 Hide Employees ▲"
            : "👥 View Employees ▼";
    }
}

function openReviewGroupForEmployee(groupNumber, taskId) {
    openReviewModal();

    const body = document.getElementById(
        "reviewGroupBody-" + groupNumber
    );

    const groupButton = document.getElementById(
        "groupButton-" + groupNumber
    );

    if (body && !body.classList.contains("open")) {
        body.classList.add("open");

        if (groupButton) {
            groupButton.textContent = "👥 Hide Employees ▲";
        }
    }

    const group = document.getElementById(
        "reviewGroup-" + groupNumber
    );

    if (!group) return;

    const employeeRows = group.querySelectorAll(".review-employee-row");

    for (let i = 0; i < employeeRows.length; i++) {
        if (employeeRows[i].getAttribute("data-task-id") === String(taskId)) {
            const detail = employeeRows[i].nextElementSibling;
            const reviewButton = employeeRows[i].querySelector("button");

            if (detail && detail.classList.contains("employee-review-detail")) {
                detail.classList.add("open");

                if (reviewButton) {
                    reviewButton.textContent = "🙈 Hide Review";
                }

                setTimeout(function() {
                    detail.scrollIntoView({
                        behavior: "smooth",
                        block: "start"
                    });
                }, 150);
            }

            break;
        }
    }
}

function toggleEmployeeReview(detailId, button) {
    const detail = document.getElementById(detailId);

    if (!detail) return;

    const isOpen = detail.classList.toggle("open");

    if (button) {
        button.textContent = isOpen
            ? "🙈 Hide Review"
            : "🔍 Review Work";
    }
}

/* =========================
   LOAD TEAMS FOR CREATE TASK
   ========================= */

async function loadManagerTeams() {
    const teamSelect = document.getElementById("taskTeamSelect");
    const message = document.getElementById("teamLoadMessage");

    teamSelect.innerHTML =
        '<option value="">Loading teams...</option>';

    teamSelect.disabled = true;
    message.textContent = "";

    try {
        const response = await fetch(
            tasksUrl + "?action=ajaxTeams",
            { headers: { "Accept": "application/json" } }
        );

        if (!response.ok) {
            throw new Error("Unable to load teams.");
        }

        const teams = await response.json();

        teamSelect.innerHTML = "";

        const placeholder = document.createElement("option");
        placeholder.value = "";
        placeholder.textContent = "Select your team";
        teamSelect.appendChild(placeholder);

        teams.forEach(function(team) {
            const option = document.createElement("option");
            option.value = team.id;
            option.textContent = team.name;
            teamSelect.appendChild(option);
        });

        if (teams.length === 0) {
            message.textContent =
                "No active teams are assigned to you.";
        }

    } catch (error) {
        teamSelect.innerHTML =
            '<option value="">Could not load teams</option>';

        message.textContent =
            "Unable to load teams. Please refresh and try again.";

        console.error(error);

    } finally {
        teamSelect.disabled = false;
    }

    clearEmployeeList("Choose a team to load its employees.");
}

document.getElementById("taskTeamSelect")
    .addEventListener("change", function() {
        const teamId = this.value;

        if (!teamId) {
            clearEmployeeList("Choose a team to load its employees.");
            return;
        }

        loadTeamEmployees(teamId);
    });

/* =========================
   LOAD EMPLOYEES IN SELECTED TEAM
   ========================= */

async function loadTeamEmployees(teamId) {
    const list = document.getElementById("employeeList");
    const heading = document.getElementById("employeeHeading");

    list.innerHTML =
        '<div class="loading-text">Loading employees...</div>';

    heading.textContent = "Loading employees...";
    updateEmployeeCount();

    try {
        const response = await fetch(
            tasksUrl + "?action=ajaxEmployees&teamId=" +
            encodeURIComponent(teamId),
            { headers: { "Accept": "application/json" } }
        );

        if (!response.ok) {
            throw new Error("Unable to load employees.");
        }

        const employees = await response.json();

        list.innerHTML = "";

        if (employees.length === 0) {
            list.innerHTML =
                '<div class="employee-message">No active employees are assigned to this team.</div>';

            heading.textContent = "No employees found";
            updateEmployeeCount();
            return;
        }

        heading.textContent = "Employees in selected team";

        employees.forEach(function(employee) {
            const label = document.createElement("label");
            label.className = "employee-option";

            const checkbox = document.createElement("input");
            checkbox.type = "checkbox";
            checkbox.name = "assignedEmployees";
            checkbox.value = employee.id;
            checkbox.addEventListener("change", updateEmployeeCount);

            const text = document.createElement("span");
            text.textContent = employee.name + " (" + employee.id + ")";

            label.appendChild(checkbox);
            label.appendChild(text);
            list.appendChild(label);
        });

        updateEmployeeCount();

    } catch (error) {
        list.innerHTML =
            '<div class="employee-message">Unable to load employees. Please select the team again.</div>';

        heading.textContent = "Employee loading failed";
        updateEmployeeCount();

        console.error(error);
    }
}

function clearEmployeeList(text) {
    const list = document.getElementById("employeeList");

    list.innerHTML = '<div class="employee-message"></div>';
    list.querySelector(".employee-message").textContent = text;

    document.getElementById("employeeHeading").textContent =
        "Select a team first";

    updateEmployeeCount();
}

function updateEmployeeCount() {
    const selected = document.querySelectorAll(
        '#employeeList input[name="assignedEmployees"]:checked'
    ).length;

    document.getElementById("employeeCount").textContent =
        selected + (selected === 1
            ? " employee selected"
            : " employees selected");
}

document.getElementById("selectAllEmployees")
    .addEventListener("click", function() {
        document.querySelectorAll(
            '#employeeList input[name="assignedEmployees"]'
        ).forEach(function(checkbox) {
            checkbox.checked = true;
        });

        updateEmployeeCount();
    });

document.getElementById("clearEmployees")
    .addEventListener("click", function() {
        document.querySelectorAll(
            '#employeeList input[name="assignedEmployees"]'
        ).forEach(function(checkbox) {
            checkbox.checked = false;
        });

        updateEmployeeCount();
    });

/* =========================
   VALIDATIONS
   ========================= */

document.getElementById("createTaskForm")
    .addEventListener("submit", function(event) {
        const teamId = document.getElementById("taskTeamSelect").value;

        const selectedEmployees = document.querySelectorAll(
            '#employeeList input[name="assignedEmployees"]:checked'
        );

        if (!teamId) {
            event.preventDefault();
            alert("Please select a team first.");
            return;
        }

        if (selectedEmployees.length === 0) {
            event.preventDefault();
            alert("Please select at least one employee.");
            return;
        }

        const startDate = document.getElementById("createStartDate").value;
        const dueDate = document.getElementById("createDueDate").value;

        if (startDate && dueDate && dueDate < startDate) {
            event.preventDefault();
            alert("Due date cannot be earlier than the start date.");
            return;
        }

        const button = document.getElementById("createTaskButton");
        button.disabled = true;
        button.textContent = "⏳ Assigning Tasks...";
    });

const startDateInput = document.getElementById("createStartDate");
const dueDateInput = document.getElementById("createDueDate");

if (startDateInput && dueDateInput) {
    startDateInput.addEventListener("change", function() {
        dueDateInput.min = startDateInput.value;

        if (dueDateInput.value && dueDateInput.value < startDateInput.value) {
            dueDateInput.value = startDateInput.value;
        }
    });
}

const editStartDateInput = document.getElementById("editTaskStart");
const editDueDateInput = document.getElementById("editTaskDue");

if (editStartDateInput && editDueDateInput) {
    editStartDateInput.addEventListener("change", function() {
        editDueDateInput.min = editStartDateInput.value;

        if (editDueDateInput.value && editDueDateInput.value < editStartDateInput.value) {
            editDueDateInput.value = editStartDateInput.value;
        }
    });
}

document.getElementById("editTaskForm")
    .addEventListener("submit", function(event) {
        const start = editStartDateInput.value;
        const due = editDueDateInput.value;

        if (start && due && due < start) {
            event.preventDefault();
            alert("Due date cannot be earlier than the start date.");
        }
    });

/* =========================
   REPORT DATE VALIDATION
   ========================= */

const reportFromDateInput = document.getElementById("reportFromDate");
const reportToDateInput = document.getElementById("reportToDate");

if (reportFromDateInput && reportToDateInput) {
    reportFromDateInput.addEventListener("change", function() {
        reportToDateInput.min = reportFromDateInput.value;

        if (reportToDateInput.value
                && reportToDateInput.value < reportFromDateInput.value) {
            reportToDateInput.value = reportFromDateInput.value;
        }
    });

    reportToDateInput.addEventListener("change", function() {
        reportFromDateInput.max = reportToDateInput.value;
    });
}

const reportFilterFormEl = document.getElementById("reportFilterForm");
if (reportFilterFormEl) reportFilterFormEl
    .addEventListener("submit", function(event) {
        const from = reportFromDateInput.value;
        const to = reportToDateInput.value;

        if (from && to && from > to) {
            event.preventDefault();
            alert("From Date cannot be later than To Date.");
        }
    });

function toggleReportMembers(id, button) {
    const panel = document.getElementById(id);
    if (!panel) return;
    const open = panel.style.display === "block";
    panel.style.display = open ? "none" : "block";
    button.setAttribute("aria-expanded", open ? "false" : "true");
    button.textContent = open ? "View Members" : "Hide Members";
}

document.addEventListener("keydown", function(event) {
    if (event.key === "Escape") {
        closeTaskModal();
        closeReviewModal();
        closeEditTaskModal();
    }
});
</script>

</body>
</html>