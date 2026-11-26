
<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ page import="model.Task" %>

<%
    Object roleObj = session.getAttribute("role");

    if (roleObj == null ||
        !"ADMIN".equalsIgnoreCase(roleObj.toString())) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    Task task = (Task) request.getAttribute("task");

    if (task == null) {
        response.sendRedirect(request.getContextPath() + "/tasks?action=list");
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
<title>Edit Task</title>

<style>
body {
    font-family: Arial, sans-serif;
    background: #f3f5f9;
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
    box-sizing: border-box;
    padding: 10px;
    margin-top: 7px;
    border: 1px solid #ccc;
    border-radius: 6px;
}
button, .back {
    display: inline-block;
    margin-top: 20px;
    padding: 11px 18px;
    border: none;
    border-radius: 6px;
    background: #263b70;
    color: white;
    text-decoration: none;
    cursor: pointer;
}
.back {
    background: #666;
    margin-left: 8px;
}
</style>
</head>

<body>
<div class="container">

    <h2>Edit Task #<%= task.getId() %></h2>

    <form action="<%= request.getContextPath() %>/tasks" method="post">

        <input type="hidden" name="action" value="update">
        <input type="hidden" name="id" value="<%= task.getId() %>">

        <label>Task Title</label>
        <input type="text" name="taskTitle"
               value="<%= task.getTaskTitle() == null ? "" : task.getTaskTitle() %>"
               maxlength="150" required>

        <label>Description</label>
        <textarea name="description" rows="4"><%= task.getDescription() == null ? "" : task.getDescription() %></textarea>

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
                            String empId = rs.getString("employee_id");
                            String selected =
                                empId.equals(task.getAssignedTo())
                                ? "selected" : "";
            %>
            <option value="<%= empId %>" <%= selected %>>
                <%= rs.getString("name") %> (<%= empId %>)
            </option>
            <%
                        }
                    }
                } catch (Exception e) {
                    out.println("<option value=''>Unable to load employees</option>");
                    e.printStackTrace();
                }
            %>
        </select>

        <label>Department</label>
        <input type="text" name="department"
               value="<%= task.getDepartment() == null ? "" : task.getDepartment() %>"
               maxlength="100" required>

        <label>Priority</label>
        <select name="priority" required>
            <option value="LOW" <%= "LOW".equals(task.getPriority()) ? "selected" : "" %>>Low</option>
            <option value="MEDIUM" <%= "MEDIUM".equals(task.getPriority()) ? "selected" : "" %>>Medium</option>
            <option value="HIGH" <%= "HIGH".equals(task.getPriority()) ? "selected" : "" %>>High</option>
            <option value="URGENT" <%= "URGENT".equals(task.getPriority()) ? "selected" : "" %>>Urgent</option>
        </select>

        <label>Start Date</label>
        <input type="date" name="startDate"
               value="<%= task.getStartDate() == null ? "" : task.getStartDate() %>"
               required>

        <label>Due Date</label>
        <input type="date" name="dueDate"
               value="<%= task.getDueDate() == null ? "" : task.getDueDate() %>"
               required>

        <label>Status</label>
        <select name="status" required>
            <option value="ASSIGNED" <%= "ASSIGNED".equals(task.getStatus()) ? "selected" : "" %>>Assigned</option>
            <option value="IN_PROGRESS" <%= "IN_PROGRESS".equals(task.getStatus()) ? "selected" : "" %>>In Progress</option>
            <option value="COMPLETED" <%= "COMPLETED".equals(task.getStatus()) ? "selected" : "" %>>Completed</option>
            <option value="ON_HOLD" <%= "ON_HOLD".equals(task.getStatus()) ? "selected" : "" %>>On Hold</option>
        </select>

        <label>Employee Comment</label>
        <textarea name="employeeComment" rows="3"><%= task.getEmployeeComment() == null ? "" : task.getEmployeeComment() %></textarea>

        <button type="submit">Save Changes</button>

        <a class="back"
           href="<%= request.getContextPath() %>/tasks?action=list">
           Cancel
        </a>

    </form>
</div>
</body>
</html>
