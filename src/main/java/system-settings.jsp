<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.SystemSetting,DAO.UserMonitorDAO,util.Html,service.SystemSettingsService" %>
<% String pageTitle = "System Settings & Users"; String active = "settings"; %>
<%@ include file="_head.jspf" %>
<%
    List<SystemSetting> settings = (List<SystemSetting>) request.getAttribute("settings");
    List<String> errors = (List<String>) request.getAttribute("errors");
    Map<String, String> typed = (Map<String, String>) request.getAttribute("typed");
    Map<String, Map<String, Long>> counts = (Map<String, Map<String, Long>>) request.getAttribute("counts");
    List<UserMonitorDAO.UserRow> users = (List<UserMonitorDAO.UserRow>) request.getAttribute("users");
    Map<String, String> val = new HashMap<String, String>();
    if (settings != null) for (SystemSetting s : settings) val.put(s.getSettingKey(), s.getSettingValue() == null ? "" : s.getSettingValue());
    if (typed != null) val.putAll(typed);          // re-show what the admin typed when validation failed
    String[] days = { "MON","TUE","WED","THU","FRI","SAT","SUN" };
    Set<String> chosenDays = new HashSet<String>(Arrays.asList(val.getOrDefault("working_days", "").split(",")));
    String[] dateFormats = { "dd/MM/yyyy","MM/dd/yyyy","yyyy-MM-dd","dd-MMM-yyyy" };
    String[] timeFormats = { "HH:mm","hh:mm a","HH:mm:ss" };
%>
<% if (request.getAttribute("message") != null) { %><div class="alert ok"><%= Html.esc(request.getAttribute("message")) %></div><% } %>
<% if (errors != null && !errors.isEmpty()) { %><div class="alert err"><ul style="margin:0;padding-left:18px"><% for (String e : errors) { %><li><%= Html.esc(e) %></li><% } %></ul></div><% } %>

<div class="card">
  <h2>System settings</h2>
  <form method="post" action="<%= cp %>/system/settings">
    <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
    <div class="fields">
      <label>Company name<input name="company_name" maxlength="100" required value="<%= Html.esc(val.get("company_name")) %>"></label>
      <label>Company email<input name="company_email" type="email" maxlength="150" value="<%= Html.esc(val.get("company_email")) %>"></label>
      <label>Company phone<input name="company_phone" maxlength="20" value="<%= Html.esc(val.get("company_phone")) %>"></label>
      <label>Company logo (https URL or /path)<input name="company_logo" maxlength="255" value="<%= Html.esc(val.get("company_logo")) %>"></label>
      <label class="full">Company address<input name="company_address" maxlength="255" value="<%= Html.esc(val.get("company_address")) %>"></label>

      <div class="full"><div class="mute" style="font-size:12px;margin-bottom:6px">Official working days</div>
        <% for (String d : days) { %><label class="chk" style="display:inline-flex;margin-right:12px"><input type="checkbox" name="working_days" value="<%= d %>" <%= chosenDays.contains(d) ? "checked" : "" %>><%= d %></label><% } %></div>

      <label>Working hours start<input type="time" name="working_hours_start" required value="<%= Html.esc(val.get("working_hours_start")) %>"></label>
      <label>Working hours end<input type="time" name="working_hours_end" required value="<%= Html.esc(val.get("working_hours_end")) %>"></label>
      <label>Attendance grace period (minutes, 0-120)<input type="number" name="attendance_grace_minutes" min="0" max="120" required value="<%= Html.esc(val.get("attendance_grace_minutes")) %>"></label>
      <label>Session timeout (minutes, 5-480)<input type="number" name="session_timeout_minutes" min="5" max="480" required value="<%= Html.esc(val.get("session_timeout_minutes")) %>"></label>
      <label>Annual leave days<input type="number" name="leave_annual_days" min="0" max="365" required value="<%= Html.esc(val.get("leave_annual_days")) %>"></label>
      <label>Sick leave days<input type="number" name="leave_sick_days" min="0" max="365" required value="<%= Html.esc(val.get("leave_sick_days")) %>"></label>
      <label>Casual leave days<input type="number" name="leave_casual_days" min="0" max="365" required value="<%= Html.esc(val.get("leave_casual_days")) %>"></label>
      <label>Date format<select name="date_format"><% for (String f : dateFormats) { %><option <%= f.equals(val.get("date_format")) ? "selected" : "" %>><%= f %></option><% } %></select></label>
      <label>Time format<select name="time_format"><% for (String f : timeFormats) { %><option <%= f.equals(val.get("time_format")) ? "selected" : "" %>><%= f %></option><% } %></select></label>
      <div class="full">
        <label class="chk" style="display:inline-flex;margin-right:18px"><input type="checkbox" name="notify_email" <%= "true".equals(val.get("notify_email")) ? "checked" : "" %>>Email notifications</label>
        <label class="chk" style="display:inline-flex"><input type="checkbox" name="notify_in_app" <%= "true".equals(val.get("notify_in_app")) ? "checked" : "" %>>In-app notifications</label>
      </div>
    </div>
    <p class="mute" style="font-size:12px">Every change is validated and recorded in the audit log with the old and new values.</p>
    <button type="submit">Save settings</button>
  </form>
</div>

<div class="card">
  <h2>Accounts by role</h2>
  <div class="scroll"><table>
    <tr><th>Role</th><th>Total</th><th>Active</th><th>Inactive / other</th></tr>
    <% long gT = 0, gA = 0;
       if (counts != null) for (Map.Entry<String, Map<String, Long>> e : counts.entrySet()) {
           long t = 0, a = 0; for (Map.Entry<String, Long> s : e.getValue().entrySet()) { t += s.getValue(); if ("ACTIVE".equals(s.getKey())) a += s.getValue(); }
           gT += t; gA += a; %>
    <tr><td><%= Html.esc(e.getKey()) %></td><td><%= t %></td><td><%= a %></td><td><%= t - a %></td></tr>
    <% } %>
    <tr><th>All</th><th><%= gT %></th><th><%= gA %></th><th><%= gT - gA %></th></tr>
  </table></div>
</div>

<div class="card">
  <h2>Users</h2>
  <form class="filters" method="get" action="<%= cp %>/system/settings">
    <label>Role<select name="role"><option value="">All</option>
      <% for (String r : new String[]{"ADMIN","HR","MANAGER","EMPLOYEE"}) { %><option <%= r.equals(request.getAttribute("fRole")) ? "selected" : "" %>><%= r %></option><% } %></select></label>
    <label>Status<select name="status"><option value="">All</option>
      <% for (String r : new String[]{"ACTIVE","INACTIVE"}) { %><option <%= r.equals(request.getAttribute("fStatus")) ? "selected" : "" %>><%= r %></option><% } %></select></label>
    <button type="submit">Filter</button>
  </form>
  <div class="scroll" style="margin-top:12px"><table>
    <tr><th>ID</th><th>Name</th><th>Email</th><th>Role</th><th>Status</th><th>Last login</th></tr>
    <% if (users == null || users.isEmpty()) { %><tr><td colspan="6" class="mute">No users match.</td></tr><% } else for (UserMonitorDAO.UserRow u : users) { %>
    <tr><td><%= Html.esc(u.id) %></td><td><%= Html.esc(u.name) %></td><td><%= Html.esc(u.email) %></td><td><%= Html.esc(u.role) %></td>
        <td><span class="tag <%= Html.esc(u.status == null ? "" : u.status.toUpperCase()) %>"><%= Html.esc(u.status) %></span></td>
        <td><%= u.lastLogin == null ? "<span class='mute'>never recorded</span>" : Html.esc(u.lastLogin) %></td></tr>
    <% } %>
  </table></div>
  <p class="mute" style="font-size:12px">Shows up to 200 users per role. "Last login" only exists for logins made after this module was installed.</p>
</div>
</main></body></html>
