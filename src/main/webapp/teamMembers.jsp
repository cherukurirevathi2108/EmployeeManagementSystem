<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
    String managerId = (String) session.getAttribute("managerId");

    if (managerId == null) {
        response.sendRedirect(request.getContextPath() + "/login.html");
        return;
    }

    String selectedTeamId = request.getParameter("teamId");

    Connection con = null;
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {

        con = DBcConnection.getConnection();

%>

<!DOCTYPE html>
<html>

<head>

    <meta charset="UTF-8">

    <title>View Team Members</title>

    <style>

        * {
            box-sizing: border-box;
            font-family: Arial, sans-serif;
        }

        body {
            margin: 0;
            background: #f4f7fb;
        }

        .container {
            width: 92%;
            margin: 40px auto;
        }

        .card {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
        }

        h1 {
            margin-bottom: 8px;
            color: #0f172a;
        }

        .subtitle {
            color: #64748b;
            margin-bottom: 25px;
        }

        label {
            display: block;
            margin-bottom: 7px;
            font-weight: bold;
            color: #475569;
        }

        select {
            width: 100%;
            padding: 12px;
            border: 1px solid #cbd5e1;
            border-radius: 8px;
            margin-bottom: 25px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }

        th {
            background: #f1f5f9;
            padding: 14px;
            text-align: left;
            color: #475569;
        }

        td {
            padding: 14px;
            border-bottom: 1px solid #e2e8f0;
        }

        .status {
            background: #dcfce7;
            color: #166534;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 12px;
        }

        .back {
            display: inline-block;
            margin-top: 25px;
            background: #64748b;
            color: white;
            padding: 11px 18px;
            border-radius: 8px;
            text-decoration: none;
        }

        .empty {
            text-align: center;
            padding: 25px;
            color: #64748b;
        }

        .team-box {
            background: #f0fdf4;
            color: #166534;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
        }

    </style>

</head>

<body>

<div class="container">

    <div class="card">

        <h1>
            View Team Members
        </h1>

        <p class="subtitle">
            Select one of your teams to view its members.
        </p>


        <form method="get"
              action="<%= request.getContextPath() %>/teamMembers.jsp">

            <label>
                Select Team
            </label>

            <select name="teamId"
                    onchange="this.form.submit()"
                    required>

                <option value="">
                    Select Team
                </option>

                <%

                    String teamSql =
                        "SELECT team_id, team_name " +
                        "FROM teams " +
                        "WHERE manager_id = ? " +
                        "AND status = 'ACTIVE' " +
                        "ORDER BY team_id";

                    ps = con.prepareStatement(teamSql);

                    ps.setString(1, managerId);

                    rs = ps.executeQuery();

                    while (rs.next()) {

                        String teamId =
                            rs.getString("team_id");

                %>

                <option value="<%= teamId %>"
                    <%= teamId.equals(selectedTeamId)
                        ? "selected"
                        : "" %>>

                    <%= teamId %>
                    -
                    <%= rs.getString("team_name") %>

                </option>

                <%

                    }

                    rs.close();
                    ps.close();

                %>

            </select>

        </form>


        <% if (selectedTeamId != null &&
               !selectedTeamId.trim().isEmpty()) { %>


            <%

                String teamName = null;

                String teamCheckSql =
                    "SELECT team_name " +
                    "FROM teams " +
                    "WHERE team_id = ? " +
                    "AND manager_id = ? " +
                    "AND status = 'ACTIVE'";

                ps = con.prepareStatement(teamCheckSql);

                ps.setString(1, selectedTeamId);
                ps.setString(2, managerId);

                rs = ps.executeQuery();

                if (rs.next()) {
                    teamName =
                        rs.getString("team_name");
                }

                rs.close();
                ps.close();

            %>


            <% if (teamName != null) { %>


                <div class="team-box">

                    Team:

                    <strong>
                        <%= teamName %>
                    </strong>

                    (<%= selectedTeamId %>)

                </div>


                <table>

                    <thead>

                        <tr>

                            <th>
                                Employee ID
                            </th>

                            <th>
                                Name
                            </th>

                            <th>
                                Designation
                            </th>

                            <th>
                                Department
                            </th>

                            <th>
                                Status
                            </th>

                        </tr>

                    </thead>


                    <tbody>

                    <%

                        String memberSql =
                            "SELECT e.employee_id, e.name, " +
                            "e.designation, e.department " +
                            "FROM team_members tm " +
                            "JOIN employees e " +
                            "ON tm.employee_id = e.employee_id " +
                            "WHERE tm.team_id = ? " +
                            "AND tm.status = 'ACTIVE' " +
                            "ORDER BY e.name";

                        ps = con.prepareStatement(memberSql);

                        ps.setString(1, selectedTeamId);

                        rs = ps.executeQuery();

                        boolean found = false;

                        while (rs.next()) {

                            found = true;

                    %>

                        <tr>

                            <td>
                                <%= rs.getString("employee_id") %>
                            </td>

                            <td>
                                <%= rs.getString("name") %>
                            </td>

                            <td>
                                <%= rs.getString("designation") %>
                            </td>

                            <td>
                                <%= rs.getString("department") %>
                            </td>

                            <td>

                                <span class="status">
                                    ACTIVE
                                </span>

                            </td>

                        </tr>

                    <%

                        }

                        rs.close();
                        ps.close();

                        if (!found) {

                    %>

                        <tr>

                            <td colspan="5"
                                class="empty">

                                No employees are assigned to this team.

                            </td>

                        </tr>

                    <%

                        }

                    %>

                    </tbody>

                </table>


            <% } else { %>


                <div style="color:red; margin-top:20px;">

                    Invalid team or this team is not assigned to you.

                </div>


            <% } %>


        <% } %>


        <a href="<%= request.getContextPath() %>/manager"
           class="back">

            Back to Dashboard

        </a>

    </div>

</div>

</body>

</html>

<%

    } catch (Exception e) {

        e.printStackTrace();

%>

<h3 style="color:red; padding:30px;">

    Error:
    <%= e.getMessage() %>

</h3>

<%

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