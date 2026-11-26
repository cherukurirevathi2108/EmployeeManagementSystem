<%@ page import="java.util.List" %>
<%@ page import="model.Team" %>

<!DOCTYPE html>

<html>

<head>

    <title>Manage Teams</title>

    <style>

        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #f4f6f8;
        }

        .header {
            background: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
        }

        .container {
            width: 95%;
            margin: 30px auto;
        }

        .top-buttons {
            margin-bottom: 20px;
        }

        .button {
            display: inline-block;
            padding: 10px 18px;
            margin-right: 10px;
            background: #2c3e50;
            color: white;
            text-decoration: none;
            border-radius: 5px;
        }

        .button:hover {
            background: #1a252f;
        }

        .back-button {
            background: #777;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            box-shadow: 0 0 10px #ccc;
        }

        th {
            background: #2c3e50;
            color: white;
            padding: 13px;
        }

        td {
            padding: 12px;
            text-align: center;
            border-bottom: 1px solid #ddd;
        }

        tr:hover {
            background: #f5f5f5;
        }

        .action {
            display: inline-block;
            padding: 7px 10px;
            margin: 2px;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            font-size: 13px;
        }

        .view {
            background: #3498db;
        }

        .edit {
            background: #f39c12;
        }

        .members {
            background: #27ae60;
        }

        .delete {
            background: #e74c3c;
        }

        .active {
            color: green;
            font-weight: bold;
        }

        .inactive {
            color: red;
            font-weight: bold;
        }

        .no-data {
            text-align: center;
            padding: 30px;
            background: white;
            color: #777;
        }

        .manager-name {
            font-weight: bold;
            color: #2c3e50;
        }

    </style>

</head>


<body>


<div class="header">

    <h1>Manage Teams</h1>

</div>


<div class="container">


    <div class="top-buttons">

        <!-- IMPORTANT:
             Open ManageTeamsServlet, NOT manageTeams.jsp directly
        -->

        <a href="createTeam.jsp" class="button">
            + Create Team
        </a>

        <a href="adminPanel.jsp" class="button back-button">
            Back to Admin Panel
        </a>

    </div>


    <table>

        <tr>

            <th>Team ID</th>

            <th>Team Name</th>

            <th>Department</th>

            <th>Manager</th>

            <th>Status</th>

            <th>Actions</th>

        </tr>


        <%

            List<Team> teams =
                (List<Team>) request.getAttribute("teams");

            if (teams != null && !teams.isEmpty()) {

                for (Team team : teams) {

        %>


        <tr>


            <!-- TEAM ID -->

            <td>

                <%= team.getTeamId() %>

            </td>


            <!-- TEAM NAME -->

            <td>

                <%= team.getTeamName() %>

            </td>


            <!-- DEPARTMENT -->

            <td>

                <%= team.getDepartment() %>

            </td>


            <!-- MANAGER -->

            <td>

                <%

                    String managerName =
                        team.getManagerName();

                    if (managerName != null &&
                        !managerName.trim().isEmpty()) {

                %>

                    <span class="manager-name">

                        <%= managerName %>

                    </span>

                <%

                    } else {

                %>

                    <span>

                        Manager Not Assigned

                    </span>

                <%

                    }

                %>

            </td>


            <!-- STATUS -->

            <td>

                <%

                    if ("ACTIVE".equalsIgnoreCase(
                            team.getStatus())) {

                %>

                    <span class="active">

                        ACTIVE

                    </span>

                <%

                    } else {

                %>

                    <span class="inactive">

                        INACTIVE

                    </span>

                <%

                    }

                %>

            </td>


            <!-- ACTIONS -->

            <td>


                <a class="action view"
                   href="ViewTeamServlet?teamId=<%= team.getTeamId() %>">

                    View

                </a>


                <a class="action edit"
                   href="editTeam.jsp?teamId=<%= team.getTeamId() %>">

                    Edit

                </a>


                <a class="action members"
                   href="teamMembers.jsp?teamId=<%= team.getTeamId() %>">

                    Members

                </a>


                <a class="action delete"
                   href="DeleteTeamServlet?teamId=<%= team.getTeamId() %>"
                   onclick="return confirm('Are you sure you want to delete this team?');">

                    Delete

                </a>


            </td>


        </tr>


        <%

                }

            } else {

        %>


        <tr>

            <td colspan="6">

                <div class="no-data">

                    No teams found.

                </div>

            </td>

        </tr>


        <%

            }

        %>


    </table>


</div>


</body>

</html>