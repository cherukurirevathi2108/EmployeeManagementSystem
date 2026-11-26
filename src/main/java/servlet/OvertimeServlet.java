package servlet;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.Month;
import java.time.format.TextStyle;
import java.util.List;
import java.util.Locale;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import service.AttendanceAutoCheckout;
import service.OvertimeService;
import service.OvertimeService.OtRequest;

/**
 * Overtime page (/overtime), written as standalone HTML (no JSP needed).
 *
 *  - logged in as EMPLOYEE : request overtime + see own requests
 *  - logged in as MANAGER  : approve / reject the requests of the team members
 *
 * See service.OvertimeService for the rules.
 */
@WebServlet("/overtime")
public class OvertimeServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    // ------------------------------------------------------------------
    // GET
    // ------------------------------------------------------------------

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);
        String managerId = session == null ? null : (String) session.getAttribute("managerId");
        String employeeId = session == null ? null : (String) session.getAttribute("employeeId");

        if (managerId == null && employeeId == null) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        String html;

        try {
            html = managerId != null
                    ? managerPage(request, managerId)
                    : employeePage(request, employeeId);
        } catch (Exception e) {
            e.printStackTrace();
            response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    "Unable to load the overtime page");
            return;
        }

        response.setContentType("text/html; charset=UTF-8");
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write(html);
    }

    // ------------------------------------------------------------------
    // POST
    // ------------------------------------------------------------------

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        HttpSession session = request.getSession(false);
        String managerId = session == null ? null : (String) session.getAttribute("managerId");
        String employeeId = session == null ? null : (String) session.getAttribute("employeeId");

        if (managerId == null && employeeId == null) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        String action = request.getParameter("action");
        String message;
        boolean ok = true;

        try {

            if ("request".equals(action) && managerId == null && employeeId != null) {

                LocalDate date = LocalDate.parse(request.getParameter("otDate"));
                double hours = Double.parseDouble(request.getParameter("hours"));

                OvertimeService.request(employeeId, date, hours, request.getParameter("reason"));
                message = "Overtime request sent to your manager.";

            } else if ("decide".equals(action) && managerId != null) {

                int id = Integer.parseInt(request.getParameter("id"));
                boolean approve = "approve".equals(request.getParameter("decision"));

                message = OvertimeService.decide(id, managerId, approve, request.getParameter("note"));

            } else {
                message = "Unknown action.";
                ok = false;
            }

        } catch (IllegalArgumentException e) {
            message = e.getMessage() == null ? "Invalid request." : e.getMessage();
            ok = false;
        } catch (Exception e) {
            e.printStackTrace();
            message = "Something went wrong. Please try again.";
            ok = false;
        }

        response.sendRedirect(request.getContextPath() + "/overtime?" + (ok ? "msg=" : "err=")
                + URLEncoder.encode(message, StandardCharsets.UTF_8));
    }

    // ------------------------------------------------------------------
    // Pages
    // ------------------------------------------------------------------

    private String employeePage(HttpServletRequest request, String employeeId) throws Exception {

        String ctx = request.getContextPath();
        LocalDate today = LocalDate.now();
        List<OtRequest> list = OvertimeService.forEmployee(employeeId);

        StringBuilder h = head("My Overtime", ctx + "/employee", "Employee dashboard", request);

        h.append("<div class=\"card\"><h2>Request overtime</h2>")
         .append("<p class=\"hint\">Your regular day ends at ").append(AttendanceAutoCheckout.CUTOFF)
         .append(". When your manager approves, your check-out becomes ")
         .append(AttendanceAutoCheckout.CUTOFF).append(" + the OT hours, and the OT pay is added to your salary ")
         .append("and salary slip automatically.</p>")
         .append("<form method=\"post\" action=\"").append(esc(ctx)).append("/overtime\" class=\"form\">")
         .append("<input type=\"hidden\" name=\"action\" value=\"request\">")
         .append("<label>Date<input type=\"date\" name=\"otDate\" required value=\"").append(today)
         .append("\" min=\"").append(today.minusDays(OvertimeService.MAX_DAYS_BACK))
         .append("\" max=\"").append(today).append("\"></label>")
         .append("<label>OT hours<select name=\"hours\">");

        for (double hrs = 0.5; hrs <= OvertimeService.MAX_HOURS; hrs += 0.5) {
            h.append("<option value=\"").append(hrs).append("\"").append(hrs == 2.0 ? " selected" : "")
             .append(">").append(hrs).append(" h</option>");
        }

        h.append("</select></label>")
         .append("<label class=\"wide\">Reason<textarea name=\"reason\" maxlength=\"500\" required ")
         .append("placeholder=\"What did you work on?\"></textarea></label>")
         .append("<button type=\"submit\">Send to manager</button></form></div>");

        h.append("<div class=\"card\"><h2>My overtime requests</h2>");

        if (list.isEmpty()) {
            h.append("<p class=\"hint\">No overtime requests yet.</p>");
        } else {
            h.append("<div class=\"scroll\"><table><thead><tr><th>Date</th><th>Hours</th><th>Reason</th>")
             .append("<th>Status</th><th>Check-out</th><th>Manager note</th><th>Paid in salary</th>")
             .append("<th class=\"r\">OT pay</th></tr></thead><tbody>");

            for (OtRequest r : list) {
                h.append("<tr><td>").append(r.otDate).append("</td><td>").append(hours(r.hours))
                 .append("</td><td>").append(esc(r.reason)).append("</td><td>").append(badge(r.status))
                 .append("</td><td>").append("APPROVED".equals(r.status) ? String.valueOf(r.checkOutTime) : "-")
                 .append("</td><td>").append(esc(r.managerNote == null || r.managerNote.isEmpty() ? "-" : r.managerNote))
                 .append("</td><td>").append(payMonth(r)).append("</td><td class=\"r\">");

                if (r.amount != null) {
                    h.append(money(r.amount));
                } else if ("APPROVED".equals(r.status) && r.payMonth != null) {
                    BigDecimal est = OvertimeService.estimateAmount(
                            employeeId, r.payMonth, r.payYear, r.hours);
                    h.append(est == null ? "-" : "~ " + money(est) + " <small>(estimate)</small>");
                } else {
                    h.append("-");
                }

                h.append("</td></tr>");
            }

            h.append("</tbody></table></div>");
        }

        h.append("</div>");
        return foot(h);
    }

    private String managerPage(HttpServletRequest request, String managerId) throws Exception {

        String ctx = request.getContextPath();
        List<OtRequest> pending = OvertimeService.forManager(managerId, "PENDING");
        List<OtRequest> all = OvertimeService.forManager(managerId, "");

        StringBuilder h = head("Overtime Approvals", ctx + "/manager", "Manager dashboard", request);

        h.append("<div class=\"card\"><h2>Waiting for your approval (").append(pending.size()).append(")</h2>")
         .append("<p class=\"hint\">On approval the employee's check-out becomes ")
         .append(AttendanceAutoCheckout.CUTOFF).append(" + the OT hours and the OT pay goes into the salary.</p>");

        if (pending.isEmpty()) {
            h.append("<p class=\"hint\">No pending overtime requests.</p>");
        } else {
            h.append("<div class=\"scroll\"><table><thead><tr><th>Employee</th><th>Date</th><th>Hours</th>")
             .append("<th>New check-out</th><th>Reason</th><th>Decision</th></tr></thead><tbody>");

            for (OtRequest r : pending) {
                h.append("<tr><td>").append(esc(r.employeeName)).append(" <small>").append(esc(r.employeeId))
                 .append("</small></td><td>").append(r.otDate).append("</td><td>").append(hours(r.hours))
                 .append("</td><td>").append(r.checkOutTime).append("</td><td>").append(esc(r.reason))
                 .append("</td><td><form method=\"post\" action=\"").append(esc(ctx)).append("/overtime\" class=\"inline\">")
                 .append("<input type=\"hidden\" name=\"action\" value=\"decide\">")
                 .append("<input type=\"hidden\" name=\"id\" value=\"").append(r.id).append("\">")
                 .append("<input type=\"text\" name=\"note\" maxlength=\"300\" placeholder=\"Note (optional)\">")
                 .append("<button name=\"decision\" value=\"approve\" class=\"ok\">Approve</button>")
                 .append("<button name=\"decision\" value=\"reject\" class=\"no\">Reject</button>")
                 .append("</form></td></tr>");
            }

            h.append("</tbody></table></div>");
        }

        h.append("</div><div class=\"card\"><h2>Decided requests</h2>");

        boolean any = false;
        StringBuilder rows = new StringBuilder();

        for (OtRequest r : all) {
            if ("PENDING".equals(r.status)) continue;
            any = true;
            rows.append("<tr><td>").append(esc(r.employeeName)).append(" <small>").append(esc(r.employeeId))
                .append("</small></td><td>").append(r.otDate).append("</td><td>").append(hours(r.hours))
                .append("</td><td>").append(badge(r.status)).append("</td><td>")
                .append("APPROVED".equals(r.status) ? String.valueOf(r.checkOutTime) : "-")
                .append("</td><td>").append(esc(r.managerNote == null || r.managerNote.isEmpty() ? "-" : r.managerNote))
                .append("</td><td>").append(payMonth(r)).append("</td></tr>");
        }

        if (!any) {
            h.append("<p class=\"hint\">Nothing decided yet.</p>");
        } else {
            h.append("<div class=\"scroll\"><table><thead><tr><th>Employee</th><th>Date</th><th>Hours</th>")
             .append("<th>Status</th><th>Check-out</th><th>Note</th><th>Paid in salary</th></tr></thead><tbody>")
             .append(rows).append("</tbody></table></div>");
        }

        h.append("</div>");
        return foot(h);
    }

    // ------------------------------------------------------------------
    // HTML helpers
    // ------------------------------------------------------------------

    private StringBuilder head(String title, String backUrl, String backText, HttpServletRequest request) {

        StringBuilder h = new StringBuilder();

        h.append("<!DOCTYPE html><html><head><meta charset=\"UTF-8\">")
         .append("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">")
         .append("<title>").append(esc(title)).append("</title><style>")
         .append("*{box-sizing:border-box}body{margin:0;background:#eef2f7;font-family:Segoe UI,Arial,sans-serif;color:#0f172a}")
         .append(".wrap{max-width:1000px;margin:0 auto;padding:22px 14px}")
         .append(".top{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:16px}")
         .append(".top h1{margin:0;font-size:22px;color:#1d4ed8}.top a{color:#2563eb;text-decoration:none;font-weight:600;font-size:14px}")
         .append(".card{background:#fff;border:1px solid #dbe3ee;border-radius:12px;padding:20px;margin-bottom:18px}")
         .append(".card h2{margin:0 0 8px;font-size:17px}.hint{color:#64748b;font-size:13px;margin:4px 0 12px}")
         .append(".form{display:grid;grid-template-columns:1fr 1fr;gap:12px}.form .wide{grid-column:1/-1}")
         .append("label{display:block;font-size:12px;font-weight:600;color:#475569}")
         .append("input,select,textarea{width:100%;margin-top:4px;padding:9px 10px;border:1px solid #cbd5e1;border-radius:8px;font:inherit;font-size:14px}")
         .append("textarea{min-height:70px;resize:vertical}")
         .append("button{border:0;background:#2563eb;color:#fff;padding:10px 16px;border-radius:8px;font-weight:600;cursor:pointer;font-size:14px}")
         .append(".form button{grid-column:1/-1;justify-self:start}")
         .append("button.ok{background:#16a34a}button.no{background:#dc2626}")
         .append("form.inline{display:flex;gap:6px;align-items:center;flex-wrap:wrap}form.inline input{width:150px;margin:0}")
         .append("table{width:100%;border-collapse:collapse}th{background:#f1f5f9;text-align:left;font-size:12px;padding:9px 10px;white-space:nowrap}")
         .append("td{padding:9px 10px;border-bottom:1px solid #e5e7eb;font-size:13px;vertical-align:top}.r{text-align:right;white-space:nowrap}")
         .append("small{color:#64748b}.scroll{overflow-x:auto}")
         .append(".b{display:inline-block;padding:3px 10px;border-radius:20px;font-size:11px;font-weight:700}")
         .append(".b.PENDING{background:#fef3c7;color:#92400e}.b.APPROVED{background:#dcfce7;color:#166534}.b.REJECTED{background:#fee2e2;color:#991b1b}")
         .append(".msg{padding:11px 14px;border-radius:8px;margin-bottom:16px;font-size:14px}")
         .append(".msg.ok{background:#dcfce7;color:#166534;border:1px solid #bbf7d0}.msg.err{background:#fee2e2;color:#991b1b;border:1px solid #fecaca}")
         .append("@media(max-width:640px){.form{grid-template-columns:1fr}}")
         .append("</style></head><body><div class=\"wrap\"><div class=\"top\"><h1>")
         .append(esc(title)).append("</h1><a href=\"").append(esc(backUrl)).append("\">&larr; ")
         .append(esc(backText)).append("</a></div>");

        String msg = request.getParameter("msg");
        String err = request.getParameter("err");

        if (msg != null && !msg.isEmpty()) {
            h.append("<div class=\"msg ok\">").append(esc(msg)).append("</div>");
        }
        if (err != null && !err.isEmpty()) {
            h.append("<div class=\"msg err\">").append(esc(err)).append("</div>");
        }

        return h;
    }

    private String foot(StringBuilder h) {
        return h.append("</div></body></html>").toString();
    }

    private static String badge(String status) {
        return "<span class=\"b " + esc(status) + "\">" + esc(status) + "</span>";
    }

    private static String hours(BigDecimal h) {
        return h.stripTrailingZeros().toPlainString() + " h";
    }

    private static String money(BigDecimal v) {
        return "&#8377;" + String.format("%,.2f", v);
    }

    private static String payMonth(OtRequest r) {
        if (!"APPROVED".equals(r.status) || r.payMonth == null || r.payYear == null) {
            return "-";
        }
        return Month.of(r.payMonth).getDisplayName(TextStyle.SHORT, Locale.ENGLISH) + " " + r.payYear;
    }

    private static String esc(Object v) {
        if (v == null) return "";
        return String.valueOf(v).replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
}
