<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String managerId = (String) session.getAttribute("managerId");

if (managerId == null) {
    response.sendRedirect("managerLogin.jsp");
    return;
}

String teamId = request.getParameter("teamId");

if (teamId == null || teamId.trim().isEmpty()) {
    response.sendRedirect("managerDashboard.jsp?message=Team ID is missing");
    return;
}

Connection con = DBcConnection.getConnection();

PreparedStatement ps = con.prepareStatement(
    "SELECT team_id, team_name, description, department, status " +
    "FROM teams WHERE team_id=? AND manager_id=?"
);

ps.setString(1, teamId);
ps.setString(2, managerId);

ResultSet rs = ps.executeQuery();

if (!rs.next()) {
    rs.close();
    ps.close();
    con.close();

    response.sendRedirect(
        "managerDashboard.jsp?message=You are not authorized for this team"
    );

    return;
}
%>

<!DOCTYPE html>
<html>

<head>

<title>Update Team</title>

<style>

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.container {
    width: 550px;
    margin: 50px auto;
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ccc;
}

h2 {
    text-align: center;
    color: #2c3e50;
}

label {
    display: block;
    margin-top: 15px;
    font-weight: bold;
}

input,
textarea,
select {
    width: 100%;
    padding: 11px;
    margin-top: 6px;
    border: 1px solid #ccc;
    border-radius: 5px;
    box-sizing: border-box;
}

input[readonly] {
    background: #eee;
}

button {
    width: 100%;
    margin-top: 25px;
    padding: 12px;
    background: #f39c12;
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-size: 16px;
}

.back {
    display: block;
    text-align: center;
    margin-top: 15px;
    text-decoration: none;
    color: #2c3e50;
}

</style>

</head>

<body>

<div class="container">

<h2>Update Team</h2>

<form action="ManagerEditTeamServlet" method="post">

<label>Team ID</label>

<input type="text"
       name="teamId"
       value="<%= rs.getString("team_id") %>"
       readonly>


<label>Team Name</label>

<input type="text"
       name="teamName"
       value="<%= rs.getString("team_name") %>"
       required>


<label>Description</label>

<textarea name="description"
          rows="4"><%= rs.getString("description") == null ? "" : rs.getString("description") %></textarea>


<label>Department</label>

<select name="department" required>

<option value="IT"
<%= "IT".equals(rs.getString("department")) ? "selected" : "" %>>
IT
</option>

<option value="HR"
<%= "HR".equals(rs.getString("department")) ? "selected" : "" %>>
HR
</option>

<option value="Finance"
<%= "Finance".equals(rs.getString("department")) ? "selected" : "" %>>
Finance
</option>

<option value="Marketing"
<%= "Marketing".equals(rs.getString("department")) ? "selected" : "" %>>
Marketing
</option>

<option value="Sales"
<%= "Sales".equals(rs.getString("department")) ? "selected" : "" %>>
Sales
</option>

<option value="Operations"
<%= "Operations".equals(rs.getString("department")) ? "selected" : "" %>>
Operations
</option>

</select>


<label>Status</label>

<select name="status">

<option value="ACTIVE"
<%= "ACTIVE".equals(rs.getString("status")) ? "selected" : "" %>>
ACTIVE
</option>

<option value="INACTIVE"
<%= "INACTIVE".equals(rs.getString("status")) ? "selected" : "" %>>
INACTIVE
</option>

</select>


<button type="submit">
    Update Team
</button>

</form>


<a href="managerDashboard.jsp" class="back">
    ← Back to Manager Dashboard
</a>

</div>

<%

rs.close();
ps.close();
con.close();

%>

</body>

</html>