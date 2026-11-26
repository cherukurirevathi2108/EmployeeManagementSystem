<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,java.sql.*,model.Employe,model.Task,servlet.AdminServlet" %>

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
    HttpSession adminSession = request.getSession(false);
    if (adminSession == null ||
        !"ADMIN".equalsIgnoreCase(String.valueOf(adminSession.getAttribute("role")))) {
        response.sendRedirect(request.getContextPath() + "/login.html");
        return;
    }

    String cp = request.getContextPath();
    String adminName = String.valueOf(adminSession.getAttribute("adminName") == null
        ? "Admin" : adminSession.getAttribute("adminName"));
    String adminEmail = String.valueOf(adminSession.getAttribute("adminEmail") == null
        ? "" : adminSession.getAttribute("adminEmail"));

    String dbUrl = "jdbc:mysql://localhost:3306/employee_db";
    String dbUser = "root";
    String dbPassword = "root";

    int employeeCount = request.getAttribute("employeeCount") == null ? 0
        : (Integer) request.getAttribute("employeeCount");
    int managerCount = request.getAttribute("managerCount") == null ? 0
        : (Integer) request.getAttribute("managerCount");
    int teamCount = request.getAttribute("teamCount") == null ? 0
        : (Integer) request.getAttribute("teamCount");
    int hrCount = request.getAttribute("hrCount") == null ? 0
        : (Integer) request.getAttribute("hrCount");

    List<Employe> searchResults =
        (List<Employe>) request.getAttribute("searchResults");
    if (searchResults == null) searchResults = new ArrayList<Employe>();

    List<AdminServlet.AttendanceData> attendanceData =
        (List<AdminServlet.AttendanceData>) request.getAttribute("attendanceData");
    if (attendanceData == null) attendanceData = new ArrayList<AdminServlet.AttendanceData>();

    List<AdminServlet.LeaveData> leaveData =
        (List<AdminServlet.LeaveData>) request.getAttribute("leaveData");
    if (leaveData == null) leaveData = new ArrayList<AdminServlet.LeaveData>();

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

    String action = request.getAttribute("action") == null
        ? "" : String.valueOf(request.getAttribute("action"));

    List<AdminServlet.ReportRow> reportRows =
        (List<AdminServlet.ReportRow>) request.getAttribute("reportRows");
    if (reportRows == null) reportRows = new ArrayList<AdminServlet.ReportRow>();

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
<title>Admin Dashboard - <%= util.Html.esc(util.Branding.name()) %></title>

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
                if(!best && !a.classList.contains("logout") && (h==="#dashboard" || /\/admin$/.test(h) || h==="#")){ best=a; }
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
    var HOME="<%= cp %>/admin";
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
<style>
/* =====================================================================
   Welcome banner + stat cards only (appended last; nothing else is touched)
   ===================================================================== */

/* ---- welcome banner ---- */
.content > .welcome{display:flex;align-items:center;justify-content:space-between;gap:22px;flex-wrap:wrap;padding:28px 32px;margin-bottom:24px}
.welcome-text{position:relative;z-index:1;max-width:640px}
.welcome-date{font-size:12px;font-weight:600;letter-spacing:.4px;color:#c7d2fe;margin-bottom:8px}
.content > .welcome h1{font-size:28px;margin-bottom:8px}
.content > .welcome p{font-size:13.5px;line-height:1.55;color:#e0e7ff}
.welcome-actions{position:relative;z-index:1;display:flex;gap:10px;flex-wrap:wrap}
.welcome-btn{display:inline-flex;align-items:center;padding:10px 18px;border-radius:10px;font-size:13px;font-weight:600;text-decoration:none;transition:transform .15s,background .15s,box-shadow .15s}
.welcome-btn.primary{background:#fff;color:#312e81;box-shadow:0 6px 16px rgba(15,23,42,.22)}
.welcome-btn.primary:hover{transform:translateY(-1px);box-shadow:0 10px 22px rgba(15,23,42,.28)}
.welcome-btn.ghost{background:rgba(255,255,255,.14);color:#fff;border:1px solid rgba(255,255,255,.3)}
.welcome-btn.ghost:hover{background:rgba(255,255,255,.24)}

/* ---- stat cards: 5 across, then 3 + 2, then 2 columns ---- */
.content > .stats{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:16px;margin-bottom:24px}
.content > .stats .stat-card{display:flex;flex-direction:column;position:relative;padding:18px 18px 16px;border:1px solid var(--line);border-top:1px solid var(--line);text-decoration:none;color:inherit}
.stat-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}
.stat-card .stat-icon{width:42px;height:42px;font-size:20px;background:var(--tint,#eef2ff)}
.stat-go{font-size:12px;font-weight:600;color:var(--tone,#4f46e5);opacity:0;transform:translateX(-4px);transition:opacity .15s,transform .15s}
.stat-go::after{content:" \203A"}
.stat-card:hover .stat-go,.stat-card:focus-visible .stat-go{opacity:1;transform:none}
.content > .stats .stat-card h3{font-size:32px;line-height:1;margin:0 0 6px;font-weight:700;letter-spacing:-.5px;font-variant-numeric:tabular-nums}
.content > .stats .stat-card p{font-size:12.5px;font-weight:500;color:var(--muted)}
.stat-card::before{content:"";position:absolute;left:18px;right:18px;bottom:0;height:3px;border-radius:3px 3px 0 0;background:var(--tone,#4f46e5);opacity:.85}
.tone-indigo{--tone:#4f46e5;--tint:#eef2ff}
.tone-violet{--tone:#7c3aed;--tint:#f3e8ff}
.tone-teal{--tone:#0d9488;--tint:#ccfbf1}
.tone-amber{--tone:#d97706;--tint:#fef3c7}
.tone-rose{--tone:#e11d48;--tint:#ffe4e6}

.stat-card:focus-visible,.welcome-btn:focus-visible{outline:2px solid #818cf8;outline-offset:2px}

/* ---- always ONE line: shrink to fit, scroll sideways on phones ---- */
@media(max-width:1280px){
  .content > .stats{gap:12px}
  .content > .stats .stat-card{padding:14px 14px 14px}
  .stat-top{margin-bottom:10px}
  .stat-card .stat-icon{width:36px;height:36px;font-size:17px}
  .content > .stats .stat-card h3{font-size:26px}
  .content > .stats .stat-card p{font-size:12px}
  .stat-card::before{left:14px;right:14px}
}
@media(max-width:900px){
  .content > .stats{gap:8px}
  .content > .stats .stat-card{padding:12px 10px}
  .stat-go{display:none}
  .stat-card .stat-icon{width:32px;height:32px;font-size:15px}
  .content > .stats .stat-card h3{font-size:22px}
  .content > .stats .stat-card p{font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .stat-card::before{left:10px;right:10px}
}
@media(max-width:760px){
  .content > .welcome{padding:22px 20px}
  .content > .stats{display:flex;overflow-x:auto;gap:10px;padding-bottom:6px;scroll-snap-type:x proximity;-webkit-overflow-scrolling:touch}
  .content > .stats .stat-card{flex:0 0 150px;scroll-snap-align:start}
}
@media(prefers-reduced-motion:reduce){
  .stat-card,.stat-go,.welcome-btn{transition:none!important}
  .stat-card:hover,.welcome-btn.primary:hover{transform:none}
}
</style>
</head>

<body>
<div class="sidebar">
    <%= util.Branding.sidebar("Admin Panel") %>
    <div class="menu-title">Dashboard</div>
    <a href="<%= cp %>/admin">🏠 Dashboard</a>
    <div class="menu-title">HR</div>
    <a href="<%= cp %>/admin?action=hrManagement#hrManagement">👔 Recruit &amp; Manage HR</a>
    <div class="menu-title">Employees (view only)</div>
    <a href="<%= cp %>/admin?action=viewEmployees#viewEmployees">👥 View Employees</a>
    <a href="#searchEmployee">🔍 Search Employee</a>
    <div class="menu-title">Teams (view only)</div>
    <a href="#manageTeams">👥 View Teams</a>
    <div class="menu-title">Tasks</div>
    <a href="#taskDashboard">📊 Task Dashboard</a>
    <a href="#taskManagement">📋 Task Management</a>
    <a href="#managerReviews">⭐ Manager Reviews</a>
    <div class="menu-title">Attendance</div>
    <a href="<%= cp %>/admin?action=todayAttendance#attendance">📅 Today's Attendance</a>
    <a href="<%= cp %>/admin?action=monthlyAttendance#attendance">📊 Monthly Attendance</a>
    <div class="menu-title">Overtime</div>
    <a href="<%= cp %>/admin?action=managerOvertime#managerOvertime">⏱️ Manager Overtime</a>
    <div class="menu-title">Leave</div>
    <a href="<%= cp %>/admin?action=viewLeaves#leaveManagement">📝 Leaves (approve HR)</a>
    <div class="menu-title">Payroll</div>
    <a href="<%= cp %>/admin?action=payroll&tab=history#payroll">🕑 Payroll Reports</a>
    <div class="menu-title">Audit &amp; System</div>
    <a href="#system" data-sys-tab="dashboard">🛡️ System Overview</a>
    <a href="#system" data-sys-tab="audit-logs">📜 Audit Logs</a>
    <a href="#system" data-sys-tab="login-history">🔐 Login History</a>
    <a href="#system" data-sys-tab="errors">⚠️ System Errors</a>
    <a href="#system" data-sys-tab="users">👥 Users &amp; Accounts</a>
    <a href="#system" data-sys-tab="settings">⚙️ System Settings</a>
    <a href="#system" data-sys-tab="backups">💾 Backups</a>
    <div class="menu-title">Reports</div>
    <a href="<%= cp %>/admin?action=reports&reportType=employees#reports">📈 Employees & Managers Report</a>
    <a class="logout" href="<%= cp %>/logout">🚪 Logout</a>
</div>

<div class="main">
<div class="header">
    <div><h2>Admin Dashboard</h2><p>Employee Management System</p></div>
    <div class="admin-profile">
        <div class="profile-circle">A</div>
        <div class="profile-info">
            <strong><%= h(adminName) %></strong>
            <span><%= h(adminEmail) %></span>
        </div>
    </div>
</div>

<div class="content">
    <div class="welcome">
        <div class="welcome-text">
            <div class="welcome-date"><%= new java.text.SimpleDateFormat("EEEE, d MMMM yyyy", java.util.Locale.ENGLISH).format(new java.util.Date()) %></div>
            <h1>Welcome, <%= h(adminName) %> 👋</h1>
            <p>You recruit and manage the HR team. Employees, teams, tasks, attendance, leaves, payroll and reports are run by HR and shown here for oversight.</p>
        </div>
        <div class="welcome-actions">
            <a class="welcome-btn primary" href="<%= cp %>/admin?action=hrManagement#hrManagement">Recruit HR</a>
            <a class="welcome-btn ghost" href="<%= cp %>/admin?action=viewLeaves#leaveManagement">Review leaves</a>
        </div>
    </div>

    <% if (request.getAttribute("pageError") != null) { %>
        <div class="message message-error"><%= h(request.getAttribute("pageError")) %></div>
    <% } %>

    <div class="stats">
        <a class="stat-card tone-indigo" href="<%= cp %>/admin?action=viewEmployees#viewEmployees"><span class="stat-top"><span class="stat-icon">👥</span><span class="stat-go">Open</span></span><h3><%= employeeCount %></h3><p>Total Employees</p></a>
        <a class="stat-card tone-violet" href="<%= cp %>/admin?action=reports&amp;reportType=employees#reports"><span class="stat-top"><span class="stat-icon">👤</span><span class="stat-go">Open</span></span><h3><%= managerCount %></h3><p>Total Managers</p></a>
        <a class="stat-card tone-teal" href="#manageTeams"><span class="stat-top"><span class="stat-icon">🏢</span><span class="stat-go">Open</span></span><h3><%= teamCount %></h3><p>Total Teams</p></a>
        <a class="stat-card tone-amber" href="#taskDashboard"><span class="stat-top"><span class="stat-icon">📋</span><span class="stat-go">Open</span></span><h3><%= taskCount %></h3><p>Total Tasks</p></a>
        <a class="stat-card tone-rose" href="<%= cp %>/admin?action=hrManagement#hrManagement"><span class="stat-top"><span class="stat-icon">👔</span><span class="stat-go">Open</span></span><h3><%= hrCount %></h3><p>HR Team</p></a>
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
            <a class="dashboard-btn" href="<%= cp %>/admin?action=searchTasks&status=PENDING#taskManagement"><strong>⏳ Pending Tasks</strong><span>See pending tasks.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/admin?action=searchTasks&status=IN_PROGRESS#taskManagement"><strong>🔄 In Progress</strong><span>See ongoing tasks.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/admin?action=searchTasks&status=COMPLETED#taskManagement"><strong>✅ Completed Tasks</strong><span>See completed tasks.</span></a>
            <a class="dashboard-btn" href="#managerReviews"><strong>⭐ Manager Reviews</strong><span>Filter reviews by manager and team.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/admin?action=reports&reportType=employees#reports"><strong>📈 Reports</strong><span>Open reports dashboard.</span></a>
        </div>
    </div>

    <!-- EMPLOYEE MANAGEMENT -->
    <div class="section" id="employeeManagement">
        <div class="section-header">
            <div><h2>👥 Employees</h2><p>View employee information. Employees are added and managed by HR.</p></div>
        </div>
        <div class="button-grid">
            <a class="dashboard-btn" href="<%= cp %>/admin?action=viewEmployees#viewEmployees"><strong>👥 View Employees</strong><span>View all registered employees.</span></a>
            <a class="dashboard-btn" href="#searchEmployee"><strong>🔍 Search Employee</strong><span>Search by ID or name.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/admin?action=hrManagement#hrManagement"><strong>👔 Recruit HR</strong><span>Add or deactivate HR users.</span></a>
        </div>
    </div>


    <!-- HR MANAGEMENT (admin recruits HR) -->
<%
    List<AdminServlet.HrData> hrList = (List<AdminServlet.HrData>) request.getAttribute("hrList");
    if (hrList == null) hrList = new ArrayList<AdminServlet.HrData>();
    String hrMsg = request.getParameter("hrMessage");
%>
    <div class="section" id="hrManagement">
        <div class="section-header">
            <div><h2>👔 HR Management</h2><p>Recruit HR users. HR manages employees, teams, tasks, attendance, leaves, payroll and reports.</p></div>
        </div>

        <%
            boolean hrMailOk = "sent".equals(request.getParameter("mail"));
            String hrMailErr = request.getParameter("mailErr");
        %>
        <% if ("recruited".equals(hrMsg) || "resent".equals(hrMsg)) { %>
            <div class="message <%= hrMailOk ? "message-success" : "message-error" %>">
                <%= "recruited".equals(hrMsg) ? "HR user recruited. " : "" %>HR ID: <strong><%= h(request.getParameter("newId")) %></strong>.
                <%= hrMailOk ? "Login ID, password and login link were emailed to the HR."
                             : "The login email could not be sent - use the Resend button in the table below." %>
                <% if (!hrMailOk && hrMailErr != null && !hrMailErr.isEmpty()) { %>
                    <br><small>Reason: <%= h(hrMailErr) %></small>
                <% } %>
            </div>
        <% } else if ("updated".equals(hrMsg)) { %>
            <div class="message message-success">HR status updated.</div>
        <% } else if ("duplicate".equals(hrMsg)) { %>
            <div class="message message-error">An HR user with this email already exists.</div>
        <% } else if ("invalid".equals(hrMsg)) { %>
            <div class="message message-error">Enter a name, a valid email, an optional phone number and a password of at least 6 characters.</div>
        <% } else if ("failed".equals(hrMsg)) { %>
            <div class="message message-error">That action could not be completed. Please try again.</div>
        <% } %>
        <% if (request.getAttribute("hrError") != null) { %>
            <div class="message message-error"><%= h(request.getAttribute("hrError")) %></div>
        <% } %>

        <div style="background:#f8fafc;padding:16px;margin:0 0 18px;border:1px solid #e2e8f0;border-radius:12px">
            <h3 style="margin-bottom:12px;font-size:15px">Recruit HR</h3>
            <form method="post" action="<%= cp %>/admin">
                <input type="hidden" name="action" value="addHr">
                <div class="team-form-grid">
                    <label class="full-width">HR ID
                        <input type="text" value="Will be generated automatically (HR001, HR002, ...)" disabled style="background:#eef2ff;color:#4338ca;font-weight:600">
                    </label>
                    <label>Full Name *<input type="text" name="name" maxlength="100" required></label>
                    <label>Email *<input type="email" name="email" maxlength="100" required></label>
                    <label>Phone<input type="tel" name="phone" maxlength="15"></label>
                    <label>Temporary Password * (min. 6 characters)<input type="password" name="password" minlength="6" required autocomplete="new-password"></label>
                </div>
                <div class="form-actions"><button class="success" type="submit">Recruit HR</button></div>
            </form>
            <div class="small-note" style="margin-top:8px">The HR ID is generated automatically. The HR ID, email, password and the login link are sent to the HR's email automatically.</div>
        </div>

        <div class="table-container">
            <table>
                <thead><tr><th>HR ID</th><th>Name</th><th>Email</th><th>Phone</th><th>Recruited By</th><th>Recruited On</th><th>Status</th><th>Action</th></tr></thead>
                <tbody>
                <% for (AdminServlet.HrData hu : hrList) {
                    boolean hrActive = "ACTIVE".equalsIgnoreCase(hu.status); %>
                    <tr>
                        <td><%= h(hu.hrId) %></td>
                        <td><%= h(hu.name) %></td>
                        <td><%= h(hu.email) %></td>
                        <td><%= h(hu.phone) %></td>
                        <td><%= h(hu.recruitedBy) %></td>
                        <td><%= h(hu.recruitedAt) %></td>
                        <td><span class="status <%= hrActive ? "status-active" : "status-inactive" %>"><%= hrActive ? "ACTIVE" : "INACTIVE" %></span></td>
                        <td>
                            <form method="post" action="<%= cp %>/admin" style="display:inline" onsubmit="return confirm('<%= hrActive ? "Deactivate" : "Activate" %> this HR user?')">
                                <input type="hidden" name="action" value="setHrStatus">
                                <input type="hidden" name="hrId" value="<%= h(hu.hrId) %>">
                                <input type="hidden" name="status" value="<%= hrActive ? "INACTIVE" : "ACTIVE" %>">
                                <button class="<%= hrActive ? "danger" : "success" %>" type="submit"><%= hrActive ? "Deactivate" : "Activate" %></button>
                            </form>
                            <form method="post" action="<%= cp %>/admin" style="display:inline" onsubmit="return confirm('Email the login details to <%= h(hu.email) %> again?')">
                                <input type="hidden" name="action" value="resendHrCredentials">
                                <input type="hidden" name="hrId" value="<%= h(hu.hrId) %>">
                                <button class="primary" type="submit">&#9993; Resend</button>
                            </form>
                        </td>
                    </tr>
                <% } %>
                <% if (hrList.isEmpty()) { %>
                    <tr><td colspan="8" style="text-align:center">No HR users yet. Use the form above to recruit one.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </div>

    <!-- VIEW EMPLOYEES -->
    <div class="section" id="viewEmployees">
        <div class="section-header">
            <div><h2>👥 View Employees</h2><p>All registered employees (view only).</p></div>
            
        </div>
<%
    List<Employe> employeeList = (List<Employe>) request.getAttribute("employeeList");
    if (employeeList == null) employeeList = new ArrayList<Employe>();
    String empMsgView = request.getParameter("empMessage");
%>
        <% if ("created".equals(empMsgView)) { %>
            <div class="message message-success">Employee added successfully.</div>
        <% } %>
        <a class="btn primary" href="<%= cp %>/admin?action=viewEmployees#viewEmployees">Load / Refresh Employee List</a>
        <br><br>

        <div class="table-container">
            <table>
                <thead><tr><th>Employee ID</th><th>Name</th><th>Email</th><th>Phone</th><th>Department</th><th>Designation</th><th>Salary</th><th>Status</th></tr></thead>
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
                    </tr>
                <% } %>
                <% if (employeeList.isEmpty()) { %>
                    <tr><td colspan="8" style="text-align:center">No employees found. Use the link above to load the list.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>

    </div>

    <!-- TASK MANAGEMENT -->
    <div class="section" id="taskManagement">
        <div class="section-header">
            <div><h2>📋 Task Management</h2><p>Search tasks, employee comments and manager reviews.</p></div>
        </div>

        <% if (request.getAttribute("taskError") != null) { %>
            <div class="message message-error"><%= h(request.getAttribute("taskError")) %></div>
        <% } %>
        <% if (request.getParameter("taskMessage") != null) { %>
            <div class="message message-success">Task operation: <%= h(request.getParameter("taskMessage")) %></div>
        <% } %>

        <div class="task-stats">
            <div class="task-stat"><strong><%= taskCount %></strong><span>Total Tasks</span></div>
            <div class="task-stat"><strong><%= pendingCount %></strong><span>Pending</span></div>
            <div class="task-stat"><strong><%= inProgressCount %></strong><span>In Progress</span></div>
            <div class="task-stat"><strong><%= completedCount %></strong><span>Completed</span></div>
        </div>

        <form class="filter-box" method="get" action="<%= cp %>/admin#taskManagement">
            <input type="hidden" name="action" value="searchTasks">
            <input type="text" name="search" value="<%= h(taskSearch) %>" placeholder="Search title, employee ID or department">
            <select name="status" id="taskStatusFilter">
                <option value="ALL" <%= "ALL".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>All Statuses</option>
                <option value="PENDING" <%= "PENDING".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>PENDING</option>
                <option value="IN_PROGRESS" <%= "IN_PROGRESS".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>IN_PROGRESS</option>
                <option value="COMPLETED" <%= "COMPLETED".equalsIgnoreCase(taskStatusFilter) ? "selected" : "" %>>COMPLETED</option>
            </select>
            <button class="primary" type="submit">Search</button>
            <a class="btn neutral" href="<%= cp %>/admin?action=taskManagement#taskManagement">Reset</a>
        </form>

        <div class="table-container">
            <table>
                <thead>
                    <tr><th>ID</th><th>Task</th><th>Assigned Employee</th><th>Department</th><th>Priority</th><th>Start</th><th>Due</th><th>Status</th><th>Employee Comment</th><th>Rating</th><th>Manager Review</th></tr>
                </thead>
                <tbody>
                <% if (tasks.isEmpty()) { %>
                    <tr><td colspan="11" style="text-align:center">No tasks found.</td></tr>
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
                        <td><%= h(task.getStartDate()) %></td>
                        <td><%= h(task.getDueDate()) %></td>
                        <td><span class="status status-<%= h(st.toLowerCase()) %>"><%= h(st) %></span></td>
                        <td><%= task.getEmployeeComment() == null || task.getEmployeeComment().trim().isEmpty() ? "No comment" : h(task.getEmployeeComment()) %></td>
                        <td><%= task.getManagerRating() == null ? "Not rated" : h(task.getManagerRating()) %></td>
                        <td><%= task.getManagerRemarks() == null || task.getManagerRemarks().trim().isEmpty() ? "No manager review" : h(task.getManagerRemarks()) %></td>
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

        <form method="get" action="<%= cp %>/admin#managerReviews" class="filter-box">
            <input type="hidden" name="action" value="taskManagement">
            <label style="flex:1;min-width:220px">Select Manager
                <select name="selectedManager" required onchange="this.form.submit()">
                    <option value="">-- Select Manager --</option>
                    <%
                    try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
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
                        try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
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
                    try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
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

    <!-- TEAMS (view only) -->
    <div class="section" id="manageTeams">
        <div class="section-header">
            <div><h2>🏢 Teams</h2><p>View teams and their members. Teams are created and managed by HR.</p></div>
        </div>

        <div class="table-container">
            <table>
                <thead><tr><th>Team ID</th><th>Team Name</th><th>Department</th><th>Manager</th><th>Status</th><th>Members</th></tr></thead>
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
                        String mn = rs.getString("manager_name");
                        String st = rs.getString("status");
                %>
                    <tr>
                        <td><%= h(tid) %></td>
                        <td><%= h(rs.getString("team_name")) %><div class="small-note"><%= h(rs.getString("description")) %></div></td>
                        <td><%= h(rs.getString("department")) %></td>
                        <td><%= mn == null ? "Not assigned" : h(mn) %><div class="small-note"><%= h(rs.getString("manager_id")) %></div></td>
                        <td><span class="status <%= "ACTIVE".equalsIgnoreCase(st) ? "status-active" : "status-inactive" %>"><%= h(st) %></span></td>
                        <td><button type="button" class="primary" onclick="togglePanel('teamMembers_<%= h(tid) %>')">View Members</button></td>
                    </tr>
                    <tr><td colspan="6" style="padding:0;border:0">
                        <div id="teamMembers_<%= h(tid) %>" class="team-inline-panel">
                            <h3>Members of <%= h(rs.getString("team_name")) %></h3>
                            <table>
                                <thead><tr><th>Employee ID</th><th>Name</th><th>Department</th><th>Designation</th></tr></thead>
                                <tbody>
                                <%
                                boolean membersFound = false;
                                try (PreparedStatement mp = con.prepareStatement(
                                        "SELECT e.employee_id,e.name,e.department,e.designation FROM team_members tm LEFT JOIN employees e ON e.employee_id=tm.employee_id WHERE tm.team_id=? ORDER BY e.name")) {
                                    mp.setString(1, tid);
                                    try (ResultSet mr = mp.executeQuery()) {
                                        while (mr.next()) {
                                            membersFound = true;
                                %>
                                    <tr>
                                        <td><%= h(mr.getString("employee_id")) %></td>
                                        <td><%= h(mr.getString("name")) %></td>
                                        <td><%= h(mr.getString("department")) %></td>
                                        <td><%= h(mr.getString("designation")) %></td>
                                    </tr>
                                <% } } } catch (Exception e) { application.log("Team members error", e); }
                                if (!membersFound) { %>
                                    <tr><td colspan="4" style="text-align:center">No members in this team.</td></tr>
                                <% } %>
                                </tbody>
                            </table>
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
        <form class="search-box" method="get" action="<%= cp %>/admin#searchEmployee">
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
            <a class="dashboard-btn" href="<%= cp %>/admin?action=todayAttendance#attendance"><strong>📅 Today's Attendance</strong><span>View today's saved attendance records.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/admin?action=monthlyAttendance#attendance"><strong>📊 Monthly Attendance</strong><span>View current month's saved records.</span></a>
            <a class="dashboard-btn" href="<%= cp %>/admin?action=reports&reportType=employees#reports"><strong>👥 Employees & Managers Report</strong><span>View employee and manager details.</span></a>
        </div>

        <% if (!attendanceData.isEmpty()) { %>
            <br>
            <div class="table-container">
                <table>
                    <thead><tr><th>Employee ID</th><th>Name</th><th>Date</th><th>Day</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
                    <tbody>
                    <% for (AdminServlet.AttendanceData d : attendanceData) { %>
                        <tr>
                            <td><%= h(d.employeeId) %></td>
                            <td><%= h(d.name) %></td>
                            <td><%= h(d.date) %></td>
                            <td><%
                                String dayName = "";
                                try { dayName = java.time.LocalDate.parse(d.date).getDayOfWeek()
                                        .getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.ENGLISH); }
                                catch (Exception ex) { dayName = ""; }
                                out.print(h(dayName));
                            %></td>
                            <td><%= h(d.checkIn) %></td>
                            <td><%= h(d.checkOut) %></td>
                            <td><%= h(d.status) %></td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>
        <% } %>
    </div>

<%
    List<service.OvertimeService.OtRequest> mgrOtPending =
        (List<service.OvertimeService.OtRequest>) request.getAttribute("mgrOtPending");
    List<service.OvertimeService.OtRequest> mgrOtDecided =
        (List<service.OvertimeService.OtRequest>) request.getAttribute("mgrOtDecided");
    boolean mgrOtLoaded = mgrOtPending != null;
    if (mgrOtPending == null) mgrOtPending = new ArrayList<service.OvertimeService.OtRequest>();
    if (mgrOtDecided == null) mgrOtDecided = new ArrayList<service.OvertimeService.OtRequest>();

    String mgrOtFlash = (String) adminSession.getAttribute("mgrOtFlashMsg");
    String mgrOtFlashOk = (String) adminSession.getAttribute("mgrOtFlashOk");
    adminSession.removeAttribute("mgrOtFlashMsg");
    adminSession.removeAttribute("mgrOtFlashOk");
%>
    <!-- MANAGER OVERTIME -->
    <div class="section" id="managerOvertime">
        <div class="section-header">
            <div>
                <h2>⏱️ Manager Overtime</h2>
                <p>Managers request overtime like employees. You approve or reject it here. On approval the manager's check-out becomes
                   <%= h(service.AttendanceAutoCheckout.CUTOFF) %> plus the OT hours and the OT pay is added to the manager's salary and salary slip.</p>
            </div>
        </div>

        <% if (mgrOtFlash != null) { %>
            <div class="message <%= "1".equals(mgrOtFlashOk) ? "message-success" : "message-error" %>"><%= h(mgrOtFlash) %></div>
        <% } %>
        <% if (request.getAttribute("mgrOtError") != null) { %>
            <div class="message message-error"><%= h(request.getAttribute("mgrOtError")) %></div>
        <% } %>

        <a class="btn primary" href="<%= cp %>/admin?action=managerOvertime#managerOvertime">Load / Refresh Manager Overtime</a>

        <% if (mgrOtLoaded) { %>
            <br><br>
            <h3>Waiting for your approval (<%= mgrOtPending.size() %>)</h3>
            <br>
            <div class="table-container">
                <table>
                    <thead><tr><th>Manager</th><th>Date</th><th>Hours</th><th>New Check-out</th><th>Reason</th><th>Decision</th></tr></thead>
                    <tbody>
                    <% if (mgrOtPending.isEmpty()) { %>
                        <tr><td colspan="6">No pending manager overtime requests.</td></tr>
                    <% }
                       for (service.OvertimeService.OtRequest mgrR : mgrOtPending) { %>
                        <tr>
                            <td><%= h(mgrR.employeeName) %><br><small><%= h(mgrR.employeeId) %></small></td>
                            <td><%= h(mgrR.otDate) %></td>
                            <td><%= h(mgrR.hours.stripTrailingZeros().toPlainString()) %> h</td>
                            <td><%= h(mgrR.checkOutTime) %></td>
                            <td><%= h(mgrR.reason) %></td>
                            <td>
                                <form method="post" action="<%= cp %>/admin" style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin:0">
                                    <input type="hidden" name="action" value="decideManagerOt">
                                    <input type="hidden" name="otId" value="<%= mgrR.id %>">
                                    <input type="text" name="otNote" maxlength="300" placeholder="Note (optional)" style="min-width:150px">
                                    <button type="submit" name="decision" value="approve" class="btn success">Approve</button>
                                    <button type="submit" name="decision" value="reject" class="btn danger"
                                            onclick="return confirm('Reject this overtime request?');">Reject</button>
                                </form>
                            </td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>

            <br>
            <h3>Decided requests</h3>
            <br>
            <div class="table-container">
                <table>
                    <thead><tr><th>Manager</th><th>Date</th><th>Hours</th><th>Status</th><th>Check-out</th><th>Note</th><th>Paid In Salary</th></tr></thead>
                    <tbody>
                    <% if (mgrOtDecided.isEmpty()) { %>
                        <tr><td colspan="7">Nothing decided yet.</td></tr>
                    <% }
                       for (service.OvertimeService.OtRequest mgrR : mgrOtDecided) {
                           String mgrPaidIn = (mgrR.payMonth != null && mgrR.payYear != null && "APPROVED".equals(mgrR.status))
                               ? java.time.Month.of(mgrR.payMonth).getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.ENGLISH) + " " + mgrR.payYear
                               : "-"; %>
                        <tr>
                            <td><%= h(mgrR.employeeName) %><br><small><%= h(mgrR.employeeId) %></small></td>
                            <td><%= h(mgrR.otDate) %></td>
                            <td><%= h(mgrR.hours.stripTrailingZeros().toPlainString()) %> h</td>
                            <td><span class="status status-<%= "APPROVED".equals(mgrR.status) ? "completed" : "rejected" %>"><%= h(mgrR.status) %></span></td>
                            <td><%= "APPROVED".equals(mgrR.status) ? h(mgrR.checkOutTime) : "-" %></td>
                            <td><%= h(mgrR.managerNote == null || mgrR.managerNote.isEmpty() ? "-" : mgrR.managerNote) %></td>
                            <td><%= h(mgrPaidIn) %></td>
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
            <div><h2>📝 Leave Requests</h2><p>Employee and manager leave is approved by HR (view only here). HR leave requests are approved by you - see the table below.</p></div>
        </div>
        <a class="btn primary" href="<%= cp %>/admin?action=viewLeaves#leaveManagement">View Leave Requests</a>

        <% if (!leaveData.isEmpty()) { %>
            <br><br>
            <div class="table-container">
                <table>
                    <thead><tr><th>Leave ID</th><th>Employee</th><th>Leave Type</th><th>From</th><th>To</th><th>Reason</th><th>Status</th></tr></thead>
                    <tbody>
                    <% for (AdminServlet.LeaveData leave : leaveData) { %>
                        <tr>
                            <td><%= h(leave.leaveId) %></td>
                            <td><%= h(leave.name == null ? "" : leave.name) %> <span class="small-note">(<%= h(leave.employeeId) %>)</span></td>
                            <td><%= h(leave.leaveType) %></td>
                            <td><%= h(leave.fromDate) %></td>
                            <td><%= h(leave.toDate) %></td>
                            <td><%= h(leave.reason) %></td>
                            <td><span class="status <%= "APPROVED".equalsIgnoreCase(leave.status) ? "status-completed" : ("REJECTED".equalsIgnoreCase(leave.status) ? "status-rejected" : "status-pending") %>"><%= h(leave.status) %></span></td>
                        </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>
        <% } %>

        <%
            List<AdminServlet.LeaveData> hrLeaveData = (List<AdminServlet.LeaveData>) request.getAttribute("hrLeaveData");
            if (hrLeaveData == null) hrLeaveData = new ArrayList<AdminServlet.LeaveData>();
            String leaveMsg = request.getParameter("leaveMessage");
        %>
        <h3 style="margin:26px 0 10px;font-size:16px">👔 HR Leave Requests <span class="small-note">(you approve or reject these)</span></h3>
        <% if ("approved".equals(leaveMsg)) { %>
            <div class="message message-success">HR leave approved.</div>
        <% } else if ("rejected".equals(leaveMsg)) { %>
            <div class="message message-success">HR leave rejected.</div>
        <% } else if ("notfound".equals(leaveMsg)) { %>
            <div class="message message-error">That request is not a pending HR leave.</div>
        <% } %>
        <% if (request.getAttribute("hrLeaveError") != null) { %>
            <div class="message message-error"><%= h(request.getAttribute("hrLeaveError")) %></div>
        <% } %>
        <div class="table-container">
            <table>
                <thead><tr><th>Leave ID</th><th>HR</th><th>Leave Type</th><th>From</th><th>To</th><th>Reason</th><th>Applied</th><th>Status</th><th>Action</th></tr></thead>
                <tbody>
                <% for (AdminServlet.LeaveData hl : hrLeaveData) { %>
                    <tr>
                        <td><%= h(hl.leaveId) %></td>
                        <td><%= h(hl.name == null ? "" : hl.name) %> <span class="small-note">(<%= h(hl.employeeId) %>)</span></td>
                        <td><%= h(hl.leaveType) %></td>
                        <td><%= h(hl.fromDate) %></td>
                        <td><%= h(hl.toDate) %></td>
                        <td><%= h(hl.reason) %></td>
                        <td><%= h(hl.appliedDate) %></td>
                        <td><span class="status <%= "APPROVED".equalsIgnoreCase(hl.status) ? "status-completed" : ("REJECTED".equalsIgnoreCase(hl.status) ? "status-rejected" : "status-pending") %>"><%= h(hl.status) %></span></td>
                        <td>
                            <% if ("PENDING".equalsIgnoreCase(hl.status)) { %>
                                <form method="post" action="<%= cp %>/admin" style="display:inline">
                                    <input type="hidden" name="action" value="approveHrLeave">
                                    <input type="hidden" name="leaveId" value="<%= h(hl.leaveId) %>">
                                    <button class="success" type="submit">Approve</button>
                                </form>
                                <form method="post" action="<%= cp %>/admin" style="display:inline">
                                    <input type="hidden" name="action" value="rejectHrLeave">
                                    <input type="hidden" name="leaveId" value="<%= h(hl.leaveId) %>">
                                    <button class="danger" type="submit">Reject</button>
                                </form>
                            <% } else { %><span class="small-note">Decided</span><% } %>
                        </td>
                    </tr>
                <% } %>
                <% if (hrLeaveData.isEmpty()) { %>
                    <tr><td colspan="9" style="text-align:center">No HR leave requests. Click "View Leave Requests" above to load them.</td></tr>
                <% } %>
                </tbody>
            </table>
        </div>
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
    String payTab = "history";
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
    String payBase = cp + "/admin?action=payroll&month=" + payMonth + "&year=" + payYear;
    String payToday = java.time.LocalDate.now().toString();
    String payPeriodLabel = (payMonth < 10 ? "0" : "") + payMonth + "/" + payYear;
%>
    <div class="section" id="payroll">
        <div class="payroll-pagebar">
            <div class="reports-crumb">Dashboard &rsaquo; <b>Payroll</b></div>
            <a class="reports-back" href="<%= cp %>/admin">&larr; Back to Dashboard</a>
        </div>

        <div class="section-header">
            <div>
                <h2>Payroll Reports</h2>
                <p>Payroll history, reports and salary slips (view only). Payroll is processed by HR.</p>
            </div>
        </div>

        <div class="ph-tabs">
            <a class="active" href="<%= h(payBase + "&tab=history#payroll") %>">&#128337; Payroll History &amp; Reports</a>
        </div>

        <% if (payMsg != null && !payMsg.isEmpty()) { %>
            <div class="message message-success"><%= h(payMsg) %></div>
        <% } %>
        <% if (payErr != null && !payErr.isEmpty()) { %>
            <div class="message message-error"><%= h(payErr) %></div>
        <% } %>

<% if (false) { %>
        <form method="get" action="<%= cp %>/admin#payroll" class="ph-period">
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

<% { %>
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

        <form method="get" action="<%= cp %>/admin#payroll" class="ph-filter">
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
            <a class="btn neutral" href="<%= cp %>/admin?action=payroll&tab=history&personType=ALL#payroll">Reset</a>
            <a class="btn success" href="<%= h(cp + "/admin?action=payrollCsv" + hQs) %>">&#11015; Download CSV</a>
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
                                <a class="ph-mini" target="_blank" rel="noopener" href="<%= cp %>/admin?action=salarySlip&payrollId=<%= pr.getId() %>">&#128196; Slip</a>
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
        <a class="reports-back" href="<%= cp %>/admin">&larr; Back to Dashboard</a>
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
                cp + "/admin?action=reports&reportType=employees&personType=" + personType + rpdSearchQs + "#reports",
                cp + "/admin#reports",
                cp + "/admin?action=reports&reportType=employees&reportPerson="
                    + java.net.URLEncoder.encode(rpdPerson, "UTF-8") + "&personKind=" + rpdKind + "#reports",
                new String[][]{{"action","reports"},{"reportType","employees"},{"personType", personType},{"reportSearch", reportSearch},
                               {"reportPerson", rpdPerson},{"personKind", rpdKind}},
                "fromDate", "toDate",
                cp + "/admin?action=personAttendance&reportPerson="
                    + java.net.URLEncoder.encode(rpdPerson, "UTF-8") + "&personKind=" + rpdKind) %>
<% } else { %>
        <form method="get" action="<%= cp %>/admin#reports" class="people-filter">
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
                <a class="btn neutral" href="<%= cp %>/admin?action=reports&reportType=employees#reports">Reset</a>
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
                    <% for (AdminServlet.ReportRow r : reportRows) {
                        String personStatus = r.five == null ? "INACTIVE" : r.five.trim().toUpperCase();
                        if (!"ACTIVE".equals(personStatus)) personStatus = "INACTIVE";
                    %>
                        <%
                            String rowKind = "MANAGER".equalsIgnoreCase(r.six) ? "MANAGER" : "EMPLOYEE";
                            String rowLink = cp + "/admin?action=reports&reportType=employees&reportPerson="
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

<%@ include file="/WEB-INF/admin/_sys_embed.jspf" %>
</div>
</div>
</body>
</html>
