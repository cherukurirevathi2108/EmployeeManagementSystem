<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,model.LoginHistory,DAO.LoginHistoryDAO,util.Html,util.Pager" %>
<% String pageTitle = "Login History"; String pageSub = "Sign-ins, sign-outs, failed attempts and session expiries"; String active = "login"; %>
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
<% if (error != null) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><%= Html.esc(error) %></div></div><% } %>
<% if (sus != null && !sus.isEmpty()) { %>
<div class="alert err"><svg class="sx-ic"><use href="#sx-i-alert"/></svg><div><b>Suspicious activity:</b> <%= request.getAttribute("threshold") %> or more failed logins within <%= request.getAttribute("window") %> minute(s)
  <ul><% for (LoginHistoryDAO.Suspicious s : sus) { %>
    <li><b><%= Html.esc(s.email) %></b> from <%= Html.esc(s.ip) %> &mdash; <%= s.attempts %> attempts, last <%= Html.esc(s.last) %></li><% } %></ul></div></div>
<% } %>

<div class="card">
  <div class="card-h"><div><h3>Filters</h3><p>Search by login ID, activity type or date range</p></div></div>
  <div class="card-b">
  <form class="filters" method="get" action="<%= cp %>/system/login-history">
    <label>Email / login ID<input name="email" value="<%= Html.esc(request.getAttribute("fEmail")) %>" maxlength="150" placeholder="Search login ID"></label>
    <label>Type<select name="type"><option value="">All types</option>
      <% for (String t : types) { %><option <%= t.equals(request.getAttribute("fType")) ? "selected" : "" %>><%= t %></option><% } %></select></label>
    <label>From<input type="date" name="from" value="<%= Html.esc(request.getAttribute("fFrom")) %>"></label>
    <label>To<input type="date" name="to" value="<%= Html.esc(request.getAttribute("fTo")) %>"></label>
    <label>Rows per page<select name="size"><% for (int s : new int[]{25,50,100}) { %><option <%= s == size ? "selected" : "" %>><%= s %></option><% } %></select></label>
    <div class="factions">
      <button type="submit">Apply filters</button>
      <a class="btn ghost" href="<%= cp %>/system/login-history">Reset</a>
    </div>
  </form>
  </div>
</div>

<div class="card">
  <div class="card-h"><h3>Login activity <span class="count"><%= total %></span></h3></div>
  <div class="tbl-wrap"><table>
    <thead><tr><th>Time</th><th>Type</th><th>User</th><th>Login ID entered</th><th>Browser / device</th></tr></thead><tbody>
    <% if (rows == null || rows.isEmpty()) { %><tr><td colspan="5" class="empty"><svg class="sx-ic"><use href="#sx-i-inbox"/></svg>No login activity found.</td></tr><% } else for (LoginHistory h : rows) { %>
    <tr>
      <td class="ts"><%= Html.ts(h.getCreatedAt()) %></td>
      <td><span class="tag <%= Html.esc(h.getActivityType()) %>"><%= Html.esc(h.getActivityType()) %></span></td>
      <td><span class="uid"><%= Html.esc(h.getUserId() == null ? "-" : h.getUserId()) %></span> <span class="mute small"><%= Html.esc(h.getUserRole()) %></span></td>
      <td><%= Html.esc(h.getEmail()) %></td>
      <td class="ua"><%= Html.esc(h.getUserAgent()) %></td>
    </tr>
    <% } %></tbody>
  </table></div>
  <%= Pager.render(cp + "/system/login-history", q, pg, pages) %>
</div>
<%@ include file="_foot.jspf" %>
