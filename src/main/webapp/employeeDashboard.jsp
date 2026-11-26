<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String employeeId = (String) session.getAttribute("employeeId");

if (employeeId == null) {
    response.sendRedirect("login.jsp");
    return;
}

String employeeName = (String) session.getAttribute("employeeName");

if (employeeName == null) {
    employeeName = "";
}
%>

<!DOCTYPE html>
<html>

<head>

<title>Employee Dashboard</title>

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

.welcome {
    font-size: 15px;
}

.logout {
    background: #e74c3c;
    color: white;
    text-decoration: none;
    padding: 10px 18px;
    border-radius: 5px;
    margin-left: 20px;
}

.container {
    width: 90%;
    margin: 40px auto;
}

.welcome-box {
    background: white;
    padding: 25px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ddd;
    margin-bottom: 30px;
}

.welcome-box h2 {
    margin-top: 0;
    color: #2c3e50;
}

.welcome-box p {
    color: #666;
}

.cards {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 25px;
}

.card {
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ddd;
    text-align: center;
}

.card h3 {
    color: #2c3e50;
}

.card p {
    color: #666;
    min-height: 45px;
}

.btn {
    display: inline-block;
    padding: 12px 20px;
    color: white;
    text-decoration: none;
    border-radius: 5px;
}

.blue {
    background: #3498db;
}

.green {
    background: #27ae60;
}

.purple {
    background: #8e44ad;
}

@media(max-width: 900px) {

    .cards {
        grid-template-columns: 1fr;
    }

}

</style>

</head>

<body>


<div class="header">

    <h2>Employee Dashboard</h2>

    <div class="welcome">

        Welcome, <b><%= employeeName %></b>

        <a href="logout.jsp" class="logout">
            Logout
        </a>

    </div>

</div>


<div class="container">


<div class="welcome-box">

    <h2>
        Welcome <%= employeeName %>
    </h2>

    <p>
        Employee ID:
        <b><%= employeeId %></b>
    </p>

    <p>
        View your assigned team, team members and team manager.
    </p>

</div>


<div class="cards">


<!-- 1. ASSIGNED TEAM -->

<div class="card">

    <h3>Assigned Team</h3>

    <p>
        View the team assigned to you.
    </p>

    <a href="employeeTeam.jsp"
       class="btn blue">

        View Assigned Team

    </a>

</div>


<!-- 2. TEAM MEMBERS -->

<div class="card">

    <h3>Team Members</h3>

    <p>
        View all employees assigned to your team.
    </p>

    <a href="employeeTeamMembers.jsp"
       class="btn green">

        View Team Members

    </a>

</div>


<!-- 3. TEAM MANAGER -->

<div class="card">

    <h3>Team Manager</h3>

    <p>
        View the manager assigned to your team.
    </p>

    <a href="employeeTeamManager.jsp"
       class="btn purple">

        View Team Manager

    </a>

</div>


</div>

</div>


</body>

</html>