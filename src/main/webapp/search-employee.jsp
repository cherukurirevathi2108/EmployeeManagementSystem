<%@ page import="java.util.ArrayList" %>
<%@ page import="model.Employe" %>

<%
    ArrayList<Employe> employees =
        (ArrayList<Employe>)
        request.getAttribute("employees");

    String search =
        (String) request.getAttribute("search");
%>

<!DOCTYPE html>
<html>

<head>

    <title>Search Employee</title>

</head>

<body>

<h1>Search Employee</h1>

<hr>


<form action="<%= request.getContextPath() %>/searchEmployee"
      method="get">

    <label>
        Employee ID or Name:
    </label>


    <input type="text"
           name="search"
           placeholder="Enter ID or Name"
           required>


    <button type="submit">
        Search
    </button>

</form>


<br>


<%
    if (employees != null) {

        if (!employees.isEmpty()) {
%>


<h2>
    Search Results
</h2>


<%
            for (Employe employee : employees) {
%>


    <a href="<%= request.getContextPath() %>/employeeDetails?id=<%= employee.getEmployeeId() %>">

        <button type="button">

            <%= employee.getEmployeeId() %>
            -
            <%= employee.getName() %>

        </button>

    </a>


    <br><br>


<%
            }

        } else {
%>


    <h3>
        No employee found.
    </h3>


<%
        }
    }
%>


<br>


<a href="<%= request.getContextPath() %>/employees">

    <button type="button">
        View All Employees
    </button>

</a>


<br><br>


<a href="<%= request.getContextPath() %>/admin-dashboard.jsp">

    <button type="button">
        Back to Admin Dashboard
    </button>

</a>


</body>

</html>g