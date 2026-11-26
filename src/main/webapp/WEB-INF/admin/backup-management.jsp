<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.BackupHistory,util.Html" %>
<% String pageTitle = "Database Backups"; String pageSub = "Create full backups and review backup history"; String active = "backups"; %>
<%@ include file="_head.jspf" %>
<%
    List<BackupHistory> history = (List<BackupHistory>) request.getAttribute("history");
    boolean restoreEnabled = (Boolean) request.getAttribute("restoreEnabled");
%>
<% if (request.getAttribute("message") != null) { %><div class="alert ok"><svg class="sx-ic"><use href="#sx-i-ok"/></svg><div><%= Html.esc(request.getAttribute("message")) %></div></div><% } %>
<% if (request.getAttribute("error") != null) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><%= Html.esc(request.getAttribute("error")) %></div></div><% } %>

<div class="card">
  <div class="card-b" style="display:flex;align-items:center;gap:18px;flex-wrap:wrap">
    <div class="sx-stat t-indigo" style="border:0;box-shadow:none;padding:0"><div class="ico"><svg class="sx-ic"><use href="#sx-i-db"/></svg></div></div>
    <div style="flex:1;min-width:240px">
      <h3 style="margin:0 0 4px;font-size:15px">Run a backup</h3>
      <p class="hint" style="margin:0">Creates a full dump of the database on the server. Backup files are stored outside the web application; any successful backup can be downloaded from the history below.</p>
    </div>
    <form method="post" action="<%= cp %>/system/backups" onsubmit="this.querySelector('button').disabled=true;this.querySelector('button').textContent='Backing up...';">
      <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
      <input type="hidden" name="action" value="backup">
      <button type="submit"><svg class="sx-ic"><use href="#sx-i-db"/></svg>Start full backup</button>
    </form>
  </div>
</div>

<div class="card">
  <div class="card-h"><h3>Backup history <span class="count"><%= history == null ? 0 : history.size() %></span></h3></div>
  <div class="tbl-wrap"><table>
    <thead><tr><th>ID</th><th>Time</th><th>File</th><th>Type</th><th>Status</th><th>Size</th><th>By</th><th>Remarks</th><th>Download</th><th>Restore</th></tr></thead><tbody>
    <% if (history == null || history.isEmpty()) { %><tr><td colspan="10" class="empty"><svg class="sx-ic"><use href="#sx-i-inbox"/></svg>No backups yet.</td></tr><% } else for (BackupHistory b : history) { %>
    <tr>
      <td class="uid"><%= b.getId() %></td><td class="ts"><%= Html.ts(b.getCreatedAt()) %></td><td><code><%= Html.esc(b.getBackupFile()) %></code></td>
      <td><%= Html.esc(b.getBackupType()) %></td>
      <td><span class="tag <%= Html.esc(b.getStatus()) %>"><%= Html.esc(b.getStatus()) %></span></td>
      <td class="nowrap"><%= b.getFileSize() >= 1048576 ? String.format("%.1f MB", b.getFileSize() / 1048576.0) : String.format("%.1f KB", b.getFileSize() / 1024.0) %></td>
      <td><%= Html.esc(b.getCreatedBy()) %></td><td class="msg mute"><%= Html.esc(b.getRemarks()) %></td>
      <td>
        <% if ("SUCCESS".equals(b.getStatus())) { %>
        <a class="btn ghost sm" href="<%= cp %>/system/backups?download=<%= b.getId() %>" title="Download <%= Html.esc(b.getBackupFile()) %>"><svg class="sx-ic" style="width:15px;height:15px"><use href="#sx-i-dl"/></svg>Download</a>
        <% } else { %><span class="mute small">&mdash;</span><% } %>
      </td>
      <td>
        <% if ("SUCCESS".equals(b.getStatus()) && restoreEnabled) { %>
        <form class="restore" method="post" action="<%= cp %>/system/backups" onsubmit="return confirm('Restoring replaces ALL current data with this backup. A safety backup is taken first. Continue?');">
          <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
          <input type="hidden" name="action" value="restore">
          <input type="hidden" name="backupId" value="<%= b.getId() %>">
          <input name="confirmText" placeholder="RESTORE <%= Html.esc(b.getBackupFile()) %>" size="34" required autocomplete="off">
          <button class="danger sm" type="submit">Restore</button>
        </form>
        <% } else if ("SUCCESS".equals(b.getStatus())) { %><span class="mute small">Disabled on this server</span><% } %>
      </td>
    </tr>
    <% } %></tbody>
  </table></div>
  <div class="card-f mute small">Backup files contain all application data, including password hashes. Keep downloaded files private. Every download is recorded in the audit log.</div>
  <% if (!restoreEnabled) { %><div class="card-f mute small">Restore is switched off. A server administrator can enable it with <code>-Dsmartoffice.restore.enabled=true</code>.</div><% } %>
</div>
<%@ include file="_foot.jspf" %>
