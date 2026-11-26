<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String teamId = request.getParameter("teamId");

if (teamId == null || teamId.trim().isEmpty()) {
    response.sendRedirect("viewTeams.jsp");
    return;
}

String teamName = "";

Connection con = null;
PreparedStatement teamPs = null;
ResultSet teamRs = null;

try {

    con = DBcConnection.getConnection();

    String teamSql =
        "SELECT team_name FROM teams WHERE team_id = ?";

    teamPs = con.prepareStatement(teamSql);
    teamPs.setString(1, teamId);

    teamRs = teamPs.executeQuery();

    if (teamRs.next()) {
        teamName = teamRs.getString("team_name");
    }

} catch (Exception e) {
    e.printStackTrace();
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

.back {
    background: #34495e;
    color: white;
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
    margin-bottom: 25px;
}

.message {
    text-align: center;
    padding: 12px;
    margin-bottom: 20px;
    border-radius: 5px;
    font-weight: bold;
}

.success {
    color: #27ae60;
    background: #eafaf1;
}

.error {
    color: #e74c3c;
    background: #fdecea;
}

.team-info {
    background: #f4f6f9;
    padding: 15px;
    border-radius: 6px;
    margin-bottom: 20px;
}

.team-info p {
    margin: 7px 0;
}

.label {
    font-weight: bold;
    color: #34495e;
}

select {
    width: 100%;
    padding: 12px;
    border: 1px solid #ccc;
    border-radius: 5px;
    font-size: 15px;
}

.add-button {
    width: 100%;
    padding: 12px;
    margin-top: 18px;
    background: #27ae60;
    color: white;
    border: none;
    border-radius: 5px;
    font-size: 16px;
    cursor: pointer;
}

.add-button:hover {
    background: #219150;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
}

th {
    background: #34495e;
    color: white;
    padding: 13px;
    text-align: center;
}

td {
    padding: 12px;
    text-align: center;
    border-bottom: 1px solid #ddd;
}

tr:hover {
    background: #f8f9fa;
}

.edit-btn {
    display: inline-block;
    background: #f39c12;
    color: white;
    padding: 7px 14px;
    text-decoration: none;
    border-radius: 4px;
    font-size: 13px;
}

.edit-btn:hover {
    background: #d68910;
}

.remove-btn {
    display: inline-block;
    background: #e74c3c;
    color: white;
    padding: 7px 14px;
    text-decoration: none;
    border-radius: 4px;
    font-size: 13px;
}

.remove-btn:hover {
    background: #c0392b;
}

.no-members {
    text-align: center;
    color: #777;
    padding: 25px;
}

</style>

</head>

<body>

<div class="header">

    <h2>Team Members</h2>

    <a href="viewTeams.jsp" class="back">
        ← Back to Teams
    </a>

</div>


<div class="container">


<!-- MESSAGE -->

<%
String message = request.getParameter("message");
String type = request.getParameter("type");

if (message != null) {
%>

<div class="message <%= "success".equals(type) ? "success" : "error" %>">

    <%= message %>

</div>

<%
}
%>


<!-- ADD TEAM MEMBER -->

<div class="box">

    <h2>Add Team Member</h2>

    <div class="team-info">

        <p>
            <span class="label">Team ID:</span>
            <%= teamId %>
        </p>

        <p>
            <span class="label">Team Name:</span>
            <%= teamName %>
        </p>

    </div>


    <form action="AddTeamMemberServlet" method="post">

        <input type="hidden"
               name="teamId"
               value="<%= teamId %>">

        <label class="label">
            Employee Name
        </label>

        <br><br>

        <select name="employeeId" required>

            <option value="">
                -- Select Employee --
            </option>

<%

Connection employeeCon = null;
PreparedStatement employeePs = null;
ResultSet employeeRs = null;

try {

    employeeCon = DBcConnection.getConnection();

    String employeeSql =
        "SELECT e.employee_id, e.name " +
        "FROM employees e " +
        "WHERE e.status = 'ACTIVE' " +
        "AND e.employee_id NOT IN " +
        "(SELECT tm.employee_id " +
        " FROM team_members tm " +
        " WHERE tm.team_id = ? " +
        " AND tm.status = 'ACTIVE') " +
        "ORDER BY e.name";

    employeePs =
        employeeCon.prepareStatement(employeeSql);

    employeePs.setString(1, teamId);

    employeeRs =
        employeePs.executeQuery();

    while (employeeRs.next()) {

%>

            <option value="<%= employeeRs.getString("employee_id") %>">

                <%= employeeRs.getString("name") %>
                (<%= employeeRs.getString("employee_id") %>)

            </option>

<%
    }

} catch (Exception e) {

    e.printStackTrace();

} finally {

    try {
        if (employeeRs != null) employeeRs.close();
    } catch (Exception e) {}

    try {
        if (employeePs != null) employeePs.close();
    } catch (Exception e) {}

    try {
        if (employeeCon != null) employeeCon.close();
    } catch (Exception e) {}
}

%>

        </select>


        <button type="submit"
                class="add-button">

            Add Employee

        </button>

    </form>

</div>


<!-- CURRENT TEAM MEMBERS -->

<div class="box">

    <h2>Team Members</h2>

    <table>

        <tr>

            <th>Employee ID</th>

            <th>Name</th>

            <th>Designation</th>

            <th>Edit</th>

            <th>Remove</th>

        </tr>


<%

Connection memberCon = null;
PreparedStatement memberPs = null;
ResultSet memberRs = null;

boolean membersFound = false;

try {

    memberCon = DBcConnection.getConnection();

    String memberSql =
        "SELECT e.employee_id, " +
        "e.name, " +
        "e.designation " +
        "FROM team_members tm " +
        "JOIN employees e " +
        "ON tm.employee_id = e.employee_id " +
        "WHERE tm.team_id = ? " +
        "AND tm.status = 'ACTIVE' " +
        "ORDER BY e.name";

    memberPs =
        memberCon.prepareStatement(memberSql);

    memberPs.setString(1, teamId);

    memberRs =
        memberPs.executeQuery();


    while (memberRs.next()) {

        membersFound = true;

        String employeeId =
            memberRs.getString("employee_id");

%>

        <tr>

            <td>
                <%= employeeId %>
            </td>

            <td>
                <%= memberRs.getString("name") %>
            </td>

            <td>
                <%= memberRs.getString("designation") %>
            </td>


            <!-- EXISTING EDIT BUTTON -->

            <td>

                <a href="editTeamMember.jsp?teamId=<%= teamId %>&employeeId=<%= employeeId %>"
                   class="edit-btn">

                    Edit

                </a>

            </td>


            <!-- NEW REMOVE BUTTON -->

            <td>

                <a href="removeTeamMember.jsp?teamId=<%= teamId %>&employeeId=<%= employeeId %>"
                   class="remove-btn">

                    Remove

                </a>

            </td>

        </tr>

<%

    }


    if (!membersFound) {

%>

        <tr>

            <td colspan="5"
                class="no-members">

                No team members assigned.

            </td>

        </tr>

<%

    }

} catch (Exception e) {

    e.printStackTrace();

%>

        <tr>

            <td colspan="5"
                class="no-members">

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

%>

    </table>

</div>

</div>


<%

try {
    if (teamRs != null) teamRs.close();
} catch (Exception e) {}

try {
    if (teamPs != null) teamPs.close();
} catch (Exception e) {}

try {
    if (con != null) con.close();
} catch (Exception e) {}

%>

</body>

</html>