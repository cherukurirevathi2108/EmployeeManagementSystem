
<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%
    Object roleObj = session.getAttribute("role");

    if (roleObj == null ||
        !"ADMIN".equalsIgnoreCase(roleObj.toString())) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    String dbURL = "jdbc:mysql://localhost:3306/employee_db";
    String dbUser = "root";
    String dbPassword = "root";
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Create Task</title>

<style>
body {
    font-family: Arial, sans-serif;
    background: #f3f5f9;
    margin: 0;
    padding: 30px;
}
.container {
    max-width: 700px;
    margin: auto;
    background: white;
    padding: 30px;
    border-radius: 12px;
    box-shadow: 0 3px 15px rgba(0,0,0,0.1);
}
h2 {
    text-align: center;
    color: #263b70;
}
label {
    display: block;
    margin-top: 15px;
    font-weight: bold;
}
input, textarea, select {
    width: 100%;
    padding: 10px;
    margin-top: 7px;
    box-sizing: border-box;
    border: 1px solid #ccc;
    border-radius: 6px;
}
textarea {
    resize: vertical;
}
button, .back {
    display: inline-block;
    margin-top: 20px;
    padding: 11px 18px;
    border: none;
    border-radius: 6px;
    color: white;
    text-decoration: none;
    cursor: pointer;
    background: #263b70;
}
.back {
    background: #666;
    margin-left: 8px;
}
button:hover {
    background: #17264b;
}
</style>
</head>

<body>
<div class="container">
    <h2>Create and Assign Task</h2>

    <form action="<%= request.getContextPath() %>/tasks"
          method="post">

        <input type="hidden" name="action" value="create">

        <label>Task Title</label>
        <input type="text" name="taskTitle" required maxlength="150">

        <label>Description</label>
        <textarea name="description" rows="4"></textarea>

        <label>Assign Employee</label>
        <select name="assignedTo" required>
            <option value="">-- Select Employee --</option>
            <%
                try {
                    Class.forName("com.mysql.cj.jdbc.Driver");

                    try (Connection con = DriverManager.getConnection(
                                dbURL, dbUser, dbPassword);
                         PreparedStatement ps = con.prepareStatement(
                                "SELECT employee_id, name FROM employees "
                              + "WHERE status = 'ACTIVE' ORDER BY name");
                         ResultSet rs = ps.executeQuery()) {

                        while (rs.next()) {
            %>
            <option value="<%= rs.getString("employee_id") %>">
                <%= rs.getString("name") %>
                (<%= rs.getString("employee_id") %>)
            </option>
            <%
                        }
                    }
                } catch (Exception e) {
                    out.println("<option value=''>Unable to load employees. "
                              + "Check database connection and employees table.</option>");
                    e.printStackTrace();
                }
            %>
        </select>

        <label>Department</label>
        <input type="text" name="department" required maxlength="100">

        <label>Priority</label>
        <select name="priority" required>
            <option value="LOW">Low</option>
            <option value="MEDIUM" selected>Medium</option>
            <option value="HIGH">High</option>
            <option value="URGENT">Urgent</option>
        </select>

        <label>Start Date</label>
        <input type="date" name="startDate" required>

        <label>Due Date</label>
        <input type="date" name="dueDate" required>

        <label>Initial Status</label>
        <select name="status" required>
            <option value="ASSIGNED" selected>Assigned</option>
            <option value="IN_PROGRESS">In Progress</option>
        </select>

        <button type="submit">Create Task</button>
        <a class="back"
           href="<%= request.getContextPath() %>/tasks?action=list">
           Back to Tasks
        </a>
    </form>
</div>
</body>
</html>
