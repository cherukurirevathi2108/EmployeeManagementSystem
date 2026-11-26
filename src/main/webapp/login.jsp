<!DOCTYPE html>
<html>
<head>
<title>Employee Login</title>

<style>
body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.login-container {
    width: 400px;
    margin: 100px auto;
    background: white;
    padding: 35px;
    border-radius: 10px;
    box-shadow: 0 2px 15px #ccc;
}

h2 {
    text-align: center;
    color: #2c3e50;
}

label {
    display: block;
    margin-top: 15px;
    font-weight: bold;
}

input {
    width: 100%;
    padding: 12px;
    margin-top: 7px;
    border: 1px solid #ccc;
    border-radius: 5px;
}

button {
    width: 100%;
    padding: 12px;
    margin-top: 25px;
    background: #2c3e50;
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
}

button:hover {
    background: #1f2d3a;
}

.message {
    color: red;
    text-align: center;
    margin-top: 10px;
}
</style>

</head>

<body>

<div class="login-container">

<h2>Employee Login</h2>

<%
String message = request.getParameter("message");

if (message != null) {
%>

<div class="message">
    <%= message %>
</div>

<%
}
%>

<form action="<%= request.getContextPath() %>/login" method="post">

<label>Employee ID</label>

<input type="text"
       name="employeeId"
       placeholder="Enter Employee ID"
       required>

<label>Password</label>

<input type="password"
       name="password"
       placeholder="Enter Password"
       required>

<button type="submit">Login</button>

</form>

</div>

</body>
</html>