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

Connection con = null;
PreparedStatement ps = null;
ResultSet rs = null;

String errorMessage = null;

try {

    con = DBcConnection.getConnection();

    String sql =
        "SELECT t.team_id, t.team_name " +
        "FROM team_members tm " +
        "JOIN teams t ON tm.team_id = t.team_id " +
        "WHERE tm.employee_id = ? " +
        "AND tm.status = 'ACTIVE' " +
        "LIMIT 1";

    ps = con.prepareStatement(sql);

    ps.setString(1, employeeId);

    rs = ps.executeQuery();

    if (rs.next()) {

        teamId = rs.getString("team_id");
        teamName = rs.getString("team_name");
    }

} catch (Exception e) {

    e.printStackTrace();

    errorMessage = "Error loading team information.";

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

<title>Team Members</title>

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
    padding: 12px;

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
    margin-top: 20px;
}

th {
    background: #34495e;
    color: white;
    padding: 13px;
}

td {
    padding: 12px;
    text-align: center;
    border-bottom: 1px solid #ddd;
}

.no-team {
    color: #e74c3c;
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

</style>

</head>


<body>


<div class="header">

    <h2>Team Members</h2>

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

        <h2>Team Members</h2>

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


    <!-- TEAM MEMBERS -->

    <div class="box">

        <h2>Team Members</h2>

        <table>

            <tr>

                <th>Employee ID</th>

                <th>Name</th>

                <th>Email</th>

                <th>Department</th>

                <th>Designation</th>

            </tr>


<%

    Connection memberCon = null;
    PreparedStatement memberPs = null;
    ResultSet memberRs = null;

    boolean found = false;

    try {

        memberCon = DBcConnection.getConnection();

        String memberSql =
            "SELECT e.employee_id, e.name, e.email, " +
            "e.department, e.designation " +
            "FROM team_members tm " +
            "JOIN employees e " +
            "ON tm.employee_id = e.employee_id " +
            "WHERE tm.team_id = ? " +
            "AND tm.status = 'ACTIVE' " +
            "ORDER BY e.employee_id";

        memberPs = memberCon.prepareStatement(memberSql);

        memberPs.setString(1, teamId);

        memberRs = memberPs.executeQuery();

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
                    <%= memberRs.getString("designation") %>
                </td>

            </tr>

<%
        }

    } catch (Exception e) {

        e.printStackTrace();

%>

        <tr>

            <td colspan="5" class="error">
                Error loading team members.
            </td>

        </tr>

<%

    } finally {

        try {
            if (memberRs != null) memberRs.close();
        } catch (Exception e) {}

        try {
            if (memberPs != null) memberPs.close();
        } catch (Exception e) {}

        try {
            if (memberCon != null) memberCon.close();
        } catch (Exception e) {}
    }

    if (!found) {
%>

        <tr>

            <td colspan="5">
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


<a href="employeeDashboard.jsp"
   class="back">

    ← Back to Employee Dashboard

</a>


</div>


</body>

</html>