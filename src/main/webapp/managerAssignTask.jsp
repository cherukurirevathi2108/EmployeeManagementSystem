<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
    String managerId =
        (String) session.getAttribute("managerId");

    if (managerId == null) {
        response.sendRedirect("managerLogin.jsp");
        return;
    }

    DBcConnection db =
        new DBcConnection();

    Connection con =
        db.getConnection();
%>

<!DOCTYPE html>
<html>

<head>

<title>Assign Task</title>

<style>

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f7fb;
}

.container {
    width: 650px;
    margin: 40px auto;
    background: white;
    padding: 35px;
    border-radius: 15px;
    box-shadow: 0 8px 25px rgba(0,0,0,0.08);
}

h2 {
    text-align: center;
    color: #1e293b;
}

label {
    display: block;
    margin-top: 18px;
    font-weight: bold;
}

input,
select,
textarea {
    width: 100%;
    padding: 12px;
    margin-top: 7px;
    box-sizing: border-box;
    border: 1px solid #d1d5db;
    border-radius: 8px;
}

textarea {
    height: 110px;
}

button {
    width: 100%;
    padding: 13px;
    margin-top: 25px;
    background: #2563eb;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 16px;
    cursor: pointer;
}

button:hover {
    background: #1d4ed8;
}

.back {
    display: block;
    text-align: center;
    margin-top: 20px;
}

</style>

</head>

<body>

<div class="container">

<h2>Assign Task</h2>

<form action="AssignTaskServlet"
      method="post">


<!-- TEAM -->

<label>Select Team</label>

<select name="teamId" required>

<option value="">
    Select Team
</option>

<%

String teamSql =
    "SELECT team_id, team_name " +
    "FROM teams " +
    "WHERE manager_id = ? " +
    "AND status = 'ACTIVE' " +
    "ORDER BY team_name";

PreparedStatement teamPs =
    con.prepareStatement(teamSql);

teamPs.setString(1, managerId);

ResultSet teamRs =
    teamPs.executeQuery();

while (teamRs.next()) {

%>

<option value="<%=teamRs.getString("team_id")%>">

<%=teamRs.getString("team_name")%>

</option>

<%

}

teamRs.close();
teamPs.close();

%>

</select>


<!-- EMPLOYEE -->

<label>Select Employee</label>

<select name="employeeId" required>

<option value="">
    Select Employee
</option>

<%

String employeeSql =
    "SELECT DISTINCT e.employee_id, e.name " +
    "FROM team_members tm " +
    "JOIN employees e " +
    "ON tm.employee_id = e.employee_id " +
    "JOIN teams t " +
    "ON tm.team_id = t.team_id " +
    "WHERE t.manager_id = ? " +
    "AND tm.status = 'ACTIVE' " +
    "AND e.status = 'ACTIVE' " +
    "ORDER BY e.name";

PreparedStatement employeePs =
    con.prepareStatement(employeeSql);

employeePs.setString(1, managerId);

ResultSet employeeRs =
    employeePs.executeQuery();

while (employeeRs.next()) {

%>

<option value="<%=employeeRs.getString("employee_id")%>">

<%=employeeRs.getString("name")%>
-
<%=employeeRs.getString("employee_id")%>

</option>

<%

}

employeeRs.close();
employeePs.close();

%>

</select>


<!-- TASK TITLE -->

<label>Task Title</label>

<input type="text"
       name="taskTitle"
       placeholder="Enter task title"
       required>


<!-- DESCRIPTION -->

<label>Task Description</label>

<textarea name="taskDescription"
          placeholder="Enter task description"
          required></textarea>


<!-- DUE DATE -->

<label>Due Date</label>

<input type="date"
       name="dueDate"
       required>


<button type="submit">
    Assign Task
</button>

</form>


<a class="back"
   href="managerDashboard.jsp">

← Back to Dashboard

</a>

</div>

</body>

</html>