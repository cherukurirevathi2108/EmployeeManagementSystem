<%@ page pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<%@ page import="java.sql.*,java.util.*" %>
<%!
    private String rpdEsc(Object v) {
        if (v == null) return "";
        return String.valueOf(v).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
    private String rpdCls(String s) {
        if (s == null) return "pending";
        String u = s.trim().toUpperCase();
        if (u.equals("ACTIVE") || u.equals("COMPLETED") || u.equals("APPROVED") || u.equals("PRESENT")) return "completed";
        if (u.equals("IN_PROGRESS")) return "progress";
        if (u.equals("INACTIVE") || u.equals("REJECTED") || u.equals("ABSENT")) return "rejected";
        return "pending";
    }
    private String rpdBadge(String s) {
        String t = (s == null || s.trim().isEmpty()) ? "-" : s.replace("_", " ");
        return "<span class=\"status status-" + rpdCls(s) + " rpd-status\">" + rpdEsc(t) + "</span>";
    }
%>
<%
    /*
     * Shared "single person" report (details, attendance, leaves, tasks, teams).
     * Included from the admin and manager dashboards. It only runs when the
     * calling dashboard (server side) sets rpdAllowed = TRUE, so it cannot be
     * opened directly by URL (it also lives under WEB-INF).
     * rpdScopeManagerId != null  => manager view: person must be an ACTIVE member
     *                               of one of that manager's ACTIVE teams.
     */
    if (!Boolean.TRUE.equals(request.getAttribute("rpdAllowed"))) { return; }

    String pid = String.valueOf(request.getAttribute("rpdPersonId"));
    String ptype = "MANAGER".equalsIgnoreCase(String.valueOf(request.getAttribute("rpdPersonType")))
        ? "MANAGER" : "EMPLOYEE";
    String scopeMgr = request.getAttribute("rpdScopeManagerId") == null
        ? null : String.valueOf(request.getAttribute("rpdScopeManagerId"));
    String backUrl = String.valueOf(request.getAttribute("rpdBackUrl"));
    String fromStr = request.getAttribute("rpdFrom") == null ? "" : String.valueOf(request.getAttribute("rpdFrom"));
    String toStr = request.getAttribute("rpdTo") == null ? "" : String.valueOf(request.getAttribute("rpdTo"));

    java.time.LocalDate today = java.time.LocalDate.now();
    java.time.LocalDate dFrom = null, dTo = null;
    try { if (!fromStr.isEmpty()) dFrom = java.time.LocalDate.parse(fromStr); } catch (Exception e) { dFrom = null; }
    try { if (!toStr.isEmpty()) dTo = java.time.LocalDate.parse(toStr); } catch (Exception e) { dTo = null; }
    boolean userRange = dFrom != null || dTo != null;
    if (dFrom == null && dTo == null) { dFrom = today.withDayOfMonth(1); dTo = today; }
    else if (dFrom == null) { dFrom = dTo; }
    else if (dTo == null) { dTo = today; }
    if (dFrom.isAfter(dTo)) { java.time.LocalDate sw = dFrom; dFrom = dTo; dTo = sw; }

    String name = "", email = "", dept = "", desig = "", status = "";
    boolean found = false, allowed = true;
    List<String[]> attRows = new ArrayList<String[]>();
    List<String[]> leaveRows = new ArrayList<String[]>();
    List<String[]> taskRows = new ArrayList<String[]>();
    List<String[]> teamRows = new ArrayList<String[]>();
    String error = null;
    int present = 0, absent = 0, onLeave = 0;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        try (Connection con = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/employee_db", "root", "root")) {

            /* ---- scope check (manager can only open own team members) ---- */
            if (scopeMgr != null) {
                allowed = false;
                if ("EMPLOYEE".equals(ptype)) {
                    try (PreparedStatement ps = con.prepareStatement(
                            "SELECT COUNT(*) FROM teams t JOIN team_members tm ON tm.team_id=t.team_id " +
                            "AND tm.status='ACTIVE' WHERE t.manager_id=? AND t.status='ACTIVE' AND tm.employee_id=?")) {
                        ps.setString(1, scopeMgr);
                        ps.setString(2, pid);
                        try (ResultSet rs = ps.executeQuery()) { if (rs.next()) allowed = rs.getInt(1) > 0; }
                    }
                }
            }

            if (allowed) {
                /* ---- 1. details ---- */
                String table = "MANAGER".equals(ptype) ? "managers" : "employees";
                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT employee_id,name,email,department,designation,status FROM " + table + " WHERE employee_id=?")) {
                    ps.setString(1, pid);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            found = true;
                            name = rs.getString("name") == null ? "" : rs.getString("name");
                            email = rs.getString("email") == null ? "" : rs.getString("email");
                            dept = rs.getString("department") == null ? "" : rs.getString("department");
                            desig = rs.getString("designation") == null ? "" : rs.getString("designation");
                            String st = rs.getString("status");
                            status = (st != null && "ACTIVE".equalsIgnoreCase(st.trim())) ? "ACTIVE" : "INACTIVE";
                        }
                    }
                }

                if (found) {
                    /* ---- 2. attendance (Mon-Fri, like the main report) ---- */
                    try (PreparedStatement aps = con.prepareStatement(
                            "SELECT check_in_time,check_out_time,status FROM attendance " +
                            "WHERE employee_id=? AND `date`=? ORDER BY attendance_id DESC LIMIT 1");
                         PreparedStatement lps = con.prepareStatement(
                            "SELECT COUNT(*) FROM leave_requests WHERE employee_id=? " +
                            "AND UPPER(status)='APPROVED' AND from_date<=? AND to_date>=?")) {
                        java.time.LocalDate d = dFrom;
                        while (!d.isAfter(dTo)) {
                            java.time.DayOfWeek dow = d.getDayOfWeek();
                            if (dow != java.time.DayOfWeek.SATURDAY && dow != java.time.DayOfWeek.SUNDAY) {
                                java.sql.Date sd = java.sql.Date.valueOf(d);
                                String cin = "-", cout = "-", ast = null;
                                boolean hasAtt = false, leave = false;
                                aps.setString(1, pid); aps.setDate(2, sd);
                                try (ResultSet rs = aps.executeQuery()) {
                                    if (rs.next()) {
                                        hasAtt = true;
                                        java.sql.Time ti = rs.getTime("check_in_time");
                                        java.sql.Time to = rs.getTime("check_out_time");
                                        cin = ti == null ? "-" : ti.toString();
                                        cout = to == null ? "-" : to.toString();
                                        ast = rs.getString("status");
                                    }
                                }
                                lps.setString(1, pid); lps.setDate(2, sd); lps.setDate(3, sd);
                                try (ResultSet rs = lps.executeQuery()) { if (rs.next()) leave = rs.getInt(1) > 0; }

                                if (hasAtt) {
                                    if (ast == null || ast.trim().isEmpty()) ast = "-".equals(cin) ? "ABSENT" : "PRESENT";
                                } else if (leave) ast = "LEAVE";
                                else ast = "ABSENT";

                                if (!(d.isAfter(today) && !hasAtt)) {
                                    attRows.add(new String[]{d.toString(), cin, cout, ast});
                                    if ("PRESENT".equalsIgnoreCase(ast)) present++;
                                    else if ("ABSENT".equalsIgnoreCase(ast)) absent++;
                                    else if ("LEAVE".equalsIgnoreCase(ast)) onLeave++;
                                }
                            }
                            d = d.plusDays(1);
                        }
                        Collections.reverse(attRows);   // newest first
                    }

                    /* ---- 3. leaves (applied date in range when a range was chosen) ---- */
                    StringBuilder ls = new StringBuilder(
                        "SELECT leave_id,leave_type,from_date,to_date,reason,status,applied_date " +
                        "FROM leave_requests WHERE employee_id=? ");
                    if (userRange) ls.append("AND DATE(applied_date)>=? AND DATE(applied_date)<=? ");
                    ls.append("ORDER BY applied_date DESC");
                    try (PreparedStatement ps = con.prepareStatement(ls.toString())) {
                        ps.setString(1, pid);
                        if (userRange) { ps.setDate(2, java.sql.Date.valueOf(dFrom)); ps.setDate(3, java.sql.Date.valueOf(dTo)); }
                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                leaveRows.add(new String[]{rs.getString("leave_id"),
                                    rs.getString("leave_type") == null ? "" : rs.getString("leave_type"),
                                    String.valueOf(rs.getDate("from_date")), String.valueOf(rs.getDate("to_date")),
                                    rs.getString("reason") == null ? "" : rs.getString("reason"),
                                    rs.getString("status") == null ? "" : rs.getString("status"),
                                    String.valueOf(rs.getTimestamp("applied_date"))});
                            }
                        }
                    }

                    /* ---- 4. tasks (start date in range when a range was chosen) ---- */
                    StringBuilder ts = new StringBuilder(
                        "SELECT id,task_title,assigned_to,created_by,priority,start_date,due_date,status FROM tasks WHERE ");
                    ts.append("MANAGER".equals(ptype) ? "(assigned_to=? OR created_by=?) " : "assigned_to=? ");
                    if (userRange) ts.append("AND start_date>=? AND start_date<=? ");
                    ts.append("ORDER BY start_date DESC, id DESC");
                    try (PreparedStatement ps = con.prepareStatement(ts.toString())) {
                        int p = 1;
                        ps.setString(p++, pid);
                        if ("MANAGER".equals(ptype)) ps.setString(p++, pid);
                        if (userRange) { ps.setDate(p++, java.sql.Date.valueOf(dFrom)); ps.setDate(p++, java.sql.Date.valueOf(dTo)); }
                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                taskRows.add(new String[]{String.valueOf(rs.getInt("id")),
                                    rs.getString("task_title") == null ? "" : rs.getString("task_title"),
                                    rs.getString("assigned_to") == null ? "" : rs.getString("assigned_to"),
                                    rs.getString("created_by") == null ? "" : rs.getString("created_by"),
                                    rs.getString("priority") == null ? "" : rs.getString("priority"),
                                    rs.getDate("start_date") == null ? "" : String.valueOf(rs.getDate("start_date")),
                                    rs.getDate("due_date") == null ? "" : String.valueOf(rs.getDate("due_date")),
                                    rs.getString("status") == null ? "ASSIGNED" : rs.getString("status")});
                            }
                        }
                    }

                    /* ---- 5. teams ---- */
                    String teamSql;
                    if ("MANAGER".equals(ptype)) {
                        teamSql = "SELECT t.team_id,t.team_name,t.department,t.status,'Manager' AS role_in_team," +
                            "(SELECT COUNT(*) FROM team_members x WHERE x.team_id=t.team_id AND x.status='ACTIVE') AS cnt " +
                            "FROM teams t WHERE t.manager_id=? ORDER BY t.team_name";
                    } else {
                        teamSql = "SELECT t.team_id,t.team_name,t.department,t.status,'Member' AS role_in_team," +
                            "(SELECT COUNT(*) FROM team_members x WHERE x.team_id=t.team_id AND x.status='ACTIVE') AS cnt " +
                            "FROM teams t JOIN team_members tm ON tm.team_id=t.team_id " +
                            "WHERE tm.employee_id=? AND tm.status='ACTIVE' ORDER BY t.team_name";
                    }
                    try (PreparedStatement ps = con.prepareStatement(teamSql)) {
                        ps.setString(1, pid);
                        try (ResultSet rs = ps.executeQuery()) {
                            while (rs.next()) {
                                teamRows.add(new String[]{rs.getString("team_id"),
                                    rs.getString("team_name") == null ? "" : rs.getString("team_name"),
                                    rs.getString("department") == null ? "" : rs.getString("department"),
                                    rs.getString("role_in_team"), String.valueOf(rs.getInt("cnt")),
                                    rs.getString("status") == null ? "" : rs.getString("status")});
                            }
                        }
                    }
                }
            }
        }
    } catch (Exception ex) {
        application.log("Person report loading error", ex);
        error = "Unable to load this report. Please check the server log for details.";
    }
%>
<style>
.rpd-back{display:inline-block;margin-bottom:14px;padding:8px 14px;border-radius:8px;background:#fff;border:1px solid #cbd5e1;color:#1e293b;text-decoration:none;font-weight:600;font-size:13px}
.rpd-back:hover{background:#f1f5f9}
.rpd-datebar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:0 0 16px;padding:12px;border:1px solid #e2e8f0;border-radius:10px;background:#f8fafc}
.rpd-datebar label{font-size:12px;font-weight:600;color:#475569;display:flex;gap:6px;align-items:center}
.rpd-card{border:1px solid #dbeafe;background:#f8fbff;border-radius:11px;padding:18px;margin-bottom:20px}
.rpd-card h3{font-size:18px;color:#0f172a;margin:0 0 4px}
.rpd-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:12px}
.rpd-grid div{font-size:13px;color:#334155;word-break:break-word}
.rpd-grid b{display:block;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.4px;margin-bottom:2px}
.rpd-sum{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:0 0 12px}
.rpd-sum div{background:#f1f5f9;border-radius:8px;padding:10px;text-align:center;font-size:12px;color:#475569}
.rpd-sum strong{display:block;font-size:20px;color:#0f172a}
.rpd-h{margin:24px 0 10px;font-size:16px;color:#0f172a}
.rpd-empty{text-align:center;color:#64748b;padding:18px}
.rpd-scroll{overflow-x:auto}
.rpd-scroll table{width:100%;border-collapse:collapse;min-width:720px}
.rpd-scroll th,.rpd-scroll td{padding:10px 12px;border-bottom:1px solid #e2e8f0;text-align:left;font-size:13px}
.rpd-scroll th{background:#f8fafc;color:#475569;font-size:12px}
.rpd-status{display:inline-block;padding:4px 10px;border-radius:20px;font-size:11px;font-weight:700;white-space:nowrap}
.rpd-status.status-completed{background:#dcfce7;color:#166534}
.rpd-status.status-pending{background:#fef3c7;color:#92400e}
.rpd-status.status-progress{background:#dbeafe;color:#1d4ed8}
.rpd-status.status-rejected{background:#fee2e2;color:#991b1b}
@media(max-width:760px){.rpd-grid,.rpd-sum{grid-template-columns:1fr 1fr}}
</style>

<%
    String formAction = String.valueOf(request.getAttribute("rpdFormAction"));
    String[][] hidden = (String[][]) request.getAttribute("rpdHidden");
    String fromName = String.valueOf(request.getAttribute("rpdFromName"));
    String toName = String.valueOf(request.getAttribute("rpdToName"));
%>
<a class="rpd-back" href="<%= rpdEsc(backUrl) %>">&larr; Back to all <%= "MANAGER".equals(ptype) ? "people" : "employees" %></a>
<form method="get" action="<%= rpdEsc(formAction) %>" class="rpd-datebar">
    <% if (hidden != null) { for (String[] hv : hidden) { %>
        <input type="hidden" name="<%= rpdEsc(hv[0]) %>" value="<%= rpdEsc(hv[1]) %>">
    <% } } %>
    <label>From <input type="date" name="<%= rpdEsc(fromName) %>" value="<%= rpdEsc(fromStr) %>"></label>
    <label>To <input type="date" name="<%= rpdEsc(toName) %>" value="<%= rpdEsc(toStr) %>"></label>
    <button type="submit" class="btn">Apply dates</button>
    <a class="rpd-back" style="margin:0" href="<%= rpdEsc(String.valueOf(request.getAttribute("rpdClearUrl"))) %>">Clear dates</a>
    <span style="font-size:11px;color:#64748b;">Attendance defaults to this month; tasks use start date, leaves use applied date.</span>
</form>

<% if (error != null) { %>
    <div class="message message-error"><%= rpdEsc(error) %></div>
<% } else if (!allowed) { %>
    <div class="message message-error">You can only view reports for active members of your own teams.</div>
<% } else if (!found) { %>
    <div class="message message-error"><%= "MANAGER".equals(ptype) ? "Manager" : "Employee" %> not found.</div>
<% } else { %>

<div class="rpd-card">
    <h3>👤 <%= rpdEsc(name) %> <%= rpdBadge(status) %></h3>
    <span style="font-size:12px;color:#64748b;"><%= "MANAGER".equals(ptype) ? "Manager" : "Employee" %> report</span>
    <div class="rpd-grid">
        <div><b>ID</b><%= rpdEsc(pid) %></div>
        <div><b>Email</b><%= rpdEsc(email) %></div>
        <div><b>Department</b><%= rpdEsc(dept) %></div>
        <div><b>Designation</b><%= rpdEsc(desig) %></div>
        <div><b>Role</b><%= "MANAGER".equals(ptype) ? "Manager" : "Employee" %></div>
        <div><b>Status</b><%= rpdEsc(status) %></div>
    </div>
</div>

<h3 class="rpd-h">🕒 Attendance Report <span style="font-size:12px;font-weight:400;color:#64748b;">(<%= dFrom %> to <%= dTo %>, Mon–Fri)</span></h3>
<div class="rpd-sum">
    <div><strong><%= attRows.size() %></strong>Days</div>
    <div><strong><%= present %></strong>Present</div>
    <div><strong><%= absent %></strong>Absent</div>
    <div><strong><%= onLeave %></strong>Leave</div>
</div>
<div class="rpd-scroll"><table>
    <thead><tr><th>Date</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead>
    <tbody>
    <% if (attRows.isEmpty()) { %><tr><td colspan="4" class="rpd-empty">No attendance records for this range.</td></tr><% } %>
    <% for (String[] r : attRows) { %>
        <tr><td><%= rpdEsc(r[0]) %></td><td><%= rpdEsc(r[1]) %></td><td><%= rpdEsc(r[2]) %></td><td><%= rpdBadge(r[3]) %></td></tr>
    <% } %>
    </tbody></table></div>

<h3 class="rpd-h">📄 Leave Report</h3>
<div class="rpd-scroll"><table>
    <thead><tr><th>Leave ID</th><th>Type</th><th>From</th><th>To</th><th>Reason</th><th>Status</th><th>Applied</th></tr></thead>
    <tbody>
    <% if (leaveRows.isEmpty()) { %><tr><td colspan="7" class="rpd-empty">No leave requests found.</td></tr><% } %>
    <% for (String[] r : leaveRows) { %>
        <tr><td><%= rpdEsc(r[0]) %></td><td><%= rpdEsc(r[1]) %></td><td><%= rpdEsc(r[2]) %></td><td><%= rpdEsc(r[3]) %></td>
            <td><%= rpdEsc(r[4]) %></td><td><%= rpdBadge(r[5]) %></td><td><%= rpdEsc(r[6]) %></td></tr>
    <% } %>
    </tbody></table></div>

<h3 class="rpd-h">📋 Task Report</h3>
<div class="rpd-scroll"><table>
    <thead><tr><th>Task ID</th><th>Title</th><th>Assigned To</th><th>Created By</th><th>Priority</th><th>Start</th><th>Due</th><th>Status</th></tr></thead>
    <tbody>
    <% if (taskRows.isEmpty()) { %><tr><td colspan="8" class="rpd-empty">No tasks found.</td></tr><% } %>
    <% for (String[] r : taskRows) { %>
        <tr><td><%= rpdEsc(r[0]) %></td><td><%= rpdEsc(r[1]) %></td><td><%= rpdEsc(r[2]) %></td><td><%= rpdEsc(r[3]) %></td>
            <td><%= rpdEsc(r[4]) %></td><td><%= rpdEsc(r[5]) %></td><td><%= rpdEsc(r[6]) %></td><td><%= rpdBadge(r[7]) %></td></tr>
    <% } %>
    </tbody></table></div>

<h3 class="rpd-h">👥 Team Report</h3>
<div class="rpd-scroll"><table>
    <thead><tr><th>Team ID</th><th>Team Name</th><th>Department</th><th>Role</th><th>Active Members</th><th>Status</th></tr></thead>
    <tbody>
    <% if (teamRows.isEmpty()) { %><tr><td colspan="6" class="rpd-empty">Not part of any team.</td></tr><% } %>
    <% for (String[] r : teamRows) { %>
        <tr><td><%= rpdEsc(r[0]) %></td><td><%= rpdEsc(r[1]) %></td><td><%= rpdEsc(r[2]) %></td><td><%= rpdEsc(r[3]) %></td>
            <td><%= rpdEsc(r[4]) %></td><td><%= rpdBadge(r[5]) %></td></tr>
    <% } %>
    </tbody></table></div>
<% } %>
