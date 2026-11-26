<%@ page import="java.util.ArrayList" %>
<%@ page import="model.Employe" %>

<%
    ArrayList<Employe> employees =
        (ArrayList<Employe>)
        request.getAttribute("employees");
%>

<!DOCTYPE html>
<html>

<head>

    <title>View Employees</title>

</head>

<body>

<h1>Registered Employees</h1>

<hr>


<%
    if (employees != null &&
        !employees.isEmpty()) {

        for (Employe employee : employees) {
%>


    <a href="<%= request.getContextPath() %>/employeeDetails?id=<%= employee.getEmployeeId() %>">

        <button type="button">

            <%= employee.getEmployeeId() %>

        </button>

    </a>


    <br><br>


<%
        }

    } else {
%>


    <h3>No employees found.</h3>


<%
    }
%>


<br>


<a href="<%= request.getContextPath() %>/admin_dashbaord.jsp">

    <button type="button">
        Back to Admin Dashboard
    </button>

</a>


</body>

</html>