<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,java.text.SimpleDateFormat,model.SystemSetting,util.Html" %>
<% String pageTitle = "System Settings"; String pageSub = ""; String active = "settings"; %>
<%@ include file="_head.jspf" %>
<%
    List<SystemSetting> settings = (List<SystemSetting>) request.getAttribute("settings");
    List<String> errors = (List<String>) request.getAttribute("errors");
    Map<String, String> typed = (Map<String, String>) request.getAttribute("typed");
    String configProblem = (String) request.getAttribute("configProblem");

    Map<String, String> val = new HashMap<String, String>();
    java.sql.Timestamp lastChanged = null;
    if (settings != null) for (SystemSetting s : settings) {
        val.put(s.getSettingKey(), s.getSettingValue() == null ? "" : s.getSettingValue());
        if (s.getUpdatedAt() != null && (lastChanged == null || s.getUpdatedAt().after(lastChanged))) lastChanged = s.getUpdatedAt();
    }
    if (typed != null) val.putAll(typed);          // re-show what the admin typed when validation failed

    String logoUrl = val.get("company_logo");
    boolean hasLogo = logoUrl != null && (logoUrl.startsWith("https://") || logoUrl.startsWith("/"));

    String[] days = { "MON","TUE","WED","THU","FRI","SAT","SUN" };
    Set<String> chosenDays = new HashSet<String>(Arrays.asList(val.getOrDefault("working_days", "").split(",")));

    String[] dfs  = { "dd MMM yyyy", "dd/MM/yyyy", "dd-MMM-yyyy", "MM/dd/yyyy", "yyyy-MM-dd" };
    String[] dfsD = { "Day Month Year", "Day/Month/Year", "Day-Month-Year", "Month/Day/Year", "Year-Month-Day" };
    String[] tfs  = { "hh:mm a", "HH:mm", "HH:mm:ss" };
    String[] tfsD = { "12-hour", "24-hour", "24-hour with seconds" };
    String currentDt = val.get("date_format") + "|" + val.get("time_format");
    Date now = new Date();
    String currentHint = "";
%>
<% if (request.getAttribute("message") != null) { %><div class="alert ok"><svg class="sx-ic"><use href="#sx-i-ok"/></svg><div><%= Html.esc(request.getAttribute("message")) %></div></div><% } %>
<% if (errors != null && !errors.isEmpty()) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><b>Please fix the following:</b><ul><% for (String e : errors) { %><li><%= Html.esc(e) %></li><% } %></ul></div></div><% } %>
<% if (configProblem != null) { %>
<div class="alert warn"><svg class="sx-ic"><use href="#sx-i-info"/></svg><div>
  <b>Logo upload is disabled:</b> <%= Html.esc(configProblem) %><br>
  Add your Cloudinary cloud name, API key and API secret to <code>WEB-INF/cloudinary.properties</code> (see <code>cloudinary.properties.example</code>) and restart the server.
</div></div>
<% } %>

<form method="post" action="<%= cp %>/system/settings"
      onsubmit="var b=this.querySelector('.set-actions button');b.disabled=true;b.textContent='Saving...';">
  <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
  <div class="card"><div class="card-b set-card">

    <div class="set-head">
      <div>
        <h3>System Settings</h3>
        <p>Application-wide configuration. Every change is validated and recorded in the audit log with the old and new values.</p>
      </div>
      <% if (lastChanged != null) { %><div class="hint" style="margin:0;white-space:nowrap">Last changed <%= Html.ts(lastChanged) %></div><% } %>
    </div>

    <div class="set-sec">Company</div>
    <div class="set-grid">
      <label>Company name
        <input name="company_name" maxlength="100" required value="<%= Html.esc(val.get("company_name")) %>">
      </label>
      <div>
        <div class="set-label">Company logo</div>
        <div class="set-logo-row">
          <div class="logo-thumb" id="sxLogoBox"><% if (hasLogo) { %><img src="<%= Html.esc(logoUrl) %>" alt="Company logo"><% } else { %><span>No logo</span><% } %></div>
          <input type="file" id="sxLogoFile" accept="image/png,image/jpeg,image/webp" hidden onchange="sxUploadLogo(this)">
          <button type="button" class="ghost" onclick="document.getElementById('sxLogoFile').click()" <%= configProblem != null ? "disabled" : "" %>>Upload logo</button>
          <button type="button" class="ghost" id="sxLogoRm" onclick="sxRemoveLogo()" <%= hasLogo ? "" : "disabled" %>>Remove logo</button>
        </div>
        <div class="hint" id="sxLogoMsg" style="margin-top:10px">PNG, JPG or WebP, up to 2 MB. Stored on Cloudinary; shown on the login page and in every dashboard.</div>
      </div>
    </div>

    <div class="set-sec">Working time</div>
    <div class="set-label">Official working days</div>
    <div class="daytiles">
      <% for (String d : days) { %><label class="daytile"><input type="checkbox" name="working_days" value="<%= d %>" <%= chosenDays.contains(d) ? "checked" : "" %>><span><%= d.charAt(0) + d.substring(1).toLowerCase() %></span></label><% } %>
    </div>
    <div class="set-row" style="margin-top:20px">
      <label>Default working hours per day
        <input type="number" name="working_hours_per_day" step="0.5" min="0.5" max="24" required value="<%= Html.esc(val.get("working_hours_per_day")) %>">
      </label>
      <label>Attendance grace period (minutes)
        <input type="number" name="attendance_grace_minutes" min="0" max="120" required value="<%= Html.esc(val.get("attendance_grace_minutes")) %>">
      </label>
    </div>

    <div class="set-sec">Leave, sessions &amp; notifications</div>
    <div class="set-row4">
      <label>Default annual leave (days)
        <input type="number" name="leave_annual_days" min="0" max="365" required value="<%= Html.esc(val.get("leave_annual_days")) %>">
      </label>
      <label>Session timeout (minutes)
        <input type="number" name="session_timeout_minutes" min="5" max="480" required value="<%= Html.esc(val.get("session_timeout_minutes")) %>">
      </label>
      <label>Email notifications
        <select name="notify_email">
          <option value="true" <%= "true".equals(val.get("notify_email")) ? "selected" : "" %>>On</option>
          <option value="false" <%= "true".equals(val.get("notify_email")) ? "" : "selected" %>>Off</option>
        </select>
        <span class="hint" style="margin:0">Welcome (login details) and payslip emails. Off stops both.</span>
      </label>
      <label>Date &amp; time format
        <select name="datetime_format" onchange="var h=this.parentNode.querySelector('.hint');if(h)h.textContent=this.options[this.selectedIndex].getAttribute('data-h');">
          <% for (int i = 0; i < dfs.length; i++) for (int j = 0; j < tfs.length; j++) {
               String v = dfs[i] + "|" + tfs[j];
               String desc = dfsD[i] + ", " + tfsD[j];
               boolean sel = v.equals(currentDt);
               if (sel) currentHint = desc;
               String shown = new SimpleDateFormat(dfs[i] + ", " + tfs[j], Locale.ENGLISH).format(now); %>
          <option value="<%= Html.esc(v) %>" data-h="<%= Html.esc(desc) %>" <%= sel ? "selected" : "" %>><%= Html.esc(shown) %></option>
          <% } %>
        </select>
        <span class="hint" style="margin:0"><%= Html.esc(currentHint) %></span>
      </label>
    </div>

    <div class="set-actions">
      <button type="submit">Save settings</button>
      <button type="button" class="ghost" onclick="var t=document.querySelector('#sysTabs [data-sys-tab=settings]');if(t)t.click();">Discard changes</button>
    </div>

  </div></div>
</form>
<%@ include file="_foot.jspf" %>
