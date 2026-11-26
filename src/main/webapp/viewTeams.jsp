<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<!DOCTYPE html>
<html>
<head>

    <title>View All Teams</title>

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

        .header h2 {
            margin: 0;
            font-size: 25px;
            font-weight: 700;
        }

        .header p {
            margin: 5px 0 0;
            font-size: 13px;
            opacity: 0.85;
        }

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

        /* ================= MAIN CONTAINER ================= */

        .container {
            width: 94%;
            max-width: 1450px;
            margin: 35px auto;
        }

        .box {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 8px 30px rgba(15, 23, 42, 0.08);
            border: 1px solid #e5e7eb;
        }

        .box-title {
            margin-bottom: 25px;
        }

        .box-title h2 {
            margin: 0;
            font-size: 23px;
            color: #111827;
        }

        .box-title p {
            margin: 6px 0 0;
            color: #6b7280;
            font-size: 13px;
        }

        /* ================= MESSAGE ================= */

        .message {
            padding: 13px 16px;
            margin-bottom: 20px;
            text-align: center;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
        }

        .success {
            background: #ecfdf5;
            color: #047857;
            border: 1px solid #a7f3d0;
        }

        .message-error {
            background: #fef2f2;
            color: #dc2626;
            border: 1px solid #fecaca;
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
            min-width: 950px;
            border-collapse: collapse;
        }

        th {
            background: #eef2ff;
            color: #3730a3;
            padding: 16px 12px;
            font-size: 13px;
            font-weight: 700;
            text-align: center;
            border-bottom: 2px solid #c7d2fe;
        }

        td {
            padding: 16px 12px;
            text-align: center;
            font-size: 14px;
            color: #4b5563;
            border-bottom: 1px solid #edf0f5;
        }

        tr:last-child td {
            border-bottom: none;
        }

        tbody tr {
            transition: 0.2s;
        }

        tbody tr:hover {
            background: #f8faff;
        }

        /* ================= TEAM ID ================= */

        .team-id {
            display: inline-block;
            background: #eef2ff;
            color: #4338ca;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 700;
        }

        /* ================= TEAM NAME ================= */

        .team-name {
            color: #111827;
            font-weight: 600;
        }

        /* ================= DEPARTMENT ================= */

        .department {
            color: #6b7280;
            font-weight: 500;
        }

        /* ================= MANAGER ================= */

        .manager-name {
            display: block;
            color: #1f2937;
            font-weight: 600;
        }

        .manager-id {
            display: block;
            color: #9ca3af;
            font-size: 11px;
            margin-top: 3px;
        }

        .not-assigned {
            color: #9ca3af;
            font-size: 13px;
            font-style: italic;
        }

        /* ================= STATUS ================= */

        .status {
            display: inline-block;
            padding: 6px 13px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.4px;
        }

        .status-active {
            background: #dcfce7;
            color: #15803d;
        }

        .status-inactive {
            background: #fee2e2;
            color: #dc2626;
        }

        /* ================= ACTION BUTTONS ================= */

        .actions {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 7px;
            flex-wrap: wrap;
        }

        .action {
            display: inline-block;
            padding: 8px 13px;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
            transition: 0.25s;
        }

        .action:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(0,0,0,0.12);
        }

        .view {
            background: #2563eb;
        }

        .view:hover {
            background: #1d4ed8;
        }

        .edit {
            background: #f59e0b;
        }

        .edit:hover {
            background: #d97706;
        }

        .members {
            background: #7c3aed;
        }

        .members:hover {
            background: #6d28d9;
        }

        .delete {
            background: #dc2626;
        }

        .delete:hover {
            background: #b91c1c;
        }

        /* ================= NO DATA ================= */

        .no-data {
            text-align: center;
            padding: 45px 20px;
            color: #9ca3af;
            font-size: 15px;
        }

        /* ================= ERROR ================= */

        .error {
            color: #dc2626;
            text-align: center;
            padding: 30px;
            font-size: 14px;
        }

        /* ================= FOOTER ================= */

        .table-info {
            margin-top: 15px;
            color: #9ca3af;
            font-size: 12px;
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

        }

    </style>

</head>

<body>

<!-- ================= HEADER ================= -->

<div class="header">

    <div>

        <h2>Employee Management System</h2>

        <p>Team Management</p>

    </div>

    <a href="admin_dashbaord.jsp" class="back">
        Admin Panel
    </a>

</div>


<!-- ================= MAIN ================= -->

<div class="container">

    <div class="box">

        <div class="box-title">

            <h2>View All Teams</h2>

            <p>
                Manage teams, managers, members and team status
            </p>

        </div>


        <!-- SUCCESS / ERROR MESSAGE -->

        <%

            String message = request.getParameter("message");

            String type = request.getParameter("type");

            if (message != null && !message.trim().isEmpty()) {

        %>

            <div class="message <%= "success".equalsIgnoreCase(type)
                    ? "success"
                    : "message-error" %>">

                <%= message %>

            </div>

        <%

            }

        %>


        <!-- ================= TEAM TABLE ================= -->

        <div class="table-wrapper">

        <table>

            <thead>

                <tr>

                    <th>Team ID</th>

                    <th>Team Name</th>

                    <th>Department</th>

                    <th>Manager</th>

                    <th>Status</th>

                    <th>Actions</th>

                </tr>

            </thead>

            <tbody>


            <%

                Connection con = null;

                PreparedStatement ps = null;

                ResultSet rs = null;

                boolean found = false;

                try {

                    con = DBcConnection.getConnection();

                    String sql =
                    	    "SELECT t.team_id, " +
                    	    "t.team_name, " +
                    	    "t.department, " +
                    	    "t.status, " +
                    	    "t.manager_id, " +
                    	    "m.name AS manager_name " +
                    	    "FROM teams t " +
                    	    "LEFT JOIN managers m " +
                    	    "ON t.manager_id = m.employee_id " +
                    	    "ORDER BY t.team_id DESC";


                    ps = con.prepareStatement(sql);

                    rs = ps.executeQuery();


                    while (rs.next()) {

                        found = true;

                        String teamId =
                            rs.getString("team_id");

                        String teamName =
                            rs.getString("team_name");

                        String department =
                            rs.getString("department");

                        String managerId =
                            rs.getString("manager_id");

                        String managerName =
                            rs.getString("manager_name");

                        String status =
                            rs.getString("status");

            %>


            <tr>

                <!-- TEAM ID -->

                <td>

                    <span class="team-id">
                        <%= teamId %>
                    </span>

                </td>


                <!-- TEAM NAME -->

                <td>

                    <span class="team-name">
                        <%= teamName %>
                    </span>

                </td>


                <!-- DEPARTMENT -->

                <td>

                    <span class="department">
                        <%= department %>
                    </span>

                </td>


                <!-- MANAGER -->

                <td>

                    <%

                    if (managerName != null) {

                    %>

                        <span class="manager-name">
                            <%= managerName %>
                        </span>

                        <span class="manager-id">
                            <%= managerId %>
                        </span>

                    <%

                    } else {

                    %>

                        <span class="not-assigned">
                            Manager Not Assigned
                        </span>

                    <%

                    }

                    %>

                </td>


                <!-- STATUS -->

                <td>

                    <%

                    if ("ACTIVE".equalsIgnoreCase(status)) {

                    %>

                        <span class="status status-active">
                            ACTIVE
                        </span>

                    <%

                    } else {

                    %>

                        <span class="status status-inactive">
                            <%= status %>
                        </span>

                    <%

                    }

                    %>

                </td>


                <!-- ACTIONS -->

                <td>

                    <div class="actions">


                        <!-- VIEW -->

                        <a
                            href="teamDetails.jsp?teamId=<%= teamId %>"
                            class="action view">

                            View

                        </a>


                        <!-- EDIT -->

                        <a
                            href="editTeam.jsp?teamId=<%= teamId %>"
                            class="action edit">

                            Edit

                        </a>


                        <!-- MEMBERS -->

                        <a
                            href="assignEmployees.jsp?teamId=<%= teamId %>"
                            class="action members">

                            Members

                        </a>


                        <!-- DELETE -->

                        <a
                            href="DeleteTeamServlet?teamId=<%= teamId %>"
                            class="action delete"
                            onclick="return confirmDelete('<%= teamName.replace("'", "\\'") %>');">

                            Delete

                        </a>


                    </div>

                </td>

            </tr>


            <%

                    }


                    if (!found) {

            %>

                <tr>

                    <td colspan="6" class="no-data">

                        No teams found.

                    </td>

                </tr>

            <%

                    }

                }

                catch (Exception e) {

                    e.printStackTrace();

            %>

                <tr>

                    <td colspan="6" class="error">

                        Error loading teams.

                    </td>

                </tr>

            <%

                }

                finally {

                    try {

                        if (rs != null)
                            rs.close();

                    } catch (Exception e) {}


                    try {

                        if (ps != null)
                            ps.close();

                    } catch (Exception e) {}


                    try {

                        if (con != null)
                            con.close();

                    } catch (Exception e) {}

                }

            %>


            </tbody>

        </table>

        </div>


        <div class="table-info">

            All registered teams are displayed here.

        </div>

    </div>

</div>


<!-- ================= DELETE CONFIRMATION ================= -->

<script>

function confirmDelete(teamName) {

    return confirm(
        'Are you sure you want to delete the team "' +
        teamName +
        '"?'
    );

}

</script>


</body>

</html>