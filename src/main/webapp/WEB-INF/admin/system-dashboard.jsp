<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.*,DAO.LoginHistoryDAO,util.Html" %>
<% String pageTitle = "System Dashboard"; String pageSub = "Security, activity and platform health at a glance"; String active = "dashboard"; %>
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
<% if (request.getAttribute("error") != null) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><%= Html.esc(request.getAttribute("error")) %></div></div><% } %>
<% if (sus != null && !sus.isEmpty()) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-alert"/></svg><div><b><%= sus.size() %> suspicious login pattern(s)</b> detected (repeated failed logins). <a href="<%= cp %>/system/login-history">Review now</a></div></div><% } %>

<div class="sx-stats">
  <div class="sx-stat t-indigo"><div class="ico"><svg class="sx-ic"><use href="#sx-i-users"/></svg></div><div><b><%= totalUsers %></b><span>Total users</span></div></div>
  <div class="sx-stat t-green"><div class="ico"><svg class="sx-ic"><use href="#sx-i-ucheck"/></svg></div><div><b><%= activeUsers %></b><span>Active users</span></div></div>
  <div class="sx-stat t-slate"><div class="ico"><svg class="sx-ic"><use href="#sx-i-ux"/></svg></div><div><b><%= inactiveUsers %></b><span>Inactive users</span></div></div>
  <div class="sx-stat t-violet"><div class="ico"><svg class="sx-ic"><use href="#sx-i-file"/></svg></div><div><b><%= auditTotal %></b><span>Audit records</span></div></div>
  <div class="sx-stat t-blue"><div class="ico"><svg class="sx-ic"><use href="#sx-i-login"/></svg></div><div><b><%= loginsToday %></b><span>Logins today</span></div></div>
  <div class="sx-stat <%= failedToday > 0 ? "t-red" : "t-green" %>"><div class="ico"><svg class="sx-ic"><use href="#sx-i-alert"/></svg></div><div><b style="color:<%= failedToday > 0 ? "var(--s-bad-t)" : "inherit" %>"><%= failedToday %></b><span>Failed logins today</span></div></div>
</div>

<div class="two">
  <div class="card">
    <div class="card-h"><div><h3>Recent system activity</h3><p>Latest recorded actions</p></div></div>
    <div class="tbl-wrap"><table>
      <thead><tr><th>Time</th><th>User</th><th>Module</th><th>Action</th></tr></thead><tbody>
      <% if (recentActivity == null || recentActivity.isEmpty()) { %><tr><td colspan="4" class="empty"><svg class="sx-ic"><use href="#sx-i-inbox"/></svg>Nothing recorded yet.</td></tr><% } else for (AuditLog a : recentActivity) { %>
      <tr><td class="ts"><%= Html.ts(a.getCreatedAt()) %></td><td class="uid"><%= Html.esc(a.getUserId()) %></td><td><%= Html.esc(a.getModuleName()) %></td><td><span class="tag <%= Html.esc(a.getActionType()) %>"><%= Html.esc(a.getActionType()) %></span></td></tr>
      <% } %></tbody></table></div>
    <div class="card-f"><a href="<%= cp %>/system/audit-logs">View all audit logs &rarr;</a></div>
  </div>

  <div class="card">
    <div class="card-h"><div><h3>Recent logins</h3><p>Sign-in and sign-out activity</p></div></div>
    <div class="tbl-wrap"><table>
      <thead><tr><th>Time</th><th>Type</th><th>Login ID</th></tr></thead><tbody>
      <% if (recentLogins == null || recentLogins.isEmpty()) { %><tr><td colspan="3" class="empty"><svg class="sx-ic"><use href="#sx-i-inbox"/></svg>Nothing recorded yet.</td></tr><% } else for (LoginHistory h : recentLogins) { %>
      <tr><td class="ts"><%= Html.ts(h.getCreatedAt()) %></td><td><span class="tag <%= Html.esc(h.getActivityType()) %>"><%= Html.esc(h.getActivityType()) %></span></td><td><%= Html.esc(h.getEmail()) %></td></tr>
      <% } %></tbody></table></div>
    <div class="card-f"><a href="<%= cp %>/system/login-history">Full login history &rarr;</a></div>
  </div>

  <div class="card">
    <div class="card-h"><div><h3>Security events</h3><p>Access denials, CSRF failures, brute-force attempts</p></div></div>
    <div class="tbl-wrap"><table>
      <thead><tr><th>Time</th><th>Event</th><th>Details</th></tr></thead><tbody>
      <% if (recentSecurity == null || recentSecurity.isEmpty()) { %><tr><td colspan="3" class="empty"><svg class="sx-ic"><use href="#sx-i-shield"/></svg>No security events.</td></tr><% } else for (AuditLog a : recentSecurity) { %>
      <tr><td class="ts"><%= Html.ts(a.getCreatedAt()) %></td><td><span class="tag HIGH"><%= Html.label(a.getActionType()) %></span></td><td class="msg"><%= Html.esc(a.getDescription()) %></td></tr>
      <% } %></tbody></table></div>
    <div class="card-f"><a href="<%= cp %>/system/audit-logs?module=SECURITY">All security events &rarr;</a></div>
  </div>

  <div class="card">
    <div class="card-h"><div><h3>Recent errors</h3><p>Latest application errors</p></div></div>
    <div class="tbl-wrap"><table>
      <thead><tr><th>Time</th><th>Severity</th><th>Module</th><th>Message</th></tr></thead><tbody>
      <% if (recentErrors == null || recentErrors.isEmpty()) { %><tr><td colspan="4" class="empty"><svg class="sx-ic"><use href="#sx-i-ok"/></svg>No errors recorded.</td></tr><% } else for (SystemError e : recentErrors) { %>
      <tr><td class="ts"><%= Html.ts(e.getCreatedAt()) %></td><td><span class="tag <%= Html.esc(e.getSeverity()) %>"><%= Html.esc(e.getSeverity()) %></span></td><td><%= Html.esc(e.getModuleName()) %></td><td class="msg"><%= Html.esc(e.getErrorMessage() != null && e.getErrorMessage().length() > 80 ? e.getErrorMessage().substring(0, 80) + "..." : e.getErrorMessage()) %></td></tr>
      <% } %></tbody></table></div>
    <div class="card-f"><a href="<%= cp %>/system/errors">All errors &rarr;</a></div>
  </div>

  <div class="card">
    <div class="card-h"><div><h3>Latest backup</h3><p>Most recent database backup</p></div></div>
    <div class="card-b">
    <% if (backup == null) { %><p class="mute" style="margin:0">No backup has been taken yet.</p><% } else { %>
      <dl class="kv">
        <dt>Status</dt><dd><span class="tag <%= Html.esc(backup.getStatus()) %>"><%= Html.esc(backup.getStatus()) %></span></dd>
        <dt>Taken at</dt><dd><%= Html.ts(backup.getCreatedAt()) %></dd>
        <dt>File</dt><dd><code><%= Html.esc(backup.getBackupFile()) %></code></dd>
      </dl>
    <% } %>
    </div>
    <% if ("ADMIN".equals(role)) { %><div class="card-f"><a href="<%= cp %>/system/backups">Manage backups &rarr;</a></div><% } %>
  </div>

  <div class="card">
    <div class="card-h"><div><h3>Configuration overview</h3><p>Key system settings</p></div></div>
    <div class="card-b">
      <dl class="kv">
        <dt>Company</dt><dd><%= Html.esc(request.getAttribute("companyName")) %></dd>
        <dt>Session timeout</dt><dd><%= request.getAttribute("sessionTimeout") %> min</dd>
      </dl>
    </div>
    <% if ("ADMIN".equals(role)) { %><div class="card-f"><a href="<%= cp %>/system/settings">System settings &rarr;</a></div><% } %>
  </div>
</div>
<%@ include file="_foot.jspf" %>
