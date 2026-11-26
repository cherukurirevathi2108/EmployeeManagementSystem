<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%

String managerId =
    (String) session.getAttribute("managerId");

if (managerId == null) {

    response.sendRedirect("managerLogin.jsp");

    return;
}


String teamId =
    request.getParameter("teamId");

if (teamId == null || teamId.trim().isEmpty()) {

    response.sendRedirect(
        "managerDashboard.jsp?message=Team ID is missing"
    );

    return;
}


Connection con =
    DBcConnection.getConnection();


PreparedStatement teamPs =
    con.prepareStatement(

        "SELECT team_id, team_name, description, " +
        "department, status " +
        "FROM teams " +
        "WHERE team_id=? AND manager_id=?"
    );


teamPs.setString(1, teamId);
teamPs.setString(2, managerId);


ResultSet teamRs =
    teamPs.executeQuery();


if (!teamRs.next()) {

    teamRs.close();
    teamPs.close();
    con.close();

    response.sendRedirect(
        "managerDashboard.jsp?message=" +
        "Team not found or not assigned to you"
    );

    return;
}


String teamName =
    teamRs.getString("team_name");

String description =
    teamRs.getString("description");

String department =
    teamRs.getString("department");

String status =
    teamRs.getString("status");

%>


<!DOCTYPE html>

<html>

<head>

    <title>Team Details</title>

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">


    <style>

        * {
            box-sizing: border-box;
        }


        /* =========================
           BODY
        ========================= */

        body {

            margin: 0;

            font-family:
                Arial,
                Helvetica,
                sans-serif;

            background:
                linear-gradient(
                    135deg,
                    #eef2ff 0%,
                    #f8f5ff 45%,
                    #eef7ff 100%
                );

            color: #1f2937;

            min-height: 100vh;
        }


        /* =========================
           HEADER
        ========================= */

        .top-header {

            width: 100%;

            padding: 18px 45px;

            background:
                linear-gradient(
                    135deg,
                    #4f46e5,
                    #6d28d9,
                    #7c3aed
                );

            color: white;

            display: flex;

            align-items: center;

            justify-content: space-between;

            box-shadow:
                0 4px 18px
                rgba(79, 70, 229, 0.25);
        }


        .brand {

            font-size: 22px;

            font-weight: bold;

            letter-spacing: 0.3px;
        }


        .brand span {

            opacity: 0.8;

            font-size: 14px;

            font-weight: normal;

            margin-left: 8px;
        }


        /* =========================
           CONTAINER
        ========================= */

        .container {

            width: 90%;

            max-width: 1100px;

            margin: 40px auto 60px;
        }


        /* =========================
           TITLE
        ========================= */

        .page-title {

            text-align: center;

            margin-bottom: 30px;
        }


        .title-box {

            width: 60px;

            height: 60px;

            margin: 0 auto 15px;

            border-radius: 16px;

            display: flex;

            align-items: center;

            justify-content: center;

            background:
                linear-gradient(
                    135deg,
                    #4f46e5,
                    #7c3aed
                );

            color: white;

            font-size: 14px;

            font-weight: bold;

            letter-spacing: 1px;

            box-shadow:
                0 8px 20px
                rgba(79, 70, 229, 0.25);
        }


        .page-title h2 {

            margin: 0;

            color: #1e1b4b;

            font-size: 28px;
        }


        .page-title p {

            margin-top: 8px;

            color: #6b7280;

            font-size: 14px;
        }


        /* =========================
           BOX
        ========================= */

        .box {

            background:
                rgba(255, 255, 255, 0.97);

            padding: 30px;

            margin-bottom: 25px;

            border-radius: 16px;

            border: 1px solid #e5e7eb;

            box-shadow:
                0 12px 35px
                rgba(79, 70, 229, 0.10),

                0 3px 10px
                rgba(0, 0, 0, 0.04);
        }


        /* =========================
           BOX TITLE
        ========================= */

        .box-header {

            display: flex;

            align-items: center;

            justify-content: space-between;

            margin-bottom: 20px;

            padding-bottom: 15px;

            border-bottom:
                1px solid #e5e7eb;
        }


        .box-header h3 {

            margin: 0;

            color: #312e81;

            font-size: 20px;
        }


        .member-count {

            padding: 6px 12px;

            background: #eef2ff;

            color: #4f46e5;

            border-radius: 20px;

            font-size: 12px;

            font-weight: bold;
        }


        /* =========================
           DETAILS
        ========================= */

        .details {

            margin-top: 5px;
        }


        .row {

            display: flex;

            padding: 15px 12px;

            border-bottom:
                1px solid #edf0f5;

            transition: background 0.2s;
        }


        .row:hover {

            background: #f8f7ff;
        }


        .row:last-child {

            border-bottom: none;
        }


        .label {

            width: 190px;

            font-weight: 600;

            color: #4b5563;
        }


        .value {

            flex: 1;

            color: #111827;

            word-break: break-word;
        }


        /* =========================
           STATUS
        ========================= */

        .status {

            display: inline-block;

            padding: 6px 13px;

            border-radius: 20px;

            font-size: 12px;

            font-weight: bold;
        }


        .status-active {

            background: #dcfce7;

            color: #15803d;
        }


        .status-inactive {

            background: #fee2e2;

            color: #dc2626;
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

            border-collapse: separate;

            border-spacing: 0;

            margin-top: 5px;

            overflow: hidden;

            border: 1px solid #e5e7eb;

            border-radius: 10px;
        }


        th {

            background:
                linear-gradient(
                    135deg,
                    #4f46e5,
                    #6366f1
                );

            color: white;

            padding: 14px 12px;

            font-size: 13px;

            text-align: center;

            white-space: nowrap;
        }


        td {

            padding: 14px 12px;

            border-bottom:
                1px solid #edf0f5;

            text-align: center;

            font-size: 13px;

            color: #374151;
        }


        tbody tr {

            transition: background 0.2s;
        }


        tbody tr:hover {

            background: #f8f7ff;
        }


        tbody tr:last-child td {

            border-bottom: none;
        }


        /* =========================
           EMPTY MESSAGE
        ========================= */

        .empty-message {

            padding: 30px;

            text-align: center;

            color: #6b7280;

            background: #f9fafb;

            border-radius: 10px;

            font-size: 14px;
        }


        /* =========================
           BACK BUTTON
        ========================= */

        .back {

            display: inline-block;

            padding: 12px 20px;

            background:
                linear-gradient(
                    135deg,
                    #4f46e5,
                    #7c3aed
                );

            color: white;

            text-decoration: none;

            border-radius: 9px;

            font-size: 14px;

            font-weight: 600;

            box-shadow:
                0 7px 16px
                rgba(79, 70, 229, 0.20);

            transition:
                transform 0.2s,
                box-shadow 0.2s;
        }


        .back:hover {

            transform: translateY(-2px);

            box-shadow:
                0 10px 22px
                rgba(79, 70, 229, 0.28);
        }


        /* =========================
           RESPONSIVE
        ========================= */

        @media (max-width: 700px) {

            .top-header {

                padding: 16px 20px;
            }


            .brand {

                font-size: 18px;
            }


            .brand span {

                display: none;
            }


            .container {

                width: 94%;

                margin-top: 25px;
            }


            .box {

                padding: 20px;
            }


            .row {

                display: block;
            }


            .label {

                width: 100%;

                margin-bottom: 7px;
            }


            .page-title h2 {

                font-size: 23px;
            }


            .box-header {

                align-items: flex-start;

                gap: 10px;

                flex-direction: column;
            }

        }

    </style>

</head>


<body>


    <!-- =========================
         HEADER
    ========================= -->

    <div class="top-header">

        <div class="brand">

            Employee Management System

            <span>
                Team Management
            </span>

        </div>

    </div>



    <!-- =========================
         MAIN CONTAINER
    ========================= -->

    <div class="container">


        <!-- =========================
             PAGE TITLE
        ========================= -->

        <div class="page-title">

            <div class="title-box">
                TEAM
            </div>

            <h2>
                Team Details
            </h2>

            <p>
                View team information and assigned employees
            </p>

        </div>



        <!-- =========================
             TEAM INFORMATION
        ========================= -->

        <div class="box">


            <div class="box-header">

                <h3>
                    Team Information
                </h3>

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

            </div>



            <div class="details">


                <!-- TEAM ID -->

                <div class="row">

                    <div class="label">
                        Team ID
                    </div>

                    <div class="value">

                        <strong>
                            <%= teamId %>
                        </strong>

                    </div>

                </div>



                <!-- TEAM NAME -->

                <div class="row">

                    <div class="label">
                        Team Name
                    </div>

                    <div class="value">

                        <strong>
                            <%= teamName %>
                        </strong>

                    </div>

                </div>



                <!-- DESCRIPTION -->

                <div class="row">

                    <div class="label">
                        Description
                    </div>

                    <div class="value">

                        <%= description == null
                            ? ""
                            : description %>

                    </div>

                </div>



                <!-- DEPARTMENT -->

                <div class="row">

                    <div class="label">
                        Department
                    </div>

                    <div class="value">

                        <%= department == null
                            ? ""
                            : department %>

                    </div>

                </div>



                <!-- MANAGER -->

                <div class="row">

                    <div class="label">
                        Manager ID
                    </div>

                    <div class="value">

                        <strong>
                            <%= managerId %>
                        </strong>

                    </div>

                </div>



                <!-- STATUS -->

                <div class="row">

                    <div class="label">
                        Status
                    </div>

                    <div class="value">

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

                    </div>

                </div>


            </div>

        </div>



        <!-- =========================
             TEAM MEMBERS
        ========================= -->

        <div class="box">


            <div class="box-header">

                <h3>
                    Team Members
                </h3>

                <span class="member-count">
                    Assigned Employees
                </span>

            </div>


            <div class="table-wrapper">

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
                                Email
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

                        PreparedStatement memberPs =
                            con.prepareStatement(

                                "SELECT e.employee_id, " +
                                "e.name, e.email, " +
                                "e.department, tm.status " +

                                "FROM team_members tm " +

                                "JOIN employees e " +

                                "ON tm.employee_id = " +
                                "e.employee_id " +

                                "WHERE tm.team_id=? " +

                                "AND tm.status='ACTIVE' " +

                                "ORDER BY e.employee_id"
                            );


                        memberPs.setString(
                            1,
                            teamId
                        );


                        ResultSet memberRs =
                            memberPs.executeQuery();


                        boolean found = false;


                        while (memberRs.next()) {

                            found = true;

                    %>

                        <tr>

                            <td>

                                <strong>
                                    <%= memberRs.getString(
                                        "employee_id") %>
                                </strong>

                            </td>


                            <td>

                                <%= memberRs.getString(
                                    "name") %>

                            </td>


                            <td>

                                <%= memberRs.getString(
                                    "email") %>

                            </td>


                            <td>

                                <%= memberRs.getString(
                                    "department") %>

                            </td>


                            <td>

                                <%

                                    String memberStatus =
                                        memberRs.getString(
                                            "status"
                                        );


                                    if ("ACTIVE".equalsIgnoreCase(
                                        memberStatus)) {

                                %>

                                    <span class="status status-active">
                                        ACTIVE
                                    </span>

                                <%

                                    } else {

                                %>

                                    <span class="status status-inactive">
                                        <%= memberStatus %>
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

                            <td colspan="5">

                                <div class="empty-message">

                                    No employees assigned to this team.

                                </div>

                            </td>

                        </tr>

                    <%

                        }


                        memberRs.close();

                        memberPs.close();

                        teamRs.close();

                        teamPs.close();

                        con.close();

                    %>

                    </tbody>

                </table>

            </div>

        </div>



        <!-- =========================
             BACK
        ========================= -->

        <a
            href="managerDashboard.jsp"
            class="back">

            Back to Manager Dashboard

        </a>


    </div>


</body>

</html>