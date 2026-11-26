<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%

String teamId = request.getParameter("teamId");

if (teamId == null || teamId.trim().isEmpty()) {
    response.sendRedirect("viewTeams.jsp");
    return;
}

Connection con = null;
PreparedStatement teamPs = null;
PreparedStatement memberPs = null;
ResultSet teamRs = null;
ResultSet memberRs = null;

String teamName = "";
String description = "";
String department = "";
String managerName = "";
String managerId = "";
String status = "";
String createdDate = "";

boolean teamFound = false;

try {

    con = DBcConnection.getConnection();

    /*
     * Get Team Details
     */

    String teamSql =
        "SELECT t.team_id, " +
        "t.team_name, " +
        "t.description, " +
        "t.department, " +
        "t.manager_id, " +
        "t.status, " +
        "t.created_at, " +
        "e.name AS manager_name " +

        "FROM teams t " +

        "LEFT JOIN employees e " +
        "ON t.manager_id = e.employee_id " +
        "AND e.designation = 'Manager' " +

        "WHERE t.team_id = ?";

    teamPs = con.prepareStatement(teamSql);

    teamPs.setString(1, teamId);

    teamRs = teamPs.executeQuery();

    if (teamRs.next()) {

        teamFound = true;

        teamName = teamRs.getString("team_name");
        description = teamRs.getString("description");
        department = teamRs.getString("department");
        managerId = teamRs.getString("manager_id");
        managerName = teamRs.getString("manager_name");
        status = teamRs.getString("status");

        Timestamp createdTimestamp =
            teamRs.getTimestamp("created_at");

        if (createdTimestamp != null) {
            createdDate = createdTimestamp.toString();
        }
    }

} catch (Exception e) {

    e.printStackTrace();

}

%>

<!DOCTYPE html>

<html>

<head>

<title>Team Details</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: "Segoe UI", Arial, sans-serif;
    background: #f4f6fb;
    color: #1f2937;
}


/* ================= HEADER ================= */

.header {

    background: linear-gradient(135deg, #4338ca, #6d28d9);

    color: white;

    padding: 22px 45px;

    display: flex;

    justify-content: space-between;

    align-items: center;

    box-shadow: 0 4px 18px rgba(67, 56, 202, 0.25);

}

.header-left h2 {

    margin: 0;

    font-size: 25px;

    font-weight: 700;

}

.header-left p {

    margin: 5px 0 0;

    font-size: 13px;

    opacity: 0.85;

}


/* ================= BACK BUTTON ================= */

.back {

    background: rgba(255,255,255,0.15);

    color: white;

    text-decoration: none;

    padding: 11px 20px;

    border-radius: 8px;

    font-size: 14px;

    font-weight: 600;

    border: 1px solid rgba(255,255,255,0.3);

    transition: 0.3s;

}

.back:hover {

    background: white;

    color: #4338ca;

}


/* ================= CONTAINER ================= */

.container {

    width: 92%;

    max-width: 1200px;

    margin: 35px auto;

}


/* ================= BOX ================= */

.box {

    background: white;

    padding: 30px;

    border-radius: 16px;

    box-shadow: 0 8px 30px rgba(15, 23, 42, 0.08);

    border: 1px solid #e5e7eb;

    margin-bottom: 25px;

}

.box h2 {

    margin: 0 0 22px;

    color: #111827;

    font-size: 21px;

    padding-bottom: 15px;

    border-bottom: 1px solid #e5e7eb;

}


/* ================= TEAM DETAILS ================= */

.detail {

    display: flex;

    align-items: center;

    min-height: 58px;

    padding: 13px 8px;

    border-bottom: 1px solid #edf0f5;

}

.detail:last-child {

    border-bottom: none;

}

.label {

    width: 210px;

    font-weight: 600;

    color: #374151;

    font-size: 14px;

}

.value {

    flex: 1;

    color: #6b7280;

    font-size: 14px;

}


/* ================= TEAM ID ================= */

.team-id {

    display: inline-block;

    background: #eef2ff;

    color: #4338ca;

    padding: 7px 12px;

    border-radius: 7px;

    font-size: 12px;

    font-weight: 700;

}


/* ================= TEAM NAME ================= */

.team-name {

    color: #111827;

    font-weight: 700;

    font-size: 15px;

}


/* ================= DESCRIPTION ================= */

.description {

    color: #4b5563;

    line-height: 1.6;

}


/* ================= MANAGER ================= */

.manager-name {

    color: #111827;

    font-weight: 600;

}

.manager-id {

    color: #9ca3af;

    font-size: 11px;

    margin-left: 5px;

}

.manager-box {

    display: inline-block;

    background: #f5f3ff;

    padding: 8px 12px;

    border-radius: 8px;

    border: 1px solid #ddd6fe;

}


/* ================= STATUS ================= */

.status {

    display: inline-block;

    padding: 7px 15px;

    border-radius: 20px;

    font-size: 11px;

    font-weight: 700;

    letter-spacing: 0.4px;

}

.active {

    background: #dcfce7;

    color: #15803d;

}

.inactive {

    background: #fee2e2;

    color: #dc2626;

}


/* ================= CREATED DATE ================= */

.created-date {

    color: #6b7280;

    font-size: 13px;

}


/* ================= TABLE ================= */

.table-wrapper {

    width: 100%;

    overflow-x: auto;

    border: 1px solid #e5e7eb;

    border-radius: 12px;

}

table {

    width: 100%;

    min-width: 650px;

    border-collapse: collapse;

}

th {

    background: #eef2ff;

    color: #3730a3;

    padding: 15px;

    text-align: center;

    font-size: 13px;

    font-weight: 700;

    border-bottom: 2px solid #c7d2fe;

}

td {

    padding: 15px;

    text-align: center;

    font-size: 14px;

    color: #4b5563;

    border-bottom: 1px solid #edf0f5;

}

tbody tr {

    transition: 0.2s;

}

tbody tr:hover {

    background: #f8faff;

}

tbody tr:last-child td {

    border-bottom: none;

}


/* ================= EMPLOYEE ID ================= */

.employee-id {

    display: inline-block;

    background: #eef2ff;

    color: #4338ca;

    padding: 6px 10px;

    border-radius: 6px;

    font-size: 12px;

    font-weight: 700;

}


/* ================= EMPLOYEE NAME ================= */

.employee-name {

    color: #111827;

    font-weight: 600;

}


/* ================= DESIGNATION ================= */

.designation {

    display: inline-block;

    background: #f3e8ff;

    color: #7e22ce;

    padding: 6px 11px;

    border-radius: 6px;

    font-size: 11px;

    font-weight: 600;

}


/* ================= NO MEMBERS ================= */

.no-members {

    text-align: center;

    color: #9ca3af;

    padding: 40px 20px;

    font-size: 14px;

}


/* ================= ERROR ================= */

.error {

    text-align: center;

    color: #dc2626;

    font-weight: 600;

    padding: 30px;

    background: #fef2f2;

    border-radius: 8px;

}


/* ================= RESPONSIVE ================= */

@media (max-width: 768px) {

    .header {

        padding: 20px;

        flex-direction: column;

        align-items: flex-start;

        gap: 15px;

    }

    .back {

        width: 100%;

        text-align: center;

    }

    .container {

        width: 96%;

        margin: 20px auto;

    }

    .box {

        padding: 20px;

    }

    .detail {

        display: block;

        padding: 14px 5px;

    }

    .label {

        width: 100%;

        margin-bottom: 6px;

    }

}

</style>

</head>


<body>


<!-- ================= HEADER ================= -->

<div class="header">

    <div class="header-left">

        <h2>Employee Management System</h2>

        <p>Team Management</p>

    </div>

    <a href="viewTeams.jsp" class="back">
        Back to All Teams
    </a>

</div>


<!-- ================= MAIN ================= -->

<div class="container">


<%

if (!teamFound) {

%>


    <div class="box">

        <p class="error">
            Team not found.
        </p>

    </div>


<%

} else {

%>


<!-- ================= TEAM DETAILS ================= -->

<div class="box">

    <h2>Team Details</h2>


    <!-- TEAM ID -->

    <div class="detail">

        <div class="label">
            Team ID
        </div>

        <div class="value">

            <span class="team-id">
                <%= teamId %>
            </span>

        </div>

    </div>


    <!-- TEAM NAME -->

    <div class="detail">

        <div class="label">
            Team Name
        </div>

        <div class="value">

            <span class="team-name">
                <%= teamName %>
            </span>

        </div>

    </div>


    <!-- DESCRIPTION -->

    <div class="detail">

        <div class="label">
            Description
        </div>

        <div class="value description">

            <%

            if (description != null &&
                !description.trim().isEmpty()) {

            %>

                <%= description %>

            <%

            } else {

            %>

                No description available

            <%

            }

            %>

        </div>

    </div>


    <!-- DEPARTMENT -->

    <div class="detail">

        <div class="label">
            Department
        </div>

        <div class="value">
            <%= department %>
        </div>

    </div>


    <!-- MANAGER -->

    <div class="detail">

        <div class="label">
            Team Manager
        </div>

        <div class="value">


            <%

            if (managerName != null) {

            %>

                <span class="manager-box">

                    <span class="manager-name">
                        <%= managerName %>
                    </span>

                    <span class="manager-id">
                        (<%= managerId %>)
                    </span>

                </span>

            <%

            } else {

            %>

                <span style="color:#9ca3af;">
                    Manager Not Assigned
                </span>

            <%

            }

            %>


        </div>

    </div>


    <!-- STATUS -->

    <div class="detail">

        <div class="label">
            Status
        </div>

        <div class="value">

            <%

            if ("ACTIVE".equalsIgnoreCase(status)) {

            %>

                <span class="status active">
                    ACTIVE
                </span>

            <%

            } else {

            %>

                <span class="status inactive">
                    <%= status %>
                </span>

            <%

            }

            %>

        </div>

    </div>


    <!-- CREATED DATE -->

    <div class="detail">

        <div class="label">
            Created Date
        </div>

        <div class="value created-date">
            <%= createdDate %>
        </div>

    </div>

</div>


<!-- ================= TEAM MEMBERS ================= -->

<div class="box">

    <h2>Team Members</h2>


    <div class="table-wrapper">

    <table>

        <thead>

            <tr>

                <th>Employee ID</th>

                <th>Name</th>

                <th>Designation</th>

            </tr>

        </thead>


        <tbody>


<%

boolean membersFound = false;


try {

    String memberSql =

        "SELECT e.employee_id, " +
        "e.name, " +
        "e.designation " +

        "FROM team_members tm " +

        "JOIN employees e " +
        "ON tm.employee_id = e.employee_id " +

        "WHERE tm.team_id = ? " +

        "AND tm.status = 'ACTIVE' " +

        "ORDER BY e.employee_id";


    memberPs = con.prepareStatement(memberSql);

    memberPs.setString(1, teamId);

    memberRs = memberPs.executeQuery();


    while (memberRs.next()) {

        membersFound = true;

%>


        <tr>

            <!-- EMPLOYEE ID -->

            <td>

                <span class="employee-id">
                    <%= memberRs.getString("employee_id") %>
                </span>

            </td>


            <!-- NAME -->

            <td>

                <span class="employee-name">
                    <%= memberRs.getString("name") %>
                </span>

            </td>


            <!-- DESIGNATION -->

            <td>

                <span class="designation">
                    <%= memberRs.getString("designation") %>
                </span>

            </td>

        </tr>


<%

    }


    if (!membersFound) {

%>


        <tr>

            <td colspan="3" class="no-members">

                No team members assigned.

            </td>

        </tr>


<%

    }


} catch (Exception e) {

    e.printStackTrace();

%>


        <tr>

            <td colspan="3" class="error">

                Error loading team members.

            </td>

        </tr>


<%

}

%>


        </tbody>

    </table>

    </div>

</div>


<%

}

%>


</div>


</body>

</html>


<%

// Close resources

try {

    if (memberRs != null)
        memberRs.close();

} catch (Exception e) {}


try {

    if (memberPs != null)
        memberPs.close();

} catch (Exception e) {}


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