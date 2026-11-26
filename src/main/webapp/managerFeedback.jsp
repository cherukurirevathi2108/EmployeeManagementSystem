<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String managerId = (String) session.getAttribute("managerId");
String managerName = (String) session.getAttribute("managerName");

if (managerId == null) {
    response.sendRedirect(request.getContextPath() + "/login.html");
    return;
}

if (managerName == null || managerName.trim().isEmpty()) {
    managerName = "Manager";
}

String message = request.getParameter("message");

Connection con = null;

String checkInTime = null;
String checkOutTime = null;
String attendanceStatus = "Not Checked In";

int breakCount = 0;

try {

    con = DBcConnection.getConnection();

    /* ================= TODAY ATTENDANCE ================= */

    PreparedStatement psAttendance = con.prepareStatement(
        "SELECT check_in_time, check_out_time, status " +
        "FROM attendance " +
        "WHERE employee_id=? AND date=CURDATE()"
    );

    psAttendance.setString(1, managerId);

    ResultSet rsAttendance = psAttendance.executeQuery();

    if (rsAttendance.next()) {

        Time inTime = rsAttendance.getTime("check_in_time");
        Time outTime = rsAttendance.getTime("check_out_time");

        if (inTime != null) {
            checkInTime = inTime.toString();
        }

        if (outTime != null) {
            checkOutTime = outTime.toString();
        }

        if (rsAttendance.getString("status") != null) {
            attendanceStatus = rsAttendance.getString("status");
        }
    }

    rsAttendance.close();
    psAttendance.close();


    /* ================= BREAK COUNT ================= */

    PreparedStatement psBreak = con.prepareStatement(
        "SELECT COUNT(*) FROM breaks " +
        "WHERE employee_id=? AND break_date=CURDATE()"
    );

    psBreak.setString(1, managerId);

    ResultSet rsBreak = psBreak.executeQuery();

    if (rsBreak.next()) {
        breakCount = rsBreak.getInt(1);
    }

    rsBreak.close();
    psBreak.close();

} catch(Exception e) {
    e.printStackTrace();
}
%>

<!DOCTYPE html>
<html>

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1.0">

<title>Manager Dashboard</title>

<style>

/* =====================================================
   GLOBAL
===================================================== */

* {
    box-sizing: border-box;
}

html {
    scroll-behavior: smooth;
}

body {

    margin: 0;

    font-family: "Segoe UI", Arial, sans-serif;

    background: #f4f7fb;

    color: #1e293b;
}


/* =====================================================
   SIDEBAR
===================================================== */

.sidebar {

    position: fixed;

    left: 0;
    top: 0;

    width: 255px;
    height: 100vh;

    background: linear-gradient(
        180deg,
        #111827 0%,
        #1e293b 100%
    );

    color: white;

    padding: 25px 16px;

    overflow-y: auto;

    box-shadow:
        5px 0 25px rgba(15,23,42,0.15);

    z-index: 1000;
}


.sidebar h2 {

    text-align: center;

    margin: 5px 0 30px;

    font-size: 23px;

    font-weight: 700;
}


.sidebar a {

    display: flex;

    align-items: center;

    gap: 11px;

    text-decoration: none;

    color: #cbd5e1;

    padding: 13px 15px;

    margin-bottom: 6px;

    border-radius: 9px;

    transition: all 0.25s ease;

    font-size: 14px;
}


.sidebar a:hover {

    background: rgba(255,255,255,0.09);

    color: white;

    transform: translateX(3px);
}


.menu-title {

    color: #64748b;

    font-size: 11px;

    margin: 24px 10px 8px;

    text-transform: uppercase;

    font-weight: 700;

    letter-spacing: 1px;
}


/* =====================================================
   MAIN
===================================================== */

.main {

    margin-left: 255px;

    padding: 30px;

    min-height: 100vh;
}


/* =====================================================
   HEADER
===================================================== */

.header {

    background: linear-gradient(
        135deg,
        #ffffff 0%,
        #f8fafc 100%
    );

    padding: 25px 30px;

    border-radius: 16px;

    display: flex;

    justify-content: space-between;

    align-items: center;

    box-shadow:
        0 5px 25px rgba(15,23,42,0.07);

    border: 1px solid #e8edf4;
}


.header h1 {

    margin: 0;

    font-size: 28px;

    color: #0f172a;
}


.header p {

    margin: 8px 0 0;

    color: #64748b;

    font-size: 14px;
}


.header strong {

    background: #eef2ff;

    color: #4f46e5;

    padding: 10px 16px;

    border-radius: 30px;

    font-size: 13px;
}


/* =====================================================
   MESSAGE
===================================================== */

.message {

    margin-top: 20px;

    padding: 15px 18px;

    background: #ecfdf5;

    color: #166534;

    border: 1px solid #bbf7d0;

    border-radius: 10px;
}


/* =====================================================
   SUMMARY CARDS
===================================================== */

.cards {

    display: grid;

    grid-template-columns: repeat(3, 1fr);

    gap: 20px;

    margin-top: 25px;
}


.card {

    background: white;

    padding: 24px;

    border-radius: 15px;

    box-shadow:
        0 5px 20px rgba(15,23,42,0.06);

    border: 1px solid #edf0f5;

    transition: 0.25s ease;
}


.card:hover {

    transform: translateY(-4px);

    box-shadow:
        0 10px 28px rgba(15,23,42,0.10);
}


.card:nth-child(1) {
    border-left: 4px solid #2563eb;
}

.card:nth-child(2) {
    border-left: 4px solid #16a34a;
}

.card:nth-child(3) {
    border-left: 4px solid #f59e0b;
}


.card h3 {

    margin: 0;

    color: #64748b;

    font-size: 14px;

    font-weight: 600;
}


.card .value {

    font-size: 25px;

    font-weight: 700;

    margin-top: 12px;

    color: #0f172a;
}


/* =====================================================
   SECTIONS
===================================================== */

.section,
.dashboard-section {

    background: white;

    margin-top: 25px;

    padding: 26px;

    border-radius: 15px;

    box-shadow:
        0 5px 20px rgba(15,23,42,0.06);

    border: 1px solid #edf0f5;

    scroll-margin-top: 25px;
}


.section h2,
.dashboard-section h2 {

    margin-top: 0;

    margin-bottom: 22px;

    font-size: 20px;

    color: #0f172a;
}


/* =====================================================
   TEAM FEATURE CARDS
===================================================== */

.team-feature-grid {

    display: grid;

    grid-template-columns: repeat(3, 1fr);

    gap: 20px;
}


.team-feature-card {

    padding: 25px;

    border-radius: 15px;

    background:
        linear-gradient(
            145deg,
            #ffffff,
            #f8fafc
        );

    border: 1px solid #e5e7eb;

    transition: all 0.3s ease;
}


.team-feature-card:hover {

    transform: translateY(-5px);

    box-shadow:
        0 12px 30px rgba(15,23,42,0.10);
}


.team-feature-card:nth-child(1) {
    border-top: 4px solid #2563eb;
}

.team-feature-card:nth-child(2) {
    border-top: 4px solid #16a34a;
}

.team-feature-card:nth-child(3) {
    border-top: 4px solid #7c3aed;
}


.team-feature-card h3 {

    margin: 0 0 10px;

    font-size: 18px;
}


.team-feature-card p {

    color: #64748b;

    font-size: 14px;

    line-height: 1.6;

    min-height: 45px;
}


/* =====================================================
   FEATURE BUTTONS
===================================================== */

.feature-btn {

    display: inline-block;

    text-decoration: none;

    padding: 11px 18px;

    border-radius: 8px;

    color: white;

    margin-top: 10px;

    font-size: 13px;

    font-weight: 600;

    transition: 0.25s ease;
}


.feature-btn:hover {

    transform: translateY(-2px);

    box-shadow:
        0 6px 15px rgba(0,0,0,0.15);
}


.feature-blue {

    background:
        linear-gradient(
            135deg,
            #2563eb,
            #1d4ed8
        );
}


.feature-green {

    background:
        linear-gradient(
            135deg,
            #16a34a,
            #15803d
        );
}


.feature-purple {

    background:
        linear-gradient(
            135deg,
            #7c3aed,
            #6d28d9
        );
}


/* =====================================================
   FORMS
===================================================== */

.form-group {

    margin-bottom: 17px;
}


.form-group label,
.dashboard-section label {

    display: block;

    margin-bottom: 7px;

    color: #334155;

    font-size: 13px;

    font-weight: 600;
}


.form-group input,
.form-group select,
.form-group textarea,
.dashboard-section input,
.dashboard-section select,
.dashboard-section textarea {

    width: 100%;

    padding: 12px 13px;

    border: 1px solid #dbe1ea;

    border-radius: 8px;

    font-size: 14px;

    color: #334155;

    background: white;

    outline: none;

    transition: 0.2s ease;
}


.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus,
.dashboard-section input:focus,
.dashboard-section select:focus,
.dashboard-section textarea:focus {

    border-color: #6366f1;

    box-shadow:
        0 0 0 3px rgba(99,102,241,0.10);
}


.form-group textarea,
.dashboard-section textarea {

    min-height: 105px;

    resize: vertical;
}


/* =====================================================
   BUTTONS
===================================================== */

button {

    border: none;

    padding: 11px 19px;

    border-radius: 8px;

    cursor: pointer;

    font-weight: 600;

    font-size: 13px;

    transition: 0.25s ease;
}


button:hover:not(:disabled) {

    transform: translateY(-2px);

    box-shadow:
        0 6px 15px rgba(0,0,0,0.12);
}


.btn-blue {

    background:
        linear-gradient(
            135deg,
            #2563eb,
            #1d4ed8
        );

    color: white;
}


.btn-green {

    background:
        linear-gradient(
            135deg,
            #16a34a,
            #15803d
        );

    color: white;
}


.btn-red {

    background:
        linear-gradient(
            135deg,
            #ef4444,
            #dc2626
        );

    color: white;
}


.btn-purple {

    background:
        linear-gradient(
            135deg,
            #7c3aed,
            #6d28d9
        );

    color: white;
}


.btn-gray {

    background: #64748b;

    color: white;
}


button:disabled {

    background: #cbd5e1;

    color: #64748b;

    cursor: not-allowed;
}


/* =====================================================
   TABLE
===================================================== */

.table-container {

    overflow-x: auto;

    border: 1px solid #e5e7eb;

    border-radius: 10px;
}


table {

    width: 100%;

    border-collapse: collapse;

    background: white;
}


th {

    background: #f8fafc;

    color: #475569;

    text-align: left;

    padding: 14px;

    font-size: 13px;

    border-bottom: 1px solid #e5e7eb;
}


td {

    padding: 14px;

    border-bottom: 1px solid #edf0f5;

    color: #475569;

    font-size: 13px;
}


tr:last-child td {

    border-bottom: none;
}


tr:hover td {

    background: #f8fafc;
}


/* =====================================================
   STATUS
===================================================== */

.status-active {

    color: #15803d;

    font-weight: 700;
}


.status-pending {

    color: #ca8a04;

    font-weight: 700;
}


.status-approved {

    color: #15803d;

    font-weight: 700;
}


.status-rejected {

    color: #dc2626;

    font-weight: 700;
}


/* =====================================================
   RESPONSIVE
===================================================== */

@media(max-width:1100px) {

    .cards,
    .team-feature-grid {

        grid-template-columns: 1fr 1fr;
    }
}


@media(max-width:800px) {

    .sidebar {

        position: relative;

        width: 100%;

        height: auto;
    }


    .main {

        margin-left: 0;

        padding: 20px;
    }


    .cards,
    .team-feature-grid {

        grid-template-columns: 1fr;
    }


    .header {

        flex-direction: column;

        align-items: flex-start;

        gap: 15px;
    }

}

</style>

</head>


<body>


<!-- =====================================================
     SIDEBAR
===================================================== -->

<div class="sidebar">

    <h2>Manager Panel</h2>


    <a href="#home">
        📊 Dashboard
    </a>


    <div class="menu-title">
        Attendance
    </div>


    <a href="#attendance">
        🕒 Attendance
    </a>


    <a href="#breaks">
        ☕ Breaks
    </a>


    <div class="menu-title">
        Leave
    </div>


    <a href="#leave">
        📝 Apply Leave
    </a>


    <a href="#leaveStatus">
        📋 Leave Status
    </a>


    <div class="menu-title">
        Team Management
    </div>


    <a href="#assignTasks">
        📌 Assign Tasks
    </a>


    <a href="#teamMembers">
        👥 View Team Members
    </a>


    <a href="#giveFeedback">
        💬 Give Feedback
    </a>


    <div class="menu-title">
        Teams
    </div>


    <a href="#myTeams">
        🗂️ My Teams
    </a>


    <div class="menu-title">
        Account
    </div>


    <a href="<%=request.getContextPath()%>/logout">
        🚪 Logout
    </a>

</div>



<!-- =====================================================
     MAIN
===================================================== -->

<div class="main">


<!-- =====================================================
     HEADER
===================================================== -->

<div class="header" id="home">

    <div>

        <h1>
            Welcome, <%=managerName%>
        </h1>

        <p>
            Manager ID:
            <strong
                style="background:none;
                       padding:0;
                       color:#64748b;">
                <%=managerId%>
            </strong>
        </p>

    </div>


    <div>

        <strong>
            Manager Dashboard
        </strong>

    </div>

</div>



<% if(message != null && !message.trim().isEmpty()) { %>

<div class="message">

    <%=message%>

</div>

<% } %>



<!-- =====================================================
     SUMMARY CARDS
===================================================== -->

<div class="cards">


    <div class="card">

        <h3>
            Today's Status
        </h3>

        <div class="value">
            <%=attendanceStatus%>
        </div>

    </div>


    <div class="card">

        <h3>
            Check In
        </h3>

        <div class="value">

            <%=checkInTime != null
                ? checkInTime
                : "--"%>

        </div>

    </div>


    <div class="card">

        <h3>
            Check Out
        </h3>

        <div class="value">

            <%=checkOutTime != null
                ? checkOutTime
                : "--"%>

        </div>

    </div>


</div>



<!-- =====================================================
     ATTENDANCE
===================================================== -->

<div class="section" id="attendance">

    <h2>
        🕒 Attendance
    </h2>


    <form
        action="<%=request.getContextPath()%>/manager"
        method="post"
        style="display:inline-block;
               margin-right:10px;">

        <input
            type="hidden"
            name="action"
            value="checkIn">


        <button
            type="submit"
            class="btn-blue"
            <%=checkInTime != null
                ? "disabled"
                : ""%>>

            Check In

        </button>

    </form>



    <form
        action="<%=request.getContextPath()%>/manager"
        method="post"
        style="display:inline-block;">

        <input
            type="hidden"
            name="action"
            value="checkOut">


        <button
            type="submit"
            class="btn-red"
            <%=checkInTime == null ||
                checkOutTime != null
                ? "disabled"
                : ""%>>

            Check Out

        </button>

    </form>

</div>



<!-- =====================================================
     BREAKS
===================================================== -->

<div class="section" id="breaks">

    <h2>
        ☕ Breaks
    </h2>


    <p>

        Breaks taken today:

        <strong>
            <%=breakCount%> / 2
        </strong>

    </p>


    <form
        action="<%=request.getContextPath()%>/manager"
        method="post"
        style="display:inline-block;">

        <input
            type="hidden"
            name="action"
            value="startBreak">


        <button
            type="submit"
            class="btn-green"
            <%=breakCount >= 2
                ? "disabled"
                : ""%>>

            Start Break

        </button>

    </form>



    <form
        action="<%=request.getContextPath()%>/manager"
        method="post"
        style="display:inline-block;
               margin-left:10px;">

        <input
            type="hidden"
            name="action"
            value="endBreak">


        <button
            type="submit"
            class="btn-gray">

            End Break

        </button>

    </form>

</div>



<!-- =====================================================
     TEAM MANAGEMENT
===================================================== -->

<div class="section">

    <h2>
        Team Management
    </h2>


    <div class="team-feature-grid">


        <!-- ASSIGN TASK -->

        <div class="team-feature-card">

            <h3>
                📌 Assign Tasks
            </h3>

            <p>
                Assign tasks to employees
                working in your teams.
            </p>


            <a
                href="#assignTasks"
                class="feature-btn feature-blue">

                Assign Tasks

            </a>

        </div>



        <!-- TEAM MEMBERS -->

        <div class="team-feature-card">

            <h3>
                👥 View Team Members
            </h3>

            <p>
                View employees assigned
                to your teams.
            </p>


            <a
                href="#teamMembers"
                class="feature-btn feature-green">

                View Members

            </a>

        </div>



        <!-- FEEDBACK -->

        <div class="team-feature-card">

            <h3>
                💬 Give Feedback
            </h3>

            <p>
                Give feedback to employees
                working in your teams.
            </p>


            <a
                href="#giveFeedback"
                class="feature-btn feature-purple">

                Give Feedback

            </a>

        </div>


    </div>

</div>



<!-- =====================================================
     ASSIGN TASKS
===================================================== -->

<div
    class="dashboard-section"
    id="assignTasks">

    <h2>
        📌 Assign Tasks
    </h2>


    <form
        action="<%=request.getContextPath()%>/AssignTaskServlet"
        method="post">


        <div class="form-group">

            <label>
                Select Team
            </label>


            <select
                name="teamId"
                required>

                <option value="">
                    Select Team
                </option>


                <%

                try {

                    PreparedStatement psTeams =
                        con.prepareStatement(

                            "SELECT team_id, team_name " +
                            "FROM teams " +
                            "WHERE manager_id=? " +
                            "AND status='ACTIVE' " +
                            "ORDER BY team_id"

                        );


                    psTeams.setString(
                        1,
                        managerId
                    );


                    ResultSet rsTeams =
                        psTeams.executeQuery();


                    while(rsTeams.next()) {

                %>

                <option
                    value="<%=rsTeams.getInt("team_id")%>">

                    <%=rsTeams.getString("team_name")%>

                </option>

                <%

                    }

                    rsTeams.close();
                    psTeams.close();

                }
                catch(Exception e) {

                    e.printStackTrace();

                }

                %>

            </select>

        </div>



        <div class="form-group">

            <label>
                Employee ID
            </label>


            <input
                type="text"
                name="employeeId"
                placeholder="Enter Employee ID"
                required>

        </div>



        <div class="form-group">

            <label>
                Task Title
            </label>


            <input
                type="text"
                name="taskTitle"
                placeholder="Enter task title"
                required>

        </div>



        <div class="form-group">

            <label>
                Task Description
            </label>


            <textarea
                name="taskDescription"
                placeholder="Enter task description"
                required></textarea>

        </div>



        <div class="form-group">

            <label>
                Due Date
            </label>


            <input
                type="date"
                name="dueDate"
                required>

        </div>



        <button
            type="submit"
            class="btn-blue">

            Assign Task

        </button>

    </form>

</div>



<!-- =====================================================
     TEAM MEMBERS
===================================================== -->

<div
    class="dashboard-section"
    id="teamMembers">

    <h2>
        👥 View Team Members
    </h2>


    <div class="table-container">

        <table>

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


            <%

            try {

                PreparedStatement psMembers =
                    con.prepareStatement(

                        "SELECT DISTINCT " +
                        "e.employee_id, " +
                        "e.name, " +
                        "e.designation, " +
                        "e.department, " +
                        "e.status " +

                        "FROM team_members tm " +

                        "JOIN employees e " +
                        "ON tm.employee_id=e.employee_id " +

                        "JOIN teams t " +
                        "ON tm.team_id=t.team_id " +

                        "WHERE t.manager_id=? " +
                        "AND tm.status='ACTIVE' " +

                        "ORDER BY e.name"

                    );


                psMembers.setString(
                    1,
                    managerId
                );


                ResultSet rsMembers =
                    psMembers.executeQuery();


                boolean hasMembers = false;


                while(rsMembers.next()) {

                    hasMembers = true;

            %>

            <tr>

                <td>
                    <%=rsMembers.getString(
                        "employee_id")%>
                </td>

                <td>
                    <%=rsMembers.getString(
                        "name")%>
                </td>

                <td>
                    <%=rsMembers.getString(
                        "designation")%>
                </td>

                <td>
                    <%=rsMembers.getString(
                        "department")%>
                </td>

                <td class="status-active">

                    <%=rsMembers.getString(
                        "status")%>

                </td>

            </tr>

            <%

                }


                if(!hasMembers) {

            %>

            <tr>

                <td
                    colspan="5"
                    style="text-align:center;
                           color:#94a3b8;">

                    No team members found.

                </td>

            </tr>

            <%

                }


                rsMembers.close();
                psMembers.close();

            }
            catch(Exception e) {

                e.printStackTrace();

            %>

            <tr>

                <td colspan="5">

                    Unable to load team members.

                </td>

            </tr>

            <%

            }

            %>

        </table>

    </div>

</div>



<!-- =====================================================
     GIVE FEEDBACK
===================================================== -->

<div
    class="dashboard-section"
    id="giveFeedback">

    <h2>
        💬 Give Feedback
    </h2>


    <form
        action="<%=request.getContextPath()%>/ManagerFeedbackServlet"
        method="post">


        <div class="form-group">

            <label>
                Select Team
            </label>


            <select
                name="teamId"
                required>

                <option value="">
                    Select Team
                </option>


                <%

                try {

                    PreparedStatement psFeedbackTeams =
                        con.prepareStatement(

                            "SELECT team_id, team_name " +
                            "FROM teams " +
                            "WHERE manager_id=? " +
                            "AND status='ACTIVE' " +
                            "ORDER BY team_id"

                        );


                    psFeedbackTeams.setString(
                        1,
                        managerId
                    );


                    ResultSet rsFeedbackTeams =
                        psFeedbackTeams.executeQuery();


                    while(rsFeedbackTeams.next()) {

                %>

                <option
                    value="<%=rsFeedbackTeams.getInt(
                        "team_id")%>">

                    <%=rsFeedbackTeams.getString(
                        "team_name")%>

                </option>

                <%

                    }

                    rsFeedbackTeams.close();
                    psFeedbackTeams.close();

                }
                catch(Exception e) {

                    e.printStackTrace();

                }

                %>

            </select>

        </div>



        <div class="form-group">

            <label>
                Employee ID
            </label>


            <input
                type="text"
                name="employeeId"
                placeholder="Enter Employee ID"
                required>

        </div>



        <div class="form-group">

            <label>
                Rating
            </label>


            <select
                name="rating"
                required>

                <option value="">
                    Select Rating
                </option>

                <option value="1">
                    1 - Poor
                </option>

                <option value="2">
                    2 - Average
                </option>

                <option value="3">
                    3 - Good
                </option>

                <option value="4">
                    4 - Very Good
                </option>

                <option value="5">
                    5 - Excellent
                </option>

            </select>

        </div>



        <div class="form-group">

            <label>
                Feedback
            </label>


            <textarea
                name="feedbackText"
                placeholder="Enter your feedback..."
                required></textarea>

        </div>



        <button
            type="submit"
            class="btn-purple">

            Submit Feedback

        </button>

    </form>

</div>



<!-- =====================================================
     APPLY LEAVE
===================================================== -->

<div
    class="section"
    id="leave">

    <h2>
        📝 Apply Leave
    </h2>


    <form
        action="<%=request.getContextPath()%>/manager"
        method="post">


        <input
            type="hidden"
            name="action"
            value="applyLeave">


        <div class="form-group">

            <label>
                Leave Type
            </label>


            <select
                name="leaveType"
                required>

                <option value="">
                    Select Leave Type
                </option>

                <option value="CASUAL">
                    Casual Leave
                </option>

                <option value="SICK">
                    Sick Leave
                </option>

                <option value="PERSONAL">
                    Personal Leave
                </option>

            </select>

        </div>



        <div class="form-group">

            <label>
                From Date
            </label>


            <input
                type="date"
                name="fromDate"
                required>

        </div>



        <div class="form-group">

            <label>
                To Date
            </label>


            <input
                type="date"
                name="toDate"
                required>

        </div>



        <div class="form-group">

            <label>
                Reason
            </label>


            <textarea
                name="reason"
                placeholder="Enter reason"
                required></textarea>

        </div>



        <button
            type="submit"
            class="btn-blue">

            Apply Leave

        </button>

    </form>

</div>



<!-- =====================================================
     LEAVE STATUS
===================================================== -->

<div
    class="section"
    id="leaveStatus">

    <h2>
        📋 Leave Status
    </h2>


    <div class="table-container">

        <table>

            <tr>

                <th>Leave ID</th>

                <th>Type</th>

                <th>From</th>

                <th>To</th>

                <th>Reason</th>

                <th>Status</th>

            </tr>


            <%

            try {

                PreparedStatement psLeaves =
                    con.prepareStatement(

                        "SELECT leave_id, leave_type, " +
                        "from_date, to_date, reason, status " +

                        "FROM leave_requests " +

                        "WHERE employee_id=? " +

                        "ORDER BY applied_date DESC, " +
                        "leave_id DESC " +

                        "LIMIT 5"

                    );


                psLeaves.setString(
                    1,
                    managerId
                );


                ResultSet rsLeaves =
                    psLeaves.executeQuery();


                boolean hasLeaves = false;


                while(rsLeaves.next()) {

                    hasLeaves = true;


                    String leaveStatus =
                        rsLeaves.getString("status");


                    String statusClass;


                    if("APPROVED".equalsIgnoreCase(
                        leaveStatus)) {

                        statusClass =
                            "status-approved";

                    }
                    else if("REJECTED".equalsIgnoreCase(
                        leaveStatus)) {

                        statusClass =
                            "status-rejected";

                    }
                    else {

                        statusClass =
                            "status-pending";

                    }

            %>

            <tr>

                <td>
                    <%=rsLeaves.getInt(
                        "leave_id")%>
                </td>

                <td>
                    <%=rsLeaves.getString(
                        "leave_type")%>
                </td>

                <td>
                    <%=rsLeaves.getDate(
                        "from_date")%>
                </td>

                <td>
                    <%=rsLeaves.getDate(
                        "to_date")%>
                </td>

                <td>
                    <%=rsLeaves.getString(
                        "reason")%>
                </td>

                <td class="<%=statusClass%>">

                    <%=leaveStatus%>

                </td>

            </tr>

            <%

                }


                if(!hasLeaves) {

            %>

            <tr>

                <td
                    colspan="6"
                    style="text-align:center;
                           color:#94a3b8;">

                    No leave requests found.

                </td>

            </tr>

            <%

                }


                rsLeaves.close();
                psLeaves.close();

            }
            catch(Exception e) {

                e.printStackTrace();

            %>

            <tr>

                <td colspan="6">

                    Unable to load leave requests.

                </td>

            </tr>

            <%

            }

            %>

        </table>

    </div>

</div>



<!-- =====================================================
     MY TEAMS
===================================================== -->

<div
    class="section"
    id="myTeams">

    <h2>
        🗂️ My Teams
    </h2>


    <div class="table-container">

        <table>

            <tr>

                <th>Team ID</th>

                <th>Team Name</th>

                <th>Department</th>

                <th>Manager</th>

                <th>Status</th>

            </tr>


            <%

            try {

                PreparedStatement psMyTeams =
                    con.prepareStatement(

                        "SELECT " +
                        "t.team_id, " +
                        "t.team_name, " +
                        "t.department, " +
                        "t.manager_id, " +
                        "e.name AS manager_name, " +
                        "t.status " +

                        "FROM teams t " +

                        "LEFT JOIN employees e " +
                        "ON t.manager_id=e.employee_id " +

                        "WHERE t.manager_id=? " +

                        "ORDER BY t.team_id DESC"

                    );


                psMyTeams.setString(
                    1,
                    managerId
                );


                ResultSet rsMyTeams =
                    psMyTeams.executeQuery();


                boolean hasTeams = false;


                while(rsMyTeams.next()) {

                    hasTeams = true;

            %>

            <tr>

                <td>
                    <%=rsMyTeams.getInt(
                        "team_id")%>
                </td>

                <td>
                    <%=rsMyTeams.getString(
                        "team_name")%>
                </td>

                <td>
                    <%=rsMyTeams.getString(
                        "department")%>
                </td>

                <td>
                    <%=rsMyTeams.getString(
                        "manager_name")%>
                </td>

                <td class="status-active">

                    <%=rsMyTeams.getString(
                        "status")%>

                </td>

            </tr>

            <%

                }


                if(!hasTeams) {

            %>

            <tr>

                <td
                    colspan="5"
                    style="text-align:center;
                           color:#94a3b8;">

                    No teams assigned to you.

                </td>

            </tr>

            <%

                }


                rsMyTeams.close();
                psMyTeams.close();

            }
            catch(Exception e) {

                e.printStackTrace();

            %>

            <tr>

                <td colspan="5">

                    Unable to load teams.

                </td>

            </tr>

            <%

            }

            %>

        </table>

    </div>

</div>


</div>


</body>

</html>


<%

if(con != null) {

    try {

        con.close();

    }
    catch(Exception e) {

        e.printStackTrace();

    }

}

%>