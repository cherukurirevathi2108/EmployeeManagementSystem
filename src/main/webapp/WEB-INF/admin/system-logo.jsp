<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*,util.Html" %>
<% String pageTitle = "System Settings"; String pageSub = "Branding and application settings"; String active = "logo"; %>
<%@ include file="_head.jspf" %>
<%
    List<String> errors = (List<String>) request.getAttribute("errors");
    String logoUrl = (String) request.getAttribute("logoUrl");
    String configProblem = (String) request.getAttribute("configProblem");
    boolean hasLogo = logoUrl != null && (logoUrl.startsWith("https://") || logoUrl.startsWith("/"));
%>
<% if (request.getAttribute("message") != null) { %><div class="alert ok"><svg class="sx-ic"><use href="#sx-i-ok"/></svg><div><%= Html.esc(request.getAttribute("message")) %></div></div><% } %>
<% if (errors != null && !errors.isEmpty()) { %><div class="alert err"><svg class="sx-ic"><use href="#sx-i-x"/></svg><div><ul><% for (String e : errors) { %><li><%= Html.esc(e) %></li><% } %></ul></div></div><% } %>
<% if (configProblem != null) { %>
<div class="alert warn"><svg class="sx-ic"><use href="#sx-i-info"/></svg><div>
  <b>Upload is disabled:</b> <%= Html.esc(configProblem) %><br>
  Ask the server administrator to set the JVM option <code>-Dcloudinary.url=cloudinary://API_KEY:API_SECRET@CLOUD_NAME</code>
  (or the environment variable <code>CLOUDINARY_URL</code>), then restart the server.
</div></div>
<% } %>

<div class="card">
  <div class="card-h"><div><h3>Company logo</h3><p>Shown across the application. Images are stored on Cloudinary. PNG, JPG, GIF or WebP, up to 2 MB.</p></div></div>
  <div class="card-b">
    <div class="logo-box">
      <div>
        <% if (hasLogo) { %>
          <img class="logo-prev" id="sxLogoPrev" src="<%= Html.esc(logoUrl) %>" alt="Current company logo">
        <% } else { %>
          <div class="logo-empty" id="sxLogoEmpty">No logo uploaded yet</div>
          <img class="logo-prev" id="sxLogoPrev" alt="Selected logo preview" style="display:none">
        <% } %>
      </div>
      <div style="flex:1;min-width:260px">
        <form method="post" action="<%= cp %>/system/logo" enctype="multipart/form-data"
              onsubmit="var b=this.querySelector('button');b.disabled=true;b.textContent='Uploading...';">
          <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
          <label>Choose a new logo
            <input type="file" name="logo" accept="image/png,image/jpeg,image/gif,image/webp" required <%= configProblem != null ? "disabled" : "" %>
                   onchange="var f=this.files[0];if(!f)return;if(f.size>2097152){alert('The image must be 2 MB or smaller.');this.value='';return;}var p=document.getElementById('sxLogoPrev');p.src=URL.createObjectURL(f);p.style.display='block';var e=document.getElementById('sxLogoEmpty');if(e)e.style.display='none';">
          </label>
          <div class="factions" style="margin-top:14px">
            <button type="submit" <%= configProblem != null ? "disabled" : "" %>><svg class="sx-ic"><use href="#sx-i-dl"/></svg>Upload logo</button>
          </div>
        </form>
        <% if (hasLogo) { %>
        <form method="post" action="<%= cp %>/system/logo" style="margin-top:12px" onsubmit="return confirm('Remove the company logo?');">
          <input type="hidden" name="csrfToken" value="<%= Html.esc(csrf) %>">
          <input type="hidden" name="action" value="remove">
          <button type="submit" class="ghost danger-ghost sm">Remove current logo</button>
        </form>
        <% } %>
      </div>
    </div>
  </div>
  <% if (hasLogo) { %><div class="card-f mute small">Stored at: <code><%= Html.esc(logoUrl) %></code></div><% } %>
</div>
<%@ include file="_foot.jspf" %>
