<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="java.time.*" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.List" %>
<%@ page import="model.DBcConnection" %>
<%@ page import="service.OvertimeService" %>

<%!
private String esc(Object value) {
    if (value == null) return "";
    return String.valueOf(value).replace("&","&amp;")
        .replace("<","&lt;").replace(">","&gt;")
        .replace("\"","&quot;").replace("'","&#39;");
}

private List<String> getProofFiles(String proofValue) {
    List<String> files = new ArrayList<String>();
    if (proofValue != null && !proofValue.trim().isEmpty()) {
        for (String file : proofValue.split("\\|")) {
            if (file != null && !file.trim().isEmpty()) files.add(file.trim());
        }
    }
    return files;
}

private String validDate(String value) {
    if (value == null || !value.matches("\\d{4}-\\d{2}-\\d{2}")) return "";
    try {
        LocalDate.parse(value);
        return value;
    } catch (Exception e) {
        return "";
    }
}

private String reportStatusClass(String status) {
    if (status == null) return "report-status-neutral";
    String s = status.trim().toUpperCase().replace(' ', '_');

    if ("PRESENT".equals(s) || "APPROVED".equals(s)
            || "COMPLETED".equals(s)) return "report-status-success";

    if ("ABSENT".equals(s) || "REJECTED".equals(s))
        return "report-status-danger";

    if ("IN_PROGRESS".equals(s) || "WORKING".equals(s))
        return "report-status-info";

    if ("LEAVE".equals(s) || "PENDING".equals(s)
            || "ASSIGNED".equals(s)) return "report-status-warning";

    return "report-status-neutral";
}
%>

<%
String employeeId = (String) session.getAttribute("employeeId");
if (employeeId == null) {
    response.sendRedirect(request.getContextPath() + "/login.html");
    return;
}

String employeeName = (String) session.getAttribute("name");
if (employeeName == null) employeeName = "";

String contextPath = request.getContextPath();

/* ---------- Overtime request (posted from the Overtime page of this dashboard) ---------- */
if ("POST".equalsIgnoreCase(request.getMethod())) {
    request.setCharacterEncoding("UTF-8");
    if ("request".equals(request.getParameter("otAction"))) {
        String otMsg;
        boolean otOk = true;
        try {
            LocalDate otDate = LocalDate.parse(request.getParameter("otDate"));
            double otHours = Double.parseDouble(request.getParameter("otHours"));
            OvertimeService.request(employeeId, otDate, otHours, request.getParameter("otReason"));
            otMsg = "Overtime request sent to your manager.";
        } catch (IllegalArgumentException otEx) {
            otMsg = (otEx.getMessage() == null || otEx.getMessage().isEmpty()) ? "Invalid request." : otEx.getMessage();
            otOk = false;
        } catch (Exception otEx) {
            application.log("Overtime request error", otEx);
            otMsg = "Something went wrong. Please try again.";
            otOk = false;
        }
        session.setAttribute("otFlashMsg", otMsg);
        session.setAttribute("otFlashOk", otOk ? "1" : "0");
        response.sendRedirect(contextPath + "/employee#overtime");
        return;
    }
}

String attendanceFrom = validDate(request.getParameter("attendanceFrom"));
String attendanceTo = validDate(request.getParameter("attendanceTo"));
String attendanceFilter = request.getParameter("attendanceFilter");
if (attendanceFilter == null) attendanceFilter = "";

String leaveFrom = validDate(request.getParameter("leaveFrom"));
String leaveTo = validDate(request.getParameter("leaveTo"));
String leaveFilter = request.getParameter("leaveFilter");
if (leaveFilter == null) leaveFilter = "";

String taskFrom = validDate(request.getParameter("taskFrom"));
String taskTo = validDate(request.getParameter("taskTo"));
String taskFilter = request.getParameter("taskFilter");
if (taskFilter == null) taskFilter = "";

/* Selected report dropdown */
String reportType = request.getParameter("reportType");
if (!"leave".equals(reportType) && !"task".equals(reportType)
        && !"attendance".equals(reportType)) {
    reportType = "attendance";
}

String email = "", phone = "", department = "", designation = "", salary = "";
List<String[]> myTeams = new ArrayList<String[]>();
List<String[]> todayBreaks = new ArrayList<String[]>();

String checkInTime = null, checkOutTime = null, attendanceStatus = "ABSENT";
boolean hasCheckedIn = false, hasCheckedOut = false, leaveToday = false;

String latestLeaveId = null, latestLeaveType = null, latestFromDate = null;
String latestToDate = null, latestReason = null, latestLeaveStatus = null;
String latestAppliedDate = null;

int totalTasks = 0, assignedTasks = 0, inProgressTasks = 0, completedTasks = 0;

Connection con = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {
    con = DBcConnection.getConnection();

    ps = con.prepareStatement(
        "SELECT email, phone, department, designation, salary FROM employees WHERE employee_id=?");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    if (rs.next()) {
        email = rs.getString("email");
        phone = rs.getString("phone");
        department = rs.getString("department");
        designation = rs.getString("designation");
        salary = rs.getString("salary");
    }
    rs.close(); ps.close(); rs = null; ps = null;

    ps = con.prepareStatement(
        "SELECT t.team_id,t.team_name,t.department,t.manager_id," +
        "COALESCE(m.name,e.name) AS manager_name " +
        "FROM team_members tm JOIN teams t ON tm.team_id=t.team_id " +
        "LEFT JOIN managers m ON t.manager_id=m.employee_id " +
        "LEFT JOIN employees e ON t.manager_id=e.employee_id " +
        "WHERE tm.employee_id=? AND tm.status='ACTIVE' AND t.status='ACTIVE' ORDER BY t.team_id");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    while (rs.next()) {
        myTeams.add(new String[] {
            rs.getString("team_id"), rs.getString("team_name"),
            rs.getString("department"), rs.getString("manager_id"),
            rs.getString("manager_name")
        });
    }
    rs.close(); ps.close(); rs = null; ps = null;

    ps = con.prepareStatement(
        "SELECT COUNT(*) FROM leave_requests WHERE employee_id=? " +
        "AND status='APPROVED' AND CURDATE() BETWEEN from_date AND to_date");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    if (rs.next()) leaveToday = rs.getInt(1) > 0;
    rs.close(); ps.close(); rs = null; ps = null;

    ps = con.prepareStatement(
        "SELECT leave_id,leave_type,from_date,to_date,reason,status,applied_date " +
        "FROM leave_requests WHERE employee_id=? ORDER BY leave_id DESC LIMIT 1");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    if (rs.next()) {
        latestLeaveId = rs.getString("leave_id");
        latestLeaveType = rs.getString("leave_type");
        latestFromDate = String.valueOf(rs.getDate("from_date"));
        latestToDate = String.valueOf(rs.getDate("to_date"));
        latestReason = rs.getString("reason");
        latestLeaveStatus = rs.getString("status");
        latestAppliedDate = String.valueOf(rs.getTimestamp("applied_date"));
    }
    rs.close(); ps.close(); rs = null; ps = null;

    ps = con.prepareStatement(
        "SELECT check_in_time,check_out_time,status FROM attendance " +
        "WHERE employee_id=? AND date=CURDATE()");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    if (rs.next()) {
        checkInTime = rs.getString("check_in_time");
        checkOutTime = rs.getString("check_out_time");
        attendanceStatus = rs.getString("status");
        hasCheckedIn = checkInTime != null && !checkInTime.trim().isEmpty();
        hasCheckedOut = checkOutTime != null && !checkOutTime.trim().isEmpty();
    }
    rs.close(); ps.close(); rs = null; ps = null;

    ps = con.prepareStatement(
        "SELECT break_number,break_start,break_end FROM breaks " +
        "WHERE employee_id=? AND break_date=CURDATE() ORDER BY break_number");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    while (rs.next()) {
        todayBreaks.add(new String[] {
            String.valueOf(rs.getInt("break_number")),
            rs.getString("break_start"), rs.getString("break_end")
        });
    }
    rs.close(); ps.close(); rs = null; ps = null;

    ps = con.prepareStatement(
        "SELECT COUNT(*) AS total_tasks," +
        "COALESCE(SUM(CASE WHEN UPPER(REPLACE(status,' ','_')) IN ('ASSIGNED','PENDING') " +
        "OR status IS NULL OR TRIM(status)='' THEN 1 ELSE 0 END),0) AS assigned_tasks," +
        "COALESCE(SUM(CASE WHEN UPPER(REPLACE(status,' ','_'))='IN_PROGRESS' " +
        "THEN 1 ELSE 0 END),0) AS in_progress_tasks," +
        "COALESCE(SUM(CASE WHEN UPPER(status)='COMPLETED' THEN 1 ELSE 0 END),0) " +
        "AS completed_tasks FROM tasks WHERE assigned_to=?");
    ps.setString(1, employeeId);
    rs = ps.executeQuery();
    if (rs.next()) {
        totalTasks = rs.getInt("total_tasks");
        assignedTasks = rs.getInt("assigned_tasks");
        inProgressTasks = rs.getInt("in_progress_tasks");
        completedTasks = rs.getInt("completed_tasks");
    }
} catch (Exception e) {
    application.log("Employee dashboard loading error", e);
} finally {
    try { if (rs != null) rs.close(); } catch (Exception e) {}
    try { if (ps != null) ps.close(); } catch (Exception e) {}
    try { if (con != null) con.close(); } catch (Exception e) {}
}

String currentStatus;
if (leaveToday) currentStatus = "LEAVE";
else if (!hasCheckedIn) currentStatus = "ABSENT";
else if (!hasCheckedOut) currentStatus = "WORKING";
else currentStatus = "PRESENT";

String todayStatus = currentStatus;
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Employee Dashboard - <%= util.Html.esc(util.Branding.name()) %></title>

<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:"Segoe UI",Arial,sans-serif;background:#f4f7fb;color:#263238}
.sidebar{position:fixed;left:0;top:0;width:240px;height:100vh;background:linear-gradient(180deg,#0f172a,#1e3a8a);color:white;padding:25px 18px;z-index:1000;overflow-y:auto}
.logo{font-size:22px;font-weight:bold;text-align:center;padding:15px 5px 28px}
.logo span{display:block;font-size:12px;opacity:.75;margin-top:6px;font-weight:normal}
.menu{list-style:none}.menu li{margin:7px 0}
.menu a{display:flex;gap:12px;padding:12px 14px;color:white;text-decoration:none;border-radius:9px;font-size:14px}
.menu a:hover{background:rgba(255,255,255,.15)}
.sidebar-logout{margin-top:25px}
.sidebar-logout a{display:block;text-align:center;background:#ef4444;color:white;padding:11px;border-radius:9px;text-decoration:none;font-weight:600}
.main{margin-left:240px;min-height:100vh}
.topbar{min-height:75px;background:white;display:flex;justify-content:space-between;align-items:center;padding:15px 30px;box-shadow:0 2px 8px #0000000d}
.topbar h2,.section-header h2{color:#0f172a}
.topbar p,.section-header span{color:#7b8794;font-size:12px;margin-top:3px}
.employee-info{display:flex;align-items:center;gap:12px}
.employee-info-text{text-align:right}.employee-info-text strong{display:block}
.employee-info-text span{color:#7b8794;font-size:12px}
.avatar{width:42px;height:42px;border-radius:50%;background:linear-gradient(135deg,#2563eb,#7c3aed);color:white;display:flex;align-items:center;justify-content:center;font-size:19px}
.content{padding:28px 30px}
.welcome{background:linear-gradient(135deg,#1d4ed8,#4338ca);color:white;border-radius:18px;padding:28px;margin-bottom:25px}
.welcome h1{font-size:27px;margin-bottom:8px}.welcome p{line-height:1.6}
.employee-id,.status-badge{display:inline-block;margin-top:15px;background:#ffffff2b;padding:8px 13px;border-radius:8px}
.status-badge{font-size:12px;font-weight:600}
.stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px;margin-bottom:25px}
.stat-card{background:white;border-radius:15px;padding:20px;display:flex;gap:15px;align-items:center;box-shadow:0 5px 18px #0000000a;min-width:0}
.stat-icon{width:50px;height:50px;background:#dbeafe;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:23px;flex-shrink:0}
.stat-card:nth-child(2) .stat-icon{background:#dcfce7}.stat-card:nth-child(3) .stat-icon{background:#fef3c7}
.stat-text span{display:block;font-size:12px;color:#7b8794}
.stat-text strong{display:block;margin-top:4px;color:#0f172a;font-size:21px;overflow-wrap:anywhere}
.task-stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:15px;margin-bottom:20px}
.task-stat-card{background:white;border-radius:15px;padding:20px;box-shadow:0 5px 18px #0000000a;border-left:5px solid #64748b}
.task-stat-card h3{color:#64748b;font-size:13px;margin-bottom:12px}
.task-stat-card .task-count{color:#0f172a;font-size:30px;font-weight:700}
.task-stat-card.assigned{border-left-color:#f59e0b}.task-stat-card.progress{border-left-color:#2563eb}.task-stat-card.completed{border-left-color:#16a34a}
.section-card{background:white;border-radius:16px;padding:24px;margin-bottom:25px;box-shadow:0 5px 18px #0000000a;scroll-margin-top:20px}
.section-header{display:flex;justify-content:space-between;align-items:center;gap:12px;margin-bottom:18px}
.section-header h2{font-size:20px}
.table-container{width:100%;overflow-x:auto}
table{width:100%;border-collapse:collapse}
th{background:#f8fafc;color:#475569;padding:13px 10px;font-size:12px;border-bottom:1px solid #e2e8f0;white-space:nowrap}
td{padding:13px 10px;text-align:center;border-bottom:1px solid #edf2f7;font-size:13px;color:#475569;vertical-align:top}
tr:hover{background:#f8fafc}
.status{display:inline-block;padding:6px 11px;border-radius:20px;font-size:11px;font-weight:600;white-space:nowrap}
.status-pending{background:#fef3c7;color:#92400e}.status-progress,.status-working{background:#dbeafe;color:#1d4ed8}
.status-completed,.status-present{background:#dcfce7;color:#166534}.status-leave{background:#fef3c7;color:#92400e}
.status-absent,.status-rejected{background:#fee2e2;color:#991b1b}
.btn{display:inline-block;border:none;padding:9px 14px;border-radius:8px;color:white;cursor:pointer;font-weight:600;font-size:12px;margin:3px;text-decoration:none}
.checkin{background:#16a34a}.checkout{background:#ef4444}.break-btn{background:#7c3aed}.proof-btn{background:#0f766e}
.btn:disabled{background:#cbd5e1;cursor:not-allowed}
input,select,textarea{width:100%;padding:11px;border:1px solid #d1d5db;border-radius:8px;font-family:inherit;margin-top:6px}
textarea{min-height:80px;resize:vertical}.form-group{margin-bottom:15px}
label{font-size:13px;font-weight:600;color:#475569}
.empty{padding:30px;text-align:center;color:#7b8794}.empty-icon{font-size:38px;margin-bottom:8px}
.task-card-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}
.employee-task-card{background:white;border:1px solid #e2e8f0;border-radius:14px;padding:20px;box-shadow:0 4px 14px #00000008;min-width:0}
.employee-task-card:hover{box-shadow:0 8px 22px #00000012}
.task-card-top{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;margin-bottom:12px}
.task-card-id{color:#64748b;font-size:12px;margin-bottom:6px}
.task-card-title{color:#0f172a;font-size:17px;overflow-wrap:anywhere}
.task-card-description{color:#64748b;font-size:13px;line-height:1.6;margin:12px 0;overflow-wrap:anywhere;white-space:pre-wrap}
.task-card-meta{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:15px 0}
.task-meta-item{background:#f8fafc;border-radius:9px;padding:10px;min-width:0}
.task-meta-item span{display:block;color:#64748b;font-size:11px;margin-bottom:5px}
.task-meta-item strong{color:#334155;font-size:13px;overflow-wrap:anywhere}
.task-card-actions{display:flex;flex-wrap:wrap;gap:7px;margin-top:15px}
.task-card-actions .btn{margin:0}.task-open-btn{background:#2563eb}
.task-modal{display:none;position:fixed;inset:0;background:#0f172aab;z-index:3000;padding:20px;overflow-y:auto}
.task-modal.show{display:flex;align-items:flex-start;justify-content:center}
.task-modal-content{width:100%;max-width:850px;margin:auto;background:white;border-radius:16px;overflow:hidden}
.task-modal-header{display:flex;justify-content:space-between;align-items:flex-start;gap:15px;padding:22px 25px;background:#f8fafc;border-bottom:1px solid #e2e8f0}
.task-modal-header h2{color:#0f172a;font-size:20px;overflow-wrap:anywhere}
.task-modal-header p{color:#64748b;font-size:12px;margin-top:6px}
.task-modal-close{border:0;background:#e2e8f0;color:#334155;width:36px;height:36px;border-radius:9px;font-size:22px;cursor:pointer;flex-shrink:0}
.task-modal-body{padding:24px 25px}
.task-detail-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-bottom:20px}
.task-detail-item{padding:13px;border:1px solid #e2e8f0;border-radius:10px;min-width:0}
.task-detail-item span{display:block;color:#64748b;font-size:11px;margin-bottom:6px}
.task-detail-item strong{color:#334155;font-size:13px;overflow-wrap:anywhere}
.task-modal-section{margin-top:20px}.task-modal-section h3{color:#0f172a;font-size:15px;margin-bottom:10px}
.task-modal-description,.task-remarks{color:#475569;line-height:1.7;white-space:pre-wrap;overflow-wrap:anywhere;background:#f8fafc;padding:14px;border-radius:10px}
.task-file-link{display:inline-flex;text-decoration:none;color:#1d4ed8;background:#eff6ff;border:1px solid #bfdbfe;padding:10px 13px;border-radius:9px;font-size:12px;font-weight:600;margin:3px 5px 3px 0;overflow-wrap:anywhere}
.task-upload-box{border:1px solid #e2e8f0;background:white;padding:18px;border-radius:12px;margin-top:10px}
.task-submit-btn{background:#0f766e;margin-top:5px}
.file-label{display:block;padding:10px;background:#f8fafc;border:1px dashed #94a3b8;border-radius:8px;margin-top:8px}

/* Professional Reports */
.reports-heading{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:14px;margin-bottom:24px}
.reports-heading h2{color:#0f172a;font-size:23px;font-weight:750;margin-bottom:7px}
.reports-heading p{color:#64748b;font-size:13px;line-height:1.7}
.report-employee-chip{display:inline-flex;align-items:center;gap:8px;background:#eff6ff;color:#1d4ed8;border:1px solid #bfdbfe;padding:10px 14px;border-radius:10px;font-size:12px;font-weight:700}
.report-panel{background:#fff;border:1px solid #e2e8f0;border-radius:15px;margin-bottom:24px;overflow:hidden;box-shadow:0 4px 14px rgba(15,23,42,.035)}
.report-panel-header{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:13px;padding:20px 22px;background:#fff;border-bottom:1px solid #edf2f7}
.report-title-wrap{display:flex;align-items:center;gap:13px;min-width:0}
.report-icon{width:46px;height:46px;display:flex;align-items:center;justify-content:center;border-radius:12px;font-size:21px;flex-shrink:0}
.report-icon.attendance{background:#dbeafe;color:#1d4ed8}
.report-icon.leave{background:#fef3c7;color:#92400e}
.report-icon.task{background:#dcfce7;color:#166534}
.report-title-wrap h3{color:#0f172a;font-size:16px;font-weight:750;margin-bottom:5px}
.report-title-wrap p{color:#64748b;font-size:12px;line-height:1.6}
.report-count{display:inline-flex;align-items:center;background:#f1f5f9;color:#475569;border:1px solid #e2e8f0;border-radius:20px;padding:7px 11px;font-size:11px;font-weight:700;white-space:nowrap}
.report-filter-area{padding:18px 22px;background:#f8fafc;border-bottom:1px solid #e2e8f0}
.report-filters{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;align-items:end;margin:0;padding:0;background:transparent;border-radius:0}
.report-filters label{display:block;color:#475569;font-size:12px;font-weight:700}
.report-filters input,.report-filters select{width:100%;height:42px;padding:9px 11px;margin-top:7px;margin-bottom:0;background:#fff;border:1px solid #cbd5e1;border-radius:8px;color:#334155;font-size:12px;outline:none}
.report-filters input:focus,.report-filters select:focus{border-color:#3b82f6;box-shadow:0 0 0 3px rgba(59,130,246,.12)}
.report-actions{display:flex;align-items:center;flex-wrap:wrap;gap:7px}
.report-actions .btn{min-height:40px;display:inline-flex;align-items:center;justify-content:center;margin:0;white-space:nowrap}
.report-submit{background:#1d4ed8}
.report-reset{background:#64748b}
.report-table-wrap{padding:0 18px 18px;overflow-x:auto}
.report-table-wrap table{width:100%;min-width:640px;border-collapse:separate;border-spacing:0}
.report-table-wrap th{background:#f8fafc;color:#64748b;text-transform:uppercase;letter-spacing:.045em;font-size:10px;font-weight:750;padding:14px 12px;border-bottom:1px solid #e2e8f0;text-align:left}
.report-table-wrap td{font-size:12px;color:#334155;padding:14px 12px;border-bottom:1px solid #edf2f7;text-align:left;line-height:1.6;max-width:250px;overflow-wrap:anywhere}
.report-table-wrap tbody tr:hover{background:#f8fbff}
.report-table-wrap tbody tr:last-child td{border-bottom:0}
.report-table-wrap .report-empty-cell{text-align:center;color:#94a3b8;padding:28px 12px}
.report-status{display:inline-block;padding:5px 10px;border-radius:20px;font-size:10px;font-weight:750;white-space:nowrap;text-transform:uppercase;letter-spacing:.02em}
.report-status-success{background:#dcfce7;color:#166534}
.report-status-danger{background:#fee2e2;color:#991b1b}
.report-status-warning{background:#fef3c7;color:#92400e}
.report-status-info{background:#dbeafe;color:#1d4ed8}
.report-status-neutral{background:#e2e8f0;color:#475569}
.report-panel .report-table-wrap{margin-top:0}
.report-dropdown-wrap{max-width:360px;margin-bottom:24px}
.report-dropdown-wrap label{display:block;margin-bottom:6px}
.report-dropdown-wrap select{height:44px;margin-top:0;background:#fff;border:1px solid #cbd5e1;border-radius:9px;color:#0f172a;font-size:14px;font-weight:600}
.footer{text-align:center;color:#94a3b8;font-size:12px;padding:15px}

@media(max-width:1100px){
    .task-stats{grid-template-columns:repeat(2,minmax(0,1fr))}
    .task-card-grid{grid-template-columns:1fr}
    .report-filters{grid-template-columns:repeat(2,minmax(0,1fr))}
}
@media(max-width:950px){
    .sidebar{width:210px}.main{margin-left:210px}.content{padding:20px}.stats{grid-template-columns:1fr}
}
@media(max-width:700px){
    .sidebar{position:relative;width:100%;height:auto}
    .main{margin-left:0}.topbar{padding:15px 20px}.content{padding:15px}
    .employee-info-text{display:none}
}
@media(max-width:550px){
    .task-stats{grid-template-columns:1fr}
    .welcome h1{font-size:22px}
    .section-card{padding:15px}
    .section-header{align-items:flex-start;flex-direction:column}
    .task-detail-grid,.task-card-meta,.report-filters{grid-template-columns:1fr}
    .task-modal{padding:8px}
    .task-modal-header,.task-modal-body{padding:16px}
    .report-panel-header{padding:16px}
    .report-filter-area{padding:14px}
    .report-table-wrap{padding:0 10px 12px}
    .report-actions .btn{flex:1}
}
</style>
<style>
/* ===== Overtime page ===== */
.report-icon.overtime{background:#ede9fe;color:#5b21b6}
.ot-msg{padding:12px 16px;border-radius:10px;font-size:13px;font-weight:600;margin-bottom:18px}
.ot-msg.ok{background:#dcfce7;color:#166534;border:1px solid #bbf7d0}
.ot-msg.err{background:#fee2e2;color:#991b1b;border:1px solid #fecaca}
.ot-sum{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:24px}
.ot-sum div{background:#fff;border:1px solid #e2e8f0;border-left:4px solid #64748b;border-radius:12px;padding:16px 18px;box-shadow:0 1px 2px rgba(15,23,42,.05)}
.ot-sum span{display:block;color:#64748b;font-size:12px;font-weight:600;margin-bottom:8px}
.ot-sum strong{display:block;color:#0f172a;font-size:24px;font-weight:750}
.ot-sum .pend{border-left-color:#f59e0b}.ot-sum .appr{border-left-color:#16a34a}.ot-sum .rej{border-left-color:#dc2626}.ot-sum .pay{border-left-color:#7c3aed}
.ot-form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px;padding:20px 22px 22px}
.ot-form label{display:block;color:#475569;font-size:12px;font-weight:700}
.ot-form input,.ot-form select,.ot-form textarea{width:100%;padding:10px 12px;margin-top:7px;background:#fff;border:1px solid #cbd5e1;border-radius:8px;color:#334155;font-size:13px;font-family:inherit;outline:none}
.ot-form input,.ot-form select{height:42px}
.ot-form textarea{min-height:84px;resize:vertical}
.ot-form input:focus,.ot-form select:focus,.ot-form textarea:focus{border-color:#3b82f6;box-shadow:0 0 0 3px rgba(59,130,246,.12)}
.ot-form .wide{grid-column:1/-1}
.ot-form .btn{margin:0;min-height:42px}
.ot-hint{padding:14px 22px 0;color:#64748b;font-size:12.5px;line-height:1.7}
.ot-chips{margin:16px 22px 4px}
@media(max-width:900px){.ot-sum{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:640px){.ot-form{grid-template-columns:1fr}}
</style>
<script>
/* Reports open as their own page view (no other dashboard sections around them) */
(function(){
    var d=document.documentElement;
    function sync(){ d.classList.toggle("reports-mode", window.location.hash==="#reports"); }
    window.addEventListener("hashchange",function(){
        sync();
        var h=window.location.hash;
        var el=h.length>1?document.getElementById(h.substring(1)):null;
        if(el&&h!=="#reports"){ el.scrollIntoView(); } else { window.scrollTo(0,0); }
    });
    sync();
})();
</script>
<style>
/* ===== Reports page view ===== */
.reports-pagebar{display:none;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:-4px 0 18px;padding-bottom:14px;border-bottom:1px solid #e2e8f0}
html.reports-mode .reports-pagebar{display:flex}
.reports-crumb{font-size:12.5px;color:#64748b}
.reports-crumb b{color:#0f172a}
.reports-back{display:inline-flex;align-items:center;gap:6px;padding:8px 14px;border-radius:9px;border:1px solid #cbd5e1;background:#fff;color:#1e293b;font-size:13px;font-weight:600;text-decoration:none}
.reports-back:hover{background:#f1f5f9}
.att-range-note{padding:12px 22px 0;font-size:12.5px;color:#64748b}
.att-sum{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;padding:14px 22px 6px}
.att-sum div{background:#f1f5f9;border-radius:10px;padding:12px;text-align:center;font-size:12px;color:#475569}
.att-sum strong{display:block;font-size:22px;color:#0f172a}
.att-sum .ok strong{color:#15803d}.att-sum .bad strong{color:#b91c1c}.att-sum .warn strong{color:#b45309}
@media(max-width:640px){.att-sum{grid-template-columns:repeat(2,minmax(0,1fr))}}
html.reports-mode .content > :not(#reports){display:none!important}
.rtabs{display:flex;gap:6px;background:#f1f5f9;padding:5px;border-radius:12px;width:max-content;max-width:100%;overflow-x:auto;margin:0 0 20px}
.rtab{padding:10px 20px;border-radius:9px;font-size:13px;font-weight:600;color:#475569;text-decoration:none;white-space:nowrap;transition:background .15s,color .15s}
.rtab:hover{color:#0f172a}
.rtab.active{background:#fff;color:#1d4ed8;box-shadow:0 1px 3px rgba(15,23,42,.12)}
.report-panel{border-radius:14px;box-shadow:0 1px 2px rgba(15,23,42,.05),0 6px 18px rgba(15,23,42,.04)}
.report-filter-area{background:#f8fafc}
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
/* highlight the sidebar link of the section being viewed */
(function(){
    function mark(){
        var links=document.querySelectorAll(".sidebar a[href]");
        var hash=window.location.hash, best=null;
        links.forEach(function(a){
            a.classList.remove("active");
            var h=a.getAttribute("href")||"", i=h.indexOf("#");
            if(i>-1 && hash && h.substring(i)===hash && !a.classList.contains("logout")){ best=a; }
        });
        if(!best){
            links.forEach(function(a){
                if(!best && a.getAttribute("href")==="#dashboard"){ best=a; }
            });
        }
        if(best) best.classList.add("active");
    }
    window.addEventListener("hashchange",mark);
    document.addEventListener("DOMContentLoaded",mark);
})();
</script>
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
    var HOME="#dashboard";
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
<div class="sidebar">
    <%= util.Branding.sidebar("Employee Portal") %>

    <div class="menu-title">Overview</div>
    <a href="#dashboard">🏠 Dashboard</a>
    <a href="#profile">👤 My Profile</a>

    <div class="menu-title">Work</div>
    <a href="#taskDashboard">📊 Task Dashboard</a>
    <a href="#tasks">📋 My Tasks</a>
    <a href="#teams">👥 My Teams</a>

    <div class="menu-title">Attendance &amp; Leave</div>
    <a href="#attendance">📅 Attendance</a>
    <a href="#breaks">☕ Breaks</a>
    <a href="#leave">📝 Leave</a>
    <a href="#overtime">⏱️ Overtime</a>

    <div class="menu-title">Payroll</div>
    <a href="#payslips">💰 My Payslips</a>

    <div class="menu-title">Reports</div>
    <a href="#reports">📈 My Reports</a>

    <div class="menu-title">Security</div>
    <a href="#auditLogs">🛡️ My Audit Logs</a>

    <a class="logout" href="<%=contextPath%>/logout">🚪 Logout</a>
</div>

<div class="main">
<div class="topbar">
    <div><h2>Employee Dashboard</h2><p>Manage your work and attendance</p></div>
    <div class="employee-info">
        <div class="employee-info-text"><strong><%=esc(employeeName)%></strong><span>Employee &middot; ID <%=esc(employeeId)%></span></div>
        <div class="profile-circle"><%=esc((employeeName == null || employeeName.trim().isEmpty()) ? "E" : employeeName.trim().substring(0,1).toUpperCase())%></div>
    </div>
</div>

<div class="content" id="dashboard">
<div class="welcome">
    <h1>Welcome, <%=esc(employeeName)%> 👋</h1>
    <p>Manage your tasks, attendance, teams and leave requests from one dashboard.</p>
    <div class="welcome-meta">
        <span class="welcome-chip">Employee ID: <b><%=esc(employeeId)%></b></span>
        <span class="welcome-chip">Current Status: <b><%=esc(currentStatus)%></b></span>
    </div>
</div>

<div class="stats">
    <div class="stat-card"><div class="stat-icon">👤</div><div class="stat-text"><span>Employee ID</span><strong><%=esc(employeeId)%></strong></div></div>
    <div class="stat-card"><div class="stat-icon">📅</div><div class="stat-text"><span>Present Today</span><strong><%=hasCheckedIn ? "YES" : "NO"%></strong></div></div>
    <div class="stat-card"><div class="stat-icon">📝</div><div class="stat-text"><span>Today's Status</span><strong><%=esc(todayStatus)%></strong></div></div>
</div>

<div class="section-card" id="profile">
<div class="section-header"><h2>👤 My Profile</h2><span>Employee details</span></div>
<div class="profile-grid">
<div class="profile-item"><span>Employee ID</span><strong><%=esc(employeeId)%></strong></div>
<div class="profile-item"><span>Name</span><strong><%=esc(employeeName)%></strong></div>
<div class="profile-item"><span>Email</span><strong><%=esc(email)%></strong></div>
<div class="profile-item"><span>Phone</span><strong><%=esc(phone)%></strong></div>
<div class="profile-item"><span>Department</span><strong><%=esc(department)%></strong></div>
<div class="profile-item"><span>Designation</span><strong><%=esc(designation)%></strong></div>
<div class="profile-item"><span>Salary</span><strong><%=esc(salary)%></strong></div>
</div>
</div>

<div class="section-card" id="taskDashboard">
<div class="section-header"><h2>📊 My Tasks Dashboard</h2><span>Task summary</span></div>
<div class="task-stats">
<div class="task-stat-card"><h3>📋 Total Tasks</h3><div class="task-count"><%=totalTasks%></div></div>
<div class="task-stat-card assigned"><h3>🟡 Assigned</h3><div class="task-count"><%=assignedTasks%></div></div>
<div class="task-stat-card progress"><h3>🔵 In Progress</h3><div class="task-count"><%=inProgressTasks%></div></div>
<div class="task-stat-card completed"><h3>🟢 Completed</h3><div class="task-count"><%=completedTasks%></div></div>
</div>
</div>

<div class="section-card" id="tasks">
<div class="section-header"><h2>📋 My Assigned Tasks</h2><span>Open a task to view details and submit work</span></div>
<div class="task-card-grid">
<%
Connection taskCon = null;
PreparedStatement taskPs = null;
ResultSet taskRs = null;
boolean taskFound = false;
try {
    taskCon = DBcConnection.getConnection();
    taskPs = taskCon.prepareStatement(
        "SELECT id,task_title,description,department,priority,start_date,due_date,status," +
        "instruction_file,work_proof_file,employee_comment,manager_remarks " +
        "FROM tasks WHERE assigned_to=? ORDER BY id DESC");
    taskPs.setString(1, employeeId);
    taskRs = taskPs.executeQuery();

    while (taskRs.next()) {
        taskFound = true;
        int taskId = taskRs.getInt("id");
        String taskTitle = taskRs.getString("task_title");
        String taskDescription = taskRs.getString("description");
        String taskDepartment = taskRs.getString("department");
        String taskPriority = taskRs.getString("priority");
        String taskStatus = taskRs.getString("status");
        if (taskStatus == null || taskStatus.trim().isEmpty()) taskStatus = "ASSIGNED";

        String normalizedStatus = taskStatus.trim().toUpperCase().replace(' ','_');
        String statusClass = "status-pending";
        if ("COMPLETED".equals(normalizedStatus)) statusClass = "status-completed";
        else if ("IN_PROGRESS".equals(normalizedStatus)) statusClass = "status-progress";
        else if ("REJECTED".equals(normalizedStatus)) statusClass = "status-rejected";

        String instructionFile = taskRs.getString("instruction_file");
        String workProofFile = taskRs.getString("work_proof_file");
        String employeeComment = taskRs.getString("employee_comment");
        String managerRemarks = taskRs.getString("manager_remarks");
        boolean hasInstruction = instructionFile != null && !instructionFile.trim().isEmpty();
        List<String> uploadedProofs = getProofFiles(workProofFile);
        boolean hasProof = !uploadedProofs.isEmpty();

        java.sql.Date sd = taskRs.getDate("start_date");
        java.sql.Date dd = taskRs.getDate("due_date");
        String startDate = sd == null ? "-" : sd.toString();
        String dueDate = dd == null ? "-" : dd.toString();
        String modalId = "taskModal" + taskId;
%>
<div class="employee-task-card">
<div class="task-card-top"><div><div class="task-card-id">TASK #<%=taskId%></div><h3 class="task-card-title"><%=esc(taskTitle)%></h3></div>
<span class="status <%=statusClass%>"><%=esc(taskStatus)%></span></div>
<p class="task-card-description"><%=esc(taskDescription == null || taskDescription.trim().isEmpty() ? "No description provided." : taskDescription)%></p>
<div class="task-card-meta">
<div class="task-meta-item"><span>Priority</span><strong><%=esc(taskPriority == null ? "-" : taskPriority)%></strong></div>
<div class="task-meta-item"><span>Department</span><strong><%=esc(taskDepartment == null ? "-" : taskDepartment)%></strong></div>
<div class="task-meta-item"><span>Start Date</span><strong><%=esc(util.DateFmt.date(startDate))%></strong></div>
<div class="task-meta-item"><span>Due Date</span><strong><%=esc(util.DateFmt.date(dueDate))%></strong></div>
</div>
<div class="task-card-actions">
<button type="button" class="btn task-open-btn" onclick="openTaskModal('<%=modalId%>')">👁️ View Task</button>
<% for (int i=0; i<uploadedProofs.size(); i++) { %>
<a class="btn proof-btn" href="<%=contextPath%>/task-file?id=<%=taskId%>&amp;type=proof&amp;fileIndex=<%=i%>" target="_blank" rel="noopener">📎 PDF <%=i+1%></a>
<% } %>
</div>
</div>

<div class="task-modal" id="<%=modalId%>" onclick="closeTaskModalOutside(event,'<%=modalId%>')">
<div class="task-modal-content" role="dialog" aria-modal="true">
<div class="task-modal-header"><div><h2><%=esc(taskTitle)%></h2><p>Task #<%=taskId%> · Employee Task Details</p></div>
<button type="button" class="task-modal-close" onclick="closeTaskModal('<%=modalId%>')">&times;</button></div>
<div class="task-modal-body">
<div class="task-detail-grid">
<div class="task-detail-item"><span>Task ID</span><strong>#<%=taskId%></strong></div>
<div class="task-detail-item"><span>Status</span><strong><span class="status <%=statusClass%>"><%=esc(taskStatus)%></span></strong></div>
<div class="task-detail-item"><span>Department</span><strong><%=esc(taskDepartment == null ? "-" : taskDepartment)%></strong></div>
<div class="task-detail-item"><span>Priority</span><strong><%=esc(taskPriority == null ? "-" : taskPriority)%></strong></div>
<div class="task-detail-item"><span>Start Date</span><strong><%=esc(util.DateFmt.date(startDate))%></strong></div>
<div class="task-detail-item"><span>Due Date</span><strong><%=esc(util.DateFmt.date(dueDate))%></strong></div>
</div>
<div class="task-modal-section"><h3>📝 Task Description</h3><div class="task-modal-description"><%=esc(taskDescription == null || taskDescription.trim().isEmpty() ? "No description provided." : taskDescription)%></div></div>
<div class="task-modal-section"><h3>📎 Task Files</h3>
<% if (hasInstruction) { %><a class="task-file-link" href="<%=contextPath%>/task-file?id=<%=taskId%>&amp;type=instruction" target="_blank" rel="noopener">📄 View / Download Instructions</a>
<% } else { %><p class="task-modal-description">No instruction file attached.</p><% } %>
<% if (hasProof) { for (int i=0; i<uploadedProofs.size(); i++) { %>
<a class="task-file-link" href="<%=contextPath%>/task-file?id=<%=taskId%>&amp;type=proof&amp;fileIndex=<%=i%>" target="_blank" rel="noopener">📎 View Submitted PDF <%=i+1%></a>
<% } } else { %><p class="task-modal-description">Work proof has not been submitted yet.</p><% } %>
</div>
<div class="task-modal-section"><h3>💬 Manager Remarks</h3><div class="task-remarks"><%=esc(managerRemarks != null && !managerRemarks.trim().isEmpty() ? managerRemarks : "Manager has not added remarks yet.")%></div></div>
<div class="task-modal-section"><h3>📤 Submit Your Work</h3>
<form class="task-upload-box" action="<%=contextPath%>/tasks" method="post" enctype="multipart/form-data">
<input type="hidden" name="action" value="submitProof"><input type="hidden" name="id" value="<%=taskId%>">
<div class="form-group"><label>Work Summary / Comment</label><textarea name="employeeComment" maxlength="2000" rows="4" placeholder="Describe your completed work" required><%=employeeComment != null ? esc(employeeComment) : ""%></textarea></div>
<div class="form-group"><label>Attach Work Proof (PDF only)</label><input class="file-label" type="file" name="workProofFile" accept=".pdf,application/pdf" multiple <%=hasProof ? "" : "required"%>><small>Select one or more PDF files. Previously uploaded proofs will be retained.</small></div>
<button type="submit" class="btn task-submit-btn">📤 Submit Work</button>
</form></div>
</div></div></div>
<%
    }
    if (!taskFound) {
%>
<div class="empty" style="grid-column:1/-1"><div class="empty-icon">📋</div><b>No tasks assigned yet.</b><br>Tasks assigned by your manager will appear here.</div>
<%
    }
} catch (Exception e) {
    application.log("Employee task list loading error", e);
%>
<div class="empty" style="grid-column:1/-1">Error loading tasks. Check the tasks table columns and Tomcat console.</div>
<%
} finally {
    try { if (taskRs != null) taskRs.close(); } catch (Exception e) {}
    try { if (taskPs != null) taskPs.close(); } catch (Exception e) {}
    try { if (taskCon != null) taskCon.close(); } catch (Exception e) {}
}
%>
</div>
</div>

<div class="section-card" id="teams">
<div class="section-header"><h2>👥 My Teams</h2><span>Teams assigned to you</span></div>
<div class="table-container"><table>
<thead><tr><th>Team ID</th><th>Team Name</th><th>Department</th><th>Manager ID</th><th>Manager Name</th></tr></thead>
<tbody>
<% if (myTeams.isEmpty()) { %><tr><td colspan="5">No active teams assigned.</td></tr>
<% } else { for (String[] team : myTeams) { %>
<tr><td><%=esc(team[0])%></td><td><%=esc(team[1])%></td><td><%=esc(team[2])%></td><td><%=esc(team[3])%></td><td><%=esc(team[4] == null ? "-" : team[4])%></td></tr>
<% } } %>
</tbody></table></div>

<% for (String[] team : myTeams) { %>
<div style="margin-top:20px;padding:18px;border:1px solid #e5e7eb;border-radius:12px">
<h3 style="color:#0f172a;margin-bottom:12px">👥 <%=esc(team[1])%> - Team Members</h3>
<div class="table-container"><table><thead><tr><th>Employee ID</th><th>Name</th><th>Designation</th></tr></thead><tbody>
<%
Connection teamCon = null; PreparedStatement teamPs = null; ResultSet teamRs = null;
try {
    teamCon = DBcConnection.getConnection();
    teamPs = teamCon.prepareStatement(
        "SELECT e.employee_id,e.name,e.designation FROM team_members tm " +
        "JOIN employees e ON tm.employee_id=e.employee_id " +
        "WHERE tm.team_id=? AND tm.status='ACTIVE' ORDER BY e.name");
    teamPs.setString(1, team[0]);
    teamRs = teamPs.executeQuery();
    boolean memberFound = false;
    while (teamRs.next()) {
        memberFound = true;
%>
<tr><td><%=esc(teamRs.getString("employee_id"))%></td><td><%=esc(teamRs.getString("name"))%></td><td><%=esc(teamRs.getString("designation"))%></td></tr>
<%
    }
    if (!memberFound) {
%><tr><td colspan="3">No team members found.</td></tr><%
    }
} catch (Exception e) {
    application.log("Team members loading error", e);
} finally {
    try { if (teamRs != null) teamRs.close(); } catch (Exception e) {}
    try { if (teamPs != null) teamPs.close(); } catch (Exception e) {}
    try { if (teamCon != null) teamCon.close(); } catch (Exception e) {}
}
%>
</tbody></table></div></div>
<% } %>
</div>

<div class="section-card" id="attendance">
<div class="section-header"><h2>📅 Today's Attendance</h2><span><%=util.DateFmt.date(LocalDate.now())%></span></div>
<div class="table-container"><table><thead><tr><th>Date</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
<tbody><tr><td><%=util.DateFmt.date(LocalDate.now())%></td><td><%=esc(checkInTime == null ? "-" : util.DateFmt.time(checkInTime))%></td><td><%=esc(checkOutTime == null ? "-" : util.DateFmt.time(checkOutTime))%></td>
<td><% if ("LEAVE".equalsIgnoreCase(todayStatus)) { %><span class="status status-leave">🟡 LEAVE</span>
<% } else if ("WORKING".equalsIgnoreCase(todayStatus)) { %><span class="status status-working">🔵 WORKING</span>
<% } else if ("PRESENT".equalsIgnoreCase(todayStatus)) { %><span class="status status-present">🟢 PRESENT</span>
<% } else { %><span class="status status-absent">🔴 ABSENT</span><% } %></td></tr></tbody></table></div>
<div class="action-row">
<form action="<%=contextPath%>/employee" method="post" style="display:inline"><input type="hidden" name="action" value="checkIn"><button type="submit" class="btn checkin" <%= (hasCheckedIn || leaveToday) ? "disabled" : "" %>>🟢 Check In</button></form>
<form action="<%=contextPath%>/employee" method="post" style="display:inline"><input type="hidden" name="action" value="checkOut"><button type="submit" class="btn checkout" <%= (!hasCheckedIn || hasCheckedOut || leaveToday) ? "disabled" : "" %>>🔴 Check Out</button></form>
</div>
</div>

<div class="section-card" id="breaks">
<div class="section-header"><h2>☕ Today's Breaks</h2><span>Maximum 2 breaks</span></div>
<div class="table-container"><table><thead><tr><th>Break Number</th><th>Start</th><th>End</th></tr></thead><tbody>
<% if (todayBreaks.isEmpty()) { %><tr><td colspan="3">No breaks taken today.</td></tr>
<% } else { for (String[] br : todayBreaks) { %><tr><td>Break <%=esc(br[0])%></td><td><%=esc(br[1])%></td><td><%=esc(br[2] == null ? "-" : br[2])%></td></tr><% } } %>
</tbody></table></div>
<div class="action-row">
<form action="<%=contextPath%>/employee" method="post" style="display:inline"><input type="hidden" name="action" value="startBreak"><button type="submit" class="btn break-btn" <%= (!hasCheckedIn || hasCheckedOut || leaveToday || todayBreaks.size() >= 2) ? "disabled" : "" %>>☕ Start Break</button></form>
<form action="<%=contextPath%>/employee" method="post" style="display:inline"><input type="hidden" name="action" value="endBreak"><button type="submit" class="btn break-btn">▶️ End Break</button></form>
</div>
</div>

<div class="section-card" id="leave">
<div class="section-header"><h2>📝 Leave Management</h2><span>Apply and view leave status</span></div>
<% if (latestLeaveId != null) { %>
<div class="table-container"><table><thead><tr><th>Leave ID</th><th>Type</th><th>From</th><th>To</th><th>Reason</th><th>Status</th></tr></thead>
<tbody><tr><td><%=esc(latestLeaveId)%></td><td><%=esc(latestLeaveType)%></td><td><%=esc(util.DateFmt.date(latestFromDate))%></td><td><%=esc(util.DateFmt.date(latestToDate))%></td><td><%=esc(latestReason)%></td><td><span class="status status-<%=esc(String.valueOf(latestLeaveStatus).toLowerCase())%>"><%=esc(latestLeaveStatus)%></span></td></tr></tbody></table></div>
<% } else { %><div class="empty"><div class="empty-icon">📝</div>No leave requests found.</div><% } %>
<h3 class="apply-title">➕ Apply for Leave</h3>
<form class="leave-form" action="<%=contextPath%>/employee" method="post">
<input type="hidden" name="action" value="applyLeave">
<div class="form-group"><label>Leave Type</label><select name="leaveType" required><option value="">-- Select Leave Type --</option><option value="CASUAL">Casual Leave</option><option value="SICK">Sick Leave</option><option value="PERSONAL">Personal Leave</option></select></div>
<div class="form-group"><label>From Date</label><input type="date" name="fromDate" required></div>
<div class="form-group"><label>To Date</label><input type="date" name="toDate" required></div>
<div class="form-group"><label>Reason</label><textarea name="reason" placeholder="Enter reason" required></textarea></div>
<button type="submit" class="btn checkin">📝 Apply Leave</button>
</form>
</div>

<!-- MY PAYSLIPS: shown only after the admin has marked the salary PAID -->
<div class="section-card" id="payslips">
<div class="section-header"><h2>💰 My Payslips</h2><span>Available as soon as the admin pays your salary</span></div>
<div class="table-container"><table>
<thead><tr><th>Pay Period</th><th>Gross Salary</th><th>Net Salary</th><th>Status</th><th>Payslip</th></tr></thead>
<tbody>
<%
String[] slipMonths = {"January","February","March","April","May","June","July","August","September","October","November","December"};
try {
    java.util.List<model.Payroll> slips = new DAO.PayrollDAO().searchPayroll(0, 0, "", "PAID", employeeId);
    if (slips.isEmpty()) {
%>
<tr><td colspan="5" style="text-align:center">No paid payslips yet.</td></tr>
<%
    }
    for (model.Payroll sp : slips) {
        String slipUrl = contextPath + "/employee?action=salarySlip&payrollId=" + sp.getId();
%>
<tr>
<td><strong><%=slipMonths[sp.getPayrollMonth() - 1]%> <%=sp.getPayrollYear()%></strong></td>
<td>&#8377;<%=sp.getGrossSalary() == null ? "0.00" : String.format("%,.2f", sp.getGrossSalary())%></td>
<td><strong>&#8377;<%=sp.getNetSalary() == null ? "0.00" : String.format("%,.2f", sp.getNetSalary())%></strong></td>
<td><span class="status status-completed">PAID</span></td>
<td><a class="slip-btn" href="<%=slipUrl%>" target="_blank">👁 View</a><a class="slip-btn slip-btn-primary" href="<%=slipUrl%>&download=1">⬇ Download</a></td>
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
</tbody></table></div>
</div>

<!-- MY OVERTIME -->
<%
    String otFlash = (String) session.getAttribute("otFlashMsg");
    String otFlashOk = (String) session.getAttribute("otFlashOk");
    session.removeAttribute("otFlashMsg");
    session.removeAttribute("otFlashOk");

    List<OvertimeService.OtRequest> otList = new ArrayList<OvertimeService.OtRequest>();
    List<String> otPays = new ArrayList<String>();
    int otPendingCount = 0, otRejectedCount = 0;
    java.math.BigDecimal otApprovedHours = java.math.BigDecimal.ZERO;
    java.math.BigDecimal otTotalPay = java.math.BigDecimal.ZERO;
    boolean otLoadFailed = false;
    try {
        otList = OvertimeService.forEmployee(employeeId);
        for (OvertimeService.OtRequest otX : otList) {
            String otPayText = "-";
            if ("PENDING".equals(otX.status)) otPendingCount++;
            if ("REJECTED".equals(otX.status)) otRejectedCount++;
            if ("APPROVED".equals(otX.status)) {
                otApprovedHours = otApprovedHours.add(otX.hours);
                java.math.BigDecimal otAmt = otX.amount;
                boolean otIsEstimate = false;
                if (otAmt == null && otX.payMonth != null && otX.payYear != null) {
                    otAmt = OvertimeService.estimateAmount(employeeId, otX.payMonth, otX.payYear, otX.hours);
                    otIsEstimate = otAmt != null;
                }
                if (otAmt != null) {
                    otTotalPay = otTotalPay.add(otAmt);
                    otPayText = (otIsEstimate ? "~ " : "") + "&#8377;" + String.format("%,.2f", otAmt)
                            + (otIsEstimate ? " <small>(estimate)</small>" : "");
                }
            }
            otPays.add(otPayText);
        }
    } catch (Exception otLoadEx) {
        application.log("Employee overtime page error", otLoadEx);
        otLoadFailed = true;
    }
    LocalDate otToday = LocalDate.now();
%>
<div class="section-card" id="overtime">
    <div class="reports-heading">
        <div>
            <h2>⏱️ My Overtime</h2>
            <p>Request overtime, track manager approval and see the OT pay added to your salary and salary slip.</p>
        </div>
        <div class="report-employee-chip">🕕 Regular day ends at <%=esc(service.AttendanceAutoCheckout.CUTOFF)%></div>
    </div>

    <% if (otFlash != null) { %>
        <div class="ot-msg <%= "1".equals(otFlashOk) ? "ok" : "err" %>"><%=esc(otFlash)%></div>
    <% } %>

    <div class="ot-sum">
        <div class="pend"><span>Pending Approval</span><strong><%=otPendingCount%></strong></div>
        <div class="appr"><span>Approved Hours</span><strong><%=esc(otApprovedHours.stripTrailingZeros().toPlainString())%> h</strong></div>
        <div class="rej"><span>Rejected Requests</span><strong><%=otRejectedCount%></strong></div>
        <div class="pay"><span>Approved OT Pay</span><strong>&#8377;<%=String.format("%,.2f", otTotalPay)%></strong></div>
    </div>

    <div class="report-panel">
        <div class="report-panel-header">
            <div class="report-title-wrap">
                <div class="report-icon overtime">➕</div>
                <div>
                    <h3>Request Overtime</h3>
                    <p>When your manager approves, your check-out becomes <%=esc(service.AttendanceAutoCheckout.CUTOFF)%> plus the OT hours.</p>
                </div>
            </div>
            <span class="report-count">Last <%=OvertimeService.MAX_DAYS_BACK%> days allowed</span>
        </div>
        <form method="post" action="<%=contextPath%>/employee_dashboard.jsp" class="ot-form">
            <input type="hidden" name="otAction" value="request">
            <div>
                <label for="otDate">Date</label>
                <input type="date" id="otDate" name="otDate" value="<%=otToday%>"
                       min="<%=otToday.minusDays(OvertimeService.MAX_DAYS_BACK)%>" max="<%=otToday%>" required>
            </div>
            <div>
                <label for="otHours">OT Hours</label>
                <select id="otHours" name="otHours">
                    <% for (double otH = 0.5; otH <= OvertimeService.MAX_HOURS; otH += 0.5) { %>
                        <option value="<%=otH%>" <%= otH == 2.0 ? "selected" : "" %>><%=otH%> h</option>
                    <% } %>
                </select>
            </div>
            <div class="wide">
                <label for="otReason">Reason</label>
                <textarea id="otReason" name="otReason" maxlength="500" required placeholder="What did you work on?"></textarea>
            </div>
            <div class="wide"><button type="submit" class="btn report-submit">📨 Send to Manager</button></div>
        </form>
    </div>

    <div class="report-panel">
        <div class="report-panel-header">
            <div class="report-title-wrap">
                <div class="report-icon attendance">📄</div>
                <div>
                    <h3>My Overtime Requests</h3>
                    <p>Status, check-out time, manager note and the salary month each request is paid in.</p>
                </div>
            </div>
            <span class="report-count"><%=otList.size()%> Records</span>
        </div>
        <div class="rtabs ot-chips" id="otChips">
            <a class="rtab active" href="javascript:void(0)" data-f="">All</a>
            <a class="rtab" href="javascript:void(0)" data-f="PENDING">Pending</a>
            <a class="rtab" href="javascript:void(0)" data-f="APPROVED">Approved</a>
            <a class="rtab" href="javascript:void(0)" data-f="REJECTED">Rejected</a>
        </div>
        <div class="report-table-wrap">
            <table>
                <thead><tr><th>Date</th><th>Hours</th><th>Reason</th><th>Status</th><th>Check-out</th><th>Manager Note</th><th>Paid In Salary</th><th>OT Pay</th></tr></thead>
                <tbody id="otBody">
                <% if (otLoadFailed) { %>
                    <tr><td colspan="8" class="report-empty-cell">Unable to load overtime requests.</td></tr>
                <% } else if (otList.isEmpty()) { %>
                    <tr><td colspan="8" class="report-empty-cell">No overtime requests yet.</td></tr>
                <% } else {
                    for (int otI = 0; otI < otList.size(); otI++) {
                        OvertimeService.OtRequest otR = otList.get(otI);
                        String otPaid = (otR.payMonth != null && otR.payYear != null)
                                ? java.time.Month.of(otR.payMonth).getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.ENGLISH) + " " + otR.payYear
                                : "-"; %>
                    <tr data-status="<%=esc(otR.status)%>">
                        <td><%=esc(util.DateFmt.date(otR.otDate))%></td>
                        <td><%=esc(otR.hours.stripTrailingZeros().toPlainString())%> h</td>
                        <td><%=esc(otR.reason)%></td>
                        <td><span class="report-status <%=reportStatusClass(otR.status)%>"><%=esc(otR.status)%></span></td>
                        <td><%= "APPROVED".equals(otR.status) ? esc(util.DateFmt.time(otR.checkOutTime)) : "-" %></td>
                        <td><%=esc(otR.managerNote == null || otR.managerNote.isEmpty() ? "-" : otR.managerNote)%></td>
                        <td><%=esc(otPaid)%></td>
                        <td><%=otPays.get(otI)%></td>
                    </tr>
                <%  } } %>
                    <tr id="otNoMatch" style="display:none"><td colspan="8" class="report-empty-cell">No requests with this status.</td></tr>
                </tbody>
            </table>
        </div>
    </div>
</div>
<script>
(function(){
    var chips=document.getElementById("otChips"), body=document.getElementById("otBody");
    if(!chips||!body) return;
    chips.addEventListener("click",function(ev){
        var a=ev.target.closest(".rtab"); if(!a) return;
        chips.querySelectorAll(".rtab").forEach(function(c){c.classList.toggle("active",c===a);});
        var f=a.getAttribute("data-f"), shown=0;
        body.querySelectorAll("tr[data-status]").forEach(function(tr){
            var on=!f||tr.getAttribute("data-status")===f; tr.style.display=on?"":"none"; if(on) shown++;
        });
        document.getElementById("otNoMatch").style.display=(shown===0&&body.querySelector("tr[data-status]"))?"":"none";
    });
})();
</script>

<!-- MY AUDIT LOGS (view only: the employee's own activity) -->
<div class="section-card" id="auditLogs">
    <h2>🛡️ My Audit Logs</h2>
    <p style="margin:4px 0 16px;color:#64748b;font-size:13px">A read-only record of your own activity in the system.</p>
<%@ include file="/WEB-INF/admin/_audit_embed.jspf" %>
</div>

<!-- MY REPORTS: ONE DROPDOWN, ONE REPORT VISIBLE AT A TIME -->
<div class="section-card" id="reports">
    <div class="reports-pagebar">
        <div class="reports-crumb">Dashboard &rsaquo; <b>Reports</b></div>
        <a class="reports-back" href="#dashboard">&larr; Back to Dashboard</a>
    </div>

<div class="reports-heading">
    <div>
        <h2>📈 My Reports</h2>
        <p>Review your attendance history, leave applications and assigned task progress.</p>
    </div>
    <div class="report-employee-chip">👤 Employee ID: <%=esc(employeeId)%></div>
</div>

<!-- REPORT TABS -->
<div class="rtabs">
    <a class="rtab <%= "attendance".equals(reportType) ? "active" : "" %>" href="<%=request.getRequestURI()%>?reportType=attendance#reports">📅 Attendance</a>
    <a class="rtab <%= "leave".equals(reportType) ? "active" : "" %>" href="<%=request.getRequestURI()%>?reportType=leave#reports">📝 Leave</a>
    <a class="rtab <%= "task".equals(reportType) ? "active" : "" %>" href="<%=request.getRequestURI()%>?reportType=task#reports">📋 Tasks</a>
</div>

<!-- ATTENDANCE REPORT -->
<div class="report-panel" id="attendanceReportPanel"
     style="<%= "attendance".equals(reportType) ? "" : "display:none;" %>">
    <div class="report-panel-header">
        <div class="report-title-wrap">
            <div class="report-icon attendance">📅</div>
            <div>
                <h3>Attendance Report</h3>
                <p>Check your daily attendance, check-in and check-out records.</p>
            </div>
        </div>
        <span class="report-count">Personal Records</span>
    </div>

    <div class="report-filter-area">
        <form method="get" action="<%=request.getRequestURI()%>#reports" class="report-filters">
            <input type="hidden" name="reportType" value="attendance">
            <div><label>From Date</label><input type="date" name="attendanceFrom" value="<%=esc(attendanceFrom)%>"></div>
            <div><label>To Date</label><input type="date" name="attendanceTo" value="<%=esc(attendanceTo)%>"></div>
            <div><label>Attendance Status</label>
                <select name="attendanceFilter">
                    <option value="">All Statuses</option>
                    <option value="PRESENT" <%= "PRESENT".equalsIgnoreCase(attendanceFilter) ? "selected" : "" %>>Present</option>
                    <option value="ABSENT" <%= "ABSENT".equalsIgnoreCase(attendanceFilter) ? "selected" : "" %>>Absent</option>
                    <option value="LEAVE" <%= "LEAVE".equalsIgnoreCase(attendanceFilter) ? "selected" : "" %>>Leave</option>
                </select>
            </div>
            <div class="report-actions">
                <button class="btn report-submit" type="submit">⌕ Apply Filters</button>
                <a class="btn report-reset" href="<%=request.getRequestURI()%>?reportType=attendance#reports">↻ Reset</a>
            </div>
        </form>
    </div>

<%
    /* ---- Attendance report: one row per working day (Mon-Fri) ----
       PRESENT  -> real check-in / check-out times
       LEAVE    -> approved leave and no check-in
       ABSENT   -> no check-in and no approved leave
       Default (no dates chosen) = today. */
    java.util.List<String[]> arRows = new java.util.ArrayList<String[]>();
    int arPresent = 0, arAbsent = 0, arLeave = 0;
    boolean arTodayOnly = false, arError = false;
    java.time.LocalDate arFromD = null, arToD = null;

    Connection arCon = null;
    PreparedStatement arPs = null, arLps = null;
    ResultSet arRs = null;
    try {
        java.time.LocalDate arToday = java.time.LocalDate.now();
        arFromD = attendanceFrom.isEmpty() ? null : java.time.LocalDate.parse(attendanceFrom);
        arToD = attendanceTo.isEmpty() ? null : java.time.LocalDate.parse(attendanceTo);
        if (arFromD == null && arToD == null) { arFromD = arToday; arToD = arToday; arTodayOnly = true; }
        else if (arFromD == null) { arFromD = arToD; }
        else if (arToD == null) { arToD = arToday; }
        if (arFromD.isAfter(arToD)) { java.time.LocalDate sw = arFromD; arFromD = arToD; arToD = sw; }
        if (java.time.temporal.ChronoUnit.DAYS.between(arFromD, arToD) > 366) arFromD = arToD.minusDays(366);

        arCon = DBcConnection.getConnection();
        arPs = arCon.prepareStatement(
            "SELECT check_in_time,check_out_time,status FROM attendance " +
            "WHERE employee_id=? AND date=? ORDER BY attendance_id DESC LIMIT 1");
        arLps = arCon.prepareStatement(
            "SELECT COUNT(*) FROM leave_requests WHERE employee_id=? " +
            "AND UPPER(status)='APPROVED' AND from_date<=? AND to_date>=?");

        java.time.LocalDate arDay = arToD;               // newest day first
        while (!arDay.isBefore(arFromD)) {
            java.time.DayOfWeek arDow = arDay.getDayOfWeek();
            boolean arWeekend = arDow == java.time.DayOfWeek.SATURDAY || arDow == java.time.DayOfWeek.SUNDAY;
            java.sql.Date arSql = java.sql.Date.valueOf(arDay);

            String arIn = "-", arOut = "-", arSt = null;
            boolean arHas = false, arOnLeave = false;

            arPs.setString(1, employeeId);
            arPs.setDate(2, arSql);
            arRs = arPs.executeQuery();
            if (arRs.next()) {
                arHas = true;
                String ci = arRs.getString("check_in_time");
                String co = arRs.getString("check_out_time");
                arIn = (ci == null || ci.trim().isEmpty()) ? "-" : ci;
                arOut = (co == null || co.trim().isEmpty()) ? "-" : co;
                arSt = arRs.getString("status");
            }
            arRs.close(); arRs = null;

            arLps.setString(1, employeeId);
            arLps.setDate(2, arSql);
            arLps.setDate(3, arSql);
            arRs = arLps.executeQuery();
            if (arRs.next()) arOnLeave = arRs.getInt(1) > 0;
            arRs.close(); arRs = null;

            boolean arShow = true;
            if (arOnLeave && "-".equals(arIn)) {
                arSt = "LEAVE"; arOut = "-";
            } else if (arHas) {
                if (arSt == null || arSt.trim().isEmpty()) arSt = "-".equals(arIn) ? "ABSENT" : "PRESENT";
            } else if (arWeekend || arDay.isAfter(arToday)) {
                if (arFromD.equals(arToD)) {              // single day: always show a filled row
                    arSt = arWeekend ? "WEEKEND" : "-";
                } else {
                    arShow = false;                       // range: skip weekends / future days with nothing
                }
            } else {
                arSt = "ABSENT";
            }

            if (arShow && (attendanceFilter.isEmpty() || attendanceFilter.equalsIgnoreCase(arSt))) {
                arRows.add(new String[] { arDay.toString(),
                    arDay.getDayOfWeek().getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.ENGLISH),
                    arIn, arOut, arSt });
                if ("PRESENT".equalsIgnoreCase(arSt)) arPresent++;
                else if ("ABSENT".equalsIgnoreCase(arSt)) arAbsent++;
                else if ("LEAVE".equalsIgnoreCase(arSt)) arLeave++;
            }
            arDay = arDay.minusDays(1);
        }
    } catch (Exception e) {
        arError = true;
        application.log("Employee attendance report error", e);
    } finally {
        try { if (arRs != null) arRs.close(); } catch (Exception e) {}
        try { if (arPs != null) arPs.close(); } catch (Exception e) {}
        try { if (arLps != null) arLps.close(); } catch (Exception e) {}
        try { if (arCon != null) arCon.close(); } catch (Exception e) {}
    }
%>
    <div class="att-range-note">
        <%= arTodayOnly
            ? "Showing today (" + arFromD + "). Choose From / To dates to see other days."
            : "Showing " + arFromD + " to " + arToD + " (Mon–Fri)" %>
    </div>

    <div class="att-sum">
        <div><strong><%=arRows.size()%></strong>Days</div>
        <div class="ok"><strong><%=arPresent%></strong>Present</div>
        <div class="bad"><strong><%=arAbsent%></strong>Absent</div>
        <div class="warn"><strong><%=arLeave%></strong>Leave</div>
    </div>

    <div class="report-table-wrap">
        <table>
            <thead><tr><th>Date</th><th>Day</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
            <tbody>
            <% if (arError) { %>
                <tr><td colspan="5" class="report-empty-cell">Unable to load attendance report. Please try again.</td></tr>
            <% } else if (arRows.isEmpty()) { %>
                <tr><td colspan="5" class="report-empty-cell">
                    <%= arTodayOnly ? "No attendance to show for today (weekend or not yet marked)."
                                    : "No attendance records found for the selected filters." %>
                </td></tr>
            <% } else { for (String[] arRow : arRows) { %>
                <tr>
                    <td><%=esc(arRow[0])%></td>
                    <td><%=esc(arRow[1])%></td>
                    <td><%=esc(arRow[2])%></td>
                    <td><%=esc(arRow[3])%></td>
                    <td><span class="report-status <%=reportStatusClass(arRow[4])%>"><%=esc(arRow[4])%></span></td>
                </tr>
            <% } } %>
            </tbody>
        </table>
    </div>
</div>

<!-- LEAVE REPORT -->
<div class="report-panel" id="leaveReportPanel"
     style="<%= "leave".equals(reportType) ? "" : "display:none;" %>">
    <div class="report-panel-header">
        <div class="report-title-wrap">
            <div class="report-icon leave">📝</div>
            <div>
                <h3>Leave Report</h3>
                <p>Review leave applications, requested dates and approval status.</p>
            </div>
        </div>
        <span class="report-count">Personal Records</span>
    </div>

    <div class="report-filter-area">
        <form method="get" action="<%=request.getRequestURI()%>#reports" class="report-filters">
            <input type="hidden" name="reportType" value="leave">
            <div><label>From Date</label><input type="date" name="leaveFrom" value="<%=esc(leaveFrom)%>"></div>
            <div><label>To Date</label><input type="date" name="leaveTo" value="<%=esc(leaveTo)%>"></div>
            <div><label>Leave Status</label>
                <select name="leaveFilter">
                    <option value="">All Statuses</option>
                    <option value="PENDING" <%= "PENDING".equalsIgnoreCase(leaveFilter) ? "selected" : "" %>>Pending</option>
                    <option value="APPROVED" <%= "APPROVED".equalsIgnoreCase(leaveFilter) ? "selected" : "" %>>Approved</option>
                    <option value="REJECTED" <%= "REJECTED".equalsIgnoreCase(leaveFilter) ? "selected" : "" %>>Rejected</option>
                </select>
            </div>
            <div class="report-actions">
                <button class="btn report-submit" type="submit">⌕ Apply Filters</button>
                <a class="btn report-reset" href="<%=request.getRequestURI()%>?reportType=leave#reports">↻ Reset</a>
            </div>
        </form>
    </div>

    <div class="report-table-wrap">
        <table>
            <thead><tr><th>Leave ID</th><th>Type</th><th>From</th><th>To</th><th>Reason</th><th>Status</th><th>Applied Date</th></tr></thead>
            <tbody>
            <%
            Connection lrCon = null;
            PreparedStatement lrPs = null;
            ResultSet lrRs = null;
            boolean lrFound = false;
            try {
                StringBuilder sql = new StringBuilder(
                    "SELECT leave_id,leave_type,from_date,to_date,reason,status,applied_date " +
                    "FROM leave_requests WHERE employee_id=?");
                if (!leaveFrom.isEmpty()) sql.append(" AND from_date>=?");
                if (!leaveTo.isEmpty()) sql.append(" AND from_date<=?");
                if (!leaveFilter.isEmpty()) sql.append(" AND UPPER(status)=?");
                sql.append(" ORDER BY leave_id DESC");

                lrCon = DBcConnection.getConnection();
                lrPs = lrCon.prepareStatement(sql.toString());
                int p = 1;
                lrPs.setString(p++, employeeId);
                if (!leaveFrom.isEmpty()) lrPs.setDate(p++, java.sql.Date.valueOf(leaveFrom));
                if (!leaveTo.isEmpty()) lrPs.setDate(p++, java.sql.Date.valueOf(leaveTo));
                if (!leaveFilter.isEmpty()) lrPs.setString(p++, leaveFilter.toUpperCase());

                lrRs = lrPs.executeQuery();
                while (lrRs.next()) {
                    lrFound = true;
                    String st = lrRs.getString("status");
            %>
                <tr>
                    <td>#<%=esc(lrRs.getString("leave_id"))%></td>
                    <td><%=esc(lrRs.getString("leave_type"))%></td>
                    <td><%=esc(util.DateFmt.date(lrRs.getDate("from_date")))%></td>
                    <td><%=esc(util.DateFmt.date(lrRs.getDate("to_date")))%></td>
                    <td><%=esc(lrRs.getString("reason") == null ? "-" : lrRs.getString("reason"))%></td>
                    <td><span class="report-status <%=reportStatusClass(st)%>"><%=esc(st == null ? "UNKNOWN" : st)%></span></td>
                    <td><%=esc(util.DateFmt.date(lrRs.getTimestamp("applied_date")))%></td>
                </tr>
            <%
                }
            } catch (Exception e) {
                application.log("Employee leave report error", e);
            %>
                <tr><td colspan="7" class="report-empty-cell">Unable to load leave report. Check the leave_requests table columns.</td></tr>
            <%
            } finally {
                try { if (lrRs != null) lrRs.close(); } catch (Exception e) {}
                try { if (lrPs != null) lrPs.close(); } catch (Exception e) {}
                try { if (lrCon != null) lrCon.close(); } catch (Exception e) {}
            }
            if (!lrFound) {
            %>
                <tr><td colspan="7" class="report-empty-cell">No leave requests found for the selected filters.</td></tr>
            <% } %>
            </tbody>
        </table>
    </div>
</div>

<!-- TASK REPORT -->
<div class="report-panel" id="taskReportPanel"
     style="<%= "task".equals(reportType) ? "" : "display:none;" %>">
    <div class="report-panel-header">
        <div class="report-title-wrap">
            <div class="report-icon task">📋</div>
            <div>
                <h3>Task Report</h3>
                <p>Track assigned tasks, deadlines, priorities and manager remarks.</p>
            </div>
        </div>
        <span class="report-count">Personal Records</span>
    </div>

    <div class="report-filter-area">
        <form method="get" action="<%=request.getRequestURI()%>#reports" class="report-filters">
            <input type="hidden" name="reportType" value="task">
            <div><label>Start Date From</label><input type="date" name="taskFrom" value="<%=esc(taskFrom)%>"></div>
            <div><label>Start Date To</label><input type="date" name="taskTo" value="<%=esc(taskTo)%>"></div>
            <div><label>Task Status</label>
                <select name="taskFilter">
                    <option value="">All Statuses</option>
                    <option value="ASSIGNED" <%= "ASSIGNED".equalsIgnoreCase(taskFilter) ? "selected" : "" %>>Assigned</option>
                    <option value="PENDING" <%= "PENDING".equalsIgnoreCase(taskFilter) ? "selected" : "" %>>Pending</option>
                    <option value="IN_PROGRESS" <%= "IN_PROGRESS".equalsIgnoreCase(taskFilter) ? "selected" : "" %>>In Progress</option>
                    <option value="COMPLETED" <%= "COMPLETED".equalsIgnoreCase(taskFilter) ? "selected" : "" %>>Completed</option>
                    <option value="REJECTED" <%= "REJECTED".equalsIgnoreCase(taskFilter) ? "selected" : "" %>>Rejected</option>
                </select>
            </div>
            <div class="report-actions">
                <button class="btn report-submit" type="submit">⌕ Apply Filters</button>
                <a class="btn report-reset" href="<%=request.getRequestURI()%>?reportType=task#reports">↻ Reset</a>
            </div>
        </form>
    </div>

    <div class="report-table-wrap">
        <table>
            <thead><tr><th>Task ID</th><th>Task Title</th><th>Department</th><th>Priority</th><th>Start Date</th><th>Due Date</th><th>Status</th><th>Manager Remarks</th></tr></thead>
            <tbody>
            <%
            Connection trCon = null;
            PreparedStatement trPs = null;
            ResultSet trRs = null;
            boolean trFound = false;
            try {
                StringBuilder sql = new StringBuilder(
                    "SELECT id,task_title,department,priority,start_date,due_date,status,manager_remarks " +
                    "FROM tasks WHERE assigned_to=?");
                if (!taskFrom.isEmpty()) sql.append(" AND start_date>=?");
                if (!taskTo.isEmpty()) sql.append(" AND start_date<=?");
                if (!taskFilter.isEmpty()) {
                    if ("ASSIGNED".equalsIgnoreCase(taskFilter)) {
                        sql.append(" AND (status IS NULL OR TRIM(status)='' OR UPPER(REPLACE(status,' ','_')) IN ('ASSIGNED','PENDING'))");
                    } else if ("IN_PROGRESS".equalsIgnoreCase(taskFilter)) {
                        sql.append(" AND UPPER(REPLACE(status,' ','_'))='IN_PROGRESS'");
                    } else {
                        sql.append(" AND UPPER(REPLACE(status,' ','_'))=?");
                    }
                }
                sql.append(" ORDER BY id DESC");

                trCon = DBcConnection.getConnection();
                trPs = trCon.prepareStatement(sql.toString());
                int p = 1;
                trPs.setString(p++, employeeId);
                if (!taskFrom.isEmpty()) trPs.setDate(p++, java.sql.Date.valueOf(taskFrom));
                if (!taskTo.isEmpty()) trPs.setDate(p++, java.sql.Date.valueOf(taskTo));
                if (!taskFilter.isEmpty() && !"ASSIGNED".equalsIgnoreCase(taskFilter)
                        && !"IN_PROGRESS".equalsIgnoreCase(taskFilter)) {
                    trPs.setString(p++, taskFilter.toUpperCase());
                }

                trRs = trPs.executeQuery();
                while (trRs.next()) {
                    trFound = true;
                    String st = trRs.getString("status");
                    if (st == null || st.trim().isEmpty()) st = "ASSIGNED";
                    String normalized = st.toUpperCase().replace(' ','_');
            %>
                <tr>
                    <td>#<%=trRs.getInt("id")%></td>
                    <td><strong><%=esc(trRs.getString("task_title"))%></strong></td>
                    <td><%=esc(trRs.getString("department") == null ? "-" : trRs.getString("department"))%></td>
                    <td><%=esc(trRs.getString("priority") == null ? "-" : trRs.getString("priority"))%></td>
                    <td><%=esc(util.DateFmt.date(trRs.getDate("start_date")))%></td>
                    <td><%=esc(util.DateFmt.date(trRs.getDate("due_date")))%></td>
                    <td><span class="report-status <%=reportStatusClass(st)%>"><%=esc(st)%></span></td>
                    <td><%=esc(trRs.getString("manager_remarks") == null || trRs.getString("manager_remarks").trim().isEmpty() ? "-" : trRs.getString("manager_remarks"))%></td>
                </tr>
            <%
                }
            } catch (Exception e) {
                application.log("Employee task report error", e);
            %>
                <tr><td colspan="8" class="report-empty-cell">Unable to load task report. Check the tasks table columns.</td></tr>
            <%
            } finally {
                try { if (trRs != null) trRs.close(); } catch (Exception e) {}
                try { if (trPs != null) trPs.close(); } catch (Exception e) {}
                try { if (trCon != null) trCon.close(); } catch (Exception e) {}
            }
            if (!trFound) {
            %>
                <tr><td colspan="8" class="report-empty-cell">No tasks found for the selected filters.</td></tr>
            <% } %>
            </tbody>
        </table>
    </div>
</div>
</div>

<div class="footer">Employee Portal • Employee Management System</div>
</div>
</div>

<script>
function openTaskModal(modalId) {
    var modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add("show");
        document.body.style.overflow = "hidden";
    }
}
function closeTaskModal(modalId) {
    var modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.remove("show");
        document.body.style.overflow = "";
    }
}
function closeTaskModalOutside(event, modalId) {
    if (event.target && event.target.id === modalId) closeTaskModal(modalId);
}

/* Change the selected report without changing the other dashboard sections. */
function changeEmployeeReport(selectedReport) {
    if (selectedReport !== "attendance" &&
        selectedReport !== "leave" &&
        selectedReport !== "task") {
        selectedReport = "attendance";
    }

    var url = new URL(window.location.href);
    url.searchParams.set("reportType", selectedReport);
    url.hash = "reports";
    window.location.href = url.toString();
}

document.addEventListener("keydown", function(event) {
    if (event.key === "Escape") {
        document.querySelectorAll(".task-modal.show").forEach(function(modal) {
            modal.classList.remove("show");
        });
        document.body.style.overflow = "";
    }
});
</script>
</body>
</html>



