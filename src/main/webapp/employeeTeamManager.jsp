<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String employeeId = (String) session.getAttribute("employeeId");

if (employeeId == null) {
    response.sendRedirect("login.jsp");
    return;
}

String teamId = null;
String teamName = null;

String managerId = null;
String managerName = null;
String managerEmail = null;
String managerPhone = null;
String managerDepartment = null;
String managerDesignation = null;

String errorMessage = null;

Connection con = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {

    con = DBcConnection.getConnection();

    String sql =
        "SELECT t.team_id, t.team_name, " +
        "m.employee_id AS manager_id, " +
        "m.name AS manager_name, " +
        "m.email AS manager_email, " +
        "m.phone AS manager_phone, " +
        "m.department AS manager_department, " +
        "m.designation AS manager_designation " +
        "FROM team_members tm " +
        "JOIN teams t ON tm.team_id = t.team_id " +
        "LEFT JOIN managers m ON t.manager_id = m.employee_id " +
        "WHERE tm.employee_id = ? " +
        "AND tm.status = 'ACTIVE' " +
        "LIMIT 1";

    ps = con.prepareStatement(sql);

    ps.setString(1, employeeId);

    rs = ps.executeQuery();

    if (rs.next()) {

        teamId = rs.getString("team_id");
        teamName = rs.getString("team_name");

        managerId = rs.getString("manager_id");
        managerName = rs.getString("manager_name");
        managerEmail = rs.getString("manager_email");
        managerPhone = rs.getString("manager_phone");
        managerDepartment = rs.getString("manager_department");
        managerDesignation = rs.getString("manager_designation");
    }

} catch (Exception e) {

    e.printStackTrace();

    errorMessage = "Error loading manager information.";

} finally {

    try {
        if (rs != null) rs.close();
    } catch (Exception e) {}

    try {
        if (ps != null) ps.close();
    } catch (Exception e) {}

    try {
        if (con != null) con.close();
    } catch (Exception e) {}
}
%>

<!DOCTYPE html>

<html>

<head>

<title>Team Manager</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.header {
    background: #2c3e50;
    color: white;

    padding: 20px 35px;

    display: flex;
    justify-content: space-between;
    align-items: center;
}

.header h2 {
    margin: 0;
}

.dashboard {
    color: white;
    background: #34495e;

    text-decoration: none;

    padding: 10px 18px;

    border-radius: 5px;
}

.container {
    width: 90%;

    margin: 40px auto;
}

.box {
    background: white;

    padding: 25px;

    border-radius: 10px;

    box-shadow: 0 2px 10px #ddd;

    margin-bottom: 25px;
}

.box h2 {
    margin-top: 0;

    color: #2c3e50;
}

.info {
    display: flex;

    padding: 13px;

    border-bottom: 1px solid #ddd;
}

.label {
    width: 200px;

    font-weight: bold;

    color: #34495e;
}

.value {
    flex: 1;

    color: #333;
}

.no-team {
    color: #e74c3c;

    font-weight: bold;
}

.no-manager {
    color: #e67e22;

    font-weight: bold;
}

.error {
    color: red;

    font-weight: bold;

    text-align: center;
}

.back {
    display: inline-block;

    padding: 11px 18px;

    background: #2c3e50;

    color: white;

    text-decoration: none;

    border-radius: 5px;
}

.back:hover {
    background: #1f2d3a;
}

</style>

</head>

<body>


<div class="header">

    <h2>Team Manager</h2>

    <a href="employeeDashboard.jsp"
       class="dashboard">

        Employee Dashboard

    </a>

</div>


<div class="container">


<%
if (errorMessage != null) {
%>

    <div class="box">

        <p class="error">
            <%= errorMessage %>
        </p>

    </div>

<%
}
else if (teamId == null) {
%>

    <div class="box">

        <h2>Team Manager</h2>

        <p class="no-team">
            You are not assigned to any team.
        </p>

    </div>

<%
}
else {
%>


    <!-- TEAM INFORMATION -->

    <div class="box">

        <h2>My Team</h2>

        <div class="info">

            <div class="label">
                Team ID
            </div>

            <div class="value">
                <%= teamId %>
            </div>

        </div>


        <div class="info">

            <div class="label">
                Team Name
            </div>

            <div class="value">
                <%= teamName %>
            </div>

        </div>

    </div>


<%
if (managerId == null) {
%>


    <div class="box">

        <h2>Team Manager</h2>

        <p class="no-manager">
            Manager Not Assigned
        </p>

    </div>


<%
} else {
%>


    <!-- MANAGER INFORMATION -->

    <div class="box">

        <h2>My Team Manager</h2>


        <div class="info">

            <div class="label">
                Manager ID
            </div>

            <div class="value">
                <%= managerId %>
            </div>

        </div>


        <div class="info">

            <div class="label">
                Manager Name
            </div>

            <div class="value">
                <%= managerName %>
            </div>

        </div>


        <div class="info">

            <div class="label">
                Email
            </div>

            <div class="value">
                <%= managerEmail %>
            </div>

        </div>


        <div class="info">

            <div class="label">
                Phone
            </div>

            <div class="value">
                <%= managerPhone %>
            </div>

        </div>


        <div class="info">

            <div class="label">
                Department
            </div>

            <div class="value">
                <%= managerDepartment %>
            </div>

        </div>


        <div class="info">

            <div class="label">
                Designation
            </div>

            <div class="value">
                <%= managerDesignation %>
            </div>

        </div>

    </div>


<%
}
%>


<%
}
%>


<a href="employeeDashboard.jsp"
   class="back">

    ← Back to Employee Dashboard

</a>


</div>

</body>

</html>