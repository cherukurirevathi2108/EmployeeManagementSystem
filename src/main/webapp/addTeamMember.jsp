<%@ page language="java"
    contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>

<%@ page import="model.Team"%>
<%@ page import="model.DBcConnection"%>
<%@ page import="java.sql.Connection"%>
<%@ page import="java.sql.PreparedStatement"%>
<%@ page import="java.sql.ResultSet"%>

<%
    String teamIdString = request.getParameter("id");

    if (teamIdString == null
            || teamIdString.trim().isEmpty()) {

        response.sendRedirect("ManageTeamsServlet");
        return;
    }

    int teamId = Integer.parseInt(teamIdString);


    Connection connection =
            DBcConnection.getConnection();


    String teamName = "";


    // Get team name
    String teamSql =
        "SELECT team_name FROM teams WHERE id = ?";

    PreparedStatement teamPs =
        connection.prepareStatement(teamSql);

    teamPs.setInt(1, teamId);

    ResultSet teamRs =
        teamPs.executeQuery();

    if (teamRs.next()) {

        teamName =
            teamRs.getString("team_name");

    } else {

        teamRs.close();
        teamPs.close();

        response.sendRedirect("ManageTeamsServlet");
        return;
    }

    teamRs.close();
    teamPs.close();
%>

<!DOCTYPE html>
<html>

<head>

<meta charset="UTF-8">

<title>Add Team Member</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    padding: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.container {
    width: 600px;
    margin: 50px auto;
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
}

h2 {
    text-align: center;
    color: #333;
    margin-bottom: 10px;
}

.team-info {
    text-align: center;
    margin-bottom: 30px;
    color: #555;
}

label {
    display: block;
    margin-bottom: 8px;
    font-weight: bold;
    color: #444;
}

select {
    width: 100%;
    padding: 12px;
    border: 1px solid #ccc;
    border-radius: 5px;
    font-size: 14px;
}

.button {
    width: 100%;
    margin-top: 20px;
    padding: 12px;
    border: none;
    border-radius: 5px;
    background: #28a745;
    color: white;
    font-size: 16px;
    cursor: pointer;
}

.button:hover {
    background: #218838;
}

.back-button {
    display: block;
    margin-top: 15px;
    padding: 12px;
    text-align: center;
    background: #6c757d;
    color: white;
    text-decoration: none;
    border-radius: 5px;
}

.back-button:hover {
    background: #545b62;
}

.error {
    padding: 10px;
    margin-bottom: 20px;
    background: #ffebee;
    color: #c62828;
    border-radius: 5px;
}

.message {
    padding: 10px;
    margin-bottom: 20px;
    background: #e8f5e9;
    color: #2e7d32;
    border-radius: 5px;
}

</style>

</head>

<body>

<div class="container">

    <h2>ADD TEAM MEMBER</h2>

    <div class="team-info">

        Adding member to:

        <strong>
            TEAM<%= String.format("%03d", teamId) %>
            -
            <%= teamName %>
        </strong>

    </div>


    <!-- Error -->

    <%
        String error = request.getParameter("error");

        if (error != null) {
    %>

        <div class="error">
            <%= error %>
        </div>

    <%
        }
    %>


    <!-- Form -->

    <form action="AddTeamMemberServlet"
          method="post">


        <!-- Team ID -->

        <input
            type="hidden"
            name="teamId"
            value="<%= teamId %>">


        <!-- Employee -->

        <label>Select Employee</label>

        <select name="employeeId" required>

            <option value="">
                -- Select Employee --
            </option>


            <%
                try {

                    String sql =
                        "SELECT id, employee_id, name, designation "
                      + "FROM employees "
                      + "WHERE status = 'ACTIVE' "
                      + "AND role = 'EMPLOYEE' "
                      + "ORDER BY name";

                    PreparedStatement ps =
                        connection.prepareStatement(sql);

                    ResultSet rs =
                        ps.executeQuery();


                    boolean employeeFound = false;


                    while (rs.next()) {

                        employeeFound = true;

                        int id =
                            rs.getInt("id");

                        String employeeId =
                            rs.getString("employee_id");

                        String name =
                            rs.getString("name");

                        String designation =
                            rs.getString("designation");
            %>

                        <option value="<%= id %>">

                            <%= name %>
                            -
                            <%= employeeId %>

                            <% if (designation != null
                                   && !designation.trim().isEmpty()) { %>

                                (<%= designation %>)

                            <% } %>

                        </option>

            <%
                    }


                    if (!employeeFound) {
            %>

                        <option value="">
                            No active employees available
                        </option>

            <%
                    }

                    rs.close();
                    ps.close();

                } catch (Exception e) {

                    e.printStackTrace();
            %>

                    <option value="">
                        Unable to load employees
                    </option>

            <%
                }
            %>

        </select>


        <button type="submit"
                class="button">

            Add Team Member

        </button>

    </form>


    <a href="TeamMembersServlet?id=<%= teamId %>"
       class="back-button">

        Back to Team Members

    </a>

</div>

</body>

</html>