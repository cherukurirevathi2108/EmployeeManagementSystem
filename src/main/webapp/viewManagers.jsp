<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<!DOCTYPE html>
<html>
<head>

<title>View Managers</title>

<style>

body {
    margin: 0;
    font-family: Arial;
    background: #f4f6f9;
}

.container {
    width: 92%;
    margin: 40px auto;
}

.box {
    background: white;
    padding: 25px;
    border-radius: 10px;
    box-shadow: 0 2px 10px #ccc;
}

h2 {
    text-align: center;
    color: #2c3e50;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 20px;
}

th {
    background: #34495e;
    color: white;
    padding: 12px;
}

td {
    padding: 12px;
    border-bottom: 1px solid #ddd;
    text-align: center;
}

.back {
    display: inline-block;
    margin-top: 20px;
    padding: 10px 18px;
    background: #2c3e50;
    color: white;
    text-decoration: none;
    border-radius: 5px;
}

</style>

</head>

<body>

<div class="container">

<div class="box">

<h2>All Managers</h2>

<table>

<tr>
    <th>Manager ID</th>
    <th>Name</th>
    <th>Email</th>
    <th>Phone</th>
    <th>Department</th>
    <th>Designation</th>
    <th>Status</th>
</tr>

<%

Connection con = null;
PreparedStatement ps = null;
ResultSet rs = null;

try {

    con = DBcConnection.getConnection();

    String sql =
        "SELECT employee_id, name, email, phone, " +
        "department, designation, status " +
        "FROM managers " +
        "ORDER BY employee_id";

    ps = con.prepareStatement(sql);

    rs = ps.executeQuery();

    while (rs.next()) {

%>

<tr>

<td><%= rs.getString("employee_id") %></td>

<td><%= rs.getString("name") %></td>

<td><%= rs.getString("email") %></td>

<td><%= rs.getString("phone") %></td>

<td><%= rs.getString("department") %></td>

<td><%= rs.getString("designation") %></td>

<td><%= rs.getString("status") %></td>

</tr>

<%

    }

} catch (Exception e) {

    e.printStackTrace();

%>

<tr>
    <td colspan="7">
        Error loading managers
    </td>
</tr>

<%

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

</table>

<a href="admin_dashbaord.jsp" class="back">
    ← Back to Admin dashboard
</a>

</div>

</div>

</body>
</html>