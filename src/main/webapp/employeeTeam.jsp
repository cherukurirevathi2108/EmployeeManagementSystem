<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String employeeId = (String) session.getAttribute("employeeId");

if (employeeId == null) {
    response.sendRedirect("login.jsp");
    return;
}

Connection con = null;
PreparedStatement teamPs = null;
PreparedStatement memberPs = null;
ResultSet teamRs = null;
ResultSet memberRs = null;

String teamId = "";
String teamName = "";
String description = "";
String department = "";
String status = "";
String managerId = "";
String managerName = "";

boolean hasTeam = false;

try {

    con = DBcConnection.getConnection();

    String teamSql =
        "SELECT t.team_id, t.team_name, t.description, " +
        "t.department, t.status, t.manager_id, " +
        "m.name AS manager_name " +
        "FROM team_members tm " +
        "JOIN teams t ON tm.team_id = t.team_id " +
        "LEFT JOIN managers m ON t.manager_id = m.employee_id " +
        "WHERE tm.employee_id = ? " +
        "AND tm.status = 'ACTIVE'";

    teamPs = con.prepareStatement(teamSql);
    teamPs.setString(1, employeeId);

    teamRs = teamPs.executeQuery();

    if (teamRs.next()) {

        hasTeam = true;

        teamId = teamRs.getString("team_id");
        teamName = teamRs.getString("team_name");
        description = teamRs.getString("description");
        department = teamRs.getString("department");
        status = teamRs.getString("status");
        managerId = teamRs.getString("manager_id");
        managerName = teamRs.getString("manager_name");

        if (managerId == null) {
            managerId = "Not Assigned";
        }

        if (managerName == null) {
            managerName = "Not Assigned";
        }
    }

%>

<!DOCTYPE html>
<html>

<head>

<title>My Team</title>

<style>

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
    text-decoration: none;
    background: #34495e;
    padding: 10px 18px;
    border-radius: 5px;
}

.container {
    width: 90%;
    margin: 35px auto;
}

.box {
    background: white;
    padding: 25px;
    margin-bottom: 25px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ddd;
}

.box h2 {
    color: #2c3e50;
    margin-top: 0;
}

.row {
    display: flex;
    padding: 13px;
    border-bottom: 1px solid #ddd;
}

.label {
    width: 180px;
    font-weight: bold;
    color: #34495e;
}

.value {
    flex: 1;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
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

.no-team {
    color: #e74c3c;
    font-weight: bold;
}

.back {
    display: inline-block;
    padding: 10px 18px;
    background: #2c3e50;
    color: white;
    text-decoration: none;
    border-radius: 5px;
}

</style>

</head>

<body>

<div class="header">

    <h2>My Team</h2>

    <a href="employeeDashboard.jsp" class="dashboard">
        Employee Dashboard
    </a>

</div>


<div class="container">


<!-- EMPLOYEE -->

<div class="box">

    <h2>Employee Information</h2>

    <div class="row">

        <div class="label">
            Employee ID
        </div>

        <div class="value">
            <%= employeeId %>
        </div>

    </div>

</div>


<%

if (!hasTeam) {

%>

<div class="box">

    <h2>Team Information</h2>

    <p class="no-team">
        You are not assigned to any team.
    </p>

</div>

<%

} else {

%>


<!-- MY TEAM -->

<div class="box">

    <h2>My Team</h2>

    <div class="row">

        <div class="label">
            Team ID
        </div>

        <div class="value">
            <%= teamId %>
        </div>

    </div>


    <div class="row">

        <div class="label">
            Team Name
        </div>

        <div class="value">
            <%= teamName %>
        </div>

    </div>


    <div class="row">

        <div class="label">
            Description
        </div>

        <div class="value">

            <%
            if (description == null ||
                description.trim().isEmpty()) {
            %>

                No description available.

            <%
            } else {
            %>

                <%= description %>

            <%
            }
            %>

        </div>

    </div>


    <div class="row">

        <div class="label">
            Department
        </div>

        <div class="value">
            <%= department %>
        </div>

    </div>


    <div class="row">

        <div class="label">
            Status
        </div>

        <div class="value">
            <%= status %>
        </div>

    </div>

</div>


<!-- MANAGER -->

<div class="box">

    <h2>Team Manager</h2>

    <table>

        <tr>
            <th>Manager ID</th>
            <th>Manager Name</th>
        </tr>

        <tr>
            <td>
                <%= managerId %>
            </td>

            <td>
                <%= managerName %>
            </td>
        </tr>

    </table>

</div>


<!-- MEMBERS -->

<div class="box">

    <h2>Team Members</h2>

    <table>

        <tr>

            <th>Employee ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Department</th>

        </tr>

<%

    String memberSql =
        "SELECT e.employee_id, e.name, e.email, e.department " +
        "FROM team_members tm " +
        "JOIN employees e ON tm.employee_id = e.employee_id " +
        "WHERE tm.team_id = ? " +
        "AND tm.status = 'ACTIVE' " +
        "ORDER BY e.employee_id";

    memberPs = con.prepareStatement(memberSql);

    memberPs.setString(1, teamId);

    memberRs = memberPs.executeQuery();

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

        </tr>

<%

    }

    if (!found) {

%>

        <tr>

            <td colspan="4">
                No team members found.
            </td>

        </tr>

<%

    }

%>

    </table>

</div>


<%

}

%>


<a href="employeeDashboard.jsp" class="back">
    ← Back to Employee Dashboard
</a>


</div>

</body>

</html>

<%

} catch (Exception e) {

    e.printStackTrace();

%>

<!-- ERROR MESSAGE ONLY -->

<p style="color:red; text-align:center; margin-top:50px;">
    Error loading team information.
</p>

<%

} finally {

    try {
        if (memberRs != null) memberRs.close();
    } catch (Exception e) {}

    try {
        if (memberPs != null) memberPs.close();
    } catch (Exception e) {}

    try {
        if (teamRs != null) teamRs.close();
    } catch (Exception e) {}

    try {
        if (teamPs != null) teamPs.close();
    } catch (Exception e) {}

    try {
        if (con != null) con.close();
    } catch (Exception e) {}

}

%>