<%@ page language="java"
    contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>

<!DOCTYPE html>
<html>

<head>

<meta charset="UTF-8">

<title>Add Manager</title>

<style>

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.container {
    width: 550px;
    margin: 50px auto;
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
}

h2 {
    text-align: center;
    margin-bottom: 30px;
}

.form-group {
    margin-bottom: 18px;
}

label {
    display: block;
    margin-bottom: 7px;
    font-weight: bold;
}

input,
select {
    width: 100%;
    padding: 11px;
    border: 1px solid #ccc;
    border-radius: 5px;
    box-sizing: border-box;
}

button {
    width: 100%;
    padding: 12px;
    border: none;
    border-radius: 5px;
    background: #007bff;
    color: white;
    font-size: 16px;
    cursor: pointer;
}

button:hover {
    background: #0056b3;
}

.message {
    background: #e8f5e9;
    color: #2e7d32;
    padding: 10px;
    margin-bottom: 20px;
    border-radius: 5px;
}

.error {
    background: #ffebee;
    color: #c62828;
    padding: 10px;
    margin-bottom: 20px;
    border-radius: 5px;
}

.back {
    display: block;
    text-align: center;
    margin-top: 15px;
    padding: 10px;
    background: #6c757d;
    color: white;
    text-decoration: none;
    border-radius: 5px;
}

</style>

</head>

<body>

<div class="container">

<h2>ADD MANAGER</h2>

<%
    String message = request.getParameter("message");
    String error = request.getParameter("error");

    if (message != null) {
%>

    <div class="message">
        <%= message %>
    </div>

<%
    }

    if (error != null) {
%>

    <div class="error">
        <%= error %>
    </div>

<%
    }
%>


<form action="AddManagerServlet" method="post">

    <div class="form-group">

        <label>Employee ID</label>

        <input
            type="text"
            name="employeeId"
            placeholder="Example: EMP106"
            required>

    </div>


    <div class="form-group">

        <label>Name</label>

        <input
            type="text"
            name="name"
            placeholder="Enter manager name"
            required>

    </div>


    <div class="form-group">

        <label>Email</label>

        <input
            type="email"
            name="email"
            placeholder="Enter email"
            required>

    </div>


    <div class="form-group">

        <label>Designation</label>

        <input
            type="text"
            name="designation"
            placeholder="Example: Team Manager">

    </div>


    <div class="form-group">

        <label>Department</label>

        <select name="department" required>

            <option value="">
                -- Select Department --
            </option>

            <option value="IT">IT</option>

            <option value="HR">HR</option>

            <option value="Finance">Finance</option>

            <option value="Sales">Sales</option>

        </select>

    </div>


    <button type="submit">
        Add Manager
    </button>

</form>


<a href="adminPanel.jsp" class="back">
   Admin Panel
</a>

</div>

</body>

</html>