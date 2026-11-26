<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,DAO.UserMonitorDAO,util.Html" %>
<% String pageTitle = "Users & Accounts"; String pageSub = "Account totals by role and a browsable user list"; String active = "users"; %>
<%@ include file="_head.jspf" %>
<%
    List<String> errors = (List<String>) request.getAttribute("errors");
    Map<String, Map<String, Long>> counts = (Map<String, Map<String, Long>>) request.getAttribute("counts");
    List<UserMonitorDAO.UserRow> users = (List<UserMonitorDAO.UserRow>) request.getAttribute("users");
%>
<% if (errors != null && !errors.isEmpty()) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><ul><% for (String e : errors) { %><li><%= Html.esc(e) %></li><% } %></ul></div></div><% } %>

<div class="card">
  <div class="card-h"><div><h3>Accounts by role</h3><p>Distribution of active and inactive accounts</p></div></div>
  <div class="tbl-wrap"><table>
    <thead><tr><th>Role</th><th>Total</th><th>Active</th><th>Inactive / other</th><th style="width:200px">Active share</th></tr></thead><tbody>
    <% long gT = 0, gA = 0;
       if (counts != null) for (Map.Entry<String, Map<String, Long>> e : counts.entrySet()) {
           long t = 0, a = 0; for (Map.Entry<String, Long> s : e.getValue().entrySet()) { t += s.getValue(); if ("ACTIVE".equals(s.getKey())) a += s.getValue(); }
           gT += t; gA += a; long pct = t > 0 ? (a * 100 / t) : 0; %>
    <tr><td class="uid"><%= Html.esc(e.getKey()) %></td><td><%= t %></td><td><%= a %></td><td><%= t - a %></td>
        <td><div class="bar" title="<%= pct %>% active"><i style="width:<%= pct %>%"></i></div></td></tr>
    <% } %></tbody>
    <tfoot><tr><th>All roles</th><th><%= gT %></th><th><%= gA %></th><th><%= gT - gA %></th><th></th></tr></tfoot>
  </table></div>
</div>

<div class="card">
  <div class="card-h"><div><h3>Users</h3><p>Browse accounts by role and status</p></div></div>
  <div class="card-b" style="border-bottom:1px solid var(--s-line)">
  <form class="filters" method="get" action="<%= cp %>/system/users">
    <label>Role<select name="role"><option value="">All roles</option>
      <% for (String r : new String[]{"ADMIN","HR","MANAGER","EMPLOYEE"}) { %><option <%= r.equals(request.getAttribute("fRole")) ? "selected" : "" %>><%= r %></option><% } %></select></label>
    <label>Status<select name="status"><option value="">All statuses</option>
      <% for (String r : new String[]{"ACTIVE","INACTIVE"}) { %><option <%= r.equals(request.getAttribute("fStatus")) ? "selected" : "" %>><%= r %></option><% } %></select></label>
    <div class="factions" style="grid-column:auto"><button type="submit">Apply filters</button></div>
  </form>
  </div>
  <div class="tbl-wrap"><table>
    <thead><tr><th>ID</th><th>Name</th><th>Email</th><th>Role</th><th>Status</th><th>Last login</th></tr></thead><tbody>
    <% if (users == null || users.isEmpty()) { %><tr><td colspan="6" class="empty"><svg class="sx-ic"><use href="#sx-i-users"/></svg>No users match.</td></tr><% } else for (UserMonitorDAO.UserRow u : users) { %>
    <tr><td class="uid"><%= Html.esc(u.id) %></td>
        <td><div class="person"><span class="av"><%= Html.esc(u.name == null || u.name.trim().isEmpty() ? "?" : u.name.trim().substring(0, 1).toUpperCase()) %></span><span><%= Html.esc(u.name) %></span></div></td>
        <td class="mute"><%= Html.esc(u.email) %></td><td><span class="role"><%= Html.esc(u.role) %></span></td>
        <td><span class="tag <%= Html.esc(u.status == null ? "" : u.status.toUpperCase()) %>"><%= Html.esc(u.status) %></span></td>
        <td class="ts"><%= u.lastLogin == null ? "<span class='mute'>never recorded</span>" : Html.ts(u.lastLogin) %></td></tr>
    <% } %></tbody>
  </table></div>
  <div class="card-f mute small">Shows up to 200 users per role. "Last login" only exists for logins made after this module was installed.</div>
</div>
<%@ include file="_foot.jspf" %>
