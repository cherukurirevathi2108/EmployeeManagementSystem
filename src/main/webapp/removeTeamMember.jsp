<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String teamId = request.getParameter("teamId");
String employeeId = request.getParameter("employeeId");

if (teamId == null || employeeId == null ||
    teamId.trim().isEmpty() || employeeId.trim().isEmpty()) {

    response.sendRedirect("viewTeams.jsp");
    return;
}

String teamName = "";
String employeeName = "";

Connection con = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {

    con = DBcConnection.getConnection();

    String sql =
        "SELECT t.team_name, " +
        "e.name AS employee_name " +
        "FROM team_members tm " +
        "JOIN teams t ON tm.team_id = t.team_id " +
        "JOIN employees e ON tm.employee_id = e.employee_id " +
        "WHERE tm.team_id = ? " +
        "AND tm.employee_id = ? " +
        "AND tm.status = 'ACTIVE'";

    ps = con.prepareStatement(sql);

    ps.setString(1, teamId);
    ps.setString(2, employeeId);

    rs = ps.executeQuery();

    if (rs.next()) {

        teamName = rs.getString("team_name");
        employeeName = rs.getString("employee_name");

    } else {

        response.sendRedirect(
            "assignEmployees.jsp?teamId=" +
            teamId +
            "&message=Employee is not an active member of this team&type=error"
        );

        return;
    }

} catch (Exception e) {

    e.printStackTrace();

    response.sendRedirect(
        "assignEmployees.jsp?teamId=" +
        teamId +
        "&message=Error loading employee&type=error"
    );

    return;

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

<title>Remove Team Member</title>

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
    box-shadow: 0 4px 15px rgba(67, 56, 202, 0.25);
}

.header h2 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
}

.header p {
    margin: 5px 0 0;
    font-size: 14px;
    opacity: 0.9;
}

/* =========================
   CONTAINER
   ========================= */

.container {
    width: 100%;
    max-width: 650px;
    margin: 55px auto;
    padding: 0 20px;
}

/* =========================
   MAIN BOX
   ========================= */

.box {
    background: white;
    padding: 35px;
    border-radius: 16px;
    border: 1px solid #e5e7eb;
    box-shadow: 0 10px 35px rgba(15, 23, 42, 0.09);
}

.box h2 {
    text-align: center;
    color: #312e81;
    margin: 0 0 28px;
    font-size: 23px;
}

/* =========================
   WARNING AREA
   ========================= */

.warning-box {
    background: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 10px;
    padding: 14px 16px;
    margin-bottom: 22px;
    text-align: center;
    color: #c2410c;
    font-size: 14px;
    line-height: 1.5;
}

/* =========================
   INFORMATION CARD
   ========================= */

.info {
    background: linear-gradient(135deg, #eef2ff, #f5f3ff);
    padding: 20px;
    border-radius: 12px;
    border: 1px solid #c7d2fe;
    margin-bottom: 25px;
}

.info p {
    margin: 13px 0;
    font-size: 15px;
    color: #374151;
}

.info p:last-child {
    margin-bottom: 0;
}

.label {
    display: inline-block;
    min-width: 125px;
    font-weight: 700;
    color: #4338ca;
}

/* =========================
   TEAM / EMPLOYEE VALUES
   ========================= */

.value {
    font-weight: 600;
    color: #111827;
}

.team-id {
    display: inline-block;
    background: #e0e7ff;
    color: #3730a3;
    padding: 5px 9px;
    border-radius: 6px;
    font-size: 13px;
    font-weight: 700;
}

/* =========================
   REMOVE BUTTON
   ========================= */

.remove-button {
    width: 100%;
    padding: 14px;
    background: linear-gradient(135deg, #dc2626, #ef4444);
    color: white;
    border: none;
    border-radius: 9px;
    font-size: 16px;
    font-weight: 600;
    cursor: pointer;
    transition: 0.2s ease;
    box-shadow: 0 5px 12px rgba(220, 38, 38, 0.22);
}

.remove-button:hover {
    background: linear-gradient(135deg, #b91c1c, #dc2626);
    transform: translateY(-1px);
    box-shadow: 0 7px 18px rgba(220, 38, 38, 0.30);
}

.remove-button:active {
    transform: translateY(0);
}

/* =========================
   CANCEL BUTTON
   ========================= */

.cancel-button {
    display: block;
    text-align: center;
    margin-top: 14px;
    padding: 13px;
    background: #f3f4f6;
    color: #4b5563;
    text-decoration: none;
    border: 1px solid #d1d5db;
    border-radius: 9px;
    font-size: 15px;
    font-weight: 600;
    transition: 0.2s ease;
}

.cancel-button:hover {
    background: #e5e7eb;
    color: #1f2937;
}

/* =========================
   CONFIRMATION TEXT
   ========================= */

.confirm-text {
    text-align: center;
    color: #6b7280;
    font-size: 13px;
    margin: 20px 0 18px;
}

/* =========================
   RESPONSIVE
   ========================= */

@media (max-width: 600px) {

    .header {
        padding: 20px;
    }

    .header h2 {
        font-size: 21px;
    }

    .container {
        margin: 30px auto;
        padding: 0 15px;
    }

    .box {
        padding: 25px 20px;
    }

    .box h2 {
        font-size: 20px;
    }

    .label {
        display: block;
        margin-bottom: 5px;
    }

    .info p {
        margin: 16px 0;
    }
}

</style>


<script>

function confirmRemove() {

    var employeeName =
        "<%= employeeName.replace("\\", "\\\\").replace("\"", "\\\"") %>";

    var teamName =
        "<%= teamName.replace("\\", "\\\\").replace("\"", "\\\"") %>";

    var message =
        "Are you sure you want to remove "
        + employeeName
        + " from "
        + teamName
        + "?";

    return confirm(message);
}

</script>

</head>


<body>


<!-- =========================
     HEADER
     ========================= -->

<div class="header">

    <h2>Employee Management System</h2>

    <p>Team Management / Remove Team Member</p>

</div>


<!-- =========================
     MAIN CONTAINER
     ========================= -->

<div class="container">


    <div class="box">

        <h2>Remove From Team</h2>


        <div class="warning-box">

            This employee will be removed from the selected team.
            The employee account will not be deleted.

        </div>


        <!-- =========================
             TEAM INFORMATION
             ========================= -->

        <div class="info">

            <p>

                <span class="label">
                    Team ID:
                </span>

                <span class="team-id">
                    <%= teamId %>
                </span>

            </p>


            <p>

                <span class="label">
                    Team Name:
                </span>

                <span class="value">
                    <%= teamName %>
                </span>

            </p>


            <p>

                <span class="label">
                    Employee Name:
                </span>

                <span class="value">
                    <%= employeeName %>
                </span>

            </p>

        </div>


        <div class="confirm-text">

            Please confirm that you want to remove this employee
            from the team.

        </div>


        <!-- =========================
             REMOVE FORM
             ========================= -->

        <form action="RemoveTeamMemberServlet"
              method="post"
              onsubmit="return confirmRemove();">


            <input type="hidden"
                   name="teamId"
                   value="<%= teamId %>">


            <input type="hidden"
                   name="employeeId"
                   value="<%= employeeId %>">


            <button type="submit"
                    class="remove-button">

                Remove From The Team

            </button>

        </form>


        <!-- =========================
             CANCEL
             ========================= -->

        <a href="assignEmployees.jsp?teamId=<%= teamId %>"
           class="cancel-button">

            Cancel

        </a>

    </div>

</div>


</body>

</html>