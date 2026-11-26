<%@ page import="model.Employe" %>

<%
    Employe employee =
        (Employe) request.getAttribute("employee");
%>

<!DOCTYPE html>
<html>

<head>

    <title>Employee Details</title>

</head>

<body>

<h1>Employee Details</h1>

<hr>


<%
    if (employee != null) {
%>


<table border="1"
       cellpadding="10"
       cellspacing="0">

    <tr>

        <th>Employee ID</th>

        <td>
            <%= employee.getEmployeeId() %>
        </td>

    </tr>


    <tr>

        <th>Name</th>

        <td>
            <%= employee.getName() %>
        </td>

    </tr>


    <tr>

        <th>Email</th>

        <td>
            <%= employee.getEmail() %>
        </td>

    </tr>


    <tr>

        <th>Phone</th>

        <td>
            <%= employee.getPhone() %>
        </td>

    </tr>


    <tr>

        <th>Department</th>

        <td>
            <%= employee.getDepartment() %>
        </td>

    </tr>


    <tr>

        <th>Designation</th>

        <td>
            <%= employee.getDesignation() %>
        </td>

    </tr>


    <tr>

        <th>Salary</th>

        <td>
            <%= employee.getSalary() %>
        </td>

    </tr>


    <tr>

        <th>Status</th>

        <td>
            <%= employee.getStatus() %>
        </td>

    </tr>

</table>


<br>


<a href="<%= request.getContextPath() %>/employees">

    <button type="button">
        Back to Employees
    </button>

</a>


<%
    } else {
%>


<h3>Employee not found.</h3>


<%
    }
%>


<br><br>


<a href="<%= request.getContextPath() %>/admin-dashboard.jsp">

    <button type="button">
        Back to Admin Dashboard
    </button>

</a>


</body>

</html>