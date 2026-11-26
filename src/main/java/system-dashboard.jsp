<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.*,DAO.LoginHistoryDAO,util.Html" %>
<% String pageTitle = "System Dashboard"; String active = "dashboard"; %>
<%@ include file="_head.jspf" %>
<%
    long totalUsers = request.getAttribute("totalUsers") == null ? 0 : (Long) request.getAttribute("totalUsers");
    long activeUsers = request.getAttribute("activeUsers") == null ? 0 : (Long) request.getAttribute("activeUsers");
    long inactiveUsers = request.getAttribute("inactiveUsers") == null ? 0 : (Long) request.getAttribute("inactiveUsers");
    long auditTotal = request.getAttribute("auditTotal") == null ? 0 : (Long) request.getAttribute("auditTotal");
    long loginsToday = request.getAttribute("loginsToday") == null ? 0 : (Long) request.getAttribute("loginsToday");
    long failedToday = request.getAttribute("failedToday") == null ? 0 : (Long) request.getAttribute("failedToday");
    List<AuditLog> recentActivity = (List<AuditLog>) request.getAttribute("recentActivity");
    List<AuditLog> recentSecurity = (List<AuditLog>) request.getAttribute("recentSecurity");
    List<LoginHistory> recentLogins = (List<LoginHistory>) request.getAttribute("recentLogins");
    List<LoginHistoryDAO.Suspicious> sus = (List<LoginHistoryDAO.Suspicious>) request.getAttribute("suspicious");
    List<SystemError> recentErrors = (List<SystemError>) request.getAttribute("recentErrors");
    BackupHistory backup = (BackupHistory) request.getAttribute("latestBackup");
%>
<% if (request.getAttribute("error") != null) { %><div class="alert err"><%= Html.esc(request.getAttribute("error")) %></div><% } %>
<% if (sus != null && !sus.isEmpty()) { %><div class="alert err"><b><%= sus.size() %> suspicious login pattern(s)</b> (repeated failed logins). <a href="<%= cp %>/system/login-history">Review</a></div><% } %>

<div class="grid">
  <div class="stat"><b><%= totalUsers %></b><span>Total users</span></div>
  <div class="stat"><b><%= activeUsers %></b><span>Active users</span></div>
  <div class="stat"><b><%= inactiveUsers %></b><span>Inactive users</span></div>
  <div class="stat"><b><%= auditTotal %></b><span>Audit records</span></div>
  <div class="stat"><b><%= loginsToday %></b><span>Logins today</span></div>
  <div class="stat"><b style="color:<%= failedToday > 0 ? "var(--bad)" : "inherit" %>"><%= failedToday %></b><span>Failed logins today</span></div>
</div>

<div class="two">
  <div class="card"><h3>Recent system activity</h3><div class="scroll"><table>
    <tr><th>Time</th><th>User</th><th>Module</th><th>Action</th></tr>
    <% if (recentActivity == null || recentActivity.isEmpty()) { %><tr><td colspan="4" class="mute">Nothing recorded yet.</td></tr><% } else for (AuditLog a : recentActivity) { %>
    <tr><td><%= Html.esc(a.getCreatedAt()) %></td><td><%= Html.esc(a.getUserId()) %></td><td><%= Html.esc(a.getModuleName()) %></td><td><span class="tag <%= Html.esc(a.getActionType()) %>"><%= Html.esc(a.getActionType()) %></span></td></tr>
    <% } %></table></div><p><a href="<%= cp %>/system/audit-logs">All audit logs &rarr;</a></p></div>

  <div class="card"><h3>Recent logins</h3><div class="scroll"><table>
    <tr><th>Time</th><th>Type</th><th>Login ID</th><th>IP</th></tr>
    <% if (recentLogins == null || recentLogins.isEmpty()) { %><tr><td colspan="4" class="mute">Nothing recorded yet.</td></tr><% } else for (LoginHistory h : recentLogins) { %>
    <tr><td><%= Html.esc(h.getCreatedAt()) %></td><td><span class="tag <%= Html.esc(h.getActivityType()) %>"><%= Html.esc(h.getActivityType()) %></span></td><td><%= Html.esc(h.getEmail()) %></td><td><%= Html.esc(h.getIpAddress()) %></td></tr>
    <% } %></table></div><p><a href="<%= cp %>/system/login-history">Full login history &rarr;</a></p></div>

  <div class="card"><h3>Security events</h3><div class="scroll"><table>
    <tr><th>Time</th><th>Event</th><th>Details</th></tr>
    <% if (recentSecurity == null || recentSecurity.isEmpty()) { %><tr><td colspan="3" class="mute">No security events.</td></tr><% } else for (AuditLog a : recentSecurity) { %>
    <tr><td><%= Html.esc(a.getCreatedAt()) %></td><td><span class="tag HIGH"><%= Html.esc(a.getActionType()) %></span></td><td><%= Html.esc(a.getDescription()) %></td></tr>
    <% } %></table></div><p><a href="<%= cp %>/system/audit-logs?module=SECURITY">All security events &rarr;</a></p></div>

  <div class="card"><h3>Recent errors</h3><div class="scroll"><table>
    <tr><th>Time</th><th>Severity</th><th>Module</th><th>Message</th></tr>
    <% if (recentErrors == null || recentErrors.isEmpty()) { %><tr><td colspan="4" class="mute">No errors recorded.</td></tr><% } else for (SystemError e : recentErrors) { %>
    <tr><td><%= Html.esc(e.getCreatedAt()) %></td><td><span class="tag <%= Html.esc(e.getSeverity()) %>"><%= Html.esc(e.getSeverity()) %></span></td><td><%= Html.esc(e.getModuleName()) %></td><td><%= Html.esc(e.getErrorMessage() != null && e.getErrorMessage().length() > 80 ? e.getErrorMessage().substring(0, 80) + "..." : e.getErrorMessage()) %></td></tr>
    <% } %></table></div><p><a href="<%= cp %>/system/errors">All errors &rarr;</a></p></div>

  <div class="card"><h3>Latest backup</h3>
    <% if (backup == null) { %><p class="mute">No backup has been taken yet.</p><% } else { %>
    <p><span class="tag <%= Html.esc(backup.getStatus()) %>"><%= Html.esc(backup.getStatus()) %></span> &nbsp; <%= Html.esc(backup.getCreatedAt()) %><br>
       <code><%= Html.esc(backup.getBackupFile()) %></code></p><% } %>
    <% if ("ADMIN".equals(role)) { %><p><a href="<%= cp %>/system/backups">Manage backups &rarr;</a></p><% } %></div>

  <div class="card"><h3>Configuration overview</h3>
    <p>Company: <b><%= Html.esc(request.getAttribute("companyName")) %></b><br>Session timeout: <b><%= request.getAttribute("sessionTimeout") %> min</b></p>
    <% if ("ADMIN".equals(role)) { %><p><a href="<%= cp %>/system/settings">Settings &amp; users &rarr;</a></p><% } %></div>
</div>
</main></body></html>
