<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.BackupHistory,util.Html" %>
<% String pageTitle = "Database Backups"; String active = "backups"; %>
<%@ include file="_head.jspf" %>
<%
    List<BackupHistory> history = (List<BackupHistory>) request.getAttribute("history");
    boolean restoreEnabled = (Boolean) request.getAttribute("restoreEnabled");
%>
<% if (request.getAttribute("message") != null) { %><div class="alert ok"><%= Html.esc(request.getAttribute("message")) %></div><% } %>
<% if (request.getAttribute("error") != null) { %><div class="alert err"><%= Html.esc(request.getAttribute("error")) %></div><% } %>

<div class="card">
  <h2>Run a backup</h2>
  <p class="mute">Creates a full dump of the database on the server. Backup files are stored outside the web application and cannot be downloaded from here.</p>
  <form method="post" action="<%= cp %>/system/backups" onsubmit="this.querySelector('button').disabled=true;this.querySelector('button').textContent='Backing up...';">
    <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
    <input type="hidden" name="action" value="backup">
    <button type="submit">Start full backup</button>
  </form>
</div>

<div class="card">
  <h2>Backup history</h2>
  <div class="scroll"><table>
    <tr><th>ID</th><th>Time</th><th>File</th><th>Type</th><th>Status</th><th>Size</th><th>By</th><th>Remarks</th><th>Restore</th></tr>
    <% if (history == null || history.isEmpty()) { %><tr><td colspan="9" class="mute">No backups yet.</td></tr><% } else for (BackupHistory b : history) { %>
    <tr>
      <td><%= b.getId() %></td><td><%= Html.esc(b.getCreatedAt()) %></td><td><code><%= Html.esc(b.getBackupFile()) %></code></td>
      <td><%= Html.esc(b.getBackupType()) %></td>
      <td><span class="tag <%= Html.esc(b.getStatus()) %>"><%= Html.esc(b.getStatus()) %></span></td>
      <td><%= b.getFileSize() >= 1048576 ? String.format("%.1f MB", b.getFileSize() / 1048576.0) : String.format("%.1f KB", b.getFileSize() / 1024.0) %></td>
      <td><%= Html.esc(b.getCreatedBy()) %></td><td style="max-width:300px"><%= Html.esc(b.getRemarks()) %></td>
      <td>
        <% if ("SUCCESS".equals(b.getStatus()) && restoreEnabled) { %>
        <form method="post" action="<%= cp %>/system/backups" onsubmit="return confirm('Restoring replaces ALL current data with this backup. A safety backup is taken first. Continue?');">
          <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
          <input type="hidden" name="action" value="restore">
          <input type="hidden" name="backupId" value="<%= b.getId() %>">
          <input name="confirmText" placeholder="RESTORE <%= Html.esc(b.getBackupFile()) %>" size="34" required autocomplete="off">
          <button class="danger" type="submit">Restore</button>
        </form>
        <% } else if ("SUCCESS".equals(b.getStatus())) { %><span class="mute">disabled on this server</span><% } %>
      </td>
    </tr>
    <% } %>
  </table></div>
  <% if (!restoreEnabled) { %><p class="mute" style="font-size:12px">Restore is switched off. A server administrator can enable it with <code>-Dsmartoffice.restore.enabled=true</code>.</p><% } %>
</div>
</main></body></html>
