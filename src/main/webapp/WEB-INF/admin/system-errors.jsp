<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.SystemError,util.Html,util.Pager" %>
<% String pageTitle = "System Errors"; String pageSub = "Application errors captured with a reference number"; String active = "errors"; %>
<%@ include file="_head.jspf" %>
<%
    List<SystemError> rows = (List<SystemError>) request.getAttribute("rows");
    List<String> modules = (List<String>) request.getAttribute("modules");
    String error = (String) request.getAttribute("error");
    long total = (Long) request.getAttribute("total");
    int pg = (Integer) request.getAttribute("page"), pages = request.getAttribute("pages") == null ? 1 : (Integer) request.getAttribute("pages");
    int size = (Integer) request.getAttribute("size");
    String q = Pager.query("severity", (String) request.getAttribute("fSeverity"), "module", (String) request.getAttribute("fModule"),
            "q", (String) request.getAttribute("fQ"), "from", (String) request.getAttribute("fFrom"),
            "to", (String) request.getAttribute("fTo"), "size", String.valueOf(size));
%>
<% if (error != null) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><%= Html.esc(error) %></div></div><% } %>

<div class="card">
  <div class="card-h"><div><h3>Filters</h3><p>Filter errors by severity, module, date or message</p></div></div>
  <div class="card-b">
  <form class="filters" method="get" action="<%= cp %>/system/errors">
    <label>Severity<select name="severity"><option value="">All severities</option>
      <% for (String s : new String[]{"CRITICAL","HIGH","MEDIUM","LOW"}) { %><option <%= s.equals(request.getAttribute("fSeverity")) ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <label>Module<select name="module"><option value="">All modules</option>
      <% if (modules != null) for (String m : modules) { %><option <%= m.equals(request.getAttribute("fModule")) ? "selected" : "" %>><%= Html.esc(m) %></option><% } %></select></label>
    <label>From<input type="date" name="from" value="<%= Html.esc(request.getAttribute("fFrom")) %>"></label>
    <label>To<input type="date" name="to" value="<%= Html.esc(request.getAttribute("fTo")) %>"></label>
    <label>Search message<input name="q" value="<%= Html.esc(request.getAttribute("fQ")) %>" maxlength="100" placeholder="Keyword"></label>
    <label>Rows per page<select name="size"><% for (int s : new int[]{25,50,100}) { %><option <%= s == size ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <div class="factions">
      <button type="submit">Apply filters</button>
      <a class="btn ghost" href="<%= cp %>/system/errors">Reset</a>
    </div>
  </form>
  </div>
</div>

<div class="card">
  <div class="card-h"><h3>Error log <span class="count"><%= total %></span></h3></div>
  <div class="tbl-wrap"><table>
    <thead><tr><th>Ref</th><th>Time</th><th>Severity</th><th>Module</th><th>Type</th><th>Message</th><th>User</th></tr></thead><tbody>
    <% if (rows == null || rows.isEmpty()) { %><tr><td colspan="7" class="empty"><svg class="sx-ic"><use href="#sx-i-ok"/></svg>No errors recorded.</td></tr><% } else for (SystemError e : rows) { %>
    <tr>
      <td class="uid">#<%= e.getId() %></td><td class="ts"><%= Html.ts(e.getCreatedAt()) %></td>
      <td><span class="tag <%= Html.esc(e.getSeverity()) %>"><%= Html.esc(e.getSeverity()) %></span></td>
      <td><%= Html.esc(e.getModuleName()) %></td><td><code><%= Html.esc(e.getErrorType()) %></code></td>
      <td class="msg"><%= Html.esc(e.getErrorMessage()) %></td><td><%= Html.esc(e.getUserId()) %></td>
    </tr>
    <% } %></tbody>
  </table></div>
  <%= Pager.render(cp + "/system/errors", q, pg, pages) %>
</div>
<%@ include file="_foot.jspf" %>
