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

<meta name="viewport" content="width=device-width, initial-scale=1.0">

<style>

/* =========================
   GLOBAL
   ========================= */

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: Arial, Helvetica, sans-serif;
    background: #f5f7fb;
    color: #1f2937;
}

/* =========================
   HEADER
   ========================= */

.header {
    background: linear-gradient(135deg, #4338ca, #6d28d9);
    color: white;
    padding: 22px 40px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    box-shadow: 0 4px 15px rgba(67, 56, 202, 0.25);
}

.header h2 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
}

.header-subtitle {
    margin-top: 5px;
    font-size: 14px;
    opacity: 0.9;
}

/* =========================
   BACK BUTTON
   ========================= */

.back {
    background: rgba(255, 255, 255, 0.15);
    color: white;
    text-decoration: none;
    padding: 10px 18px;
    border-radius: 8px;
    border: 1px solid rgba(255, 255, 255, 0.25);
    font-size: 14px;
    font-weight: 600;
    transition: 0.2s ease;
}

.back:hover {
    background: rgba(255, 255, 255, 0.25);
}

/* =========================
   CONTAINER
   ========================= */

.container {
    width: 92%;
    max-width: 1200px;
    margin: 40px auto;
}

/* =========================
   MESSAGE
   ========================= */

.message {
    text-align: center;
    padding: 14px 18px;
    margin-bottom: 22px;
    border-radius: 10px;
    font-weight: 600;
    font-size: 14px;
}

.success {
    color: #047857;
    background: #ecfdf5;
    border: 1px solid #a7f3d0;
}

.error {
    color: #dc2626;
    background: #fef2f2;
    border: 1px solid #fecaca;
}

/* =========================
   BOX
   ========================= */

.box {
    background: white;
    padding: 30px;
    border-radius: 16px;
    box-shadow: 0 8px 30px rgba(15, 23, 42, 0.08);
    border: 1px solid #e5e7eb;
    margin-bottom: 28px;
}

.box h2 {
    margin: 0 0 25px;
    color: #312e81;
    font-size: 21px;
}

/* =========================
   TEAM INFORMATION
   ========================= */

.team-info {
    background: linear-gradient(135deg, #eef2ff, #f5f3ff);
    padding: 18px 20px;
    border-radius: 12px;
    border: 1px solid #c7d2fe;
    margin-bottom: 25px;
}

.team-info p {
    margin: 8px 0;
    font-size: 15px;
}

.label {
    font-weight: 700;
    color: #4338ca;
}

/* =========================
   FORM
   ========================= */

.form-label {
    display: block;
    margin-bottom: 8px;
    font-weight: 600;
    color: #374151;
    font-size: 14px;
}

select {
    width: 100%;
    padding: 13px 14px;
    border: 1px solid #d1d5db;
    border-radius: 9px;
    font-size: 15px;
    background: white;
    color: #111827;
    cursor: pointer;
    transition: 0.2s ease;
}

select:focus {
    outline: none;
    border-color: #6366f1;
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.12);
}

/* =========================
   ADD BUTTON
   ========================= */

.add-button {
    width: 100%;
    padding: 14px;
    margin-top: 18px;
    background: linear-gradient(135deg, #4f46e5, #7c3aed);
    color: white;
    border: none;
    border-radius: 9px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: 0.2s ease;
    box-shadow: 0 5px 12px rgba(79, 70, 229, 0.25);
}

.add-button:hover {
    transform: translateY(-1px);
    box-shadow: 0 7px 18px rgba(79, 70, 229, 0.35);
}

.add-button:active {
    transform: translateY(0);
}

/* =========================
   TABLE
   ========================= */

.table-wrapper {
    width: 100%;
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 5px;
    min-width: 650px;
}

th {
    background: #eef2ff;
    color: #3730a3;
    padding: 14px 12px;
    text-align: center;
    font-size: 14px;
    font-weight: 700;
    border-bottom: 2px solid #c7d2fe;
}

td {
    padding: 14px 12px;
    text-align: center;
    border-bottom: 1px solid #e5e7eb;
    font-size: 14px;
    color: #374151;
}

tr {
    transition: 0.2s ease;
}

tr:hover {
    background: #f8faff;
}

/* =========================
   EMPLOYEE ID
   ========================= */

.employee-id {
    display: inline-block;
    background: #eef2ff;
    color: #4338ca;
    padding: 6px 10px;
    border-radius: 7px;
    font-weight: 700;
    font-size: 13px;
}

/* =========================
   DESIGNATION
   ========================= */

.designation {
    display: inline-block;
    background: #f3e8ff;
    color: #7e22ce;
    padding: 6px 10px;
    border-radius: 7px;
    font-size: 13px;
    font-weight: 600;
}

/* =========================
   EDIT BUTTON
   ========================= */

.edit-btn {
    display: inline-block;
    background: #f59e0b;
    color: white;
    padding: 8px 15px;
    text-decoration: none;
    border-radius: 7px;
    font-size: 13px;
    font-weight: 600;
    transition: 0.2s ease;
}

.edit-btn:hover {
    background: #d97706;
    transform: translateY(-1px);
}

/* =========================
   EMPTY MEMBERS
   ========================= */

.no-members {
    text-align: center;
    color: #6b7280;
    padding: 30px !important;
    font-size: 14px;
    background: #fafafa;
}

/* =========================
   SECTION TITLE
   ========================= */

.section-title {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 20px;
}

.member-count {
    background: #eef2ff;
    color: #4338ca;
    padding: 6px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 700;
}

/* =========================
   RESPONSIVE
   ========================= */

@media (max-width: 700px) {

    .header {
        padding: 20px;
        flex-direction: column;
        align-items: flex-start;
        gap: 15px;
    }

    .header h2 {
        font-size: 21px;
    }

    .back {
        width: 100%;
        text-align: center;
    }

    .container {
        width: 94%;
        margin: 25px auto;
    }

    .box {
        padding: 22px 18px;
    }

    .box h2 {
        font-size: 19px;
    }

}

</style>

</head>

<body>


<!-- =========================
     HEADER
     ========================= -->

<div class="header">

    <div>

        <h2>Employee Management System</h2>

        <div class="header-subtitle">
            Team Management / Team Members
        </div>

    </div>

    <a href="viewTeams.jsp" class="back">
        Back to Teams
    </a>

</div>


<div class="container">


<!-- =========================
     MESSAGE
     ========================= -->

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


<!-- =========================
     ADD TEAM MEMBER
     ========================= -->

<div class="box">

    <h2>Add Team Member</h2>


    <div class="team-info">

        <p>

            <span class="label">
                Team ID:
            </span>

            <%= teamId %>

        </p>


        <p>

            <span class="label">
                Team Name:
            </span>

            <%= teamName %>

        </p>

    </div>


    <form action="AddTeamMemberServlet" method="post">

        <input type="hidden"
               name="teamId"
               value="<%= teamId %>">


        <label class="form-label">
            Employee Name
        </label>


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

        if (employeeRs != null)
            employeeRs.close();

    } catch (Exception e) {}

    try {

        if (employeePs != null)
            employeePs.close();

    } catch (Exception e) {}

    try {

        if (employeeCon != null)
            employeeCon.close();

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


<!-- =========================
     CURRENT TEAM MEMBERS
     ========================= -->

<div class="box">

    <div class="section-title">

        <h2>
            Team Members
        </h2>

    </div>


    <div class="table-wrapper">

        <table>

            <tr>

                <th>Employee ID</th>

                <th>Name</th>

                <th>Designation</th>

                <th>Action</th>

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

                    <span class="employee-id">

                        <%= employeeId %>

                    </span>

                </td>


                <td>

                    <%= memberRs.getString("name") %>

                </td>


                <td>

                    <span class="designation">

                        <%= memberRs.getString("designation") %>

                    </span>

                </td>


                <td>

                    <a href="removeTeamMember.jsp?teamId=<%= teamId %>&employeeId=<%= employeeId %>"
                       class="edit-btn">

                        Edit

                    </a>

                </td>

            </tr>

<%

    }


    if (!membersFound) {

%>

            <tr>

                <td colspan="4"
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

                <td colspan="4"
                    class="no-members">

                    Error loading team members.

                </td>

            </tr>

<%

} finally {

    try {

        if (memberRs != null)
            memberRs.close();

    } catch (Exception e) {}

    try {

        if (memberPs != null)
            memberPs.close();

    } catch (Exception e) {}

    try {

        if (memberCon != null)
            memberCon.close();

    } catch (Exception e) {}

}

%>

        </table>

    </div>

</div>


</div>


<%

try {

    if (teamRs != null)
        teamRs.close();

} catch (Exception e) {}

try {

    if (teamPs != null)
        teamPs.close();

} catch (Exception e) {}

try {

    if (con != null)
        con.close();

} catch (Exception e) {}

%>

</body>

</html>