<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.AuditLog,util.Html,util.Pager" %>
<% String pageTitle = "Audit Logs"; String pageSub = "A tamper-evident trail of who did what, and when"; String active = "audit"; %>
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
    String[] actions = { "CREATE", "UPDATE", "DELETE", "EXPORT", "ACCESS_DENIED", "CSRF_FAILURE", "REPEATED_FAILED_LOGIN", "UNKNOWN_USER_LOGIN", "RESTORE" };
%>
<% if (!full) { %><div class="alert warn"><svg class="sx-ic"><use href="#sx-i-info"/></svg><div>You are viewing your own activity<%= "MANAGER".equals(role) ? " and the activity of your team members" : "" %>.</div></div><% } %>
<% if (error != null) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><%= Html.esc(error) %></div></div><% } %>

<div class="card">
  <div class="card-h"><div><h3>Filters</h3><p>Narrow the log by user, module, action, date or description</p></div></div>
  <div class="card-b">
  <form class="filters" method="get" action="<%= cp %>/system/audit-logs">
    <% if (full) { %><label>User ID<input name="user" value="<%= Html.esc(request.getAttribute("fUser")) %>" maxlength="50" placeholder="e.g. EMP101"></label><% } %>
    <label>Module
      <select name="module"><option value="">All modules</option>
      <% if (modules != null) for (String m : modules) { %><option <%= m.equals(request.getAttribute("fModule")) ? "selected" : "" %>><%= Html.esc(m) %></option><% } %>
      </select></label>
    <label>Action
      <select name="action"><option value="">All actions</option>
      <% for (String a : actions) { %><option value="<%= a %>" <%= a.equals(request.getAttribute("fAction")) ? "selected" : "" %>><%= Html.label(a) %></option><% } %>
      </select></label>
    <label>From<input type="date" name="from" value="<%= Html.esc(request.getAttribute("fFrom")) %>"></label>
    <label>To<input type="date" name="to" value="<%= Html.esc(request.getAttribute("fTo")) %>"></label>
    <label>Search description<input name="q" value="<%= Html.esc(request.getAttribute("fQ")) %>" maxlength="100" placeholder="Keyword"></label>
    <label>Rows per page<select name="size"><% for (int s : new int[]{25,50,100}) { %><option <%= s == size ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <div class="factions">
      <button type="submit">Apply filters</button>
      <a class="btn ghost" href="<%= cp %>/system/audit-logs">Reset</a>
      <a class="btn ghost push" href="<%= cp %>/system/audit-logs?<%= Html.esc(q) %>&amp;export=csv"><svg class="sx-ic"><use href="#sx-i-dl"/></svg>Export CSV</a>
    </div>
  </form>
  </div>
</div>

<div class="card">
  <div class="card-h"><h3>Audit records <span class="count"><%= total %></span></h3></div>
  <div class="tbl-wrap"><table>
    <thead><tr><th>Time</th><th>User</th><th>Module</th><th>Action</th><th>Description</th><th>Changes</th></tr></thead><tbody>
    <% if (logs == null || logs.isEmpty()) { %><tr><td colspan="6" class="empty"><svg class="sx-ic"><use href="#sx-i-inbox"/></svg>No audit records found.</td></tr><% } else for (AuditLog a : logs) { %>
    <tr>
      <td class="ts"><%= Html.ts(a.getCreatedAt()) %></td>
      <td>
        <% boolean unknownUser = a.getUserId() == null && ("UNKNOWN_USER_LOGIN".equals(a.getActionType()) || "REPEATED_FAILED_LOGIN".equals(a.getActionType())); %>
        <% if (unknownUser) { %><div class="uid" style="color:var(--s-warn-t)">Unknown user</div><div class="mute small">Not a registered account</div>
        <% } else { %><div class="uid"><%= Html.esc(a.getUserId() == null ? "-" : a.getUserId()) %></div><div class="mute small"><%= Html.esc(a.getUserRole()) %></div><% } %>
      </td>
      <td><%= Html.esc(a.getModuleName()) %></td>
      <td><span class="tag <%= Html.esc(a.getActionType()) %>"><%= Html.label(a.getActionType()) %></span></td>
      <td class="msg"><%= Html.esc(a.getDescription()) %></td>
      <td>
        <% if (a.getOldValues() != null || a.getNewValues() != null) { %>
        <details class="chg"><summary>View changes</summary>
          <% if (a.getOldValues() != null) { %><div class="lbl">Before</div><pre class="before"><%= Html.esc(a.getOldValues()) %></pre><% } %>
          <% if (a.getNewValues() != null) { %><div class="lbl">After</div><pre class="after"><%= Html.esc(a.getNewValues()) %></pre><% } %>
        </details>
        <% } else { %><span class="mute">&mdash;</span><% } %>
      </td>
    </tr>
    <% } %></tbody>
  </table></div>
  <%= Pager.render(cp + "/system/audit-logs", q, pg, pages) %>
</div>
<%@ include file="_foot.jspf" %>
