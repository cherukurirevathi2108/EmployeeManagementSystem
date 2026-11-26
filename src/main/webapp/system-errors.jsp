<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.SystemError,util.Html,util.Pager" %>
<% String pageTitle = "System Errors"; String active = "errors"; %>
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
<% if (error != null) { %><div class="alert err"><%= Html.esc(error) %></div><% } %>
<div class="card">
  <form class="filters" method="get" action="<%= cp %>/system/errors">
    <label>Severity<select name="severity"><option value="">All</option>
      <% for (String s : new String[]{"CRITICAL","HIGH","MEDIUM","LOW"}) { %><option <%= s.equals(request.getAttribute("fSeverity")) ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <label>Module<select name="module"><option value="">All</option>
      <% if (modules != null) for (String m : modules) { %><option <%= m.equals(request.getAttribute("fModule")) ? "selected" : "" %>><%= Html.esc(m) %></option><% } %></select></label>
    <label>From<input type="date" name="from" value="<%= Html.esc(request.getAttribute("fFrom")) %>"></label>
    <label>To<input type="date" name="to" value="<%= Html.esc(request.getAttribute("fTo")) %>"></label>
    <label>Search message<input name="q" value="<%= Html.esc(request.getAttribute("fQ")) %>" maxlength="100"></label>
    <label>Rows<select name="size"><% for (int s : new int[]{25,50,100}) { %><option <%= s == size ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <button type="submit">Filter</button>
    <a class="btn ghost" href="<%= cp %>/system/errors">Reset</a>
  </form>
</div>
<div class="card">
  <h3><%= total %> error(s)</h3>
  <div class="scroll"><table>
    <tr><th>Ref</th><th>Time</th><th>Severity</th><th>Module</th><th>Type</th><th>Message</th><th>User</th></tr>
    <% if (rows == null || rows.isEmpty()) { %><tr><td colspan="7" class="mute">No errors recorded.</td></tr><% } else for (SystemError e : rows) { %>
    <tr>
      <td>#<%= e.getId() %></td><td><%= Html.esc(e.getCreatedAt()) %></td>
      <td><span class="tag <%= Html.esc(e.getSeverity()) %>"><%= Html.esc(e.getSeverity()) %></span></td>
      <td><%= Html.esc(e.getModuleName()) %></td><td><code><%= Html.esc(e.getErrorType()) %></code></td>
      <td style="max-width:420px"><%= Html.esc(e.getErrorMessage()) %></td><td><%= Html.esc(e.getUserId()) %></td>
    </tr>
    <% } %>
  </table></div>
  <%= Pager.render(cp + "/system/errors", q, pg, pages) %>
</div>
</main></body></html>
