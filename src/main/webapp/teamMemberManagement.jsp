<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<!DOCTYPE html>
<html>

<head>

<title>Team Member Management</title>

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
    width: 95%;
    margin: 35px auto;
}

.box {
    background: white;
    padding: 25px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ddd;
}

.box h2 {
    margin-top: 0;
    color: #2c3e50;
}

/* MESSAGE */

.message {
    padding: 12px;
    margin-bottom: 20px;
    text-align: center;
    border-radius: 5px;
    font-weight: bold;
}

.success {
    background: #eafaf1;
    color: #27ae60;
    border: 1px solid #27ae60;
}

.error-message {
    background: #fdecea;
    color: #e74c3c;
    border: 1px solid #e74c3c;
}


/* SELECT TEAM */

.team-form {
    display: flex;
    gap: 12px;
    align-items: center;
    margin-bottom: 30px;
}

.team-form label {
    font-weight: bold;
    color: #2c3e50;
}

.team-form select {
    width: 300px;
    padding: 10px;
    border: 1px solid #ccc;
    border-radius: 5px;
}

.team-form button {
    background: #3498db;
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 5px;
    cursor: pointer;
}

.team-form button:hover {
    opacity: 0.85;
}


/* ADD MEMBER */

.add-member-box {
    background: #f8f9fa;
    padding: 20px;
    border-radius: 8px;
    margin-bottom: 25px;
    border: 1px solid #ddd;
}

.add-member-box h3 {
    margin-top: 0;
    color: #2c3e50;
}

.add-form {
    display: flex;
    gap: 12px;
    align-items: center;
}

.add-form select {
    width: 350px;
    padding: 10px;
    border: 1px solid #ccc;
    border-radius: 5px;
}

.add-btn {
    background: #27ae60;
    color: white;
    border: none;
    padding: 10px 18px;
    border-radius: 5px;
    cursor: pointer;
}

.add-btn:hover {
    opacity: 0.85;
}


/* TABLE */

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
}

th {
    background: #34495e;
    color: white;
    padding: 14px;
    text-align: center;
}

td {
    padding: 13px;
    text-align: center;
    border-bottom: 1px solid #ddd;
}

tr:hover {
    background: #f8f9fa;
}


/* STATUS */

.status-active {
    color: #27ae60;
    font-weight: bold;
}

.status-inactive {
    color: #e74c3c;
    font-weight: bold;
}


/* REMOVE */

.remove-btn {
    background: #e74c3c;
    color: white;
    text-decoration: none;
    padding: 8px 14px;
    border-radius: 4px;
    display: inline-block;
}

.remove-btn:hover {
    opacity: 0.85;
}

.no-data {
    text-align: center;
    padding: 30px;
    color: #777;
}

</style>

</head>

<body>


<div class="header">

    <h2>Team Member Management</h2>

    <a href="adminPanel.jsp" class="back">
        ← Admin Panel
    </a>

</div>


<div class="container">

<div class="box">


<!-- MESSAGE -->

<%
String message = request.getParameter("message");
String type = request.getParameter("type");

if (message != null && !message.trim().isEmpty()) {
%>

<div class="message
    <%= "success".equalsIgnoreCase(type)
        ? "success"
        : "error-message" %>">

    <%= message %>

</div>

<%
}
%>


<h2>Select Team</h2>


<!-- SELECT TEAM -->

<form action="teamMemberManagement.jsp"
      method="get"
      class="team-form">

    <label>Select Team:</label>

    <select name="teamId" required>

        <option value="">
            -- Select Team --
        </option>


<%

Connection con = null;

PreparedStatement teamPs = null;
ResultSet teamRs = null;

String selectedTeamId =
    request.getParameter("teamId");


try {

    con = DBcConnection.getConnection();

    String teamSql =
        "SELECT team_id, team_name " +
        "FROM teams " +
        "WHERE status = 'ACTIVE' " +
        "ORDER BY team_name";

    teamPs =
        con.prepareStatement(teamSql);

    teamRs =
        teamPs.executeQuery();


    while (teamRs.next()) {

        String id =
            teamRs.getString("team_id");

        String name =
            teamRs.getString("team_name");

%>

        <option value="<%= id %>"
            <%= id.equals(selectedTeamId)
                ? "selected"
                : "" %>>

            <%= name %> (<%= id %>)

        </option>

<%

    }

} catch (Exception e) {

    e.printStackTrace();

} finally {

    try {
        if (teamRs != null) teamRs.close();
    } catch (Exception e) {}

    try {
        if (teamPs != null) teamPs.close();
    } catch (Exception e) {}

}

%>

    </select>


    <button type="submit">
        Select Team
    </button>

</form>


<%

if (selectedTeamId != null &&
    !selectedTeamId.trim().isEmpty()) {


    /*
     * Get selected team name
     */

    PreparedStatement namePs = null;
    ResultSet nameRs = null;

    String selectedTeamName = "";


    try {

        String nameSql =
            "SELECT team_name " +
            "FROM teams " +
            "WHERE team_id = ?";

        namePs =
            con.prepareStatement(nameSql);

        namePs.setString(1, selectedTeamId);

        nameRs =
            namePs.executeQuery();


        if (nameRs.next()) {

            selectedTeamName =
                nameRs.getString("team_name");

        }


    } catch (Exception e) {

        e.printStackTrace();

    } finally {

        try {
            if (nameRs != null) nameRs.close();
        } catch (Exception e) {}

        try {
            if (namePs != null) namePs.close();
        } catch (Exception e) {}

    }

%>


<h2>
    Team: <%= selectedTeamName %>
</h2>


<!-- ADD MEMBER SECTION -->

<div class="add-member-box">

    <h3>Add Team Member</h3>


    <form action="AddTeamMemberServlet"
          method="post"
          class="add-form">


        <input type="hidden"
               name="teamId"
               value="<%= selectedTeamId %>">


        <select name="employeeId" required>

            <option value="">
                -- Select Employee --
            </option>


<%

    PreparedStatement empPs = null;
    ResultSet empRs = null;


    try {

        String employeeSql =
            "SELECT employee_id, name, designation " +
            "FROM employees " +
            "WHERE status = 'ACTIVE' " +
            "AND employee_id NOT IN " +
            "(SELECT employee_id " +
            " FROM team_members " +
            " WHERE team_id = ? " +
            " AND status = 'ACTIVE') " +
            "ORDER BY employee_id";


        empPs =
            con.prepareStatement(employeeSql);

        empPs.setString(1, selectedTeamId);

        empRs =
            empPs.executeQuery();


        while (empRs.next()) {

%>

            <option value="<%= empRs.getString("employee_id") %>">

                <%= empRs.getString("employee_id") %>
                -
                <%= empRs.getString("name") %>
                -
                <%= empRs.getString("designation") %>

            </option>

<%

        }


    } catch (Exception e) {

        e.printStackTrace();

    } finally {

        try {
            if (empRs != null) empRs.close();
        } catch (Exception e) {}

        try {
            if (empPs != null) empPs.close();
        } catch (Exception e) {}

    }

%>

        </select>


        <button type="submit"
                class="add-btn">

            Add Member

        </button>

    </form>

</div>


<!-- CURRENT MEMBERS -->

<h2>Team Members</h2>


<table>

<tr>

    <th>Employee ID</th>

    <th>Employee Name</th>

    <th>Designation</th>

    <th>Status</th>

    <th>Action</th>

</tr>


<%

PreparedStatement memberPs = null;
ResultSet memberRs = null;

boolean found = false;


try {

    String memberSql =
        "SELECT e.employee_id, " +
        "e.name, " +
        "e.designation, " +
        "tm.status " +
        "FROM team_members tm " +
        "JOIN employees e " +
        "ON tm.employee_id = e.employee_id " +
        "WHERE tm.team_id = ? " +
        "ORDER BY e.employee_id";


    memberPs =
        con.prepareStatement(memberSql);

    memberPs.setString(1, selectedTeamId);

    memberRs =
        memberPs.executeQuery();


    while (memberRs.next()) {

        found = true;


        String employeeId =
            memberRs.getString("employee_id");

        String employeeName =
            memberRs.getString("name");

        String designation =
            memberRs.getString("designation");

        String memberStatus =
            memberRs.getString("status");

%>


<tr>

    <td>
        <%= employeeId %>
    </td>

    <td>
        <%= employeeName %>
    </td>

    <td>
        <%= designation %>
    </td>


    <td>

        <%
        if ("ACTIVE".equalsIgnoreCase(memberStatus)) {
        %>

            <span class="status-active">
                ACTIVE
            </span>

        <%
        } else {
        %>

            <span class="status-inactive">
                INACTIVE
            </span>

        <%
        }
        %>

    </td>


    <td>

        <%
        if ("ACTIVE".equalsIgnoreCase(memberStatus)) {
        %>

        <a href="RemoveTeamMemberServlet?teamId=<%= selectedTeamId %>&employeeId=<%= employeeId %>"
           class="remove-btn"
           onclick="return confirm('Are you sure you want to remove this employee from the team?');">

            Remove Member

        </a>

        <%
        } else {
        %>

            <span class="status-inactive">
                INACTIVE
            </span>

        <%
        }
        %>

    </td>

</tr>


<%

    }


    if (!found) {

%>

<tr>

    <td colspan="5"
        class="no-data">

        No members found in this team.

    </td>

</tr>

<%

    }


} catch (Exception e) {

    e.printStackTrace();

%>

<tr>

    <td colspan="5"
        class="no-data">

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

}

%>

</table>


<%

}

%>


</div>

</div>

</body>

</html>