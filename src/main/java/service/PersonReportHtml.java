package service;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Builds the single-person report (details, attendance, leaves, tasks, teams)
 * as an HTML string. Used by the admin and manager dashboards.
 *
 * scopeManagerId == null  -> admin view (any employee / manager)
 * scopeManagerId != null  -> manager view: the person must be an ACTIVE member
 *                            of one of that manager's ACTIVE teams.
 */
public class PersonReportHtml {

    private static final String URL = "jdbc:mysql://localhost:3306/employee_db";
    private static final String USER = "root";
    private static final String PASSWORD = "root";

    private static String esc(Object v) {
        if (v == null) return "";
        return String.valueOf(v).replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }

    private static String cls(String s) {
        if (s == null) return "pending";
        String u = s.trim().toUpperCase();
        if (u.equals("ACTIVE") || u.equals("COMPLETED") || u.equals("APPROVED") || u.equals("PRESENT")) return "completed";
        if (u.equals("IN_PROGRESS")) return "progress";
        if (u.equals("INACTIVE") || u.equals("REJECTED") || u.equals("ABSENT")) return "rejected";
        return "pending";
    }

    private static String badge(String s) {
        if ("WEEKEND".equals(s)) return "<span class=\"rpd-status\" style=\"background:#f1f5f9;color:#64748b\">WEEKEND</span>";
        String t = (s == null || s.trim().isEmpty()) ? "-" : s.replace("_", " ");
        return "<span class=\"rpd-status rpd-" + cls(s) + "\">" + esc(t) + "</span>";
    }

    private static String nz(String s) { return s == null ? "" : s; }

    public static String render(String personId, String personType, String scopeManagerId,
                                String fromStr, String toStr, String backUrl,
                                String formAction, String clearUrl, String[][] hidden,
                                String fromName, String toName) {
        return render(personId, personType, scopeManagerId, fromStr, toStr, backUrl,
                formAction, clearUrl, hidden, fromName, toName, null);
    }

    /**
     * attendanceBaseUrl (optional): when given, "View" and "Download" buttons are shown
     * for the attendance report. It must already contain the person parameters, e.g.
     * /admin?action=personAttendance&reportPerson=E1&personKind=EMPLOYEE
     */
    public static String render(String personId, String personType, String scopeManagerId,
                                String fromStr, String toStr, String backUrl,
                                String formAction, String clearUrl, String[][] hidden,
                                String fromName, String toName, String attendanceBaseUrl) {
        return render(personId, personType, scopeManagerId, fromStr, toStr, backUrl,
                formAction, clearUrl, hidden, fromName, toName, attendanceBaseUrl, null);
    }

    /** attendanceDay (yyyy-MM-dd, optional): the single day shown in Attendance until From/To are chosen. */
    public static String render(String personId, String personType, String scopeManagerId,
                                String fromStr, String toStr, String backUrl,
                                String formAction, String clearUrl, String[][] hidden,
                                String fromName, String toName, String attendanceBaseUrl,
                                String attendanceDay) {

        String pid = personId == null ? "" : personId.trim();
        String ptype = "MANAGER".equalsIgnoreCase(personType) ? "MANAGER" : "EMPLOYEE";
        fromStr = fromStr == null ? "" : fromStr;
        toStr = toStr == null ? "" : toStr;

        LocalDate today = LocalDate.now();
        LocalDate dFrom = null, dTo = null;
        try { if (!fromStr.isEmpty()) dFrom = LocalDate.parse(fromStr); } catch (Exception e) { dFrom = null; }
        try { if (!toStr.isEmpty()) dTo = LocalDate.parse(toStr); } catch (Exception e) { dTo = null; }
        boolean userRange = dFrom != null || dTo != null;
        if (dFrom == null && dTo == null) {
            LocalDate day = today;
            try { if (attendanceDay != null && !attendanceDay.trim().isEmpty()) day = LocalDate.parse(attendanceDay.trim()); }
            catch (Exception e) { day = today; }
            dFrom = day; dTo = day;
        }
        else if (dFrom == null) { dFrom = dTo; }
        else if (dTo == null) { dTo = today; }
        if (dFrom.isAfter(dTo)) { LocalDate sw = dFrom; dFrom = dTo; dTo = sw; }

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
            try (Connection con = DriverManager.getConnection(URL, USER, PASSWORD)) {

                if (scopeManagerId != null) {
                    allowed = false;
                    if ("EMPLOYEE".equals(ptype)) {
                        try (PreparedStatement ps = con.prepareStatement(
                                "SELECT COUNT(*) FROM teams t JOIN team_members tm ON tm.team_id=t.team_id "
                                + "AND tm.status='ACTIVE' WHERE t.manager_id=? AND t.status='ACTIVE' AND tm.employee_id=?")) {
                            ps.setString(1, scopeManagerId);
                            ps.setString(2, pid);
                            try (ResultSet rs = ps.executeQuery()) {
                                if (rs.next()) allowed = rs.getInt(1) > 0;
                            }
                        }
                    }
                }

                if (allowed) {
                    String table = "MANAGER".equals(ptype) ? "managers" : "employees";
                    try (PreparedStatement ps = con.prepareStatement(
                            "SELECT employee_id,name,email,department,designation,status FROM "
                            + table + " WHERE employee_id=?")) {
                        ps.setString(1, pid);
                        try (ResultSet rs = ps.executeQuery()) {
                            if (rs.next()) {
                                found = true;
                                name = nz(rs.getString("name"));
                                email = nz(rs.getString("email"));
                                dept = nz(rs.getString("department"));
                                desig = nz(rs.getString("designation"));
                                String st = rs.getString("status");
                                status = (st != null && "ACTIVE".equalsIgnoreCase(st.trim())) ? "ACTIVE" : "INACTIVE";
                            }
                        }
                    }

                    if (found) {
                        // ---- attendance (Mon-Fri) ----
                        int[] cnt = loadAttendance(con, pid, dFrom, dTo, today, attRows);
                        present = cnt[0];
                        absent = cnt[1];
                        onLeave = cnt[2];

                        // ---- leaves ----
                        StringBuilder ls = new StringBuilder(
                                "SELECT leave_id,leave_type,from_date,to_date,reason,status,applied_date "
                                + "FROM leave_requests WHERE employee_id=? ");
                        if (userRange) ls.append("AND DATE(applied_date)>=? AND DATE(applied_date)<=? ");
                        ls.append("ORDER BY applied_date DESC");
                        try (PreparedStatement ps = con.prepareStatement(ls.toString())) {
                            ps.setString(1, pid);
                            if (userRange) {
                                ps.setDate(2, java.sql.Date.valueOf(dFrom));
                                ps.setDate(3, java.sql.Date.valueOf(dTo));
                            }
                            try (ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                                    leaveRows.add(new String[]{nz(rs.getString("leave_id")),
                                        nz(rs.getString("leave_type")),
                                        String.valueOf(rs.getDate("from_date")),
                                        String.valueOf(rs.getDate("to_date")),
                                        nz(rs.getString("reason")),
                                        nz(rs.getString("status")),
                                        String.valueOf(rs.getTimestamp("applied_date"))});
                                }
                            }
                        }

                        // ---- tasks ----
                        StringBuilder ts = new StringBuilder(
                                "SELECT id,task_title,assigned_to,created_by,priority,start_date,due_date,status "
                                + "FROM tasks WHERE ");
                        ts.append("MANAGER".equals(ptype) ? "(assigned_to=? OR created_by=?) " : "assigned_to=? ");
                        if (userRange) ts.append("AND start_date>=? AND start_date<=? ");
                        ts.append("ORDER BY start_date DESC, id DESC");
                        try (PreparedStatement ps = con.prepareStatement(ts.toString())) {
                            int p = 1;
                            ps.setString(p++, pid);
                            if ("MANAGER".equals(ptype)) ps.setString(p++, pid);
                            if (userRange) {
                                ps.setDate(p++, java.sql.Date.valueOf(dFrom));
                                ps.setDate(p++, java.sql.Date.valueOf(dTo));
                            }
                            try (ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                                    String tstatus = rs.getString("status");
                                    taskRows.add(new String[]{String.valueOf(rs.getInt("id")),
                                        nz(rs.getString("task_title")),
                                        nz(rs.getString("assigned_to")),
                                        nz(rs.getString("created_by")),
                                        nz(rs.getString("priority")),
                                        rs.getDate("start_date") == null ? "" : String.valueOf(rs.getDate("start_date")),
                                        rs.getDate("due_date") == null ? "" : String.valueOf(rs.getDate("due_date")),
                                        tstatus == null ? "ASSIGNED" : tstatus});
                                }
                            }
                        }

                        // ---- teams ----
                        String teamSql;
                        if ("MANAGER".equals(ptype)) {
                            teamSql = "SELECT t.team_id,t.team_name,t.department,t.status,'Manager' AS role_in_team,"
                                + "(SELECT COUNT(*) FROM team_members x WHERE x.team_id=t.team_id AND x.status='ACTIVE') AS cnt "
                                + "FROM teams t WHERE t.manager_id=? ORDER BY t.team_name";
                        } else {
                            teamSql = "SELECT t.team_id,t.team_name,t.department,t.status,'Member' AS role_in_team,"
                                + "(SELECT COUNT(*) FROM team_members x WHERE x.team_id=t.team_id AND x.status='ACTIVE') AS cnt "
                                + "FROM teams t JOIN team_members tm ON tm.team_id=t.team_id "
                                + "WHERE tm.employee_id=? AND tm.status='ACTIVE' ORDER BY t.team_name";
                        }
                        try (PreparedStatement ps = con.prepareStatement(teamSql)) {
                            ps.setString(1, pid);
                            try (ResultSet rs = ps.executeQuery()) {
                                while (rs.next()) {
                                    teamRows.add(new String[]{nz(rs.getString("team_id")),
                                        nz(rs.getString("team_name")),
                                        nz(rs.getString("department")),
                                        rs.getString("role_in_team"),
                                        String.valueOf(rs.getInt("cnt")),
                                        nz(rs.getString("status"))});
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            ex.printStackTrace();
            error = "Unable to load this report. Please check the server log for details.";
        }

        // ===================== HTML =====================
        StringBuilder h = new StringBuilder();
        String roleLabel = "MANAGER".equals(ptype) ? "Manager" : "Employee";

        h.append("<style>")
         .append(".rpd-back{display:inline-block;margin-bottom:14px;padding:8px 14px;border-radius:8px;background:#fff;border:1px solid #cbd5e1;color:#1e293b;text-decoration:none;font-weight:600;font-size:13px}")
         .append(".rpd-back:hover{background:#f1f5f9}")
         .append(".rpd-datebar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:0 0 16px;padding:12px;border:1px solid #e2e8f0;border-radius:10px;background:#f8fafc}")
         .append(".rpd-datebar label{font-size:12px;font-weight:600;color:#475569;display:flex;gap:6px;align-items:center}")
         .append(".rpd-datebar button{padding:8px 14px;border:0;border-radius:8px;background:#2563eb;color:#fff;font-weight:600;cursor:pointer}")
         .append(".rpd-card{border:1px solid #e2e8f0;background:#fff;border-radius:14px;padding:20px;margin-bottom:18px;box-shadow:0 1px 2px rgba(15,23,42,.05),0 6px 18px rgba(15,23,42,.04)}")
         .append(".rpd-head{display:flex;align-items:center;gap:14px}")
         .append(".rpd-avatar{width:52px;height:52px;border-radius:14px;background:linear-gradient(135deg,#6366f1,#4338ca);color:#fff;font-size:22px;font-weight:700;display:flex;align-items:center;justify-content:center;flex:none}")
         .append(".rpd-sub{font-size:12.5px;color:#64748b}")
         .append(".rpd-tabs{display:flex;gap:6px;background:#f1f5f9;padding:5px;border-radius:12px;margin-bottom:16px;overflow-x:auto}")
         .append(".rpd-tab{border:0;background:transparent;padding:10px 16px;border-radius:9px;font-size:13px;font-weight:600;color:#475569;cursor:pointer;white-space:nowrap;display:flex;align-items:center;gap:7px}")
         .append(".rpd-tab i{font-style:normal;background:#e2e8f0;color:#475569;border-radius:20px;padding:1px 8px;font-size:11px}")
         .append(".rpd-tab:hover{color:#0f172a}")
         .append(".rpd-tab.active{background:#fff;color:#4338ca;box-shadow:0 1px 3px rgba(15,23,42,.12)}")
         .append(".rpd-tab.active i{background:#e0e7ff;color:#4338ca}")
         .append(".rpd-panel{display:none;background:#fff;border:1px solid #e2e8f0;border-radius:14px;padding:20px;box-shadow:0 1px 2px rgba(15,23,42,.05)}")
         .append(".rpd-panel.active{display:block}")
         .append(".rpd-panel-head{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;margin-bottom:14px}")
         .append(".rpd-panel-head .rpd-h{margin:0 0 2px}")
         .append(".rpd-range{font-size:12px;color:#64748b}")
         .append(".rpd-sum .s-ok strong{color:#15803d}.rpd-sum .s-bad strong{color:#b91c1c}.rpd-sum .s-warn strong{color:#b45309}")
         .append(".rpd-card h3{font-size:18px;color:#0f172a;margin:0 0 4px}")
         .append(".rpd-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:16px;padding-top:14px;border-top:1px solid #eef2f7}")
         .append(".rpd-grid div{font-size:13px;color:#334155;word-break:break-word}")
         .append(".rpd-grid b{display:block;font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.4px;margin-bottom:2px}")
         .append(".rpd-sum{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:0 0 12px}")
         .append(".rpd-sum div{background:#f1f5f9;border-radius:8px;padding:10px;text-align:center;font-size:12px;color:#475569}")
         .append(".rpd-sum strong{display:block;font-size:20px;color:#0f172a}")
         .append(".rpd-h{margin:24px 0 10px;font-size:16px;color:#0f172a}")
         .append(".rpd-act{display:inline-block;margin-left:8px;padding:5px 12px;border-radius:7px;border:1px solid #2563eb;color:#2563eb;background:#fff;font-size:12px;font-weight:700;text-decoration:none;vertical-align:middle}")
         .append(".rpd-act:hover{background:#eff6ff}.rpd-dl{background:#2563eb;color:#fff}.rpd-dl:hover{background:#1d4ed8}")
         .append(".rpd-empty{text-align:center;color:#64748b;padding:18px}")
         .append(".rpd-scroll{overflow-x:auto}")
         .append(".rpd-scroll table{width:100%;border-collapse:collapse;min-width:720px}")
         .append(".rpd-scroll th,.rpd-scroll td{padding:10px 12px;border-bottom:1px solid #e2e8f0;text-align:left;font-size:13px}")
         .append(".rpd-scroll th{background:#f8fafc;color:#475569;font-size:12px}")
         .append(".rpd-status{display:inline-block;padding:4px 10px;border-radius:20px;font-size:11px;font-weight:700;white-space:nowrap}")
         .append(".rpd-completed{background:#dcfce7;color:#166534}.rpd-pending{background:#fef3c7;color:#92400e}")
         .append(".rpd-progress{background:#dbeafe;color:#1d4ed8}.rpd-rejected{background:#fee2e2;color:#991b1b}")
         .append(".rpd-chips{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 14px}")
         .append(".rpd-chip{border:1px solid #cbd5e1;background:#fff;color:#334155;padding:7px 14px;border-radius:20px;font-size:12px;font-weight:700;cursor:pointer}")
         .append(".rpd-chip i{font-style:normal;margin-left:6px;background:#e2e8f0;color:#334155;border-radius:20px;padding:1px 8px;font-size:11px}")
         .append(".rpd-chip:hover{background:#f1f5f9}")
         .append(".rpd-chip.active{background:#4338ca;border-color:#4338ca;color:#fff}")
         .append(".rpd-chip.active i{background:rgba(255,255,255,.25);color:#fff}")
         .append(".rpd-chip[data-f=PENDING].active{background:#b45309;border-color:#b45309}")
         .append(".rpd-chip[data-f=APPROVED].active{background:#15803d;border-color:#15803d}")
         .append(".rpd-chip[data-f=REJECTED].active{background:#b91c1c;border-color:#b91c1c}")
         .append(".rpd-error{padding:13px;border-radius:8px;background:#fee2e2;color:#991b1b;border:1px solid #fecaca}")
         .append("@media(max-width:760px){.rpd-grid,.rpd-sum{grid-template-columns:1fr 1fr}}")
         .append("</style>");

        // backUrl == null / empty -> no back link (used by the manager's own "Personal Reports" page)
        if (backUrl != null && !backUrl.trim().isEmpty()) {
            h.append("<a class=\"rpd-back\" href=\"").append(esc(backUrl)).append("\">&larr; Back to all ")
             .append("MANAGER".equals(ptype) || scopeManagerId == null ? "people" : "employees").append("</a>");
        }

        if (error != null) {
            h.append("<div class=\"rpd-error\">").append(esc(error)).append("</div>");
            return h.toString();
        }
        if (!allowed) {
            h.append("<div class=\"rpd-error\">You can only view reports for active members of your own teams.</div>");
            return h.toString();
        }
        if (!found) {
            h.append("<div class=\"rpd-error\">").append(roleLabel).append(" not found.</div>");
            return h.toString();
        }

        // date bar
        h.append("<form method=\"get\" action=\"").append(esc(formAction)).append("\" class=\"rpd-datebar\">");
        if (hidden != null) {
            for (String[] hv : hidden) {
                h.append("<input type=\"hidden\" name=\"").append(esc(hv[0])).append("\" value=\"")
                 .append(esc(hv[1])).append("\">");
            }
        }
        h.append("<label>From <input type=\"date\" name=\"").append(esc(fromName)).append("\" value=\"")
         .append(esc(fromStr)).append("\"></label>")
         .append("<label>To <input type=\"date\" name=\"").append(esc(toName)).append("\" value=\"")
         .append(esc(toStr)).append("\"></label>")
         .append("<button type=\"submit\">Apply dates</button>")
         .append("<a class=\"rpd-back\" style=\"margin:0\" href=\"").append(esc(clearUrl)).append("\">Clear dates</a>")
         .append("<span style=\"font-size:11px;color:#64748b;\">Attendance shows one day (today, or the date chosen in the list) until you pick From / To dates; tasks use start date, leaves use applied date.</span>")
         .append("</form>");

        // profile header
        String initials = name.trim().isEmpty() ? "?" : name.trim().substring(0, 1).toUpperCase();
        h.append("<div class=\"rpd-card\"><div class=\"rpd-head\"><div class=\"rpd-avatar\">").append(esc(initials)).append("</div>")
         .append("<div><h3>").append(esc(name)).append(" ").append(badge(status)).append("</h3>")
         .append("<span class=\"rpd-sub\">").append(roleLabel).append(" &middot; ID ").append(esc(pid)).append("</span></div></div>")
         .append("<div class=\"rpd-grid\">")
         .append("<div><b>Email</b>").append(esc(email)).append("</div>")
         .append("<div><b>Department</b>").append(esc(dept)).append("</div>")
         .append("<div><b>Designation</b>").append(esc(desig)).append("</div>")
         .append("</div></div>");

        // tabs: one report at a time
        h.append("<div class=\"rpd-tabs\" role=\"tablist\">")
         .append("<button type=\"button\" class=\"rpd-tab active\" data-panel=\"rpdAtt\" onclick=\"rpdTab(this)\">🕒 Attendance <i>").append(attRows.size()).append("</i></button>")
         .append("<button type=\"button\" class=\"rpd-tab\" data-panel=\"rpdLeave\" onclick=\"rpdTab(this)\">📄 Leaves <i>").append(leaveRows.size()).append("</i></button>")
         .append("<button type=\"button\" class=\"rpd-tab\" data-panel=\"rpdTask\" onclick=\"rpdTab(this)\">📋 Tasks <i>").append(taskRows.size()).append("</i></button>")
         .append("<button type=\"button\" class=\"rpd-tab\" data-panel=\"rpdTeam\" onclick=\"rpdTab(this)\">👥 Teams <i>").append(teamRows.size()).append("</i></button>")
         .append("</div>");

        // attendance panel
        h.append("<div class=\"rpd-panel active\" id=\"rpdAtt\"><div class=\"rpd-panel-head\"><div><h3 class=\"rpd-h\">Attendance Report</h3>")
         .append("<span class=\"rpd-range\">").append(dFrom.equals(dTo) && !userRange ? (dFrom.equals(today) ? "Today (" : "Day (") + dFrom + ") - choose From / To dates to see other days"
                        : dFrom + " to " + dTo + " (Mon–Fri)").append("</span></div>");
        if (attendanceBaseUrl != null) {
            String q = attendanceBaseUrl + "&fromDate=" + enc(dFrom.toString()) + "&toDate=" + enc(dTo.toString());
            h.append("<div><a class=\"rpd-act\" target=\"_blank\" rel=\"noopener\" href=\"").append(esc(q + "&mode=view"))
             .append("\">👁 View</a> <a class=\"rpd-act rpd-dl\" href=\"").append(esc(q + "&mode=csv"))
             .append("\">⬇ Download</a></div>");
        }
        h.append("</div>")
         .append("<div class=\"rpd-sum\"><div><strong>").append(attRows.size()).append("</strong>Days</div>")
         .append("<div class=\"s-ok\"><strong>").append(present).append("</strong>Present</div>")
         .append("<div class=\"s-bad\"><strong>").append(absent).append("</strong>Absent</div>")
         .append("<div class=\"s-warn\"><strong>").append(onLeave).append("</strong>Leave</div></div>");
        table(h, new String[]{"Date", "Day", "Check In", "Check Out", "Status"}, attRows, 4, "No attendance records for this range.");
        h.append("</div>");

        int lvPending = 0, lvApproved = 0, lvRejected = 0;
        for (String[] lr : leaveRows) {
            String u = lr[5] == null ? "" : lr[5].trim().toUpperCase();
            if ("APPROVED".equals(u)) lvApproved++;
            else if ("REJECTED".equals(u)) lvRejected++;
            else lvPending++;
        }
        h.append("<div class=\"rpd-panel\" id=\"rpdLeave\"><div class=\"rpd-panel-head\"><div><h3 class=\"rpd-h\">Leave Report</h3>")
         .append("<span class=\"rpd-range\">All leave requests").append(userRange ? " applied in the selected dates" : "").append("</span></div></div>");
        h.append("<div class=\"rpd-chips\">")
         .append(chip("ALL", "All", leaveRows.size(), true))
         .append(chip("PENDING", "Pending", lvPending, false))
         .append(chip("APPROVED", "Approved", lvApproved, false))
         .append(chip("REJECTED", "Rejected", lvRejected, false))
         .append("</div>");
        leaveTable(h, leaveRows);
        h.append("</div>");

        h.append("<div class=\"rpd-panel\" id=\"rpdTask\"><div class=\"rpd-panel-head\"><div><h3 class=\"rpd-h\">Task Report</h3>")
         .append("<span class=\"rpd-range\">").append("MANAGER".equals(ptype) ? "Assigned to and created by this manager" : "Tasks assigned to this employee")
         .append(userRange ? " (start date in range)" : "").append("</span></div></div>");
        table(h, new String[]{"Task ID", "Title", "Assigned To", "Created By", "Priority", "Start", "Due", "Status"}, taskRows, 7, "No tasks found.");
        h.append("</div>");

        h.append("<div class=\"rpd-panel\" id=\"rpdTeam\"><div class=\"rpd-panel-head\"><div><h3 class=\"rpd-h\">Team Report</h3>")
         .append("<span class=\"rpd-range\">").append("MANAGER".equals(ptype) ? "Teams managed" : "Teams this employee belongs to").append("</span></div></div>");
        table(h, new String[]{"Team ID", "Team Name", "Department", "Role", "Active Members", "Status"}, teamRows, 5, "Not part of any team.");
        h.append("</div>");

        h.append("<script>function rpdTab(b){var w=b.parentNode;w.querySelectorAll('.rpd-tab').forEach(function(x){x.classList.remove('active')});")
         .append("document.querySelectorAll('.rpd-panel').forEach(function(x){x.classList.remove('active')});")
         .append("b.classList.add('active');document.getElementById(b.getAttribute('data-panel')).classList.add('active');}")
         .append("function rpdLeaveFilter(b){var f=b.getAttribute('data-f');")
         .append("b.parentNode.querySelectorAll('.rpd-chip').forEach(function(x){x.classList.remove('active')});b.classList.add('active');")
         .append("var n=0;document.querySelectorAll('#rpdLeaveTable tbody tr[data-st]').forEach(function(r){")
         .append("var show=(f==='ALL'||r.getAttribute('data-st')===f);r.style.display=show?'':'none';if(show)n++;});")
         .append("var e=document.getElementById('rpdLeaveNone');if(e){e.style.display=n===0?'':'none';}}")
         .append("</script>");

        return h.toString();
    }

    /**
     * Attendance of many people for ONE day (used by the admin / manager lists).
     * Returns id -> {checkIn, checkOut, status}. status = PRESENT / ABSENT / LEAVE /
     * WEEKEND (no record on Sat/Sun) / "-" (future day with nothing yet).
     */
    public static java.util.Map<String, String[]> dayAttendance(java.util.Collection<String> ids, String dateStr) {
        java.util.Map<String, String[]> out = new java.util.LinkedHashMap<String, String[]>();
        LocalDate day;
        try { day = (dateStr == null || dateStr.trim().isEmpty()) ? LocalDate.now() : LocalDate.parse(dateStr.trim()); }
        catch (Exception e) { day = LocalDate.now(); }
        if (ids == null || ids.isEmpty()) return out;

        boolean weekend = day.getDayOfWeek() == DayOfWeek.SATURDAY || day.getDayOfWeek() == DayOfWeek.SUNDAY;
        boolean future = day.isAfter(LocalDate.now());
        java.sql.Date sd = java.sql.Date.valueOf(day);

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection con = DriverManager.getConnection(URL, USER, PASSWORD);
                 PreparedStatement aps = con.prepareStatement(
                    "SELECT check_in_time,check_out_time,status FROM attendance "
                    + "WHERE employee_id=? AND `date`=? ORDER BY attendance_id DESC LIMIT 1");
                 PreparedStatement lps = con.prepareStatement(
                    "SELECT COUNT(*) FROM leave_requests WHERE employee_id=? "
                    + "AND UPPER(status)='APPROVED' AND from_date<=? AND to_date>=?")) {
                for (String id : ids) {
                    String cin = "-", cout = "-", st = null;
                    boolean has = false, leave = false;
                    aps.setString(1, id);
                    aps.setDate(2, sd);
                    try (ResultSet rs = aps.executeQuery()) {
                        if (rs.next()) {
                            has = true;
                            java.sql.Time ti = rs.getTime("check_in_time");
                            java.sql.Time to = rs.getTime("check_out_time");
                            cin = ti == null ? "-" : ti.toString();
                            cout = to == null ? "-" : to.toString();
                            st = rs.getString("status");
                        }
                    }
                    lps.setString(1, id);
                    lps.setDate(2, sd);
                    lps.setDate(3, sd);
                    try (ResultSet rs = lps.executeQuery()) {
                        if (rs.next()) leave = rs.getInt(1) > 0;
                    }
                    if (leave && "-".equals(cin)) {
                        st = "LEAVE"; cout = "-";
                    } else if (has) {
                        if (st == null || st.trim().isEmpty()) st = "-".equals(cin) ? "ABSENT" : "PRESENT";
                    } else if (weekend) {
                        st = "WEEKEND";
                    } else if (future) {
                        st = "-";
                    } else {
                        st = "ABSENT";
                    }
                    out.put(id, new String[]{cin, cout, st});
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return out;
    }

    /** Small HTML badge for the list tables (PRESENT / ABSENT / LEAVE / WEEKEND). */
    public static String attendanceBadge(String status) {
        if (status == null || "-".equals(status)) return "<span style=\"color:#94a3b8\">-</span>";
        if ("WEEKEND".equals(status)) return "<span class=\"rpd-status\" style=\"background:#f1f5f9;color:#64748b\">WEEKEND</span>";
        return badge(status);
    }

    private static String enc(String s) {
        try { return java.net.URLEncoder.encode(s == null ? "" : s, "UTF-8"); }
        catch (Exception e) { return ""; }
    }

    /** Mon-Fri attendance rows (newest first). Approved leave shows as LEAVE unless checked in. */
    private static int[] loadAttendance(Connection con, String pid, LocalDate dFrom, LocalDate dTo,
                                        LocalDate today, List<String[]> attRows) throws Exception {
        // a single-day report always shows a row (Date + Day + times + status), never an empty table
        boolean singleDay = dFrom.equals(dTo);
        int present = 0, absent = 0, onLeave = 0;
        try (PreparedStatement aps = con.prepareStatement(
                "SELECT check_in_time,check_out_time,status FROM attendance "
                + "WHERE employee_id=? AND `date`=? ORDER BY attendance_id DESC LIMIT 1");
             PreparedStatement lps = con.prepareStatement(
                "SELECT COUNT(*) FROM leave_requests WHERE employee_id=? "
                + "AND UPPER(status)='APPROVED' AND from_date<=? AND to_date>=?")) {
            LocalDate d = dFrom;
            while (!d.isAfter(dTo)) {
                DayOfWeek dow = d.getDayOfWeek();
                boolean weekend = dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY;
                {
                    java.sql.Date sd = java.sql.Date.valueOf(d);
                    String cin = "-", cout = "-", ast = null;
                    boolean hasAtt = false, leave = false;
                    aps.setString(1, pid);
                    aps.setDate(2, sd);
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
                    lps.setString(1, pid);
                    lps.setDate(2, sd);
                    lps.setDate(3, sd);
                    try (ResultSet rs = lps.executeQuery()) {
                        if (rs.next()) leave = rs.getInt(1) > 0;
                    }
                    boolean showRow = !(d.isAfter(today) && !hasAtt) && !(weekend && !hasAtt);
                    if (leave && "-".equals(cin) && !weekend) {
                        ast = "LEAVE";
                        cout = "-";
                        showRow = true;
                    } else if (hasAtt) {
                        if (ast == null || ast.trim().isEmpty()) ast = "-".equals(cin) ? "ABSENT" : "PRESENT";
                    } else if (weekend) {
                        ast = "WEEKEND";
                    } else if (d.isAfter(today)) {
                        ast = "-";
                    } else {
                        ast = "ABSENT";
                    }
                    if (singleDay) showRow = true;
                    if (showRow) {
                        attRows.add(new String[]{d.toString(),
                            dow.getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.ENGLISH),
                            cin, cout, ast});
                        if ("PRESENT".equalsIgnoreCase(ast)) present++;
                        else if ("ABSENT".equalsIgnoreCase(ast)) absent++;
                        else if ("LEAVE".equalsIgnoreCase(ast)) onLeave++;
                    }
                }
                d = d.plusDays(1);
            }
            Collections.reverse(attRows);
        }
        return new int[]{present, absent, onLeave};
    }

    // ===================== attendance View / Download =====================

    public static class AttendanceData {
        public boolean found;
        public String id = "", name = "", email = "", dept = "", desig = "", status = "", type = "EMPLOYEE";
        public LocalDate from, to;
        public List<String[]> rows = new ArrayList<String[]>();
        public int present, absent, leave;
    }

    public static AttendanceData attendanceData(String personId, String personType,
                                                String fromStr, String toStr) throws Exception {
        AttendanceData ad = new AttendanceData();
        ad.id = personId == null ? "" : personId.trim();
        ad.type = "MANAGER".equalsIgnoreCase(personType) ? "MANAGER" : "EMPLOYEE";

        LocalDate today = LocalDate.now();
        LocalDate dFrom = null, dTo = null;
        try { if (fromStr != null && !fromStr.isEmpty()) dFrom = LocalDate.parse(fromStr); } catch (Exception e) { dFrom = null; }
        try { if (toStr != null && !toStr.isEmpty()) dTo = LocalDate.parse(toStr); } catch (Exception e) { dTo = null; }
        if (dFrom == null && dTo == null) { dFrom = today; dTo = today; }
        else if (dFrom == null) { dFrom = dTo; }
        else if (dTo == null) { dTo = today; }
        if (dFrom.isAfter(dTo)) { LocalDate sw = dFrom; dFrom = dTo; dTo = sw; }
        ad.from = dFrom;
        ad.to = dTo;

        Class.forName("com.mysql.cj.jdbc.Driver");
        try (Connection con = DriverManager.getConnection(URL, USER, PASSWORD)) {
            String table = "MANAGER".equals(ad.type) ? "managers" : "employees";
            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT name,email,department,designation,status FROM " + table + " WHERE employee_id=?")) {
                ps.setString(1, ad.id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        ad.found = true;
                        ad.name = nz(rs.getString("name"));
                        ad.email = nz(rs.getString("email"));
                        ad.dept = nz(rs.getString("department"));
                        ad.desig = nz(rs.getString("designation"));
                        String st = rs.getString("status");
                        ad.status = (st != null && "ACTIVE".equalsIgnoreCase(st.trim())) ? "ACTIVE" : "INACTIVE";
                    }
                }
            }
            if (ad.found) {
                int[] cnt = loadAttendance(con, ad.id, dFrom, dTo, today, ad.rows);
                ad.present = cnt[0];
                ad.absent = cnt[1];
                ad.leave = cnt[2];
            }
        }
        return ad;
    }

    private static String csv(String v) {
        String s = v == null ? "" : v;
        if (!s.isEmpty() && "=+@\t\r".indexOf(s.charAt(0)) >= 0) s = "'" + s;   // spreadsheet formula safety
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }

    /** CSV text (open directly in Excel). */
    public static String attendanceCsv(AttendanceData ad) {
        StringBuilder sb = new StringBuilder();
        sb.append("\uFEFF");   // BOM so Excel reads UTF-8 correctly
        sb.append("Employee ID,Name,Type,Date,Day,Check In,Check Out,Status\r\n");
        for (String[] r : ad.rows) {
            sb.append(csv(ad.id)).append(',').append(csv(ad.name)).append(',')
              .append(csv("MANAGER".equals(ad.type) ? "Manager" : "Employee")).append(',')
              .append(csv(r[0])).append(',').append(csv(r[1])).append(',')
              .append(csv(r[2])).append(',').append(csv(r[3])).append(',').append(csv(r[4])).append("\r\n");
        }
        return sb.toString();
    }

    /** Stand-alone printable page for the "View" button. */
    public static String attendanceViewHtml(AttendanceData ad, String downloadUrl) {
        StringBuilder h = new StringBuilder();
        h.append("<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"UTF-8\">")
         .append("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
         .append("<title>Attendance Report - ").append(esc(ad.name)).append("</title><style>")
         .append("body{font-family:Segoe UI,Arial,sans-serif;background:#f1f5f9;margin:0;padding:24px;color:#0f172a}")
         .append(".page{max-width:900px;margin:0 auto;background:#fff;border-radius:12px;padding:26px;box-shadow:0 4px 18px rgba(15,23,42,.08)}")
         .append("h1{font-size:22px;margin:0 0 4px}.sub{color:#64748b;font-size:13px;margin-bottom:16px}")
         .append(".info{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin:14px 0;font-size:13px}")
         .append(".info b{display:block;font-size:11px;color:#64748b;text-transform:uppercase}")
         .append(".sum{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:14px 0}")
         .append(".sum div{background:#f1f5f9;border-radius:8px;padding:10px;text-align:center;font-size:12px;color:#475569}")
         .append(".sum strong{display:block;font-size:20px;color:#0f172a}")
         .append("table{width:100%;border-collapse:collapse;margin-top:8px}")
         .append("th,td{padding:9px 12px;border-bottom:1px solid #e2e8f0;text-align:left;font-size:13px}")
         .append("th{background:#f8fafc;color:#475569;font-size:12px}")
         .append(".rpd-status{display:inline-block;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:700}")
         .append(".rpd-completed{background:#dcfce7;color:#166534}.rpd-pending{background:#fef3c7;color:#92400e}")
         .append(".rpd-progress{background:#dbeafe;color:#1d4ed8}.rpd-rejected{background:#fee2e2;color:#991b1b}")
         .append(".bar{display:flex;gap:10px;margin-bottom:16px}")
         .append(".bar a,.bar button{padding:9px 16px;border-radius:8px;border:1px solid #2563eb;background:#2563eb;color:#fff;font-weight:600;font-size:13px;text-decoration:none;cursor:pointer}")
         .append(".bar .alt{background:#fff;color:#2563eb}")
         .append("@media print{body{background:#fff;padding:0}.page{box-shadow:none}.bar{display:none}}")
         .append("</style></head><body><div class=\"page\">")
         .append("<div class=\"bar\"><a href=\"").append(esc(downloadUrl)).append("\">⬇ Download</a>")
         .append("<button class=\"alt\" onclick=\"window.print()\">🖨 Print / Save as PDF</button></div>")
         .append("<h1>Attendance Report</h1><div class=\"sub\">")
         .append(ad.from).append(" to ").append(ad.to).append(" (Mon–Fri)</div>")
         .append("<div class=\"info\"><div><b>Name</b>").append(esc(ad.name)).append("</div>")
         .append("<div><b>ID</b>").append(esc(ad.id)).append("</div>")
         .append("<div><b>Role</b>").append("MANAGER".equals(ad.type) ? "Manager" : "Employee").append("</div>")
         .append("<div><b>Email</b>").append(esc(ad.email)).append("</div>")
         .append("<div><b>Department</b>").append(esc(ad.dept)).append("</div>")
         .append("<div><b>Designation</b>").append(esc(ad.desig)).append("</div></div>")
         .append("<div class=\"sum\"><div><strong>").append(ad.rows.size()).append("</strong>Days</div>")
         .append("<div><strong>").append(ad.present).append("</strong>Present</div>")
         .append("<div><strong>").append(ad.absent).append("</strong>Absent</div>")
         .append("<div><strong>").append(ad.leave).append("</strong>Leave</div></div>")
         .append("<table><thead><tr><th>Date</th><th>Day</th><th>Check In</th><th>Check Out</th><th>Status</th></tr></thead><tbody>");
        if (ad.rows.isEmpty()) {
            h.append("<tr><td colspan=\"5\" style=\"text-align:center;color:#64748b\">No attendance records for this range.</td></tr>");
        }
        for (String[] r : ad.rows) {
            h.append("<tr><td>").append(esc(r[0])).append("</td><td>").append(esc(r[1])).append("</td><td>")
             .append(esc(r[2])).append("</td><td>").append(esc(r[3])).append("</td><td>").append(badge(r[4])).append("</td></tr>");
        }
        h.append("</tbody></table></div></body></html>");
        return h.toString();
    }

    /** One leave-status filter button (All / Pending / Approved / Rejected). */
    private static String chip(String filter, String label, int count, boolean active) {
        return "<button type=\"button\" class=\"rpd-chip" + (active ? " active" : "") + "\" data-f=\"" + filter
             + "\" onclick=\"rpdLeaveFilter(this)\">" + esc(label) + " <i>" + count + "</i></button>";
    }

    /** Leave table; every row carries data-st (PENDING / APPROVED / REJECTED) so the buttons can filter it. */
    private static void leaveTable(StringBuilder h, List<String[]> rows) {
        String[] heads = {"Leave ID", "Type", "From", "To", "Reason", "Status", "Applied"};
        h.append("<div class=\"rpd-scroll\"><table id=\"rpdLeaveTable\"><thead><tr>");
        for (String t : heads) h.append("<th>").append(esc(t)).append("</th>");
        h.append("</tr></thead><tbody>");
        h.append("<tr id=\"rpdLeaveNone\" style=\"").append(rows.isEmpty() ? "" : "display:none")
         .append("\"><td colspan=\"").append(heads.length).append("\" class=\"rpd-empty\">No leave requests found.</td></tr>");
        for (String[] r : rows) {
            String u = r[5] == null ? "" : r[5].trim().toUpperCase();
            String st = "APPROVED".equals(u) ? "APPROVED" : ("REJECTED".equals(u) ? "REJECTED" : "PENDING");
            h.append("<tr data-st=\"").append(st).append("\">");
            for (int i = 0; i < r.length; i++) {
                if (i == 5) h.append("<td>").append(badge(st)).append("</td>");
                else h.append("<td>").append(esc(r[i])).append("</td>");
            }
            h.append("</tr>");
        }
        h.append("</tbody></table></div>");
    }

    private static void table(StringBuilder h, String[] heads, List<String[]> rows, int statusCol, String emptyMsg) {
        h.append("<div class=\"rpd-scroll\"><table><thead><tr>");
        for (String t : heads) h.append("<th>").append(esc(t)).append("</th>");
        h.append("</tr></thead><tbody>");
        if (rows.isEmpty()) {
            h.append("<tr><td colspan=\"").append(heads.length).append("\" class=\"rpd-empty\">")
             .append(esc(emptyMsg)).append("</td></tr>");
        }
        for (String[] r : rows) {
            h.append("<tr>");
            for (int i = 0; i < r.length; i++) {
                if (i == statusCol) h.append("<td>").append(badge(r[i])).append("</td>");
                else h.append("<td>").append(esc(r[i])).append("</td>");
            }
            h.append("</tr>");
        }
        h.append("</tbody></table></div>");
    }
}
