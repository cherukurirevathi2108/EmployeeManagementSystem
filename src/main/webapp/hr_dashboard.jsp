<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,java.sql.*,model.Employe,model.Task,servlet.HRServlet" %>

<%!
    private String h(Object value) {
        if (value == null) return "";
        return String.valueOf(value)
            .replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace("\"", "&quot;")
            .replace("'", "&#39;");
    }
%>

<%
    HttpSession hrSession = request.getSession(false);
    if (hrSession == null ||
        !"HR".equalsIgnoreCase(String.valueOf(hrSession.getAttribute("role")))) {
        response.sendRedirect(request.getContextPath() + "/login.html");
        return;
    }

    String cp = request.getContextPath();
    String hrName = String.valueOf(hrSession.getAttribute("hrName") == null
        ? "HR" : hrSession.getAttribute("hrName"));
    String hrEmail = String.valueOf(hrSession.getAttribute("hrEmail") == null
        ? "" : hrSession.getAttribute("hrEmail"));

    int employeeCount = request.getAttribute("employeeCount") == null ? 0
        : (Integer) request.getAttribute("employeeCount");
    int managerCount = request.getAttribute("managerCount") == null ? 0
        : (Integer) request.getAttribute("managerCount");
    int teamCount = request.getAttribute("teamCount") == null ? 0
        : (Integer) request.getAttribute("teamCount");

    List<Employe> searchResults =
        (List<Employe>) request.getAttribute("searchResults");
    if (searchResults == null) searchResults = new ArrayList<Employe>();

    List<HRServlet.AttendanceData> attendanceData =
        (List<HRServlet.AttendanceData>) request.getAttribute("attendanceData");
    if (attendanceData == null) attendanceData = new ArrayList<HRServlet.AttendanceData>();

    List<HRServlet.LeaveData> leaveData =
        (List<HRServlet.LeaveData>) request.getAttribute("leaveData");
    if (leaveData == null) leaveData = new ArrayList<HRServlet.LeaveData>();

    List<Task> tasks = (List<Task>) request.getAttribute("tasks");
    if (tasks == null) tasks = new ArrayList<Task>();

    int taskCount = request.getAttribute("taskCount") == null ? tasks.size()
        : (Integer) request.getAttribute("taskCount");
    int pendingCount = request.getAttribute("pendingCount") == null ? 0
        : (Integer) request.getAttribute("pendingCount");
    int inProgressCount = request.getAttribute("inProgressCount") == null ? 0
        : (Integer) request.getAttribute("inProgressCount");
    int completedCount = request.getAttribute("completedCount") == null ? 0
        : (Integer) request.getAttribute("completedCount");

    String taskSearch = String.valueOf(request.getAttribute("taskSearch") == null
        ? "" : request.getAttribute("taskSearch"));
    String taskStatusFilter = String.valueOf(
        request.getAttribute("taskStatusFilter") == null
        ? "ALL" : request.getAttribute("taskStatusFilter"));

    String selectedManager = request.getParameter("selectedManager") == null
        ? "" : request.getParameter("selectedManager");
    String selectedTeam = request.getParameter("selectedTeam") == null
        ? "" : request.getParameter("selectedTeam");

    String teamMessage = null;
    String teamMessageType = "success";

    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String operation = request.getParameter("teamOperation");
        String teamId = request.getParameter("teamId");

        if (operation != null) {
            try {

                try (Connection con = model.DBcConnection.getConnection()) {

                    if ("createTeam".equals(operation)) {
                        String name = request.getParameter("teamName");
                        String description = request.getParameter("description");
                        String department = request.getParameter("department");
                        String managerId = request.getParameter("managerId");
                        String status = request.getParameter("status");

                        if (name == null || name.trim().isEmpty()
                            || managerId == null || managerId.trim().isEmpty()) {
                            throw new Exception("Team name and manager are required.");
                        }

                        String newTeamId;
                        try (PreparedStatement ps = con.prepareStatement(
                            "SELECT CONCAT('TEAM',LPAD(COALESCE(MAX(CAST(SUBSTRING(team_id,5) AS UNSIGNED)),0)+1,3,'0')) FROM teams");
                             ResultSet rs = ps.executeQuery()) {
                            rs.next();
                            newTeamId = rs.getString(1);
                        }

                        try (PreparedStatement ps = con.prepareStatement(
                            "INSERT INTO teams(team_id,team_name,description,department,manager_id,status,created_at,updated_at) VALUES(?,?,?,?,?,?,NOW(),NOW())")) {
                            ps.setString(1, newTeamId);
                            ps.setString(2, name.trim());
                            ps.setString(3, description);
                            ps.setString(4, department);
                            ps.setString(5, managerId);
                            ps.setString(6, status == null ? "ACTIVE" : status);
                            ps.executeUpdate();
                        }
                        teamMessage = "Team created successfully: " + newTeamId;

                    } else if ("saveTeam".equals(operation)) {
                        try (PreparedStatement ps = con.prepareStatement(
                            "UPDATE teams SET team_name=?,description=?,department=?,manager_id=?,status=?,updated_at=NOW() WHERE team_id=?")) {
                            ps.setString(1, request.getParameter("teamName"));
                            ps.setString(2, request.getParameter("description"));
                            ps.setString(3, request.getParameter("department"));
                            ps.setString(4, request.getParameter("managerId"));
                            ps.setString(5, request.getParameter("status"));
                            ps.setString(6, teamId);
                            teamMessage = ps.executeUpdate() > 0
                                ? "Team updated successfully." : "Team not found.";
                        }

                    } else if ("deleteTeam".equals(operation)) {
                        con.setAutoCommit(false);
                        try {
                            try (PreparedStatement ps = con.prepareStatement(
                                "DELETE FROM team_members WHERE team_id=?")) {
                                ps.setString(1, teamId);
                                ps.executeUpdate();
                            }
                            try (PreparedStatement ps = con.prepareStatement(
                                "DELETE FROM teams WHERE team_id=?")) {
                                ps.setString(1, teamId);
                                ps.executeUpdate();
                            }
                            con.commit();
                            teamMessage = "Team deleted successfully.";
                        } catch (Exception ex) {
                            con.rollback();
                            throw ex;
                        }

                    } else if ("addMember".equals(operation)) {
                        try (PreparedStatement ps = con.prepareStatement(
                            "INSERT IGNORE INTO team_members(team_id,employee_id) VALUES(?,?)")) {
                            ps.setString(1, teamId);
                            ps.setString(2, request.getParameter("employeeId"));
                            teamMessage = ps.executeUpdate() > 0
                                ? "Employee added to team."
                                : "Employee is already assigned to this team.";
                        }

                    } else if ("removeMember".equals(operation)) {
                        try (PreparedStatement ps = con.prepareStatement(
                            "DELETE FROM team_members WHERE team_id=? AND employee_id=?")) {
                            ps.setString(1, teamId);
                            ps.setString(2, request.getParameter("employeeId"));
                            ps.executeUpdate();
                            teamMessage = "Employee removed from team.";
                        }
                    }
                }
            } catch (Exception e) {
                teamMessage = "Team operation failed: " + e.getMessage();
                teamMessageType = "error";
                application.log("Team management error", e);
            }
        }
    }

    String action = request.getAttribute("action") == null
        ? "" : String.valueOf(request.getAttribute("action"));

    List<HRServlet.ReportRow> reportRows =
        (List<HRServlet.ReportRow>) request.getAttribute("reportRows");
    if (reportRows == null) reportRows = new ArrayList<HRServlet.ReportRow>();

    String reportType = request.getAttribute("reportType") == null
        ? "employees" : String.valueOf(request.getAttribute("reportType"));
    String fromDate = request.getAttribute("fromDate") == null
        ? "" : String.valueOf(request.getAttribute("fromDate"));
    String toDate = request.getAttribute("toDate") == null
        ? "" : String.valueOf(request.getAttribute("toDate"));
    String reportSearch = request.getAttribute("reportSearch") == null
        ? "" : String.valueOf(request.getAttribute("reportSearch"));
    String personType = request.getAttribute("personType") == null
        ? "ALL" : String.valueOf(request.getAttribute("personType"));
    String attendanceStatus = request.getAttribute("attendanceStatus") == null
        ? "ALL" : String.valueOf(request.getAttribute("attendanceStatus"));

    int reportTotal = request.getAttribute("reportTotal") == null
        ? 0 : (Integer) request.getAttribute("reportTotal");
    int reportEmployeeCount = request.getAttribute("reportEmployeeCount") == null
        ? employeeCount : (Integer) request.getAttribute("reportEmployeeCount");
    int reportAttendanceCount = request.getAttribute("reportAttendanceCount") == null
        ? 0 : (Integer) request.getAttribute("reportAttendanceCount");
    int reportTaskCount = request.getAttribute("reportTaskCount") == null
        ? taskCount : (Integer) request.getAttribute("reportTaskCount");
    int reportLeaveCount = request.getAttribute("reportLeaveCount") == null
        ? 0 : (Integer) request.getAttribute("reportLeaveCount");
%>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HR Dashboard - <%= util.Html.esc(util.Branding.name()) %></title>

<style>
*{box-sizing:border-box;margin:0;padding:0;font-family:"Segoe UI",Arial,sans-serif}
html{scroll-behavior:smooth;scroll-padding-top:20px}
body{background:#f4f7fb;color:#1e293b}
.sidebar{position:fixed;left:0;top:0;width:235px;height:100vh;overflow-y:auto;background:#111827;padding:22px 15px;color:#fff;z-index:10}
.logo{font-size:23px;font-weight:bold;padding:10px 12px 25px}
.logo span{color:#818cf8}
.menu-title{font-size:11px;color:#9ca3af;padding:15px 12px 8px;text-transform:uppercase;letter-spacing:1px}
.sidebar a{display:block;color:#d1d5db;text-decoration:none;padding:10px 12px;margin:4px 0;border-radius:8px;font-size:13px}
.sidebar a:hover{background:#263247;color:white}
.sidebar .logout{color:#fca5a5;margin-top:20px}
.main{margin-left:235px;min-height:100vh}
.header{min-height:75px;background:white;border-bottom:1px solid #e5e7eb;display:flex;align-items:center;justify-content:space-between;gap:15px;padding:15px 28px}
.header h2{font-size:22px}
.header p,.profile-info span{color:#6b7280;font-size:12px;margin-top:4px}
.admin-profile{display:flex;align-items:center;gap:10px}
.profile-circle{width:42px;height:42px;border-radius:50%;background:#6366f1;color:white;display:flex;align-items:center;justify-content:center;font-weight:bold}
.profile-info strong,.profile-info span{display:block}
.profile-info strong{font-size:13px}
.content{padding:24px 28px}
.welcome{background:linear-gradient(135deg,#6366f1,#4338ca);color:white;border-radius:15px;padding:25px;margin-bottom:22px}
.welcome h1{font-size:26px;margin-bottom:8px}
.welcome p{font-size:13px}
.stats,.task-stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:22px}
.stat-card,.task-stat{background:white;padding:18px;border:1px solid #e5e7eb;border-radius:12px}
.stat-card h3{font-size:24px;margin:8px 0}
.stat-card p,.task-stat span{font-size:12px;color:#6b7280}
.stat-icon{font-size:22px}
.task-stat strong{display:block;font-size:22px;margin-bottom:4px}
.section{background:white;border:1px solid #e5e7eb;border-radius:13px;padding:21px;margin-bottom:22px}
.section-header{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:17px}
.section-header h2{font-size:19px}
.section-header p{color:#6b7280;font-size:12px;margin-top:5px}
.button-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.dashboard-btn{display:block;padding:16px;background:#f8fafc;border:1px solid #e5e7eb;border-radius:10px;color:#1e293b;text-decoration:none}
.dashboard-btn:hover{background:#eef2ff;border-color:#c7d2fe}
.dashboard-btn strong,.dashboard-btn span{display:block}
.dashboard-btn strong{font-size:13px;margin-bottom:6px}
.dashboard-btn span{font-size:11px;color:#6b7280}
input,select,textarea{width:100%;padding:10px;border:1px solid #cbd5e1;border-radius:7px;background:white;font-size:13px}
label{display:block;font-size:12px;font-weight:600}
label input,label select,label textarea{margin-top:6px;font-weight:normal}
.search-box,.filter-box{display:flex;gap:9px;flex-wrap:wrap;margin-bottom:16px;align-items:end}
.search-box input,.filter-box input,.filter-box select{flex:1;min-width:150px}
button,.btn{display:inline-block;padding:9px 12px;border:0;border-radius:7px;color:white;font-size:12px;cursor:pointer;text-decoration:none;white-space:nowrap}
.primary{background:#4f46e5}.success{background:#16a34a}.danger{background:#dc2626}.neutral{background:#475569}
button:hover,.btn:hover{opacity:.88}
.table-container{width:100%;overflow-x:auto}
table{width:100%;border-collapse:collapse;min-width:750px}
th{background:#f8fafc;color:#64748b;text-align:left;text-transform:uppercase;font-size:10px;padding:12px}
td{padding:12px;border-bottom:1px solid #edf0f4;font-size:12px;vertical-align:top;max-width:300px;overflow-wrap:anywhere}
.status{display:inline-block;padding:5px 9px;border-radius:20px;font-size:10px;font-weight:700;background:#e2e8f0;color:#334155}
.status-active,.status-completed{background:#dcfce7;color:#166534}
.status-pending{background:#fef3c7;color:#92400e}
.status-in_progress{background:#dbeafe;color:#1d4ed8}
.status-rejected,.status-inactive{background:#fee2e2;color:#991b1b}
.status-absent{background:#fee2e2;color:#991b1b}
.status-leave{background:#fef3c7;color:#92400e}
.status-present{background:#dcfce7;color:#166534}
.team-inline-panel{display:none;background:#f8fafc;padding:15px;margin:8px 0;border:1px solid #e2e8f0;border-radius:9px}
.team-inline-panel h3{margin-bottom:12px;font-size:15px}
.team-form-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
.full-width{grid-column:1/-1}
.form-actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
.small-note{font-size:11px;color:#64748b;margin-top:7px;white-space:pre-wrap}
.message{padding:12px 14px;border-radius:8px;margin-bottom:15px;font-size:13px}
.message-success{background:#dcfce7;color:#166534}
.message-error{background:#fee2e2;color:#991b1b}
.manager-review-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:20px}
.manager-review-card{display:block;text-decoration:none;color:#1e293b;background:#f8fafc;border:1px solid #e2e8f0;padding:16px;border-radius:10px}
.manager-review-card strong,.manager-review-card span{display:block}
.manager-review-card span{color:#64748b;font-size:12px;margin-top:4px}
.review-heading{background:#f8fafc;border:1px solid #e2e8f0;border-radius:9px;padding:14px;margin-bottom:15px}
.review-heading h3{font-size:16px;margin-bottom:5px}
.review-heading p{color:#64748b;font-size:12px;margin-top:5px}
.report-cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-bottom:18px}
.report-card{padding:17px;border:1px solid #e2e8f0;background:#f8fafc;border-radius:10px}
.report-card strong{display:block;font-size:23px;margin-bottom:5px}
.report-card span{font-size:12px;color:#64748b}
.report-filter-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:14px}
.report-filter-actions{display:flex;gap:9px;flex-wrap:wrap;margin-bottom:18px}
.report-members-panel{display:none;background:#f8fafc;border:1px solid #e2e8f0;border-radius:9px;padding:15px;margin:8px 0}
.report-members-panel h3{font-size:15px;margin-bottom:10px}
.report-members-panel table{min-width:850px}
.report-member-toggle{min-width:115px}
@media(max-width:1100px){.stats,.task-stats,.report-cards{grid-template-columns:repeat(2,minmax(0,1fr))}.button-grid,.manager-review-grid,.report-filter-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:760px){.sidebar{position:relative;width:100%;height:auto}.main{margin-left:0}.header{padding:15px}.content{padding:14px}.stats,.task-stats,.button-grid,.team-form-grid,.manager-review-grid,.report-cards,.report-filter-grid{grid-template-columns:1fr}.full-width{grid-column:auto}}
</style>
<style>
/* ===== Professional theme (admin) ===== */
:root{--brand:#4f46e5;--brand-dark:#4338ca;--ink:#0f172a;--muted:#64748b;--line:#e2e8f0;--bg:#f1f5f9;--shadow:0 1px 2px rgba(15,23,42,.05),0 6px 20px rgba(15,23,42,.05)}
body{background:var(--bg);color:var(--ink);-webkit-font-smoothing:antialiased}
.sidebar{background:linear-gradient(180deg,#0b1220 0%,#111c33 100%);box-shadow:2px 0 18px rgba(15,23,42,.18)}
.sidebar::-webkit-scrollbar{width:6px}.sidebar::-webkit-scrollbar-thumb{background:#334155;border-radius:6px}
.logo{font-size:22px;letter-spacing:.3px;border-bottom:1px solid rgba(255,255,255,.08);margin-bottom:6px}
.menu-title{color:#64748b;font-weight:600;letter-spacing:1.2px}
.sidebar a{border-left:3px solid transparent;transition:background .15s,color .15s,border-color .15s,padding-left .15s}
.sidebar a:hover{background:rgba(255,255,255,.07);color:#fff;padding-left:15px}
.sidebar a.active{background:rgba(99,102,241,.2);color:#fff;border-left-color:#818cf8;font-weight:600}
.sidebar .logout{background:rgba(248,113,113,.08)}
.sidebar .logout:hover{background:rgba(248,113,113,.18)}
.header{position:sticky;top:0;z-index:9;background:rgba(255,255,255,.92);backdrop-filter:blur(8px);box-shadow:0 1px 0 var(--line),0 4px 14px rgba(15,23,42,.04)}
.header h2{font-weight:700;letter-spacing:-.2px}
.profile-circle{background:linear-gradient(135deg,#6366f1,#4338ca);box-shadow:0 4px 10px rgba(79,70,229,.35)}
.content{max-width:1500px}
.welcome{background:linear-gradient(120deg,#312e81 0%,#4f46e5 55%,#6366f1 100%);border-radius:16px;box-shadow:0 12px 28px rgba(79,70,229,.25);position:relative;overflow:hidden}
.welcome::after{content:"";position:absolute;right:-60px;top:-60px;width:220px;height:220px;border-radius:50%;background:rgba(255,255,255,.08)}
.welcome h1{font-weight:700}
.stat-card,.task-stat{border:1px solid var(--line);border-radius:14px;box-shadow:var(--shadow);transition:transform .15s,box-shadow .15s}
.stat-card:hover,.task-stat:hover{transform:translateY(-2px);box-shadow:0 10px 26px rgba(15,23,42,.09)}
.stat-card{border-top:3px solid var(--brand)}
.stat-card h3{font-weight:700}
.stat-icon{width:42px;height:42px;border-radius:11px;background:#eef2ff;display:flex;align-items:center;justify-content:center}
.section{border:1px solid var(--line);border-radius:16px;box-shadow:var(--shadow);padding:24px}
.section-header h2,.section>h2{font-weight:700;letter-spacing:-.2px}
.dashboard-btn,.manager-review-card{border-radius:12px;transition:transform .15s,box-shadow .15s,border-color .15s,background .15s}
.dashboard-btn:hover,.manager-review-card:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(79,70,229,.12);border-color:#c7d2fe;background:#f5f7ff}
input,select,textarea{border:1.5px solid #dbe2ec;border-radius:9px;padding:10px 12px;transition:border-color .15s,box-shadow .15s}
input:focus,select:focus,textarea:focus{outline:none;border-color:var(--brand);box-shadow:0 0 0 4px rgba(79,70,229,.12)}
label{color:#334155}
button,.btn{border-radius:9px;font-weight:600;padding:10px 16px;letter-spacing:.2px;transition:transform .1s,box-shadow .15s,opacity .15s}
button:hover,.btn:hover{opacity:1;transform:translateY(-1px)}
.primary{background:linear-gradient(135deg,#4f46e5,#4338ca);box-shadow:0 4px 10px rgba(79,70,229,.25)}
.success{background:linear-gradient(135deg,#16a34a,#15803d);box-shadow:0 4px 10px rgba(22,163,74,.22)}
.danger{background:linear-gradient(135deg,#ef4444,#dc2626);box-shadow:0 4px 10px rgba(220,38,38,.22)}
.neutral{background:linear-gradient(135deg,#64748b,#475569)}
.table-container{border:1px solid var(--line);border-radius:12px;background:#fff}
table{border-collapse:separate;border-spacing:0}
th{background:#f8fafc;color:#475569;font-weight:700;letter-spacing:.6px;border-bottom:1px solid var(--line);position:sticky;top:0}
td{border-bottom:1px solid #eef2f7}
tbody tr{transition:background .12s}
tbody tr:nth-child(even){background:#fcfdff}
tbody tr:hover{background:#f5f7ff}
tbody tr:last-child td{border-bottom:0}
td a:not(.btn){color:#4338ca;font-weight:600;text-decoration:none}
td a:not(.btn):hover{text-decoration:underline}
.status{padding:5px 11px;letter-spacing:.3px;text-transform:uppercase;font-size:10px}
.message{border-radius:10px;border:1px solid transparent}
.message-success{border-color:#bbf7d0}.message-error{border-color:#fecaca}
.review-heading,.report-card,.team-inline-panel,.report-members-panel{border-radius:12px}
.report-card{background:#fff;box-shadow:var(--shadow);border-top:3px solid var(--brand)}
.report-card strong{font-weight:700}
.people-filter{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-end;margin-bottom:18px;padding:16px;border:1px solid var(--line);border-radius:12px;background:linear-gradient(180deg,#fbfcff,#f6f8fc)}
.people-filter label{flex:1 1 230px;min-width:200px}
.people-filter .pf-actions{display:flex;gap:8px;align-items:center}
.people-filter .pf-hint{flex-basis:100%;font-size:11px;color:var(--muted);margin-top:-4px}
@media(max-width:760px){.header{position:static}}
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
                if(!best && !a.classList.contains("logout") && (h==="#dashboard" || /\/hr$/.test(h) || h==="#")){ best=a; }
            });
        }
        if(best) best.classList.add("active");
    }
    window.addEventListener("hashchange",mark);
    document.addEventListener("DOMContentLoaded",mark);
})();
</script>


<script>
function togglePanel(id){
    var panel=document.getElementById(id);
    if(!panel)return;
    var show=panel.style.display!=="block";
    document.querySelectorAll(".team-inline-panel").forEach(function(p){
        p.style.display="none";
    });
    panel.style.display=show?"block":"none";
}

function toggleReportMembers(id, button){
    var panel=document.getElementById(id);
    if(!panel)return;
    var show=panel.style.display!=="block";
    panel.style.display=show?"block":"none";
    if(button){
        button.textContent=show?"Hide Members":"View Members";
        button.setAttribute("aria-expanded",show?"true":"false");
    }
}

function phAddComponent(){
    var wrap=document.getElementById("phCompRows");
    if(!wrap)return;
    var row=wrap.firstElementChild.cloneNode(true);
    row.querySelectorAll("input").forEach(function(i){i.value="";});
    wrap.appendChild(row);
}

function confirmTeamDelete(){
    return confirm("Delete this team and all its member assignments?");
}

document.addEventListener("DOMContentLoaded",function(){
    document.querySelectorAll("[data-task-status]").forEach(function(link){
        link.addEventListener("click",function(){
            var filter=document.getElementById("taskStatusFilter");
            if(filter) filter.value=this.getAttribute("data-task-status");
        });
    });
});
</script>
<script>
/* Reports open as their own page view (no other dashboard sections around them) */
(function(){
    var d=document.documentElement;
    function sync(){ d.classList.toggle("reports-mode", window.location.hash==="#reports"); d.classList.toggle("payroll-mode", window.location.hash==="#payroll"); }
    window.addEventListener("hashchange",function(){
        sync();
        var h=window.location.hash;
        var el=h.length>1?document.getElementById(h.substring(1)):null;
        if(el&&h!=="#reports"&&h!=="#payroll"){ el.scrollIntoView(); } else { window.scrollTo(0,0); }
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
html.reports-mode .content > :not(#reports){display:none!important}
/* ===== Payroll page view (same behaviour as Reports) ===== */
.payroll-pagebar{display:none;align-items:center;justify-content:space-between;flex-wrap:wrap;gap:10px;margin:-4px 0 18px;padding-bottom:14px;border-bottom:1px solid #e2e8f0}
html.payroll-mode .payroll-pagebar{display:flex}
html.payroll-mode .content > :not(#payroll){display:none!important}
.payroll-num{text-align:right;white-space:nowrap}
.ph-head-actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center}
.ph-btn{display:inline-block;padding:10px 18px;border-radius:999px;font-size:13px;font-weight:700;text-decoration:none;cursor:pointer;border:1.5px solid #2563eb;white-space:nowrap}
.ph-btn-outline{background:#fff;color:#2563eb}
.ph-btn-solid{background:#2563eb;color:#fff;box-shadow:0 4px 10px rgba(37,99,235,.28)}
.ph-tabs{display:flex;gap:6px;flex-wrap:wrap;border-bottom:1px solid #e2e8f0;margin:6px 0 16px}
.ph-tabs a{padding:10px 16px;font-size:13px;font-weight:600;color:#64748b;text-decoration:none;border-bottom:3px solid transparent;margin-bottom:-1px}
.ph-tabs a:hover{color:#1e293b}
.ph-tabs a.active{color:#2563eb;border-bottom-color:#2563eb}
.ph-period,.ph-filter{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-end;margin-bottom:16px}
.ph-period label,.ph-filter label,.ph-form-grid label{display:flex;flex-direction:column;gap:4px;font-size:12px;color:#475569;font-weight:600}
.ph-period select,.ph-period input,.ph-filter select,.ph-filter input,.ph-form-grid select,.ph-form-grid input,.ph-comp-row input,.ph-comp-row select{padding:9px 11px;border:1px solid #cbd5e1;border-radius:8px;font-size:13px;background:#fff}
.ph-cards{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px;margin-bottom:20px}
.ph-cards-3{grid-template-columns:repeat(3,minmax(0,1fr))}
.ph-card{background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:18px;box-shadow:0 1px 3px rgba(15,23,42,.06)}
.ph-card strong{display:block;font-size:24px;margin:8px 0 4px;color:#0f172a}
.ph-card small{color:#64748b;font-size:12px}
.ph-label{font-size:11px;letter-spacing:.6px;color:#64748b;font-weight:700}
.ph-blue{color:#2563eb!important}.ph-red{color:#dc2626}.ph-green{color:#15803d}.ph-muted{color:#64748b}
.ph-link{display:inline-block;margin-top:10px;font-size:12px;font-weight:700;color:#2563eb;text-decoration:none;border:1px solid #cbd5e1;border-radius:999px;padding:6px 12px}
.ph-chip{display:inline-block;background:#f1f5f9;border:1px solid #e2e8f0;border-radius:6px;padding:2px 8px;font-size:11px;font-weight:600;color:#475569}
.ph-att{display:inline-block;background:#f1f5f9;border-radius:6px;padding:3px 8px;font-size:12px;font-weight:600;color:#334155}
.ph-lop{display:inline-block;background:#fee2e2;color:#b91c1c;border-radius:6px;padding:3px 8px;font-size:11px;font-weight:700;margin-left:4px}
.ph-actions{white-space:nowrap}
.ph-mini{display:inline-block;padding:6px 11px;border-radius:7px;border:1px solid #cbd5e1;background:#fff;color:#1e293b;font-size:12px;font-weight:700;text-decoration:none;cursor:pointer;box-shadow:none}
.ph-mini:hover{background:#f1f5f9;transform:none}
.ph-mini-pay{background:#16a34a;border-color:#16a34a;color:#fff}
.ph-mini-pay:hover{background:#15803d}
.ph-mini-process{background:#2563eb;border-color:#2563eb;color:#fff}
.ph-mini-process:hover{background:#1d4ed8}
.ph-form-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}
.ph-form-grid-2{grid-template-columns:repeat(2,minmax(0,1fr))}
.ph-comp-row{display:grid;grid-template-columns:2fr 1.4fr 1.4fr 1fr;gap:8px;margin-bottom:8px}
.ph-comp{display:inline-block;border-radius:6px;padding:2px 8px;font-size:11px;font-weight:700;margin:2px 4px 2px 0}
.ph-comp-earn{background:#dcfce7;color:#166534}.ph-comp-ded{background:#fee2e2;color:#991b1b}
.ph-comps-cell{min-width:290px}
.ph-comp-group{display:flex;align-items:flex-start;gap:10px;padding:6px 0}
.ph-comp-group + .ph-comp-group{border-top:1px dashed #e2e8f0}
.ph-comp-title{flex:0 0 78px;font-size:10px;font-weight:800;letter-spacing:.8px;text-transform:uppercase;padding-top:6px}
.ph-comp-title.earn{color:#15803d}.ph-comp-title.ded{color:#b91c1c}
.ph-comp-list{display:flex;flex-wrap:wrap;gap:6px;flex:1}
.ph-comp2{display:inline-flex;align-items:center;gap:7px;background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:4px 10px;font-size:11.5px;color:#475569;box-shadow:0 1px 2px rgba(15,23,42,.04)}
.ph-comp2 i{width:7px;height:7px;border-radius:50%;flex:0 0 7px}
.ph-comp2.earn i{background:#16a34a}.ph-comp2.ded i{background:#dc2626}
.ph-comp2 b{color:#0f172a;font-weight:700}
.ph-comp2.ded b{color:#b91c1c}
.ph-cards-2{grid-template-columns:repeat(2,minmax(0,1fr))}
.ph-modal{position:fixed;inset:0;background:rgba(15,23,42,.55);z-index:1000;align-items:center;justify-content:center;padding:16px}
.ph-modal-box{background:#fff;border-radius:14px;padding:22px;width:100%;max-width:520px;max-height:92vh;overflow:auto}
@media(max-width:1100px){.ph-cards,.ph-cards-3{grid-template-columns:repeat(2,minmax(0,1fr))}.ph-form-grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:760px){.ph-cards,.ph-cards-2,.ph-cards-3,.ph-form-grid,.ph-form-grid-2,.ph-comp-row{grid-template-columns:1fr}}
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
    var HOME="<%= cp %>/hr";
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
                if(href==="#home"||href==="#dashboard"||/\/hr$/.test(href)) return;
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
    <%= util.Branding.sidebar("HR Panel") %>
    <div class="menu-title">Dashboard</div>
    <a href="<%= cp %>/hr">🏠 Dashboard</a>
    <div class="menu-title">My Work</div>
    <a href="<%= cp %>/hr?action=myAttendance#myAttendance">🕘 My Attendance &amp; Breaks</a>
    <a href="<%= cp %>/hr?action=myAttendance#myLeaves">📝 My Leaves</a>
    <div class="menu-title">Employees</div>
    <a href="#addEmployee">➕ Add Employee</a>
    <a href="<%= cp %>/hr?action=viewManagers#addManager">👤 Add Manager</a>
    <a href="<%= cp %>/hr?action=viewEmployees#viewEmployees">👥 View Employees</a>
    <a href="#searchEmployee">🔍 Search Employee</a>
    <div class="menu-title">Teams</div>
    <a href="#manageTeams">👥 Manage Teams</a>
    <a href="#createTeamPanel" onclick="togglePanel('createTeamPanel')">➕ Create Team</a>
    <div class="menu-title">Tasks</div>
    <a href="#taskDashboard">📊 Task Dashboard</a>
    <a href="#taskManagement">📋 Task Management</a>
    <a href="#managerReviews">⭐ Manager Reviews</a>
    <div class="menu-title">Attendance</div>
    <a href="<%= cp %>/hr?action=todayAttendance#attendance">📅 Today's Attendance</a>
    <a href="<%= cp %>/hr?action=monthlyAttendance#attendance">📊 Monthly Attendance</a>
    <div class="menu-title">Leave</div>
    <a href="<%= cp %>/hr?action=viewLeaves#leaveManagement">📝 Leave Management</a>
    <div class="menu-title">Payroll</div>
    <a href="<%= cp %>/hr?action=payroll&tab=structures#payroll">🧾 Salary Structures</a>
    <a href="<%= cp %>/hr?action=payroll&tab=process#payroll">⚙️ Process Payroll</a>
    <a href="<%= cp %>/hr?action=payroll&tab=history#payroll">🕑 History &amp; Reports</a>
    <div class="menu-title">Reports</div>
    <a href="<%= cp %>/hr?action=reports&reportType=employees#reports">📈 Employees & Managers Report</a>
    <a class="logout" href="<%= cp %>/logout">🚪 Logout</a>
</div>

<div class="main">
<div class="header">
    <div><h2>HR Dashboard</h2><p>Employee Management System</p></div>
    <div class="admin-profile">
        <div class="profile-circle">H</div>
        <div class="profile-info">
            <strong><%= h(hrName) %></strong>
            <span><%= h(hrEmail) %></span>
        </div>
    </div>
</div>

<div class="content">
    <div class="welcome">
        <h1>Welcome, <%= h(hrName) %> 👋</h1>
        <p>Manage employees, teams, tasks, attendance, leaves, payroll and reports from one dashboard.</p>
    </div>

    <% if ("failed".equals(request.getParameter("error"))) { %>
        <div class="message message-error">That action could not be completed. Please try again.</div>
    <% } %>
    <% if (request.getAttribute("pageError") != null) { %>
        <div class="message message-error"><%= h(request.getAttribute("pageError")) %></div>
    <% } %>

    <div class="stats">
        <div class="stat-card"><div class="stat-icon">👥</div><h3><%= employeeCount %></h3><p>Total Employees</p></div>
        <div class="stat-card"><div class="stat-icon">👤</div><h3><%= managerCount %></h3><p>Total Managers</p></div>
        <div class="stat-card"><div class="stat-icon">🏢</div><h3><%= teamCount %></h3><p>Total Teams</p></div>
        <div class="stat-card"><div class="stat-icon">📋</div><h3><%= taskCount %></h3><p>Total Tasks</p></div>
    </div>

    <!-- TASK DASHBOARD -->
    <div class="section" id="taskDashboard">
        <div class="section-header">
            <div><h2>📊 Task Dashboard</h2><p>Overview of task progress.</p></div>
            <a class="btn primary" href="#taskManagement">View Tasks</a>
        </div>
        <div class="task-stats">
            <div class="task-stat"><strong><%= taskCount %></strong><span>Total Tasks</span></div>
            <div class="task-stat"><strong><%= pendingCount %></strong><span>Pending Tasks</span></div>
            <div class="task-stat"><strong><%= inProgressCount %></strong><span>In Progress</span></div>
            <div class="task-stat"><strong><%= completedCount %></strong><span>Completed</span></div>
        </div>
        <div class="button-grid">
            <a class="dashboard-btn" href="#taskManagement"><strong>📋 View All Tasks</strong><span>View task assignments and progress.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=searchTasks&status=PENDING#taskManagement"><strong>⏳ Pending Tasks</strong><span>See pending tasks.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=searchTasks&status=IN_PROGRESS#taskManagement"><strong>🔄 In Progress</strong><span>See ongoing tasks.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=searchTasks&status=COMPLETED#taskManagement"><strong>✅ Completed Tasks</strong><span>See completed tasks.</span></a>
            <a class="dashboard-btn" href="#managerReviews"><strong>⭐ Manager Reviews</strong><span>Filter reviews by manager and team.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=reports&reportType=employees#reports"><strong>📈 Reports</strong><span>Open reports dashboard.</span></a>
        </div>
    </div>

    <!-- EMPLOYEE MANAGEMENT -->
    <div class="section" id="employeeManagement">
        <div class="section-header">
            <div><h2>👥 Employee Management</h2><p>Manage employee information.</p></div>
        </div>
        <div class="button-grid">
            <a class="dashboard-btn" href="#addEmployee"><strong>➕ Add Employee</strong><span>Register a new employee.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=viewManagers#addManager"><strong>👤 Add Manager</strong><span>Register a new manager.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=viewEmployees#viewEmployees"><strong>👥 View Employees</strong><span>View all registered employees.</span></a>
            <a class="dashboard-btn" href="#searchEmployee"><strong>🔍 Search Employee</strong><span>Search by ID or name.</span></a>
        </div>
    </div>


    <!-- ADD EMPLOYEE -->
    <div class="section" id="addEmployee">
        <div class="section-header">
            <div><h2>➕ Add Employee</h2><p>Register a new employee. The ID (EMP001, EMP002, ...) is generated automatically and the login details are emailed.</p></div>
        </div>
<%
    String empMsgAdd = request.getParameter("empMessage");
%>
        <% if ("duplicate".equals(empMsgAdd)) { %>
            <div class="message message-error">An employee, manager or HR user with this email already exists.</div>
        <% } else if ("invalid".equals(empMsgAdd)) { %>
            <div class="message message-error">Please fill every required field. Use a valid email, a non-negative salary and a password of at least 6 characters.</div>
        <% } %>
        <form method="post" action="<%= cp %>/hr">
            <input type="hidden" name="action" value="addEmployee">
            <div class="team-form-grid">
                <label>Full Name *<input type="text" name="name" maxlength="100" required></label>
                <label>Email *<input type="email" name="email" maxlength="100" required></label>
                <label>Phone<input type="tel" name="phone" maxlength="15"></label>
                <label>Department *<input type="text" name="department" maxlength="100" required></label>
                <label>Designation *<input type="text" name="designation" maxlength="100" required></label>
                <label>Monthly Salary (&#8377;) *<input type="number" name="salary" min="0" step="0.01" required></label>
                <label>Status
                    <select name="status"><option value="ACTIVE">ACTIVE</option><option value="INACTIVE">INACTIVE</option></select>
                </label>
                <label class="full-width">Temporary Password * (min. 6 characters)
                    <input type="password" name="password" minlength="6" required autocomplete="new-password">
                </label>
            </div>
            <div class="form-actions">
                <button class="success" type="submit">Add Employee</button>
                <button class="neutral" type="reset">Clear</button>
            </div>
        </form>
    </div>

    <!-- VIEW EMPLOYEES -->
    <div class="section" id="viewEmployees">
        <div class="section-header">
            <div><h2>👥 View Employees</h2><p>All registered employees.</p></div>
            <a class="btn primary" href="#addEmployee">➕ Add Employee</a>
        </div>
<%
    List<Employe> employeeList = (List<Employe>) request.getAttribute("employeeList");
    if (employeeList == null) employeeList = new ArrayList<Employe>();
    String empMsgView = request.getParameter("empMessage");
%>
        <% if ("created".equals(empMsgView) || "resent".equals(empMsgView)) {
               boolean empMailOk = "sent".equals(request.getParameter("mail")); %>
            <div class="message <%= empMailOk ? "message-success" : "message-error" %>">
                <%= "created".equals(empMsgView) ? "Employee added. " : "" %>Employee ID: <strong><%= h(request.getParameter("newId")) %></strong>.
                <%= empMailOk ? "Login ID, password and login link were emailed." : "The login email could not be sent - use the Resend button below or share the details manually." %>
                <% if (!empMailOk && request.getParameter("mailErr") != null && !request.getParameter("mailErr").isEmpty()) { %>
                    <br><small>Reason: <%= h(request.getParameter("mailErr")) %></small>
                <% } %>
            </div>
        <% } %>
        <a class="btn primary" href="<%= cp %>/hr?action=viewEmployees#viewEmployees">Load / Refresh Employee List</a>
        <br><br>

        <div class="table-container">
            <table>
                <thead><tr><th>Employee ID</th><th>Name</th><th>Email</th><th>Phone</th><th>Department</th><th>Designation</th><th>Salary</th><th>Status</th><th>Login Email</th></tr></thead>
                <tbody>
                <% for (Employe emp : employeeList) {
                    String empSt = emp.getStatus() == null ? "" : emp.getStatus().trim().toUpperCase(); %>
                    <tr>
                        <td><%= h(emp.getEmployeeId()) %></td>
                        <td><%= h(emp.getName()) %></td>
                        <td><%= h(emp.getEmail()) %></td>
                        <td><%= h(emp.getPhone()) %></td>
                        <td><%= h(emp.getDepartment()) %></td>
                        <td><%= h(emp.getDesignation()) %></td>
                        <td class="payroll-num"><%= h(emp.getSalary()) %></td>
                        <td><span class="status <%= "ACTIVE".equals(empSt) ? "status-active" : "status-inactive" %>"><%= h(empSt.isEmpty() ? "INACTIVE" : empSt) %></span></td>
                        <td><form method="post" action="<%= cp %>/hr" style="margin:0" onsubmit="return confirm('Email the login ID, password and link to this person again?')"><input type="hidden" name="action" value="resendCredentials"><input type="hidden" name="personId" value="<%= h(emp.getEmployeeId()) %>"><input type="hidden" name="personType" value="EMPLOYEE"><button class="neutral" type="submit" style="padding:6px 10px;font-size:12px">&#128231; Resend</button></form></td>
                    </tr>
                <% } %>
                <% if (employeeList.isEmpty()) { %>
                    <tr><td colspan="9" style="text-align:center">No employees found. Use the link above to load the list.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>

    </div>


    <!-- ADD MANAGER -->
<%
    List<String[]> managerList = (List<String[]>) request.getAttribute("managerList");
    if (managerList == null) managerList = new ArrayList<String[]>();
    String mgrMsg = request.getParameter("mgrMessage");
%>
    <div class="section" id="addManager">
        <div class="section-header">
            <div><h2>👤 Add Manager</h2><p>Register a new manager. The ID (EMP###) is generated automatically and the login details are emailed.</p></div>
        </div>

        <% if ("created".equals(mgrMsg) || "resent".equals(mgrMsg)) {
               boolean mgrMailOk = "sent".equals(request.getParameter("mail")); %>
            <div class="message <%= mgrMailOk ? "message-success" : "message-error" %>">
                <%= "created".equals(mgrMsg) ? "Manager added. " : "" %>Manager ID: <strong><%= h(request.getParameter("newId")) %></strong>.
                <%= mgrMailOk ? "Login ID, password and login link were emailed." : "The login email could not be sent - use the Resend button below or share the details manually." %>
                <% if (!mgrMailOk && request.getParameter("mailErr") != null && !request.getParameter("mailErr").isEmpty()) { %>
                    <br><small>Reason: <%= h(request.getParameter("mailErr")) %></small>
                <% } %>
            </div>
        <% } else if ("duplicate".equals(mgrMsg)) { %>
            <div class="message message-error">An employee, manager or HR user with this email already exists.</div>
        <% } else if ("invalid".equals(mgrMsg)) { %>
            <div class="message message-error">Please fill every required field. Use a valid email and a password of at least 6 characters.</div>
        <% } %>

        <form method="post" action="<%= cp %>/hr">
            <input type="hidden" name="action" value="addManager">
            <div class="team-form-grid">
                <label>Full Name *<input type="text" name="name" maxlength="100" required></label>
                <label>Email *<input type="email" name="email" maxlength="100" required></label>
                <label>Phone<input type="tel" name="phone" maxlength="15"></label>
                <label>Department *<input type="text" name="department" maxlength="100" required></label>
                <label>Designation *<input type="text" name="designation" maxlength="100" value="Manager" required></label>
                <label>Status
                    <select name="status"><option value="ACTIVE">ACTIVE</option><option value="INACTIVE">INACTIVE</option></select>
                </label>
                <label class="full-width">Temporary Password * (min. 6 characters)
                    <input type="password" name="password" minlength="6" required autocomplete="new-password">
                </label>
            </div>
            <div class="form-actions">
                <button class="success" type="submit">Add Manager</button>
                <button class="neutral" type="reset">Clear</button>
            </div>
        </form>

        <h3 style="margin:24px 0 10px;font-size:15px">Managers</h3>
        <div class="table-container">
            <table>
                <thead><tr><th>Manager ID</th><th>Name</th><th>Email</th><th>Phone</th><th>Department</th><th>Designation</th><th>Status</th><th>Login Email</th></tr></thead>
                <tbody>
                <% for (String[] mg : managerList) {
                    boolean mgActive = "ACTIVE".equalsIgnoreCase(mg[6]); %>
                    <tr>
                        <td><%= h(mg[0]) %></td><td><%= h(mg[1]) %></td><td><%= h(mg[2]) %></td><td><%= h(mg[3]) %></td>
                        <td><%= h(mg[4]) %></td><td><%= h(mg[5]) %></td>
                        <td><span class="status <%= mgActive ? "status-active" : "status-inactive" %>"><%= mgActive ? "ACTIVE" : "INACTIVE" %></span></td>
                        <td><form method="post" action="<%= cp %>/hr" style="margin:0" onsubmit="return confirm('Email the login ID, password and link to this person again?')"><input type="hidden" name="action" value="resendCredentials"><input type="hidden" name="personId" value="<%= h(mg[0]) %>"><input type="hidden" name="personType" value="MANAGER"><button class="neutral" type="submit" style="padding:6px 10px;font-size:12px">&#128231; Resend</button></form></td>
                    </tr>
                <% } %>
                <% if (managerList.isEmpty()) { %>
                    <tr><td colspan="8" style="text-align:center">No managers to show. Use "Add Manager" in the menu to load the list.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>

<%
    String myMsg = request.getParameter("myMsg");
    String myMsgText = null;
    boolean myMsgOk = false;

    String myFlashErr = null;
    HttpSession myFlashSession = request.getSession(false);
    if (myFlashSession != null && myFlashSession.getAttribute("hrFlashError") != null) {
        myFlashErr = String.valueOf(myFlashSession.getAttribute("hrFlashError"));
        myFlashSession.removeAttribute("hrFlashError");
    }

    if (myMsg != null) {
        switch (myMsg) {
            case "error":         myMsgText = "The action could not be completed. Database error - " + (myFlashErr == null ? "see the server log." : myFlashErr); break;
            case "checkedIn":     myMsgText = "Checked in. Have a productive day!"; myMsgOk = true; break;
            case "checkedOut":    myMsgText = "Checked out. See you tomorrow!"; myMsgOk = true; break;
            case "breakStarted":  myMsgText = "Break started."; myMsgOk = true; break;
            case "breakEnded":    myMsgText = "Break ended. Welcome back!"; myMsgOk = true; break;
            case "leaveApplied":  myMsgText = "Leave applied. It is now waiting for admin approval."; myMsgOk = true; break;
            case "alreadyIn":     myMsgText = "You have already checked in today."; break;
            case "alreadyOut":    myMsgText = "You have already checked out today."; break;
            case "notCheckedIn":  myMsgText = "Please check in first."; break;
            case "onLeave":       myMsgText = "You are on approved leave today."; break;
            case "breakLimit":    myMsgText = "You have already taken the maximum of 2 breaks today."; break;
            case "breakRunning":  myMsgText = "A break is already running. End it first."; break;
            case "noBreak":       myMsgText = "There is no running break to end."; break;
            case "leavePending":  myMsgText = "You already have a pending leave request. Wait for the admin's decision."; break;
            case "leaveInvalid":  myMsgText = "Please enter a valid leave type, dates (to-date not before from-date) and a reason."; break;
            default: break;
        }
    }

    boolean myHasIn = Boolean.TRUE.equals(request.getAttribute("myHasIn"));
    boolean myHasOut = Boolean.TRUE.equals(request.getAttribute("myHasOut"));
    boolean myOnLeave = Boolean.TRUE.equals(request.getAttribute("myOnLeave"));
    String myIn = (String) request.getAttribute("myIn");
    String myOut = (String) request.getAttribute("myOut");
    String myDbStatus = request.getAttribute("myStatus") == null ? "ABSENT" : String.valueOf(request.getAttribute("myStatus"));

    List<String[]> myBreaks = (List<String[]>) request.getAttribute("myBreaks");
    if (myBreaks == null) myBreaks = new ArrayList<String[]>();
    List<String[]> myHistory = (List<String[]>) request.getAttribute("myHistory");
    if (myHistory == null) myHistory = new ArrayList<String[]>();
    List<HRServlet.LeaveData> myLeaves = (List<HRServlet.LeaveData>) request.getAttribute("myLeaves");
    if (myLeaves == null) myLeaves = new ArrayList<HRServlet.LeaveData>();

    boolean myBreakRunning = false;
    for (String[] mb : myBreaks) { if (mb[2] == null) myBreakRunning = true; }

    String myState = myOnLeave ? "LEAVE" : (!myHasIn ? "ABSENT" : (!myHasOut ? "WORKING" : myDbStatus.toUpperCase()));
    String myStateClass = "LEAVE".equals(myState) ? "status-leave"
        : "WORKING".equals(myState) ? "status-in_progress"
        : "PRESENT".equals(myState) ? "status-present"
        : "HALF DAY".equals(myState) ? "status-pending" : "status-absent";
%>

    <!-- MY ATTENDANCE (HR is an employee of the admin) -->
    <div class="section" id="myAttendance">
        <div class="section-header">
            <div><h2>🕘 My Attendance &amp; Breaks</h2><p>Check in and out, and take up to 2 breaks a day. The admin can see your attendance.</p></div>
            <span class="small-note"><%= java.time.LocalDate.now() %></span>
        </div>

        <% if (myMsgText != null) { %>
            <div class="message <%= myMsgOk ? "message-success" : "message-error" %>"><%= h(myMsgText) %></div>
        <% } %>

        <% if (request.getAttribute("myStatus") == null) { %>
            <a class="btn primary" href="<%= cp %>/hr?action=myAttendance#myAttendance">Load my attendance</a><br><br>
        <% } %>

        <div class="table-container">
            <table>
                <thead><tr><th>Date</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
                <tbody><tr>
                    <td><%= java.time.LocalDate.now() %></td>
                    <td><%= h(myIn == null ? "-" : util.DateFmt.time(myIn)) %></td>
                    <td><%= h(myOut == null ? "-" : util.DateFmt.time(myOut)) %></td>
                    <td><span class="status <%= myStateClass %>"><%= h(myState) %></span></td>
                </tr></tbody>
            </table>
        </div>

        <div class="form-actions">
            <form method="post" action="<%= cp %>/hr" style="display:inline">
                <input type="hidden" name="action" value="myCheckIn">
                <button class="success" type="submit" <%= (myHasIn || myOnLeave) ? "disabled" : "" %>>🟢 Check In</button>
            </form>
            <form method="post" action="<%= cp %>/hr" style="display:inline">
                <input type="hidden" name="action" value="myCheckOut">
                <button class="danger" type="submit" <%= (!myHasIn || myHasOut || myOnLeave) ? "disabled" : "" %>>🔴 Check Out</button>
            </form>
        </div>

        <h3 style="margin:22px 0 10px;font-size:15px">☕ Today's Breaks <span class="small-note">(maximum 2)</span></h3>
        <div class="table-container">
            <table>
                <thead><tr><th>Break</th><th>Start</th><th>End</th></tr></thead>
                <tbody>
                <% if (myBreaks.isEmpty()) { %>
                    <tr><td colspan="3" style="text-align:center">No breaks taken today.</td></tr>
                <% } else { for (String[] mb : myBreaks) { %>
                    <tr><td>Break <%= h(mb[0]) %></td><td><%= h(mb[1]) %></td><td><%= h(mb[2] == null ? "running..." : mb[2]) %></td></tr>
                <% } } %>
                </tbody>
            </table>
        </div>
        <div class="form-actions">
            <form method="post" action="<%= cp %>/hr" style="display:inline">
                <input type="hidden" name="action" value="myStartBreak">
                <button class="primary" type="submit" <%= (!myHasIn || myHasOut || myOnLeave || myBreaks.size() >= 2 || myBreakRunning) ? "disabled" : "" %>>☕ Start Break</button>
            </form>
            <form method="post" action="<%= cp %>/hr" style="display:inline">
                <input type="hidden" name="action" value="myEndBreak">
                <button class="neutral" type="submit" <%= myBreakRunning ? "" : "disabled" %>>▶️ End Break</button>
            </form>
        </div>

        <h3 style="margin:22px 0 10px;font-size:15px">📅 My Attendance - last 30 days</h3>
        <div class="table-container">
            <table>
                <thead><tr><th>Date</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
                <tbody>
                <% if (myHistory.isEmpty()) { %>
                    <tr><td colspan="4" style="text-align:center">No attendance records yet.</td></tr>
                <% } else { for (String[] mh : myHistory) {
                    String hs = mh[3] == null ? "" : mh[3].toUpperCase(); %>
                    <tr>
                        <td><%= h(mh[0]) %></td>
                        <td><%= h(mh[1] == null ? "-" : mh[1]) %></td>
                        <td><%= h(mh[2] == null ? "-" : mh[2]) %></td>
                        <td><span class="status <%= "PRESENT".equals(hs) ? "status-present" : ("HALF DAY".equals(hs) ? "status-pending" : ("LEAVE".equals(hs) ? "status-leave" : "status-absent")) %>"><%= h(hs) %></span></td>
                    </tr>
                <% } } %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- MY LEAVES (HR applies; the admin approves) -->
    <div class="section" id="myLeaves">
        <div class="section-header">
            <div><h2>📝 My Leaves</h2><p>Apply for leave and track its status. Your leave is approved or rejected by the admin.</p></div>
        </div>

        <% if (myMsgText != null && myMsg != null && (myMsg.startsWith("leave") || "error".equals(myMsg))) { %>
            <div class="message <%= myMsgOk ? "message-success" : "message-error" %>"><%= h(myMsgText) %></div>
        <% } %>

        <div style="background:#f8fafc;padding:16px;margin:0 0 18px;border:1px solid #e2e8f0;border-radius:12px">
            <h3 style="margin-bottom:12px;font-size:15px">➕ Apply for Leave</h3>
            <form method="post" action="<%= cp %>/hr">
                <input type="hidden" name="action" value="myApplyLeave">
                <div class="team-form-grid">
                    <label>Leave Type *
                        <select name="leaveType" required>
                            <option value="">-- Select Leave Type --</option>
                            <option value="CASUAL">Casual Leave</option>
                            <option value="SICK">Sick Leave</option>
                            <option value="PERSONAL">Personal Leave</option>
                        </select>
                    </label>
                    <span></span>
                    <label>From Date *<input type="date" name="fromDate" required></label>
                    <label>To Date *<input type="date" name="toDate" required></label>
                    <label class="full-width">Reason *<textarea name="reason" rows="3" maxlength="500" required></textarea></label>
                </div>
                <div class="form-actions"><button class="success" type="submit">📝 Apply Leave</button></div>
            </form>
        </div>

        <div class="table-container">
            <table>
                <thead><tr><th>Leave ID</th><th>Type</th><th>From</th><th>To</th><th>Reason</th><th>Applied</th><th>Status</th></tr></thead>
                <tbody>
                <% if (myLeaves.isEmpty()) { %>
                    <tr><td colspan="7" style="text-align:center">No leave requests yet.</td></tr>
                <% } else { for (HRServlet.LeaveData ml : myLeaves) { %>
                    <tr>
                        <td><%= h(ml.leaveId) %></td>
                        <td><%= h(ml.leaveType) %></td>
                        <td><%= h(util.DateFmt.date(ml.fromDate)) %></td>
                        <td><%= h(util.DateFmt.date(ml.toDate)) %></td>
                        <td><%= h(ml.reason) %></td>
                        <td><%= h(util.DateFmt.date(ml.appliedDate)) %></td>
                        <td><span class="status <%= "APPROVED".equalsIgnoreCase(ml.status) ? "status-completed" : ("REJECTED".equalsIgnoreCase(ml.status) ? "status-rejected" : "status-pending") %>"><%= "PENDING".equalsIgnoreCase(ml.status) ? "PENDING (admin)" : h(ml.status) %></span></td>
                    </tr>
                <% } } %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- TASK MANAGEMENT -->
    <div class="section" id="taskManagement">
        <div class="section-header">
            <div><h2>📋 Task Management</h2><p>Assign, edit and track tasks. Employee comments and manager reviews are shown for each task.</p></div>
        </div>

        <% if (request.getAttribute("taskError") != null) { %>
            <div class="message message-error"><%= h(request.getAttribute("taskError")) %></div>
        <% } %>
        <% if (request.getParameter("taskMessage") != null) { %>
            <div class="message message-success">Task operation: <%= h(request.getParameter("taskMessage")) %></div>
        <% } %>


<%
    Task editingTask = (Task) request.getAttribute("editTask");
    boolean taskEditMode = editingTask != null;
    String etPriority = taskEditMode && editingTask.getPriority() != null ? editingTask.getPriority().toUpperCase() : "MEDIUM";
    String etStatus = taskEditMode && editingTask.getStatus() != null ? editingTask.getStatus().toUpperCase() : "PENDING";
    String etAssigned = taskEditMode && editingTask.getAssignedTo() != null ? editingTask.getAssignedTo() : "";
%>
        <div style="background:#f8fafc;padding:16px;margin:0 0 18px;border:1px solid #e2e8f0;border-radius:12px">
            <h3 style="margin-bottom:12px;font-size:15px"><%= taskEditMode ? "Edit Task #" + editingTask.getId() : "Assign New Task" %></h3>
            <form method="post" action="<%= cp %>/hr">
                <input type="hidden" name="action" value="<%= taskEditMode ? "updateTask" : "createTask" %>">
                <% if (taskEditMode) { %><input type="hidden" name="id" value="<%= editingTask.getId() %>"><% } %>
                <div class="team-form-grid">
                    <label>Task Title *<input type="text" name="taskTitle" maxlength="150" required value="<%= taskEditMode ? h(editingTask.getTaskTitle()) : "" %>"></label>
                    <label>Assign To *
                        <select name="assignedTo" required>
                            <option value="">-- Select Employee --</option>
                            <%
                            try (Connection tc = model.DBcConnection.getConnection();
                                 PreparedStatement tp = tc.prepareStatement("SELECT employee_id,name,department FROM employees WHERE status='ACTIVE' ORDER BY name");
                                 ResultSet tr = tp.executeQuery()) {
                                while (tr.next()) {
                                    String teId = tr.getString("employee_id");
                            %>
                                <option value="<%= h(teId) %>" <%= teId.equals(etAssigned) ? "selected" : "" %>><%= h(tr.getString("name")) %> (<%= h(teId) %>)</option>
                            <% } } catch (Exception e) { application.log("Task employee list error", e); } %>
                        </select>
                    </label>
                    <label>Department<input type="text" name="department" maxlength="100" value="<%= taskEditMode ? h(editingTask.getDepartment()) : "" %>"></label>
                    <label>Priority *
                        <select name="priority" required>
                            <option value="HIGH" <%= "HIGH".equals(etPriority) ? "selected" : "" %>>HIGH</option>
                            <option value="MEDIUM" <%= "MEDIUM".equals(etPriority) ? "selected" : "" %>>MEDIUM</option>
                            <option value="LOW" <%= "LOW".equals(etPriority) ? "selected" : "" %>>LOW</option>
                        </select>
                    </label>
                    <label>Start Date *<input type="date" name="startDate" required value="<%= taskEditMode ? h(editingTask.getStartDate()) : java.time.LocalDate.now().toString() %>"></label>
                    <label>Due Date *<input type="date" name="dueDate" required value="<%= taskEditMode ? h(editingTask.getDueDate()) : "" %>"></label>
                    <label>Status
                        <select name="status">
                            <option value="PENDING" <%= "PENDING".equals(etStatus) ? "selected" : "" %>>PENDING</option>
                            <option value="IN_PROGRESS" <%= "IN_PROGRESS".equals(etStatus) ? "selected" : "" %>>IN_PROGRESS</option>
                            <option value="COMPLETED" <%= "COMPLETED".equals(etStatus) ? "selected" : "" %>>COMPLETED</option>
                        </select>
                    </label>
                    <label class="full-width">Description<textarea name="description" rows="3" maxlength="1000"><%= taskEditMode ? h(editingTask.getDescription()) : "" %></textarea></label>
                </div>
                <div class="form-actions">
                    <button class="success" type="submit"><%= taskEditMode ? "Update Task" : "Assign Task" %></button>
                    <% if (taskEditMode) { %><a class="btn neutral" href="<%= cp %>/hr?action=taskManagement#taskManagement">Cancel</a><% } %>
                </div>
            </form>
        </div>

        <div class="task-stats">
            <div class="task-stat"><strong><%= taskCount %></strong><span>Total Tasks</span></div>
            <div class="task-stat"><strong><%= pendingCount %></strong><span>Pending</span></div>
            <div class="task-stat"><strong><%= inProgressCount %></strong><span>In Progress</span></div>
            <div class="task-stat"><strong><%= completedCount %></strong><span>Completed</span></div>
        </div>

        <form class="filter-box" method="get" action="<%= cp %>/hr#taskManagement">
            <input type="hidden" name="action" value="searchTasks">
            <input type="text" name="search" value="<%= h(taskSearch) %>" placeholder="Search title, employee ID or department">
            <select name="status" id="taskStatusFilter">
                <option value="ALL" <%= "ALL".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>All Statuses</option>
                <option value="PENDING" <%= "PENDING".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>PENDING</option>
                <option value="IN_PROGRESS" <%= "IN_PROGRESS".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>IN_PROGRESS</option>
                <option value="COMPLETED" <%= "COMPLETED".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>COMPLETED</option>
            </select>
            <button class="primary" type="submit">Search</button>
            <a class="btn neutral" href="<%= cp %>/hr?action=taskManagement#taskManagement">Reset</a>
        </form>

        <div class="table-container">
            <table>
                <thead>
                    <tr><th>ID</th><th>Task</th><th>Assigned Employee</th><th>Department</th><th>Priority</th><th>Start</th><th>Due</th><th>Status</th><th>Employee Comment</th><th>Rating</th><th>Manager Review</th><th>Actions</th></tr>
                </thead>
                <tbody>
                <% if (tasks.isEmpty()) { %>
                    <tr><td colspan="12" style="text-align:center">No tasks found.</td></tr>
                <% } else {
                    for (Task task : tasks) {
                        String st = task.getStatus() == null ? "PENDING" : task.getStatus();
                %>
                    <tr>
                        <td><%= task.getId() %></td>
                        <td><strong><%= h(task.getTaskTitle()) %></strong><div class="small-note"><%= h(task.getDescription()) %></div></td>
                        <td><%= h(task.getAssignedTo()) %></td>
                        <td><%= h(task.getDepartment()) %></td>
                        <td><%= h(task.getPriority()) %></td>
                        <td><%= h(util.DateFmt.date(task.getStartDate())) %></td>
                        <td><%= h(util.DateFmt.date(task.getDueDate())) %></td>
                        <td><span class="status status-<%= h(st.toLowerCase()) %>"><%= h(st) %></span></td>
                        <td><%= task.getEmployeeComment() == null || task.getEmployeeComment().trim().isEmpty() ? "No comment" : h(task.getEmployeeComment()) %></td>
                        <td><%= task.getManagerRating() == null ? "Not rated" : h(task.getManagerRating()) %></td>
                        <td><%= task.getManagerRemarks() == null || task.getManagerRemarks().trim().isEmpty() ? "No manager review" : h(task.getManagerRemarks()) %></td>
                        <td style="white-space:nowrap">
                            <a class="btn primary" href="<%= cp %>/hr?action=editTask&editId=<%= task.getId() %>#taskManagement">Edit</a>
                            <form method="post" action="<%= cp %>/hr" style="display:inline" onsubmit="return confirm('Delete this task?')">
                                <input type="hidden" name="action" value="deleteTask">
                                <input type="hidden" name="id" value="<%= task.getId() %>">
                                <button class="danger" type="submit">Delete</button>
                            </form>
                        </td>
                    </tr>
                <% } } %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- MANAGER REVIEWS -->
    <div class="section" id="managerReviews">
        <div class="section-header">
            <div><h2>⭐ Manager Reviews</h2><p>Select a manager and team to see reviewed tasks for that team.</p></div>
        </div>

        <form method="get" action="<%= cp %>/hr#managerReviews" class="filter-box">
            <input type="hidden" name="action" value="taskManagement">
            <label style="flex:1;min-width:220px">Select Manager
                <select name="selectedManager" required onchange="this.form.submit()">
                    <option value="">-- Select Manager --</option>
                    <%
                    try (Connection con = model.DBcConnection.getConnection();
                         PreparedStatement ps = con.prepareStatement("SELECT employee_id,name FROM managers ORDER BY name");
                         ResultSet rs = ps.executeQuery()) {
                        while (rs.next()) {
                            String mid = rs.getString("employee_id");
                    %>
                        <option value="<%= h(mid) %>" <%= mid.equals(selectedManager) ? "selected" : "" %>><%= h(rs.getString("name")) %> (<%= h(mid) %>)</option>
                    <% } } catch (Exception e) { application.log("Manager list error", e); } %>
                </select>
            </label>

            <% if (!selectedManager.isEmpty()) { %>
                <label style="flex:1;min-width:220px">Select Team
                    <select name="selectedTeam" required onchange="this.form.submit()">
                        <option value="">-- Select Team --</option>
                        <%
                        try (Connection con = model.DBcConnection.getConnection();
                             PreparedStatement ps = con.prepareStatement("SELECT team_id,team_name FROM teams WHERE manager_id=? ORDER BY team_name")) {
                            ps.setString(1, selectedManager);
                            try (ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                                    String tid = rs.getString("team_id");
                        %>
                            <option value="<%= h(tid) %>" <%= tid.equals(selectedTeam) ? "selected" : "" %>><%= h(rs.getString("team_name")) %> (<%= h(tid) %>)</option>
                        <% } } } catch (Exception e) { application.log("Team list error", e); } %>
                    </select>
                </label>
            <% } %>
            <noscript><button class="primary" type="submit">Show Reviews</button></noscript>
        </form>

        <% if (selectedManager.isEmpty()) { %>
            <div class="message message-success">Select a manager to view their teams.</div>
        <% } else if (selectedTeam.isEmpty()) { %>
            <div class="message message-success">Select a team to view its task reviews.</div>
        <% } else { %>
            <div class="table-container">
                <table>
                    <thead><tr><th>Task ID</th><th>Task Title</th><th>Employee ID</th><th>Status</th><th>Rating</th><th>Remarks</th><th>Review Date</th></tr></thead>
                    <tbody>
                    <%
                    boolean foundReview = false;
                    try (Connection con = model.DBcConnection.getConnection();
                         PreparedStatement ps = con.prepareStatement(
                            "SELECT DISTINCT t.id,t.task_title,t.assigned_to,t.status,t.manager_rating,t.manager_remarks,t.reviewed_at FROM tasks t JOIN team_members tm ON tm.employee_id=t.assigned_to JOIN teams te ON te.team_id=tm.team_id WHERE te.manager_id=? AND te.team_id=? AND t.reviewed_by=? AND (t.manager_rating IS NOT NULL OR (t.manager_remarks IS NOT NULL AND TRIM(t.manager_remarks)<>'')) ORDER BY t.reviewed_at DESC")) {
                        ps.setString(1, selectedManager);
                        ps.setString(2, selectedTeam);
                        ps.setString(3, selectedManager);
                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                foundReview = true;
                    %>
                        <tr>
                            <td><%= rs.getInt("id") %></td>
                            <td><%= h(rs.getString("task_title")) %></td>
                            <td><%= h(rs.getString("assigned_to")) %></td>
                            <td><%= h(rs.getString("status")) %></td>
                            <td><%= rs.getObject("manager_rating") == null ? "Not rated" : h(rs.getObject("manager_rating")) %></td>
                            <td><%= h(rs.getString("manager_remarks")) %></td>
                            <td><%= h(rs.getString("reviewed_at")) %></td>
                        </tr>
                    <% } } } catch (Exception e) { application.log("Manager reviews error", e); %>
                        <tr><td colspan="7">Unable to load reviews. Check the task review columns.</td></tr>
                    <% }
                    if (!foundReview) { %>
                        <tr><td colspan="7" style="text-align:center">No manager reviews found for this team.</td></tr>
                    <% } %>
                    </tbody>
                </table>
            </div>
        <% } %>
    </div>

    <!-- TEAM MANAGEMENT -->
    <div class="section" id="manageTeams">
        <div class="section-header">
            <div><h2>🏢 Team Management</h2><p>Create, edit and delete teams, and manage team members.</p></div>
            <button class="primary" type="button" onclick="togglePanel('createTeamPanel')">➕ Create Team</button>
        </div>

        <% if (teamMessage != null) { %>
            <div class="message <%= "error".equals(teamMessageType) ? "message-error" : "message-success" %>"><%= h(teamMessage) %></div>
        <% } %>

        <div id="createTeamPanel" class="team-inline-panel">
            <h3>Create Team</h3>
            <form method="post" action="<%= cp %>/hr_dashboard.jsp#manageTeams">
                <input type="hidden" name="teamOperation" value="createTeam">
                <div class="team-form-grid">
                    <label>Team Name *
                        <input type="text" name="teamName" maxlength="100" required>
                    </label>
                    <label>Department
                        <input type="text" name="department" maxlength="100">
                    </label>
                    <label>Manager *
                        <select name="managerId" required>
                            <option value="">Select Manager</option>
                            <%
                            try (Connection con = model.DBcConnection.getConnection();
                                 PreparedStatement ps = con.prepareStatement("SELECT employee_id,name FROM managers WHERE status='ACTIVE' ORDER BY name");
                                 ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                            %>
                                <option value="<%= h(rs.getString("employee_id")) %>"><%= h(rs.getString("name")) %> (<%= h(rs.getString("employee_id")) %>)</option>
                            <% } } catch (Exception e) { application.log("Manager load error", e); } %>
                        </select>
                    </label>
                    <label>Status
                        <select name="status"><option>ACTIVE</option><option>INACTIVE</option></select>
                    </label>
                    <label class="full-width">Description
                        <textarea name="description" rows="3" maxlength="1000"></textarea>
                    </label>
                </div>
                <div class="form-actions">
                    <button class="success" type="submit">Create Team</button>
                    <button class="neutral" type="button" onclick="togglePanel('createTeamPanel')">Cancel</button>
                </div>
            </form>
        </div>

        <div class="table-container">
            <table>
                <thead><tr><th>Team ID</th><th>Team Name</th><th>Department</th><th>Manager</th><th>Status</th><th>Actions</th></tr></thead>
                <tbody>
                <%
                boolean teamsFound = false;
                try (Connection con = model.DBcConnection.getConnection();
                     PreparedStatement ps = con.prepareStatement(
                        "SELECT t.team_id,t.team_name,t.description,t.department,t.manager_id,t.status,m.name manager_name FROM teams t LEFT JOIN managers m ON t.manager_id=m.employee_id ORDER BY t.team_id DESC");
                     ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        teamsFound = true;
                        String tid = rs.getString("team_id");
                        String tn = rs.getString("team_name");
                        String desc = rs.getString("description");
                        String dep = rs.getString("department");
                        String mid = rs.getString("manager_id");
                        String mn = rs.getString("manager_name");
                        String st = rs.getString("status");
                %>
                    <tr>
                        <td><%= h(tid) %></td>
                        <td><%= h(tn) %></td>
                        <td><%= h(dep) %></td>
                        <td><%= mn == null ? "Not assigned" : h(mn) %><div class="small-note"><%= h(mid) %></div></td>
                        <td><span class="status <%= "ACTIVE".equalsIgnoreCase(st) ? "status-active" : "status-inactive" %>"><%= h(st) %></span></td>
                        <td>
                            <button type="button" class="primary" onclick="togglePanel('teamView_<%= h(tid) %>')">View</button>
                            <button type="button" class="neutral" onclick="togglePanel('teamEdit_<%= h(tid) %>')">Edit</button>
                            <button type="button" class="success" onclick="togglePanel('teamMembers_<%= h(tid) %>')">Members</button>
                            <form method="post" action="<%= cp %>/hr_dashboard.jsp#manageTeams" style="display:inline" onsubmit="return confirmTeamDelete()">
                                <input type="hidden" name="teamOperation" value="deleteTeam">
                                <input type="hidden" name="teamId" value="<%= h(tid) %>">
                                <button class="danger" type="submit">Delete</button>
                            </form>
                        </td>
                    </tr>
                    <tr><td colspan="6">
                        <div id="teamView_<%= h(tid) %>" class="team-inline-panel">
                            <h3>Team Details: <%= h(tn) %></h3>
                            <p><strong>ID:</strong> <%= h(tid) %></p>
                            <p><strong>Description:</strong> <%= h(desc) %></p>
                            <p><strong>Department:</strong> <%= h(dep) %></p>
                            <p><strong>Manager:</strong> <%= mn == null ? "Not assigned" : h(mn) %></p>
                            <p><strong>Status:</strong> <%= h(st) %></p>
                        </div>

                        <div id="teamEdit_<%= h(tid) %>" class="team-inline-panel">
                            <h3>Edit Team</h3>
                            <form method="post" action="<%= cp %>/hr_dashboard.jsp#manageTeams">
                                <input type="hidden" name="teamOperation" value="saveTeam">
                                <input type="hidden" name="teamId" value="<%= h(tid) %>">
                                <div class="team-form-grid">
                                    <label>Team Name<input name="teamName" required maxlength="100" value="<%= h(tn) %>"></label>
                                    <label>Department<input name="department" maxlength="100" value="<%= h(dep) %>"></label>
                                    <label>Manager
                                        <select name="managerId" required>
                                            <option value="">Select Manager</option>
                                            <%
                                            try (Connection mc = model.DBcConnection.getConnection();
                                                 PreparedStatement mp = mc.prepareStatement("SELECT employee_id,name FROM managers WHERE status='ACTIVE' ORDER BY name");
                                                 ResultSet mr = mp.executeQuery()) {
                                                while (mr.next()) {
                                                    String optId = mr.getString("employee_id");
                                            %>
                                                <option value="<%= h(optId) %>" <%= optId.equals(mid) ? "selected" : "" %>><%= h(mr.getString("name")) %> (<%= h(optId) %>)</option>
                                            <% } } catch (Exception e) { application.log("Manager edit list error", e); } %>
                                        </select>
                                    </label>
                                    <label>Status
                                        <select name="status">
                                            <option value="ACTIVE" <%= "ACTIVE".equalsIgnoreCase(st) ? "selected" : "" %>>ACTIVE</option>
                                            <option value="INACTIVE" <%= "INACTIVE".equalsIgnoreCase(st) ? "selected" : "" %>>INACTIVE</option>
                                        </select>
                                    </label>
                                    <label class="full-width">Description<textarea name="description" rows="3" maxlength="1000"><%= h(desc) %></textarea></label>
                                </div>
                                <div class="form-actions"><button class="success" type="submit">Save Changes</button></div>
                            </form>
                        </div>

                        <div id="teamMembers_<%= h(tid) %>" class="team-inline-panel">
                            <h3>Members of <%= h(tn) %></h3>
                            <form method="post" action="<%= cp %>/hr_dashboard.jsp#manageTeams" style="display:flex;gap:10px;margin-bottom:15px">
                                <input type="hidden" name="teamOperation" value="addMember">
                                <input type="hidden" name="teamId" value="<%= h(tid) %>">
                                <select name="employeeId" required>
                                    <option value="">Select employee to add</option>
                                    <%
                                    try (Connection ec = model.DBcConnection.getConnection();
                                         PreparedStatement ep = ec.prepareStatement("SELECT employee_id,name FROM employees WHERE status='ACTIVE' ORDER BY name");
                                         ResultSet er = ep.executeQuery()) {
                                        while (er.next()) {
                                    %>
                                        <option value="<%= h(er.getString("employee_id")) %>"><%= h(er.getString("name")) %> (<%= h(er.getString("employee_id")) %>)</option>
                                    <% } } catch (Exception e) { application.log("Employee list error", e); } %>
                                </select>
                                <button class="success" type="submit">Add Member</button>
                            </form>

                            <div class="table-container">
                                <table>
                                    <thead><tr><th>Employee ID</th><th>Name</th><th>Email</th><th>Action</th></tr></thead>
                                    <tbody>
                                    <%
                                    boolean hasMembers = false;
                                    try (Connection ec = model.DBcConnection.getConnection();
                                         PreparedStatement ep = ec.prepareStatement("SELECT e.employee_id,e.name,e.email FROM team_members tm JOIN employees e ON tm.employee_id=e.employee_id WHERE tm.team_id=? ORDER BY e.name")) {
                                        ep.setString(1, tid);
                                        try (ResultSet er = ep.executeQuery()) {
                                            while (er.next()) {
                                                hasMembers = true;
                                                String memberId = er.getString("employee_id");
                                    %>
                                        <tr>
                                            <td><%= h(memberId) %></td>
                                            <td><%= h(er.getString("name")) %></td>
                                            <td><%= h(er.getString("email")) %></td>
                                            <td>
                                                <form method="post" action="<%= cp %>/hr_dashboard.jsp#manageTeams" onsubmit="return confirm('Remove this employee from the team?')">
                                                    <input type="hidden" name="teamOperation" value="removeMember">
                                                    <input type="hidden" name="teamId" value="<%= h(tid) %>">
                                                    <input type="hidden" name="employeeId" value="<%= h(memberId) %>">
                                                    <button class="danger" type="submit">Remove</button>
                                                </form>
                                            </td>
                                        </tr>
                                    <% } } } catch (Exception e) { application.log("Team member load error", e); %>
                                        <tr><td colspan="4">Unable to load members.</td></tr>
                                    <% }
                                    if (!hasMembers) { %>
                                        <tr><td colspan="4">No members assigned to this team yet.</td></tr>
                                    <% } %>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </td></tr>
                <% } } catch (Exception e) { application.log("Team load error", e); %>
                    <tr><td colspan="6">Unable to load teams. Check teams and team_members tables.</td></tr>
                <% }
                if (!teamsFound) { %>
                    <tr><td colspan="6" style="text-align:center">No teams found.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- EMPLOYEE SEARCH -->
    <div class="section" id="searchEmployee">
        <div class="section-header">
            <div><h2>🔍 Search Employee</h2><p>Search by employee ID or name.</p></div>
        </div>
        <form class="search-box" method="get" action="<%= cp %>/hr#searchEmployee">
            <input type="hidden" name="action" value="searchEmployee">
            <input type="text" name="search" placeholder="Enter employee ID or name..." required>
            <button class="primary" type="submit">Search</button>
        </form>

        <% if (!searchResults.isEmpty()) { %>
            <div class="table-container">
                <table>
                    <thead><tr><th>Employee ID</th><th>Name</th><th>Email</th><th>Department</th><th>Designation</th><th>Status</th></tr></thead>
                    <tbody>
                    <% for (Employe emp : searchResults) { %>
                        <tr>
                            <td><%= h(emp.getEmployeeId()) %></td>
                            <td><%= h(emp.getName()) %></td>
                            <td><%= h(emp.getEmail()) %></td>
                            <td><%= h(emp.getDepartment()) %></td>
                            <td><%= h(emp.getDesignation()) %></td>
                            <td><%= h(emp.getStatus()) %></td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>
        <% } %>
    </div>

    <!-- ATTENDANCE -->
    <div class="section" id="attendance">
        <div class="section-header">
            <div><h2>📊 Attendance Management</h2><p>Employee and manager attendance details are available in Reports.</p></div>
        </div>
        <div class="button-grid">
            <a class="dashboard-btn" href="<%= cp %>/hr?action=todayAttendance#attendance"><strong>📅 Today's Attendance</strong><span>View today's saved attendance records.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=monthlyAttendance#attendance"><strong>📊 Monthly Attendance</strong><span>View current month's saved records.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/hr?action=reports&reportType=employees#reports"><strong>👥 Employees & Managers Report</strong><span>View employee and manager details.</span></a>
        </div>

        <% if (!attendanceData.isEmpty()) { %>
            <br>
            <div class="table-container">
                <table>
                    <thead><tr><th>Employee ID</th><th>Name</th><th>Date</th><th>Day</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
                    <tbody>
                    <% for (HRServlet.AttendanceData d : attendanceData) { %>
                        <tr>
                            <td><%= h(d.employeeId) %></td>
                            <td><%= h(d.name) %></td>
                            <td><%= h(util.DateFmt.date(d.date)) %></td>
                            <td><%
                                String dayName = "";
                                try { dayName = java.time.LocalDate.parse(d.date).getDayOfWeek()
                                        .getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.ENGLISH); }
                                catch (Exception ex) { dayName = ""; }
                                out.print(h(dayName));
                            %></td>
                            <td><%= h(util.DateFmt.time(d.checkIn)) %></td>
                            <td><%= h(util.DateFmt.time(d.checkOut)) %></td>
                            <td><%= h(d.status) %></td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>
        <% } %>
    </div>

    <!-- LEAVE MANAGEMENT -->
    <div class="section" id="leaveManagement">
        <div class="section-header">
            <div><h2>📝 Leave Management</h2><p>Review leave requests of employees and managers. Your own leave is approved by the admin (see My Leaves).</p></div>
        </div>
        <a class="btn primary" href="<%= cp %>/hr?action=viewLeaves#leaveManagement">View Leave Requests</a>

        <% if (!leaveData.isEmpty()) { %>
            <br><br>
            <div class="table-container">
                <table>
                    <thead><tr><th>Leave ID</th><th>Employee</th><th>Leave Type</th><th>From</th><th>To</th><th>Reason</th><th>Status</th><th>Action</th></tr></thead>
                    <tbody>
                    <% for (HRServlet.LeaveData leave : leaveData) { %>
                        <tr>
                            <td><%= h(leave.leaveId) %></td>
                            <td><%= h(leave.name == null ? "" : leave.name) %> <span class="small-note">(<%= h(leave.employeeId) %>)</span></td>
                            <td><%= h(leave.leaveType) %></td>
                            <td><%= h(util.DateFmt.date(leave.fromDate)) %></td>
                            <td><%= h(util.DateFmt.date(leave.toDate)) %></td>
                            <td><%= h(leave.reason) %></td>
                            <td><span class="status <%= "APPROVED".equalsIgnoreCase(leave.status) ? "status-completed" : ("REJECTED".equalsIgnoreCase(leave.status) ? "status-rejected" : "status-pending") %>"><%= h(leave.status) %></span></td>
                            <td>
                                <% if ("PENDING".equalsIgnoreCase(leave.status)) { %>
                                    <form method="post" action="<%= cp %>/hr" style="display:inline">
                                        <input type="hidden" name="action" value="approveLeave">
                                        <input type="hidden" name="leaveId" value="<%= h(leave.leaveId) %>">
                                        <button class="success" type="submit">Approve</button>
                                    </form>
                                    <form method="post" action="<%= cp %>/hr" style="display:inline">
                                        <input type="hidden" name="action" value="rejectLeave">
                                        <input type="hidden" name="leaveId" value="<%= h(leave.leaveId) %>">
                                        <button class="danger" type="submit">Reject</button>
                                    </form>
                                <% } else { %>No action<% } %>
                            </td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>
        <% } %>
    </div>

    <!-- PAYROLL MODULE: Payroll Operations Hub (same dashboard; actions post to /payroll and redirect back here) -->
<%!
    private String payMoney(java.math.BigDecimal v) {
        return v == null ? "0.00" : String.format("%,.2f", v);
    }
    private String payDays(double v) {
        return String.format("%.1f", v);
    }
    private String payStatusClass(String st) {
        if ("PAID".equals(st)) return "status-completed";
        if ("PROCESSED".equals(st)) return "status-in_progress";
        if ("DRAFT".equals(st) || "PENDING".equals(st)) return "status-pending";
        if ("CANCELLED".equals(st)) return "status-rejected";
        return "status-pending";
    }
%>
<%
    String payTab = request.getAttribute("payrollTab") == null ? "process" : String.valueOf(request.getAttribute("payrollTab"));
    String payCsrf = request.getAttribute("payrollCsrf") == null ? "" : String.valueOf(request.getAttribute("payrollCsrf"));

    int payMonth = request.getAttribute("payrollMonth") == null
        ? java.time.LocalDate.now().getMonthValue() : (Integer) request.getAttribute("payrollMonth");
    int payYear = request.getAttribute("payrollYear") == null
        ? java.time.LocalDate.now().getYear() : (Integer) request.getAttribute("payrollYear");

    List<model.Payroll> payrollList = (List<model.Payroll>) request.getAttribute("payrollList");
    if (payrollList == null) payrollList = new ArrayList<model.Payroll>();

    java.math.BigDecimal payGross = request.getAttribute("payrollGross") == null
        ? java.math.BigDecimal.ZERO : (java.math.BigDecimal) request.getAttribute("payrollGross");
    java.math.BigDecimal payDeductions = request.getAttribute("payrollDeductions") == null
        ? java.math.BigDecimal.ZERO : (java.math.BigDecimal) request.getAttribute("payrollDeductions");
    java.math.BigDecimal payNet = request.getAttribute("payrollNet") == null
        ? java.math.BigDecimal.ZERO : (java.math.BigDecimal) request.getAttribute("payrollNet");
    int payPending = request.getAttribute("payrollPendingCount") == null ? 0 : (Integer) request.getAttribute("payrollPendingCount");
    int payPaid = request.getAttribute("payrollPaidCount") == null ? 0 : (Integer) request.getAttribute("payrollPaidCount");
    int payActiveStructures = request.getAttribute("payrollActiveStructures") == null ? 0 : (Integer) request.getAttribute("payrollActiveStructures");
    int payEligible = request.getAttribute("payrollEligibleCount") == null ? 0 : (Integer) request.getAttribute("payrollEligibleCount");

    java.util.Map<String, service.PayrollService.AttendanceSummary> payAttMap =
        (java.util.Map<String, service.PayrollService.AttendanceSummary>) request.getAttribute("payrollAttendance");
    if (payAttMap == null) payAttMap = new java.util.HashMap<String, service.PayrollService.AttendanceSummary>();

    String payMsg = request.getParameter("payrollMsg");
    String payErr = request.getParameter("payrollError");
    if ((payErr == null || payErr.isEmpty()) && request.getAttribute("payrollError") != null) {
        payErr = String.valueOf(request.getAttribute("payrollError"));
    }

    String[] payMonthNames = {"January","February","March","April","May","June",
        "July","August","September","October","November","December"};
    String payType = request.getAttribute("payrollPersonType") == null ? "ALL" : String.valueOf(request.getAttribute("payrollPersonType"));
    String payBase = cp + "/hr?action=payroll&month=" + payMonth + "&year=" + payYear;
    String payToday = java.time.LocalDate.now().toString();
    String payPeriodLabel = (payMonth < 10 ? "0" : "") + payMonth + "/" + payYear;
%>
    <div class="section" id="payroll">
        <div class="payroll-pagebar">
            <div class="reports-crumb">Dashboard &rsaquo; <b>Payroll</b></div>
            <a class="reports-back" href="<%= cp %>/hr">&larr; Back to Dashboard</a>
        </div>

        <div class="section-header">
            <div>
                <h2>Payroll Operations Hub</h2>
                <p>Compensation structures, processing cycles, and disbursements for period <%= payPeriodLabel %>.</p>
            </div>
            <div class="ph-head-actions">
                <a class="ph-btn ph-btn-outline" href="<%= h(cp + "/hr?action=payroll&tab=structures&month=" + payMonth + "&year=" + payYear + "&newStructure=1#payroll") %>">+ New Salary Structure</a>
                <form method="post" action="<%= cp %>/payroll" style="display:inline" onsubmit="return confirm('Generate payroll for all employees and managers for <%= payPeriodLabel %>? It will be marked PAID.')">
                    <input type="hidden" name="csrf" value="<%= h(payCsrf) %>">
                    <input type="hidden" name="action" value="runPayroll">
                    <input type="hidden" name="tab" value="<%= h(payTab) %>">
                    <input type="hidden" name="month" value="<%= payMonth %>">
                    <input type="hidden" name="year" value="<%= payYear %>">
                    <button type="submit" class="ph-btn ph-btn-solid">&#9654; Run Monthly Payroll</button>
                </form>
            </div>
        </div>

        <div class="ph-tabs">
            <a class="<%= "structures".equals(payTab) ? "active" : "" %>" href="<%= h(payBase + "&tab=structures#payroll") %>">&#9776; Salary Structures</a>
            <a class="<%= "process".equals(payTab) ? "active" : "" %>" href="<%= h(payBase + "&tab=process#payroll") %>">&#9881; Process Payroll</a>
            <a class="<%= "history".equals(payTab) ? "active" : "" %>" href="<%= h(payBase + "&tab=history#payroll") %>">&#128337; Payroll History &amp; Reports</a>
        </div>

        <% if (payMsg != null && !payMsg.isEmpty()) { %>
            <div class="message message-success"><%= h(payMsg) %></div>
        <% } %>
        <% if (payErr != null && !payErr.isEmpty()) { %>
            <div class="message message-error"><%= h(payErr) %></div>
        <% } %>

<% if (false) { %>
        <form method="get" action="<%= cp %>/hr#payroll" class="ph-period">
            <input type="hidden" name="action" value="payroll">
            <input type="hidden" name="tab" value="<%= h(payTab) %>">
            <label>Month
                <select name="month">
                    <% for (int m = 1; m <= 12; m++) { %>
                        <option value="<%= m %>" <%= m == payMonth ? "selected" : "" %>><%= payMonthNames[m - 1] %></option>
                    <% } %>
                </select>
            </label>
            <label>Year <input type="number" name="year" min="2000" max="9999" value="<%= payYear %>"></label>
            <label>Show
                <select name="personType">
                    <option value="ALL" <%= "ALL".equals(payType) ? "selected" : "" %>>All</option>
                    <option value="MANAGER" <%= "MANAGER".equals(payType) ? "selected" : "" %>>Managers</option>
                    <option value="EMPLOYEE" <%= "EMPLOYEE".equals(payType) ? "selected" : "" %>>Employees</option>
                </select>
            </label>
            <button class="primary" type="submit">Load Period</button>
        </form>
<% } %>

<% if ("structures".equals(payTab)) { %>
        <!-- ================= SALARY STRUCTURES TAB ================= -->
<%
    List<model.SalaryStructure> payStructures = (List<model.SalaryStructure>) request.getAttribute("payrollStructures");
    if (payStructures == null) payStructures = new ArrayList<model.SalaryStructure>();
    java.util.Map<Integer, List<model.SalaryComponent>> payComps =
        (java.util.Map<Integer, List<model.SalaryComponent>>) request.getAttribute("payrollComponents");
    if (payComps == null) payComps = new java.util.HashMap<Integer, List<model.SalaryComponent>>();
    List<String[]> payEmployees = (List<String[]>) request.getAttribute("payrollEmployees");
    if (payEmployees == null) payEmployees = new ArrayList<String[]>();
    java.time.LocalDate payNow = java.time.LocalDate.now();

    // one salary structure per employee: people who already have one are not selectable
    java.util.Set<String> payHasStructure = new java.util.HashSet<String>();
    for (model.SalaryStructure hs : payStructures) payHasStructure.add(hs.getEmployeeId());

    // employees.salary -> used to auto-fill the basic salary of a new structure
    java.util.Map<String, String> payEmpSalary = new java.util.HashMap<String, String>();
    try (java.sql.Connection payCon = model.DBcConnection.getConnection();
         java.sql.PreparedStatement payPs = payCon.prepareStatement("SELECT employee_id, salary FROM employees WHERE salary IS NOT NULL");
         java.sql.ResultSet payRs = payPs.executeQuery()) {
        while (payRs.next()) {
            java.math.BigDecimal sal = payRs.getBigDecimal(2);
            if (sal != null && sal.signum() > 0) {
                payEmpSalary.put(payRs.getString(1), sal.setScale(2, java.math.RoundingMode.HALF_UP).toPlainString());
            }
        }
    } catch (Exception ignoredSalaryLookup) {
        // basic salary can still be typed manually
    }
%>
        <div class="review-heading">
            <h3>Salary Structures</h3>
            <p>Enter the structure <strong>once</strong>: it is used for every later month and paid automatically on the schedule. Use <strong>Edit</strong> to change it; each employee can have only <strong>one</strong> salary structure - to change it, use Edit.</p>
        </div>

        <button type="button" class="primary" onclick="phNewStructure()">+ New Salary Structure</button>

        <div id="phStructureForm" class="team-inline-panel" style="margin-top:12px">
            <form method="post" action="<%= cp %>/payroll">
                <input type="hidden" name="csrf" value="<%= h(payCsrf) %>">
                <input type="hidden" name="action" id="phAction" value="saveStructure">
                <input type="hidden" name="structureId" id="phStructId" value="">
                <input type="hidden" name="tab" value="structures">
                <div id="phEditBanner" style="display:none;margin:0 0 10px;padding:9px 12px;border-radius:8px;background:#fef9c3;border:1px solid #fde68a;font-size:13px"></div>
                <input type="hidden" name="month" value="<%= payMonth %>">
                <input type="hidden" name="year" value="<%= payYear %>">

                <div class="ph-form-grid">
                    <label>Employee
                        <select name="employeeId" id="phEmpSelect" required onchange="phOnEmployee(this)">
                            <option value="">Select employee</option>
                            <% for (String[] e : payEmployees) { %>
                                <option value="<%= h(e[0]) %>" <%= payHasStructure.contains(e[0]) ? "disabled data-has=\"1\"" : "" %> data-salary="<%= h(payEmpSalary.get(e[0]) == null ? "" : payEmpSalary.get(e[0])) %>"><%= h(e[1]) %> (<%= h(e[0]) %>)<%= e[2].isEmpty() ? "" : " - " + h(e[2]) %><%= payHasStructure.contains(e[0]) ? " - structure exists (use Edit)" : "" %></option>
                            <% } %>
                        </select>
                    </label>
                    <label>Basic Salary (&#8377;)
                        <input type="number" name="basicSalary" id="phBasic" min="0.01" step="0.01" required placeholder="auto-filled from employee salary" oninput="phRecalc()">
                    </label>
                    <label>Salary Period - From (Month)
                        <input type="month" name="effectiveFrom" id="phEffFrom" required pattern="[0-9]{4}-[0-9]{2}" placeholder="YYYY-MM">
                    </label>
                    <label>Bank Name / Type
                        <input type="text" name="bankName" id="phBank" required maxlength="100" placeholder="e.g. State Bank of India" pattern="[A-Za-z][A-Za-z .&amp;'\-]*" title="Letters only - numbers are not allowed (e.g. State Bank of India)" oninput="this.value=this.value.replace(/[^A-Za-z .&amp;'\-]/g,'')">
                    </label>
                    <label>Bank Account Number
                        <input type="text" name="accountNumber" id="phAcct" required inputmode="numeric" pattern="[0-9]{9,18}" maxlength="18" placeholder="9 to 18 digits">
                    </label>
                </div>
                <p class="ph-muted" style="font-size:12px;margin:8px 0 0">
                    Enter the salary structure <strong>only once</strong>. It is used automatically for every later month
                    until you save a new one.
                </p>

                <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;margin:14px 0 6px">
                    <h4 style="margin:0">Allowances &amp; Deductions</h4>
                    <div>
                        <button type="button" class="ph-mini" style="color:#166534;border-color:#86efac" onclick="phAddExtra('EARNING')">+ Add Earning</button>
                        <button type="button" class="ph-mini" style="color:#b91c1c;border-color:#fca5a5" onclick="phAddExtra('DEDUCTION')">&minus; Add Deduction</button>
                    </div>
                </div>
                <label class="ph-check">
                    <input type="checkbox" id="phAutoComp" checked onchange="phRecalc()">
                    <span><strong>Apply standard template</strong> (HRA, Medical, Special, PF, Provisional tax) calculated from the basic salary. Untick to use only your own earnings / deductions.</span>
                </label>

                <div id="phExtraRows"></div>
                <div id="phAutoHidden"></div>

                <div class="ph-auto-cols">
                    <table class="ph-auto-table">
                        <thead><tr><th>Earnings</th><th class="payroll-num">Amount</th></tr></thead>
                        <tbody id="phAutoEarn"></tbody>
                        <tfoot><tr><td>Gross Salary</td><td class="payroll-num" id="phAutoGross">&#8377;0.00</td></tr></tfoot>
                    </table>
                    <table class="ph-auto-table">
                        <thead><tr><th>Deductions</th><th class="payroll-num">Amount</th></tr></thead>
                        <tbody id="phAutoDed"></tbody>
                        <tfoot><tr><td>Total Deductions</td><td class="payroll-num" id="phAutoDedTotal">&#8377;0.00</td></tr></tfoot>
                    </table>
                </div>
                <div class="ph-auto-net"><span>Net salary (full attendance)</span><strong id="phAutoNet">&#8377;0.00</strong></div>
                <p class="ph-muted" style="font-size:12px;margin:6px 0 0">Leave / absence deductions are added automatically every month while generating payroll (2 paid leaves per month are never deducted). Template rates: <code>PH_TEMPLATE</code> in this page's script.</p>

                <div class="form-actions">
                    <button type="submit" class="success" id="phSubmit">Save Salary Structure</button>
                    <button type="button" class="neutral" onclick="togglePanel('phStructureForm')">Cancel</button>
                </div>

<style>
.ph-check{display:flex;gap:10px;align-items:flex-start;font-size:13px;margin:0 0 10px;cursor:pointer}
.ph-check input{margin-top:3px}
.ph-auto-cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}
.ph-auto-table{width:100%;border-collapse:collapse;background:#fff}
.ph-auto-table th{background:#f1f5f9;text-align:left;font-size:12px;padding:8px 10px}
.ph-auto-table td{padding:8px 10px;border-bottom:1px solid #e5e7eb;font-size:13px}
.ph-auto-table tfoot td{font-weight:700;background:#f8fafc}
.ph-auto-table small{color:#64748b}
.ph-auto-net{margin-top:12px;padding:12px 16px;border-radius:10px;background:#ecfdf5;border:1px solid #bbf7d0;display:flex;justify-content:space-between;color:#166534;font-size:15px}
.ph-extra{grid-template-columns:2fr 1.2fr 1.2fr auto;align-items:center}
.ph-extra.earn{border-left:4px solid #16a34a;padding-left:8px}
.ph-extra.ded{border-left:4px solid #dc2626;padding-left:8px}
@media(max-width:760px){.ph-auto-cols{grid-template-columns:1fr}.ph-extra{grid-template-columns:1fr}}
</style>
<script>
/* Standard salary template: change the rates here and every new structure uses them.
   type: EARNING / DEDUCTION, calc: PERCENTAGE (% of basic) / FIXED (rupees) */
var PH_TEMPLATE = [
    {name:"HRA",               type:"EARNING",   calc:"PERCENTAGE", amount:40},
    {name:"Medical Allowance", type:"EARNING",   calc:"PERCENTAGE", amount:10},
    {name:"Special Allowance", type:"EARNING",   calc:"FIXED",      amount:20},
    {name:"PF",                type:"DEDUCTION", calc:"PERCENTAGE", amount:12},
    {name:"Provisional tax",   type:"DEDUCTION", calc:"FIXED",      amount:150}
];

/* data of the existing structures, used by the Edit button */
var PH_STRUCTS = {
<% for (model.SalaryStructure es : payStructures) {
    List<model.SalaryComponent> ec = payComps.get(es.getId()); %>
    "<%= es.getId() %>": {emp:"<%= h(es.getEmployeeId()) %>", name:"<%= h(es.getEmployeeName()) %>",
        from:"<%= es.getEffectiveFrom() == null ? "" : String.format("%04d-%02d", es.getEffectiveFrom().getYear(), es.getEffectiveFrom().getMonthValue()) %>",
        basic:"<%= es.getBasicSalary() == null ? "" : es.getBasicSalary().setScale(2, java.math.RoundingMode.HALF_UP).toPlainString() %>",
        bank:"<%= h(es.getBankName()) %>", acct:"<%= h(es.getAccountNumber()) %>",
        comps:[<% if (ec != null) { boolean firstC = true; for (model.SalaryComponent c : ec) { %><%= firstC ? "" : "," %>{n:"<%= h(c.getComponentName()) %>",t:"<%= h(c.getComponentType()) %>",c:"<%= h(c.getCalculationType()) %>",a:"<%= c.getAmount() == null ? "0" : c.getAmount().toPlainString() %>"}<% firstC = false; } } %>]},
<% } %>
    "0": null
};

function phRound(v){ return Math.round(v*100)/100; }
function phMoney(v){ return "\u20B9"+v.toLocaleString("en-IN",{minimumFractionDigits:2,maximumFractionDigits:2}); }
function phEsc(t){ return String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/"/g,"&quot;"); }
function phDecode(t){ var d=document.createElement("textarea"); d.innerHTML=t; return d.value; }

/* own earnings / deductions typed by the admin (rows added with the buttons) */
function phExtras(){
    var list=[];
    document.querySelectorAll("#phExtraRows .ph-extra").forEach(function(row){
        var name=row.querySelector("[name=compName]").value.trim();
        var amt=parseFloat(row.querySelector("[name=compAmount]").value);
        list.push({name:name||"(unnamed)",type:row.getAttribute("data-type"),
                   calc:row.querySelector("[name=compCalc]").value,amount:isNaN(amt)?0:amt});
    });
    return list;
}

function phCalc(basic){
    var comps=(document.getElementById("phAutoComp").checked ? PH_TEMPLATE : []).concat(phExtras());
    var res={earn:[],ded:[],gross:basic,dedTotal:0,net:0};
    comps.forEach(function(c){
        var amt = c.calc==="PERCENTAGE" ? phRound(basic*c.amount/100) : phRound(c.amount);
        var row={c:c,amt:amt};
        if(c.type==="EARNING"){ res.earn.push(row); res.gross=phRound(res.gross+amt); }
        else { res.ded.push(row); res.dedTotal=phRound(res.dedTotal+amt); }
    });
    res.net=phRound(res.gross-res.dedTotal);
    return res;
}

function phRowHtml(r){
    var d=r.c.calc==="PERCENTAGE" ? " <small>("+r.c.amount+"% of basic)</small>" : "";
    return "<tr><td>"+phEsc(r.c.name)+d+"</td><td class=\"payroll-num\">"+phMoney(r.amt)+"</td></tr>";
}

function phRecalc(){
    var auto=document.getElementById("phAutoComp");
    if(!auto) return;
    var basic=parseFloat(document.getElementById("phBasic").value);
    if(isNaN(basic)||basic<0) basic=0;
    var r=phCalc(basic);

    document.getElementById("phAutoEarn").innerHTML =
        "<tr><td>Basic Salary</td><td class=\"payroll-num\">"+phMoney(basic)+"</td></tr>"+r.earn.map(phRowHtml).join("");
    document.getElementById("phAutoDed").innerHTML = r.ded.map(phRowHtml).join("") ||
        "<tr><td colspan=\"2\"><small>No deductions</small></td></tr>";
    document.getElementById("phAutoGross").textContent=phMoney(r.gross);
    document.getElementById("phAutoDedTotal").textContent=phMoney(r.dedTotal);
    document.getElementById("phAutoNet").textContent=phMoney(r.net);

    /* hidden inputs for the standard template (own rows are real inputs) */
    var box=document.getElementById("phAutoHidden");
    box.innerHTML="";
    if(!auto.checked) return;
    PH_TEMPLATE.forEach(function(c){
        [["compName",c.name],["compType",c.type],["compCalc",c.calc],["compAmount",c.amount]].forEach(function(p){
            var i=document.createElement("input");
            i.type="hidden"; i.name=p[0]; i.value=p[1];
            box.appendChild(i);
        });
    });
}

/* + Add Earning / - Add Deduction: one editable row each */
function phAddExtra(type, comp){
    var earn = type==="EARNING";
    var row=document.createElement("div");
    row.className="ph-comp-row ph-extra "+(earn?"earn":"ded");
    row.setAttribute("data-type",type);
    row.innerHTML =
        "<input type=\"text\" name=\"compName\" maxlength=\"100\" required placeholder=\""+(earn?"Earning name (e.g. Bonus)":"Deduction name (e.g. Loan EMI)")+"\" oninput=\"phRecalc()\">"+
        "<input type=\"hidden\" name=\"compType\" value=\""+type+"\">"+
        "<select name=\"compCalc\" onchange=\"phRecalc()\"><option value=\"FIXED\">Fixed amount</option><option value=\"PERCENTAGE\">% of basic</option></select>"+
        "<input type=\"number\" name=\"compAmount\" min=\"0\" step=\"0.01\" required placeholder=\"Amount / %\" oninput=\"phRecalc()\">"+
        "<button type=\"button\" class=\"ph-mini\" title=\"Remove\" onclick=\"this.parentNode.remove();phRecalc()\">&times;</button>";
    document.getElementById("phExtraRows").appendChild(row);
    if(comp){
        row.querySelector("[name=compName]").value=comp.n;
        row.querySelector("[name=compCalc]").value=comp.c==="PERCENTAGE"?"PERCENTAGE":"FIXED";
        row.querySelector("[name=compAmount]").value=comp.a;
    } else {
        row.querySelector("[name=compName]").focus();
    }
    phRecalc();
}

function phShowPanel(){
    var p=document.getElementById("phStructureForm");
    if(p.style.display!=="block") togglePanel("phStructureForm");
    p.scrollIntoView({behavior:"smooth",block:"start"});
}

function phSetMode(editing){
    document.getElementById("phAction").value = editing ? "updateStructure" : "saveStructure";
    /* every field is editable; only people who already have a structure stay blocked,
       except the one being edited */
    var cur = editing ? document.getElementById("phEmpSelect").value : "";
    Array.prototype.forEach.call(document.getElementById("phEmpSelect").options, function(o){
        if(o.getAttribute("data-has")==="1"){ o.disabled = !(editing && o.value===cur); }
    });
    document.getElementById("phSubmit").textContent = editing ? "Update Salary Structure" : "Save Salary Structure";
    if(!editing){ document.getElementById("phEditBanner").style.display="none"; document.getElementById("phStructId").value=""; }
}

function phNewStructure(){
    var f=document.getElementById("phStructureForm").querySelector("form");
    f.reset();
    document.getElementById("phExtraRows").innerHTML="";
    document.getElementById("phAutoComp").checked=true;
    phSetMode(false);
    phRecalc();
    phShowPanel();
}

/* Edit: the saved earnings / deductions are loaded as editable rows */
function phStartEdit(id){
    var st=PH_STRUCTS[String(id)];
    if(!st) return;
    var f=document.getElementById("phStructureForm").querySelector("form");
    f.reset();
    document.getElementById("phExtraRows").innerHTML="";
    document.getElementById("phStructId").value=id;
    document.getElementById("phEmpSelect").value=st.emp;
    document.getElementById("phEffFrom").value=st.from;
    document.getElementById("phBasic").value=st.basic;
    document.getElementById("phBank").value=phDecode(st.bank);
    document.getElementById("phAcct").value=phDecode(st.acct);
    document.getElementById("phAutoComp").checked=false;   /* saved rows are listed below */
    st.comps.forEach(function(c){
        phAddExtra(c.t==="EARNING"?"EARNING":"DEDUCTION",{n:phDecode(c.n),c:c.c,a:c.a});
    });
    /* enable this person's own option BEFORE the mode is applied */
    Array.prototype.forEach.call(document.getElementById("phEmpSelect").options, function(o){
        if(o.value===st.emp){ o.disabled=false; }
    });
    document.getElementById("phEmpSelect").value=st.emp;
    phSetMode(true);
    /* edit: every field (employee, salary period, basic salary, rows) must be usable */
    Array.prototype.forEach.call(f.elements,function(el){
        if(el.id==="phEmpSelect"||el.type==="hidden") return;
        el.disabled=false; el.readOnly=false;
    });
    document.getElementById("phEmpSelect").disabled=false;
    var b=document.getElementById("phEditBanner");
    b.style.display="block";
    b.innerHTML="Editing salary structure of <strong>"+st.name+"</strong> ("+st.emp+"). Everything can be changed - employee, salary period, basic salary, bank name, account number, earnings and deductions - then click Update.";
    phRecalc();
    phShowPanel();
}

function phOnEmployee(sel){
    var opt=sel.options[sel.selectedIndex];
    var sal=opt ? opt.getAttribute("data-salary") : "";
    var basic=document.getElementById("phBasic");
    if(sal && document.getElementById("phAction").value==="saveStructure"){ basic.value=sal; }
    phRecalc();
}

document.addEventListener("DOMContentLoaded",phRecalc);
</script>
            </form>
        </div>

        <div class="table-container" style="margin-top:14px">
            <table>
                <thead>
                    <tr><th>Employee</th><th>Department</th><th class="payroll-num">Basic Salary</th><th>Bank</th><th>Effective From</th><th>Components</th><th>Status</th><th>Actions</th></tr>
                </thead>
                <tbody>
                <% for (model.SalaryStructure ss : payStructures) {
                    String stLabel; String stClass;
                    if (ss.getEffectiveFrom() != null && ss.getEffectiveFrom().isAfter(payNow)) { stLabel = "UPCOMING"; stClass = "status-pending"; }
                    else if (ss.getEffectiveTo() != null && ss.getEffectiveTo().isBefore(payNow)) { stLabel = "EXPIRED"; stClass = "status-inactive"; }
                    else { stLabel = "CURRENT"; stClass = "status-active"; }
                    List<model.SalaryComponent> comps = payComps.get(ss.getId());
                %>
                    <tr>
                        <td><strong><%= h(ss.getEmployeeName()) %></strong><br><small class="ph-muted"><%= h(ss.getEmployeeId()) %></small></td>
                        <td><span class="ph-chip"><%= h(ss.getDepartment()) %></span></td>
                        <td class="payroll-num"><%= payMoney(ss.getBasicSalary()) %></td>
                        <td>
                            <% if (ss.getBankName() == null || ss.getBankName().isEmpty()) { %><span class="ph-muted">Not added</span><% } else {
                                String acct = ss.getAccountNumber() == null ? "" : ss.getAccountNumber();
                                String acctMasked = acct.length() > 4 ? "XXXX" + acct.substring(acct.length() - 4) : acct; %>
                                <strong><%= h(ss.getBankName()) %></strong><br>
                                <small class="ph-muted">A/c <%= h(acctMasked) %></small>
                            <% } %>
                        </td>
                        <td><%= ss.getEffectiveFrom() == null ? "-" : payMonthNames[ss.getEffectiveFrom().getMonthValue() - 1].substring(0, 3) + " " + ss.getEffectiveFrom().getYear() %></td>
                        <td class="ph-comps-cell">
                            <% if (comps == null || comps.isEmpty()) { %><span class="ph-muted">None</span><% } else {
                                for (int pass = 0; pass < 2; pass++) {
                                    boolean wantEarn = (pass == 0);
                                    StringBuilder grp = new StringBuilder();
                                    for (model.SalaryComponent sc : comps) {
                                        boolean earn = "EARNING".equalsIgnoreCase(sc.getComponentType());
                                        if (earn != wantEarn) continue;
                                        boolean pct = "PERCENTAGE".equalsIgnoreCase(sc.getCalculationType());
                                        grp.append("<span class=\"ph-comp2 ").append(earn ? "earn" : "ded").append("\"><i></i>")
                                           .append(h(sc.getComponentName())).append(" <b>")
                                           .append(pct ? sc.getAmount().stripTrailingZeros().toPlainString() + "%" : "&#8377;" + payMoney(sc.getAmount()))
                                           .append("</b></span>");
                                    }
                                    if (grp.length() > 0) { %>
                                        <div class="ph-comp-group">
                                            <span class="ph-comp-title <%= wantEarn ? "earn" : "ded" %>"><%= wantEarn ? "Earnings" : "Deductions" %></span>
                                            <div class="ph-comp-list"><%= grp %></div>
                                        </div>
                            <%      }
                                }
                            } %>
                        </td>
                        <td><span class="status <%= stClass %>"><%= stLabel %></span></td>
                        <td><button type="button" class="ph-mini" onclick="phStartEdit(<%= ss.getId() %>)">&#9998; Edit</button></td>
                    </tr>
                <% } %>
                <% if (payStructures.isEmpty()) { %>
                    <tr><td colspan="8" style="text-align:center">No salary structures yet. Click <strong>+ New Salary Structure</strong>.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
        <% if ("1".equals(request.getParameter("newStructure"))) { %>
            <script>document.addEventListener("DOMContentLoaded",function(){ togglePanel('phStructureForm'); });</script>
        <% } %>
<% } else if ("process".equals(payTab)) { %>
        <!-- ================= PROCESS PAYROLL TAB ================= -->
<%
    List<service.PayrollService.PreviewRow> payPreview = (List<service.PayrollService.PreviewRow>) request.getAttribute("payrollPreview");
    if (payPreview == null) payPreview = new ArrayList<service.PayrollService.PreviewRow>();
    int ppTotal = payPreview.size(), ppReady = 0, ppMissing = 0, ppDone = 0;
    java.math.BigDecimal ppGross = java.math.BigDecimal.ZERO;
    for (service.PayrollService.PreviewRow x : payPreview) {
        if (x.payrollStatus != null) ppDone++;
        else if (x.hasStructure) ppReady++;
        else ppMissing++;
        if (x.gross != null && (x.hasStructure || x.payrollStatus != null)) ppGross = ppGross.add(x.gross);
    }
%>
        <div class="pp-toolbar">
            <form method="get" action="<%= cp %>/hr#payroll" class="pp-period">
                <input type="hidden" name="action" value="payroll">
                <input type="hidden" name="tab" value="process">
                <label>Month
                    <select name="month">
                        <% for (int m = 1; m <= 12; m++) { %>
                            <option value="<%= m %>" <%= m == payMonth ? "selected" : "" %>><%= payMonthNames[m - 1] %></option>
                        <% } %>
                    </select>
                </label>
                <label>Year <input type="number" name="year" min="2000" max="9999" value="<%= payYear %>"></label>
                <label>Show
                    <select name="personType">
                        <option value="ALL" <%= "ALL".equals(payType) ? "selected" : "" %>>Everyone</option>
                        <option value="MANAGER" <%= "MANAGER".equals(payType) ? "selected" : "" %>>Managers</option>
                        <option value="EMPLOYEE" <%= "EMPLOYEE".equals(payType) ? "selected" : "" %>>Employees</option>
                    </select>
                </label>
                <button class="primary" type="submit">Load</button>
            </form>
            <form method="post" action="<%= cp %>/payroll" onsubmit="return confirm('Generate payroll for <%= payMonthNames[payMonth - 1] %> <%= payYear %>? It will be marked PAID.')">
                <input type="hidden" name="csrf" value="<%= h(payCsrf) %>">
                <input type="hidden" name="action" value="runPayroll">
                <input type="hidden" name="tab" value="process">
                <input type="hidden" name="month" value="<%= payMonth %>">
                <input type="hidden" name="year" value="<%= payYear %>">
                <button type="submit" class="pp-run" <%= ppReady == 0 ? "disabled title=\"Nothing left to generate for this period\"" : "" %>>&#9654; Generate payroll<%= ppReady > 0 ? " (" + ppReady + ")" : "" %></button>
            </form>
        </div>

        <div class="pp-stats">
            <div class="pp-stat"><span>People</span><strong><%= ppTotal %></strong></div>
            <div class="pp-stat pp-ok"><span>Ready to pay</span><strong><%= ppReady %></strong></div>
            <div class="pp-stat pp-done"><span>Already paid</span><strong><%= ppDone %></strong></div>
            <div class="pp-stat <%= ppMissing > 0 ? "pp-warn" : "" %>"><span>No structure</span><strong><%= ppMissing %></strong></div>
            <div class="pp-stat pp-wide"><span>Total gross</span><strong>&#8377;<%= payMoney(ppGross) %></strong></div>
        </div>

        <% if (ppMissing > 0) { %>
            <div class="pp-alert"><%= ppMissing %> person(s) have no salary structure and will be skipped. Add one in <a href="<%= h(payBase + "&tab=structures#payroll") %>">Salary Structures</a>.</div>
        <% } %>

        <div class="pp-card">
            <div class="pp-card-head">
                <h3><%= payMonthNames[payMonth - 1] %> <%= payYear %> &middot; payroll preview</h3>
                <div class="pp-filters">
                    <input type="search" id="ppSearch" placeholder="Search name or ID" oninput="ppFilter()">
                    <button type="button" class="pp-chip active" data-f="ALL" onclick="ppSetFilter(this)">All</button>
                    <button type="button" class="pp-chip" data-f="READY" onclick="ppSetFilter(this)">Ready</button>
                    <button type="button" class="pp-chip" data-f="PAID" onclick="ppSetFilter(this)">Paid</button>
                    <button type="button" class="pp-chip" data-f="MISSING" onclick="ppSetFilter(this)">No structure</button>
                </div>
            </div>
            <div class="table-container" style="margin:0">
            <table class="pp-table">
                <thead>
                    <tr><th>Person</th><th>Department</th><th>Attendance</th><th class="payroll-num">Gross</th><th>Status</th></tr>
                </thead>
                <tbody id="ppBody">
                <% for (service.PayrollService.PreviewRow pv : payPreview) {
                    String pvStatus = pv.payrollStatus == null ? "NOT GENERATED" : pv.payrollStatus.toUpperCase();
                    String pvKey = pv.payrollStatus != null ? "PAID" : (pv.hasStructure ? "READY" : "MISSING");
                    String initial = (pv.name == null || pv.name.trim().isEmpty()) ? "?" : pv.name.trim().substring(0, 1).toUpperCase();
                %>
                    <tr data-state="<%= pvKey %>" data-text="<%= h((pv.name + " " + pv.employeeId).toLowerCase()) %>">
                        <td>
                            <div class="pp-person">
                                <span class="pp-avatar"><%= h(initial) %></span>
                                <div><strong><%= h(pv.name) %></strong><small><%= h(pv.employeeId) %> &middot; <%= "MANAGER".equals(pv.personType) ? "Manager" : "Employee" %></small></div>
                            </div>
                        </td>
                        <td><span class="ph-chip"><%= h(pv.department) %></span></td>
                        <td>
                            <% int ppWork = Math.max(pv.attendance.workingDays, 1); double ppPct = Math.min(100.0, 100.0 * pv.attendance.presentDays / ppWork); %>
                            <div class="pp-bar"><i style="width:<%= String.format("%.0f", ppPct) %>%"></i></div>
                            <small class="ph-muted"><%= payDays(pv.attendance.presentDays) %> / <%= pv.attendance.workingDays %> days &middot; paid leave <%= payDays(pv.attendance.paidLeaveUsed) %>/<%= payDays(pv.attendance.paidLeaveAllowance) %></small>
                            <% if (pv.attendance.lopDays > 0) { %><span class="ph-lop"><%= payDays(pv.attendance.lopDays) %> unpaid</span><% } %>
                        </td>
                        <% if (!pv.hasStructure && pv.payrollStatus == null) { %>
                            <td class="payroll-num ph-red">No structure</td>
                        <% } else { %>
                            <td class="payroll-num"><strong>&#8377;<%= payMoney(pv.gross) %></strong></td>
                        <% } %>
                        <td><span class="status <%= payStatusClass(pvStatus) %>"><%= h(pvStatus) %></span></td>
                    </tr>
                <% } %>
                <% if (payPreview.isEmpty()) { %>
                    <tr><td colspan="5" style="text-align:center">No active employees or managers found.</td></tr>
                <% } %>
                </tbody>
            </table>
            </div>
            <p class="ph-muted" style="font-size:12px;margin:10px 4px 0">Every month has 2 paid leaves; salary is cut only for unpaid days above that. Weekends are not counted.</p>
        </div>

        <details class="pp-card pp-auto">
            <summary>&#9202; Automatic payroll schedule</summary>
<%
    DAO.PayrollSettingsDAO.Settings paySched = (DAO.PayrollSettingsDAO.Settings) request.getAttribute("payrollSchedule");
    if (paySched == null) paySched = new DAO.PayrollSettingsDAO.Settings();
%>
        <div class="ph-sched">
            <form method="post" action="<%= cp %>/payroll">
                <input type="hidden" name="csrf" value="<%= h(payCsrf) %>">
                <input type="hidden" name="action" value="saveSchedule">
                <input type="hidden" name="tab" value="process">
                <input type="hidden" name="month" value="<%= payMonth %>">
                <input type="hidden" name="year" value="<%= payYear %>">
                <div class="ph-sched-head">
                    <div>
                        <h3>&#9202; Automatic payroll <span class="status <%= paySched.enabled ? "status-active" : "status-inactive" %>"><%= paySched.enabled ? "ON" : "OFF" %></span></h3>
                        <p>Salary is generated and <strong>paid automatically</strong> on day <strong><%= paySched.payDay %></strong> of every month at <strong><%= String.format("%02d:00", paySched.runHour) %></strong>.</p>
                    </div>
                    <% if (paySched.lastRunAt != null) { %>
                    <div class="ph-sched-last">Last auto-run: <%= paySched.lastRunAt.toString().replace('T', ' ').substring(0, 16) %> (<%= h(paySched.lastRunMonth) %>)<br><%= h(paySched.lastRunNote) %></div>
                    <% } %>
                </div>
                <div class="ph-sched-row">
                    <label class="ph-check"><input type="checkbox" name="autoEnabled" <%= paySched.enabled ? "checked" : "" %>> <span><strong>Enable monthly auto-pay</strong></span></label>
                    <label>Pay day of month
                        <input type="number" name="payDay" min="1" max="31" value="<%= paySched.payDay %>" required>
                    </label>
                    <label>Run time
                        <select name="runHour">
                            <% for (int hr = 0; hr < 24; hr++) { %>
                                <option value="<%= hr %>" <%= hr == paySched.runHour ? "selected" : "" %>><%= String.format("%02d:00", hr) %></option>
                            <% } %>
                        </select>
                    </label>
                    <button type="submit" class="success">Save schedule</button>
                </div>
                <p class="ph-muted" style="font-size:12px;margin:8px 0 0">Runs for the current month. A day beyond the month's length (e.g. 31 in November) runs on the last day. If the server was off at that time, salary is paid as soon as it is back. Paid salaries are never repeated. Choose a time after the day's attendance is complete.</p>
            </form>
        </div>
        <style>
        .ph-sched{background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:16px;margin:0 0 16px}
        .ph-sched h3{margin:0 0 4px;font-size:16px}.ph-sched p{margin:0;font-size:13px}
        .ph-sched-head{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap}
        .ph-sched-last{font-size:12px;color:#475569;background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:8px 10px;max-width:460px}
        .ph-sched-row{display:flex;align-items:flex-end;gap:14px;flex-wrap:wrap;margin-top:12px}
        .ph-sched-row label{display:flex;flex-direction:column;gap:4px;font-size:12px;font-weight:600;color:#475569}
        .ph-sched-row input[type=number],.ph-sched-row select{padding:9px 11px;border:1px solid #cbd5e1;border-radius:8px;font-size:13px;background:#fff;min-width:120px}
        .ph-sched-row .ph-check{flex-direction:row;align-items:center;margin:0 10px 8px 0}
        </style>

        </details>

<style>
.pp-toolbar{display:flex;justify-content:space-between;align-items:flex-end;flex-wrap:wrap;gap:12px;background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:14px 16px;margin-bottom:14px}
.pp-period{display:flex;flex-wrap:wrap;gap:12px;align-items:flex-end;margin:0}
.pp-period label{display:flex;flex-direction:column;gap:4px;font-size:12px;font-weight:600;color:#475569}
.pp-period select,.pp-period input[type=number]{padding:9px 11px;border:1px solid #cbd5e1;border-radius:8px;font-size:13px;background:#fff}
.pp-run{background:#16a34a;color:#fff;border:0;border-radius:10px;padding:12px 20px;font-size:14px;font-weight:700;cursor:pointer;box-shadow:0 4px 10px rgba(22,163,74,.25)}
.pp-run:disabled{background:#cbd5e1;box-shadow:none;cursor:not-allowed}
.pp-stats{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;margin-bottom:14px}
.pp-stat{background:#fff;border:1px solid #e2e8f0;border-left:4px solid #94a3b8;border-radius:12px;padding:12px 14px}
.pp-stat span{display:block;font-size:11px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#64748b}
.pp-stat strong{display:block;font-size:22px;margin-top:4px;color:#0f172a}
.pp-ok{border-left-color:#2563eb}.pp-done{border-left-color:#16a34a}.pp-warn{border-left-color:#dc2626;background:#fef2f2}.pp-wide{border-left-color:#7c3aed}
.pp-alert{background:#fef9c3;border:1px solid #fde68a;border-radius:10px;padding:10px 14px;font-size:13px;margin-bottom:14px}
.pp-card{background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:16px;margin-bottom:14px}
.pp-card-head{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:12px}
.pp-card-head h3{margin:0;font-size:16px}
.pp-filters{display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.pp-filters input[type=search]{padding:8px 11px;border:1px solid #cbd5e1;border-radius:999px;font-size:13px;min-width:170px}
.pp-chip{border:1px solid #cbd5e1;background:#fff;color:#475569;border-radius:999px;padding:7px 13px;font-size:12px;font-weight:600;cursor:pointer}
.pp-chip.active{background:#2563eb;border-color:#2563eb;color:#fff}
.pp-person{display:flex;align-items:center;gap:10px}
.pp-person small{display:block;color:#64748b;font-size:12px}
.pp-avatar{width:34px;height:34px;border-radius:50%;background:#e0e7ff;color:#3730a3;display:flex;align-items:center;justify-content:center;font-weight:700;flex:none}
.pp-bar{height:6px;background:#e2e8f0;border-radius:99px;overflow:hidden;margin-bottom:4px;max-width:180px}
.pp-bar i{display:block;height:100%;background:#22c55e}
.pp-auto summary{cursor:pointer;font-weight:700;font-size:14px}
.pp-auto[open] summary{margin-bottom:12px}
@media(max-width:1000px){.pp-stats{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style>
<script>
var ppState="ALL";
function ppSetFilter(btn){
    ppState=btn.getAttribute("data-f");
    document.querySelectorAll(".pp-chip").forEach(function(c){c.classList.toggle("active",c===btn);});
    ppFilter();
}
function ppFilter(){
    var q=(document.getElementById("ppSearch").value||"").toLowerCase().trim();
    document.querySelectorAll("#ppBody tr[data-state]").forEach(function(r){
        var okState=(ppState==="ALL"||r.getAttribute("data-state")===ppState);
        var okText=!q||r.getAttribute("data-text").indexOf(q)>-1;
        r.style.display=(okState&&okText)?"":"none";
    });
}
</script>
<% } else { %>
        <!-- ================= HISTORY & REPORTS TAB ================= -->
<%
    int hMonth = request.getAttribute("histMonth") == null ? 0 : (Integer) request.getAttribute("histMonth");
    int hYear = request.getAttribute("histYear") == null ? 0 : (Integer) request.getAttribute("histYear");
    String hDept = request.getAttribute("histDept") == null ? "" : String.valueOf(request.getAttribute("histDept"));
    String hStatus = request.getAttribute("histStatus") == null ? "" : String.valueOf(request.getAttribute("histStatus"));
    String hEmp = request.getAttribute("histEmp") == null ? "" : String.valueOf(request.getAttribute("histEmp"));
    List<String> payDepartments = (List<String>) request.getAttribute("payrollDepartments");
    if (payDepartments == null) payDepartments = new ArrayList<String>();
    String hQs = "&personType=" + payType + "&histMonth=" + hMonth + "&histYear=" + hYear
        + "&dept=" + java.net.URLEncoder.encode(hDept, "UTF-8")
        + "&status=" + java.net.URLEncoder.encode(hStatus, "UTF-8")
        + "&empId=" + java.net.URLEncoder.encode(hEmp, "UTF-8");
%>
        <div class="review-heading">
            <h3>Payroll History &amp; Reports</h3>
            <p>Filter by month, year, department, payment status or employee. Leave month/year empty for all periods.</p>
        </div>

        <form method="get" action="<%= cp %>/hr#payroll" class="ph-filter">
            <input type="hidden" name="action" value="payroll">
            <input type="hidden" name="tab" value="history">
            <label>Month
                <select name="histMonth">
                    <option value="0">All</option>
                    <% for (int m = 1; m <= 12; m++) { %>
                        <option value="<%= m %>" <%= m == hMonth ? "selected" : "" %>><%= payMonthNames[m - 1] %></option>
                    <% } %>
                </select>
            </label>
            <label>Year <input type="number" name="histYear" min="2000" max="9999" value="<%= hYear == 0 ? "" : String.valueOf(hYear) %>" placeholder="All"></label>
            <label>Department
                <select name="dept">
                    <option value="">All</option>
                    <% for (String d : payDepartments) { %>
                        <option value="<%= h(d) %>" <%= d.equals(hDept) ? "selected" : "" %>><%= h(d) %></option>
                    <% } %>
                </select>
            </label>
            <label>Show
                <select name="personType">
                    <option value="ALL" <%= "ALL".equals(payType) ? "selected" : "" %>>All</option>
                    <option value="MANAGER" <%= "MANAGER".equals(payType) ? "selected" : "" %>>Managers</option>
                    <option value="EMPLOYEE" <%= "EMPLOYEE".equals(payType) ? "selected" : "" %>>Employees</option>
                </select>
            </label>
            <label>Payment Status
                <select name="status">
                    <option value="">All</option>
                    <% for (String sOpt : new String[]{"PAID","PROCESSED","CANCELLED"}) { %>
                        <option value="<%= sOpt %>" <%= sOpt.equals(hStatus) ? "selected" : "" %>><%= sOpt %></option>
                    <% } %>
                </select>
            </label>
            <label>Employee ID <input type="text" name="empId" value="<%= h(hEmp) %>" maxlength="40" placeholder="e.g. EMP101"></label>
            <button class="primary" type="submit">Apply Filters</button>
            <a class="btn neutral" href="<%= cp %>/hr?action=payroll&tab=history&personType=ALL#payroll">Reset</a>
            <a class="btn success" href="<%= h(cp + "/hr?action=payrollCsv" + hQs) %>">&#11015; Download CSV</a>
        </form>

        <div class="ph-cards ph-cards-2">
            <div class="ph-card"><span class="ph-label">TOTAL RECORDS</span><strong><%= payrollList.size() %></strong><small>from Oct 2026 onwards</small></div>
            <div class="ph-card"><span class="ph-label">PAYROLL STATUS</span><strong class="ph-green"><%= payPaid %> Paid</strong><small><%= payPending %> Pending</small></div>
        </div>

        <div class="table-container">
            <table>
                <thead>
                    <tr>
                        <th>Period</th><th>Employee</th><th>Department</th>
                        <th class="payroll-num">Gross</th><th class="payroll-num">Paid</th>
                        <th>Status</th><th>Slip</th>
                    </tr>
                </thead>
                <tbody>
                <% for (model.Payroll pr : payrollList) {
                    String prStatus = pr.getStatus() == null ? "PENDING" : pr.getStatus().trim().toUpperCase();
                %>
                    <tr>
                        <td><%= payMonthNames[pr.getPayrollMonth() - 1].substring(0, 3) %> <%= pr.getPayrollYear() %></td>
                        <td><strong><%= h(pr.getEmployeeName()) %></strong><br><small class="ph-muted"><%= h(pr.getEmployeeId()) %> &middot; <%= "MANAGER".equals(pr.getPersonType()) ? "Manager" : "Employee" %></small></td>
                        <td><span class="ph-chip"><%= h(pr.getDepartment()) %></span></td>
                        <td class="payroll-num"><%= payMoney(pr.getGrossSalary()) %></td>
                        <td class="payroll-num"><%= payMoney(pr.getPaidAmount()) %></td>
                        <td><span class="status <%= payStatusClass(prStatus) %>"><%= h(prStatus) %></span></td>
                        <td>
                            <% if ("PROCESSED".equals(prStatus) || "PAID".equals(prStatus)) { %>
                                <a class="ph-mini" target="_blank" rel="noopener" href="<%= cp %>/hr?action=salarySlip&payrollId=<%= pr.getId() %>">&#128196; Slip</a>
                                <% if ("PAID".equals(prStatus)) { %>
                                    <a class="ph-mini" target="_blank" rel="noopener" title="Email this salary slip to the employee" href="<%= cp %>/hr?action=emailSlip&payrollId=<%= pr.getId() %>">&#9993; Email</a>
                                <% } %>
                            <% } else { %>-<% } %>
                        </td>
                    </tr>
                <% } %>
                <% if (payrollList.isEmpty()) { %>
                    <tr><td colspan="7" style="text-align:center">No payroll records match these filters.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
<% } %>

    </div>

    <!-- REPORTS MODULE -->
    <div class="section" id="reports">
    <div class="reports-pagebar">
        <div class="reports-crumb">Dashboard &rsaquo; <b>Reports</b></div>
        <a class="reports-back" href="<%= cp %>/hr">&larr; Back to Dashboard</a>
    </div>
        <div class="section-header">
            <div>
                <h2>📈 Reports Dashboard</h2>
                <p>All employees and managers. Click one to see their details, attendance, leave, task and team reports.</p>
            </div>
        </div>

        <div class="report-cards">
            <div class="report-card"><strong><%= reportEmployeeCount %></strong><span>Total Employees</span></div>
            <div class="report-card"><strong><%= managerCount %></strong><span>Total Managers</span></div>
            <div class="report-card"><strong><%= reportEmployeeCount + managerCount %></strong><span>Total People</span></div>
        </div>

<%
    String rpdPerson = request.getParameter("reportPerson");
    String rpdKind = "MANAGER".equalsIgnoreCase(request.getParameter("personKind")) ? "MANAGER" : "EMPLOYEE";
    if (rpdPerson != null) rpdPerson = rpdPerson.trim();
    if (rpdPerson != null && rpdPerson.isEmpty()) rpdPerson = null;
    String rpdSearchQs = reportSearch.isEmpty() ? ""
        : "&reportSearch=" + java.net.URLEncoder.encode(reportSearch, "UTF-8");
    String rpdDateQs = "";
    if (!fromDate.isEmpty()) rpdDateQs += "&fromDate=" + java.net.URLEncoder.encode(fromDate, "UTF-8");
    if (!toDate.isEmpty()) rpdDateQs += "&toDate=" + java.net.URLEncoder.encode(toDate, "UTF-8");
%>
<% if (rpdPerson != null) { %>
        <%= service.PersonReportHtml.render(
                rpdPerson, rpdKind, null, fromDate, toDate,
                cp + "/hr?action=reports&reportType=employees&personType=" + personType + rpdSearchQs + "#reports",
                cp + "/hr#reports",
                cp + "/hr?action=reports&reportType=employees&reportPerson="
                    + java.net.URLEncoder.encode(rpdPerson, "UTF-8") + "&personKind=" + rpdKind + "#reports",
                new String[][]{{"action","reports"},{"reportType","employees"},{"personType", personType},{"reportSearch", reportSearch},
                               {"reportPerson", rpdPerson},{"personKind", rpdKind}},
                "fromDate", "toDate",
                cp + "/hr?action=personAttendance&reportPerson="
                    + java.net.URLEncoder.encode(rpdPerson, "UTF-8") + "&personKind=" + rpdKind) %>
<% } else { %>
        <form method="get" action="<%= cp %>/hr#reports" class="people-filter">
            <input type="hidden" name="action" value="reports">
            <input type="hidden" name="reportType" value="employees">

            <label>Search by Name or ID
                <input type="search" name="reportSearch" value="<%= h(reportSearch) %>"
                       placeholder="e.g. Ravi or EMP101" maxlength="60" autocomplete="off">
            </label>

            <label>Employee / Manager
                <select name="personType" onchange="this.form.submit()">
                    <option value="ALL" <%= "ALL".equalsIgnoreCase(personType) ? "selected" : "" %>>All</option>
                    <option value="EMPLOYEE" <%= "EMPLOYEE".equalsIgnoreCase(personType) ? "selected" : "" %>>Employees only</option>
                    <option value="MANAGER" <%= "MANAGER".equalsIgnoreCase(personType) ? "selected" : "" %>>Managers only</option>
                </select>
            </label>

            <div class="pf-actions">
                <button class="primary" type="submit">🔍 Search</button>
                <a class="btn neutral" href="<%= cp %>/hr?action=reports&reportType=employees#reports">Reset</a>
            </div>
            <div class="pf-hint">Searches employee / manager ID and name (e-mail also matches).</div>
        </form>


        <% if (request.getAttribute("reportError") != null) { %>
            <div class="message message-error"><%= h(request.getAttribute("reportError")) %></div>
        <% } %>

        <div class="review-heading">
            <h3>All Employees &amp; Managers</h3>
            <p>Click an employee or manager (or <strong>View Report</strong>) to open their full report.</p>
            <p>Total people: <strong><%= reportTotal %></strong></p>
        </div>

        <div class="table-container">
            <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Type</th>
                            <th>Email</th>
                            <th>Department</th>
                            <th>Status</th>
                            <th>Report</th>
                        </tr>
                    </thead>
                    <tbody>
                    <% for (HRServlet.ReportRow r : reportRows) {
                        String personStatus = r.five == null ? "INACTIVE" : r.five.trim().toUpperCase();
                        if (!"ACTIVE".equals(personStatus)) personStatus = "INACTIVE";
                    %>
                        <%
                            String rowKind = "MANAGER".equalsIgnoreCase(r.six) ? "MANAGER" : "EMPLOYEE";
                            String rowLink = cp + "/hr?action=reports&reportType=employees&reportPerson="
                                + java.net.URLEncoder.encode(r.one == null ? "" : r.one, "UTF-8")
                                + "&personKind=" + rowKind + "&personType=" + personType + rpdSearchQs + rpdDateQs + "#reports";
                        %>
                        <tr>
                            <td><a href="<%= h(rowLink) %>"><%= h(r.one) %></a></td>
                            <td><a href="<%= h(rowLink) %>"><%= h(r.two) %></a></td>
                            <td><%= "MANAGER".equals(rowKind) ? "Manager" : "Employee" %></td>
                            <td><%= h(r.three) %></td>
                            <td><%= h(r.four) %></td>
                            <td>
                                <span class="status <%= "ACTIVE".equals(personStatus) ? "status-active" : "status-inactive" %>">
                                    <%= h(personStatus) %>
                                </span>
                            </td>
                            <td><a class="btn" style="text-decoration:none;display:inline-block" href="<%= h(rowLink) %>">View Report</a></td>
                        </tr>
                    <% } %>
                    <% if (reportRows.isEmpty()) { %>
                        <tr><td colspan="7" style="text-align:center">No employees or managers found.</td></tr>
                    <% } %>
                    </tbody>

            </table>
        </div>
<% } %>
    </div>

</div>
</div>
</body>
</html>
