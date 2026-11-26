
<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" %>
<%@ page import="java.util.List" %>
<%@ page import="model.Task" %>

<%
    Object roleObj = session.getAttribute("role");

    if (roleObj == null ||
        !"ADMIN".equalsIgnoreCase(roleObj.toString())) {
        response.sendRedirect(request.getContextPath() + "/login.jsp");
        return;
    }

    List<Task> tasks = (List<Task>) request.getAttribute("tasks");
%>

<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Manage Tasks</title>

<style>
body {
    margin: 0;
    padding: 25px;
    font-family: Arial, sans-serif;
    background: #f3f5f9;
}
.container {
    max-width: 1400px;
    margin: auto;
    background: white;
    padding: 25px;
    border-radius: 12px;
    box-shadow: 0 3px 15px rgba(0,0,0,0.1);
}
h2 {
    text-align: center;
    color: #263b70;
}
.actions {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin: 20px 0;
}
.btn {
    display: inline-block;
    padding: 10px 15px;
    border-radius: 5px;
    color: white;
    text-decoration: none;
    border: none;
    cursor: pointer;
    font-size: 14px;
}
.create { background: #198754; }
.back { background: #555; }
.edit { background: #0d6efd; }
.delete { background: #dc3545; }
.table-wrap {
    overflow-x: auto;
}
table {
    width: 100%;
    border-collapse: collapse;
    min-width: 1050px;
}
th, td {
    padding: 12px;
    border: 1px solid #ddd;
    text-align: left;
}
th {
    background: #263b70;
    color: white;
}
tr:nth-child(even) {
    background: #f8f9fc;
}
.status {
    font-weight: bold;
}
.message {
    padding: 12px;
    background: #e7f5e9;
    border-radius: 5px;
    margin: 15px 0;
}
.empty {
    text-align: center;
    padding: 25px;
    color: #666;
}
</style>
</head>

<body>
<div class="container">

    <h2>Task Management</h2>

    <%
        String message = request.getParameter("message");

        if ("created".equals(message)) {
    %>
        <div class="message">Task created successfully.</div>
    <%
        } else if ("updated".equals(message)) {
    %>
        <div class="message">Task updated successfully.</div>
    <%
        } else if ("deleted".equals(message)) {
    %>
        <div class="message">Task deleted successfully.</div>
    <%
        } else if ("error".equals(message)) {
    %>
        <div class="message">Operation failed. Please check the server console.</div>
    <%
        }
    %>

    <div class="actions">
        <a class="btn create"
           href="<%= request.getContextPath() %>/createTask.jsp">
           + Create New Task
        </a>

        <a class="btn back"
           href="<%= request.getContextPath() %>/admin">
           Back to Admin Dashboard
        </a>

        <a class="btn back"
           href="<%= request.getContextPath() %>/tasks?action=list">
           Refresh
        </a>
    </div>

    <div class="table-wrap">
    <table>
        <thead>
            <tr>
                <th>ID</th>
                <th>Task Title</th>
                <th>Description</th>
                <th>Assigned Employee ID</th>
                <th>Department</th>
                <th>Priority</th>
                <th>Start Date</th>
                <th>Due Date</th>
                <th>Status</th>
                <th>Employee Comment</th>
                <th>Actions</th>
            </tr>
        </thead>

        <tbody>
        <%
            if (tasks != null && !tasks.isEmpty()) {
                for (Task task : tasks) {
        %>
            <tr>
                <td><%= task.getId() %></td>
                <td><%= task.getTaskTitle() == null ? "" : task.getTaskTitle() %></td>
                <td><%= task.getDescription() == null ? "" : task.getDescription() %></td>
                <td><%= task.getAssignedTo() == null ? "" : task.getAssignedTo() %></td>
                <td><%= task.getDepartment() == null ? "" : task.getDepartment() %></td>
                <td><%= task.getPriority() == null ? "" : task.getPriority() %></td>
                <td><%= task.getStartDate() == null ? "" : task.getStartDate() %></td>
                <td><%= task.getDueDate() == null ? "" : task.getDueDate() %></td>
                <td class="status"><%= task.getStatus() == null ? "" : task.getStatus() %></td>
                <td><%= task.getEmployeeComment() == null ? "" : task.getEmployeeComment() %></td>
                <td>
                    <a class="btn edit"
                       href="<%= request.getContextPath() %>/tasks?action=edit&id=<%= task.getId() %>">
                       Edit
                    </a>

                    <form action="<%= request.getContextPath() %>/tasks"
                          method="get"
                          style="display:inline"
                          onsubmit="return confirm('Are you sure you want to delete this task?');">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="<%= task.getId() %>">
                        <button type="submit" class="btn delete">Delete</button>
                    </form>
                </td>
            </tr>
        <%
                }
            } else {
        %>
            <tr>
                <td colspan="11" class="empty">
                    No tasks found. Click "Create New Task" to add a task.
                </td>
            </tr>
        <%
            }
        %>
        </tbody>
    </table>
    </div>
</div>
</body>
</html>
