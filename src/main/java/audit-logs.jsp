<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.AuditLog,util.Html,util.Pager" %>
<% String pageTitle = "Audit Logs"; String active = "audit"; %>
<%@ include file="_head.jspf" %>
<%
    List<AuditLog> logs = (List<AuditLog>) request.getAttribute("logs");
    List<String> modules = (List<String>) request.getAttribute("modules");
    String error = (String) request.getAttribute("error");
    long total = (Long) request.getAttribute("total");
    int pg = (Integer) request.getAttribute("page"), pages = request.getAttribute("pages") == null ? 1 : (Integer) request.getAttribute("pages");
    int size = (Integer) request.getAttribute("size");
    boolean full = (Boolean) request.getAttribute("fullAccess");
    String q = Pager.query("user", (String) request.getAttribute("fUser"), "module", (String) request.getAttribute("fModule"),
            "action", (String) request.getAttribute("fAction"), "q", (String) request.getAttribute("fQ"),
            "from", (String) request.getAttribute("fFrom"), "to", (String) request.getAttribute("fTo"), "size", String.valueOf(size));
    String[] actions = { "CREATE", "UPDATE", "DELETE", "EXPORT", "ACCESS_DENIED", "CSRF_FAILURE", "REPEATED_FAILED_LOGIN", "RESTORE" };
%>
<% if (!full) { %><div class="alert warn">You are viewing your own activity<%= "MANAGER".equals(role) ? " and the activity of your team members" : "" %>.</div><% } %>
<% if (error != null) { %><div class="alert err"><%= Html.esc(error) %></div><% } %>
<div class="card">
  <form class="filters" method="get" action="<%= cp %>/system/audit-logs">
    <% if (full) { %><label>User ID<input name="user" value="<%= Html.esc(request.getAttribute("fUser")) %>" maxlength="50"></label><% } %>
    <label>Module
      <select name="module"><option value="">All</option>
      <% if (modules != null) for (String m : modules) { %><option <%= m.equals(request.getAttribute("fModule")) ? "selected" : "" %>><%= Html.esc(m) %></option><% } %>
      </select></label>
    <label>Action
      <select name="action"><option value="">All</option>
      <% for (String a : actions) { %><option <%= a.equals(request.getAttribute("fAction")) ? "selected" : "" %>><%= a %></option><% } %>
      </select></label>
    <label>From<input type="date" name="from" value="<%= Html.esc(request.getAttribute("fFrom")) %>"></label>
    <label>To<input type="date" name="to" value="<%= Html.esc(request.getAttribute("fTo")) %>"></label>
    <label>Search description<input name="q" value="<%= Html.esc(request.getAttribute("fQ")) %>" maxlength="100"></label>
    <label>Rows<select name="size"><% for (int s : new int[]{25,50,100}) { %><option <%= s == size ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <button type="submit">Filter</button>
    <a class="btn ghost" href="<%= cp %>/system/audit-logs">Reset</a>
    <a class="btn ghost" href="<%= cp %>/system/audit-logs?<%= Html.esc(q) %>&amp;export=csv">Export CSV</a>
  </form>
</div>
<div class="card">
  <h3><%= total %> record(s)</h3>
  <div class="scroll"><table>
    <tr><th>Time</th><th>User</th><th>Module</th><th>Action</th><th>Record</th><th>Description</th><th>Changes</th><th>IP</th></tr>
    <% if (logs == null || logs.isEmpty()) { %><tr><td colspan="8" class="mute">No audit records found.</td></tr><% } else for (AuditLog a : logs) { %>
    <tr>
      <td><%= Html.esc(a.getCreatedAt()) %></td>
      <td><%= Html.esc(a.getUserId() == null ? "-" : a.getUserId()) %><br><span class="mute"><%= Html.esc(a.getUserRole()) %></span></td>
      <td><%= Html.esc(a.getModuleName()) %></td>
      <td><span class="tag <%= Html.esc(a.getActionType()) %>"><%= Html.esc(a.getActionType()) %></span></td>
      <td><%= Html.esc(a.getRecordId()) %></td>
      <td><%= Html.esc(a.getDescription()) %></td>
      <td><% if (a.getOldValues() != null) { %><div class="mute">before</div><pre><%= Html.esc(a.getOldValues()) %></pre><% } %>
          <% if (a.getNewValues() != null) { %><div class="mute">after</div><pre><%= Html.esc(a.getNewValues()) %></pre><% } %></td>
      <td><%= Html.esc(a.getIpAddress()) %></td>
    </tr>
    <% } %>
  </table></div>
  <%= Pager.render(cp + "/system/audit-logs", q, pg, pages) %>
</div>
</main></body></html>
