<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.LoginHistory,DAO.LoginHistoryDAO,util.Html,util.Pager" %>
<% String pageTitle = "Login History"; String active = "login"; %>
<%@ include file="_head.jspf" %>
<%
    List<LoginHistory> rows = (List<LoginHistory>) request.getAttribute("rows");
    List<LoginHistoryDAO.Suspicious> sus = (List<LoginHistoryDAO.Suspicious>) request.getAttribute("suspicious");
    String error = (String) request.getAttribute("error");
    long total = (Long) request.getAttribute("total");
    int pg = (Integer) request.getAttribute("page"), pages = request.getAttribute("pages") == null ? 1 : (Integer) request.getAttribute("pages");
    int size = (Integer) request.getAttribute("size");
    String q = Pager.query("email", (String) request.getAttribute("fEmail"), "type", (String) request.getAttribute("fType"),
            "from", (String) request.getAttribute("fFrom"), "to", (String) request.getAttribute("fTo"), "size", String.valueOf(size));
    String[] types = { "LOGIN", "LOGOUT", "FAILED_LOGIN", "SESSION_EXPIRED" };
%>
<% if (error != null) { %><div class="alert err"><%= Html.esc(error) %></div><% } %>
<% if (sus != null && !sus.isEmpty()) { %>
<div class="alert err"><b>Suspicious activity:</b> <%= request.getAttribute("threshold") %> or more failed logins within <%= request.getAttribute("window") %> minutes
  <ul style="margin:6px 0 0"><% for (LoginHistoryDAO.Suspicious s : sus) { %>
    <li><%= Html.esc(s.email) %> from <%= Html.esc(s.ip) %> &mdash; <%= s.attempts %> attempts, last <%= Html.esc(s.last) %></li><% } %></ul></div>
<% } %>
<div class="card">
  <form class="filters" method="get" action="<%= cp %>/system/login-history">
    <label>Email / login ID<input name="email" value="<%= Html.esc(request.getAttribute("fEmail")) %>" maxlength="150"></label>
    <label>Type<select name="type"><option value="">All</option>
      <% for (String t : types) { %><option <%= t.equals(request.getAttribute("fType")) ? "selected" : "" %>><%= t %></option><% } %></select></label>
    <label>From<input type="date" name="from" value="<%= Html.esc(request.getAttribute("fFrom")) %>"></label>
    <label>To<input type="date" name="to" value="<%= Html.esc(request.getAttribute("fTo")) %>"></label>
    <label>Rows<select name="size"><% for (int s : new int[]{25,50,100}) { %><option <%= s == size ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <button type="submit">Filter</button>
    <a class="btn ghost" href="<%= cp %>/system/login-history">Reset</a>
  </form>
</div>
<div class="card">
  <h3><%= total %> record(s)</h3>
  <div class="scroll"><table>
    <tr><th>Time</th><th>Type</th><th>User</th><th>Login ID entered</th><th>IP</th><th>Browser / device</th></tr>
    <% if (rows == null || rows.isEmpty()) { %><tr><td colspan="6" class="mute">No login activity found.</td></tr><% } else for (LoginHistory h : rows) { %>
    <tr>
      <td><%= Html.esc(h.getCreatedAt()) %></td>
      <td><span class="tag <%= Html.esc(h.getActivityType()) %>"><%= Html.esc(h.getActivityType()) %></span></td>
      <td><%= Html.esc(h.getUserId() == null ? "-" : h.getUserId()) %> <span class="mute"><%= Html.esc(h.getUserRole()) %></span></td>
      <td><%= Html.esc(h.getEmail()) %></td>
      <td><%= Html.esc(h.getIpAddress()) %></td>
      <td class="mute" style="max-width:320px"><%= Html.esc(h.getUserAgent()) %></td>
    </tr>
    <% } %>
  </table></div>
  <%= Pager.render(cp + "/system/login-history", q, pg, pages) %>
</div>
</main></body></html>
