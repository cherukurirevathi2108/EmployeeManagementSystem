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

String teamName = "";
String department = "";

PreparedStatement teamPs = con.prepareStatement(
    "SELECT team_name, department FROM teams WHERE team_id=? AND manager_id=?"
);

teamPs.setString(1, teamId);
teamPs.setString(2, managerId);

ResultSet teamRs = teamPs.executeQuery();

if (!teamRs.next()) {
    teamRs.close();
    teamPs.close();
    con.close();

    response.sendRedirect(
        "managerDashboard.jsp?message=You are not authorized for this team"
    );

    return;
}

teamName = teamRs.getString("team_name");
department = teamRs.getString("department");

teamRs.close();
teamPs.close();
%>

<!DOCTYPE html>
<html>

<head>

<title>Manage Team Employees</title>

<style>

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.container {
    width: 92%;
    margin: 40px auto;
}

.box {
    background: white;
    padding: 25px;
    margin-bottom: 25px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ccc;
}

h2 {
    color: #2c3e50;
}

h3 {
    color: #34495e;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
}

th {
    background: #34495e;
    color: white;
    padding: 12px;
}

td {
    padding: 12px;
    border-bottom: 1px solid #ddd;
    text-align: center;
}

button {
    padding: 8px 15px;
    border: none;
    border-radius: 5px;
    color: white;
    cursor: pointer;
}

.add {
    background: #27ae60;
}

.remove {
    background: #e74c3c;
}

.back {
    display: inline-block;
    margin-top: 10px;
    padding: 10px 18px;
    background: #2c3e50;
    color: white;
    text-decoration: none;
    border-radius: 5px;
}

.message {
    background: #d4edda;
    color: #155724;
    padding: 12px;
    border-radius: 5px;
    margin-bottom: 20px;
}

</style>

</head>

<body>

<div class="container">

<%

String message = request.getParameter("message");

if (message != null) {

%>

<div class="message">
    <%= message %>
</div>

<%

}

%>


<!-- TEAM INFORMATION -->

<div class="box">

<h2>
    Team: <%= teamName %>
</h2>

<p>
    Team ID:
    <b><%= teamId %></b>
</p>

<p>
    Department:
    <b><%= department %></b>
</p>

</div>


<!-- CURRENT TEAM MEMBERS -->

<div class="box">

<h3>Current Team Members</h3>

<table>

<tr>

<th>Employee ID</th>
<th>Name</th>
<th>Email</th>
<th>Department</th>
<th>Status</th>
<th>Action</th>

</tr>

<%

PreparedStatement memberPs = con.prepareStatement(
    "SELECT e.employee_id, e.name, e.email, " +
    "e.department, tm.status " +
    "FROM team_members tm " +
    "JOIN employees e " +
    "ON tm.employee_id = e.employee_id " +
    "WHERE tm.team_id=? AND tm.status='ACTIVE' " +
    "ORDER BY e.employee_id"
);

memberPs.setString(1, teamId);

ResultSet memberRs = memberPs.executeQuery();

boolean found = false;

while (memberRs.next()) {

    found = true;

%>

<tr>

<td>
    <%= memberRs.getString("employee_id") %>
</td>

<td>
    <%= memberRs.getString("name") %>
</td>

<td>
    <%= memberRs.getString("email") %>
</td>

<td>
    <%= memberRs.getString("department") %>
</td>

<td>
    <%= memberRs.getString("status") %>
</td>

<td>

<a href="ManagerRemoveTeamMemberServlet?teamId=<%= teamId %>&employeeId=<%= memberRs.getString("employee_id") %>"
   onclick="return confirm('Remove this employee?');">

<button class="remove">
    Remove
</button>

</a>

</td>

</tr>

<%

}

if (!found) {

%>

<tr>

<td colspan="6">
    No employees assigned to this team.
</td>

</tr>

<%

}

memberRs.close();
memberPs.close();

%>

</table>

</div>


<!-- ADD EMPLOYEES -->

<div class="box">

<h3>Add Employees</h3>

<form action="ManagerAddTeamMembersServlet" method="post">

<input type="hidden"
       name="teamId"
       value="<%= teamId %>">


<table>

<tr>

<th>Select</th>
<th>Employee ID</th>
<th>Name</th>
<th>Email</th>
<th>Department</th>

</tr>

<%

PreparedStatement availablePs = con.prepareStatement(
    "SELECT e.employee_id, e.name, e.email, e.department " +
    "FROM employees e " +
    "WHERE e.status='ACTIVE' " +
    "AND e.employee_id NOT IN " +
    "(SELECT employee_id FROM team_members " +
    "WHERE team_id=? AND status='ACTIVE') " +
    "ORDER BY e.employee_id"
);

availablePs.setString(1, teamId);

ResultSet availableRs = availablePs.executeQuery();

boolean available = false;

while (availableRs.next()) {

    available = true;

%>

<tr>

<td>

<input type="checkbox"
       name="employeeIds"
       value="<%= availableRs.getString("employee_id") %>">

</td>

<td>
    <%= availableRs.getString("employee_id") %>
</td>

<td>
    <%= availableRs.getString("name") %>
</td>

<td>
    <%= availableRs.getString("email") %>
</td>

<td>
    <%= availableRs.getString("department") %>
</td>

</tr>

<%

}

if (!available) {

%>

<tr>

<td colspan="5">
    No available employees.
</td>

</tr>

<%

}

availableRs.close();
availablePs.close();

%>

</table>


<button type="submit" class="add">
    Add Selected Employees
</button>

</form>

</div>


<a href="managerDashboard.jsp" class="back">
    ← Back to Manager Dashboard
</a>


<%

con.close();

%>

</div>

</body>

</html>