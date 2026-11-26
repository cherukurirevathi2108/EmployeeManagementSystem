<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<%
String teamId = request.getParameter("teamId");

if (teamId == null || teamId.trim().isEmpty()) {
    response.sendRedirect("viewTeams.jsp");
    return;
}

String teamName = "";
String description = "";
String department = "";
String managerId = "";
String status = "";

Connection con = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {
    con = DBcConnection.getConnection();

    String sql =
        "SELECT team_name, description, department, manager_id, status " +
        "FROM teams WHERE team_id = ?";

    ps = con.prepareStatement(sql);
    ps.setString(1, teamId);
    rs = ps.executeQuery();

    if (rs.next()) {
        teamName = rs.getString("team_name");
        description = rs.getString("description");
        department = rs.getString("department");
        managerId = rs.getString("manager_id");
        status = rs.getString("status");
    } else {
        response.sendRedirect("viewTeams.jsp");
        return;
    }

} catch (Exception e) {
    e.printStackTrace();

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

<title>Edit Team</title>

<meta name="viewport" content="width=device-width, initial-scale=1.0">

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: Arial, Helvetica, sans-serif;
    background: #f5f7fb;
    color: #1f2937;
}

/* HEADER */

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

/* CONTAINER */

.container {
    width: 100%;
    max-width: 760px;
    margin: 40px auto;
    padding: 0 20px;
}

/* MESSAGE */

.message {
    padding: 14px 18px;
    margin-bottom: 20px;
    border-radius: 10px;
    text-align: center;
    font-size: 14px;
    font-weight: 600;
}

.error {
    background: #fef2f2;
    color: #dc2626;
    border: 1px solid #fecaca;
}

.success {
    background: #ecfdf5;
    color: #059669;
    border: 1px solid #a7f3d0;
}

/* MAIN BOX */

.box {
    background: white;
    padding: 35px 40px;
    border-radius: 16px;
    box-shadow: 0 8px 30px rgba(15, 23, 42, 0.08);
    border: 1px solid #e5e7eb;
}

.box h2 {
    text-align: center;
    color: #312e81;
    margin: 0 0 30px;
    font-size: 23px;
}

/* FORM */

.form-group {
    margin-bottom: 20px;
}

label {
    display: block;
    font-weight: 600;
    margin-bottom: 8px;
    color: #374151;
    font-size: 14px;
}

input,
select,
textarea {
    width: 100%;
    padding: 12px 14px;
    border: 1px solid #d1d5db;
    border-radius: 9px;
    font-size: 15px;
    font-family: Arial, Helvetica, sans-serif;
    background: #ffffff;
    color: #111827;
    transition: 0.2s ease;
}

input:focus,
select:focus,
textarea:focus {
    outline: none;
    border-color: #6366f1;
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.12);
}

textarea {
    height: 120px;
    resize: vertical;
    line-height: 1.5;
}

input[readonly] {
    background: #f3f4f6;
    color: #6b7280;
    cursor: not-allowed;
    font-weight: 600;
}

/* TEAM ID */

.team-id-box {
    background: linear-gradient(135deg, #eef2ff, #f5f3ff);
    border: 1px solid #c7d2fe;
    color: #4338ca;
    font-weight: 700;
}

/* BUTTON */

.update-button {
    width: 100%;
    margin-top: 12px;
    padding: 14px;
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

.update-button:hover {
    transform: translateY(-1px);
    box-shadow: 0 7px 18px rgba(79, 70, 229, 0.35);
}

.update-button:active {
    transform: translateY(0);
}

/* CANCEL */

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

/* FORM ROW */

.form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
}

/* MANAGER NOTE */

.manager-note {
    margin-top: 7px;
    font-size: 12px;
    color: #6b7280;
}

/* STATUS SELECT */

.status-active {
    color: #047857;
}

.status-inactive {
    color: #dc2626;
}

/* RESPONSIVE */

@media (max-width: 700px) {

    .header {
        padding: 20px;
    }

    .header h2 {
        font-size: 21px;
    }

    .container {
        margin: 25px auto;
        padding: 0 15px;
    }

    .box {
        padding: 25px 20px;
    }

    .form-row {
        grid-template-columns: 1fr;
        gap: 0;
    }
}

</style>

</head>

<body>

<div class="header">

    <h2>Employee Management System</h2>

    <p>Team Management &nbsp; / &nbsp; Edit Team</p>

</div>


<div class="container">

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


<div class="box">

    <h2>Edit Team Details</h2>


    <form action="UpdateTeamServlet" method="post">

        <input type="hidden"
               name="teamId"
               value="<%= teamId %>">


        <div class="form-group">

            <label>Team ID</label>

            <input type="text"
                   class="team-id-box"
                   value="<%= teamId %>"
                   readonly>

        </div>


        <div class="form-group">

            <label>Team Name</label>

            <input type="text"
                   name="teamName"
                   value="<%= teamName %>"
                   maxlength="100"
                   placeholder="Enter team name"
                   required>

        </div>


        <div class="form-group">

            <label>Description</label>

            <textarea name="description"
                      maxlength="500"
                      placeholder="Enter team description"><%= description == null ? "" : description %></textarea>

        </div>


        <div class="form-row">

            <div class="form-group">

                <label>Department</label>

                <select name="department" required>

                    <option value="">-- Select Department --</option>

                    <option value="IT"
                        <%= "IT".equals(department) ? "selected" : "" %>>
                        IT
                    </option>

                    <option value="HR"
                        <%= "HR".equals(department) ? "selected" : "" %>>
                        HR
                    </option>

                    <option value="Finance"
                        <%= "Finance".equals(department) ? "selected" : "" %>>
                        Finance
                    </option>

                    <option value="Marketing"
                        <%= "Marketing".equals(department) ? "selected" : "" %>>
                        Marketing
                    </option>

                    <option value="Operations"
                        <%= "Operations".equals(department) ? "selected" : "" %>>
                        Operations
                    </option>

                    <option value="Sales"
                        <%= "Sales".equals(department) ? "selected" : "" %>>
                        Sales
                    </option>

                </select>

            </div>


            <div class="form-group">

                <label>Status</label>

                <select name="status" required>

                    <option value="ACTIVE"
                        <%= "ACTIVE".equals(status) ? "selected" : "" %>>
                        ACTIVE
                    </option>

                    <option value="INACTIVE"
                        <%= "INACTIVE".equals(status) ? "selected" : "" %>>
                        INACTIVE
                    </option>

                </select>

            </div>

        </div>


        <div class="form-group">

            <label>Team Manager</label>

            <select name="managerId" required>

                <option value="">-- Select Manager --</option>

<%

Connection managerCon = null;
PreparedStatement managerPs = null;
ResultSet managerRs = null;

try {

    managerCon = DBcConnection.getConnection();

    String managerSql =
        "SELECT employee_id, name " +
        "FROM employees " +
        "WHERE designation = 'Manager' " +
        "AND status = 'ACTIVE' " +
        "ORDER BY name";

    managerPs = managerCon.prepareStatement(managerSql);

    managerRs = managerPs.executeQuery();

    while (managerRs.next()) {

        String id = managerRs.getString("employee_id");

%>

                <option value="<%= id %>"
                    <%= id.equals(managerId) ? "selected" : "" %>>

                    <%= managerRs.getString("name") %>
                    (<%= id %>)

                </option>

<%

    }

} catch (Exception e) {

    e.printStackTrace();

} finally {

    try {
        if (managerRs != null) managerRs.close();
    } catch (Exception e) {}

    try {
        if (managerPs != null) managerPs.close();
    } catch (Exception e) {}

    try {
        if (managerCon != null) managerCon.close();
    } catch (Exception e) {}

}

%>

            </select>

            <div class="manager-note">
                Only active employees with Manager designation are shown.
            </div>

        </div>


        <button type="submit"
                class="update-button">

            Update Team

        </button>

    </form>


    <a href="viewTeams.jsp"
       class="cancel-button">

        Cancel

    </a>

</div>

</div>

</body>

</html>