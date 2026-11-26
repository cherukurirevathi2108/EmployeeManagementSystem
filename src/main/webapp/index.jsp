<!DOCTYPE html>
<html>

<head>

<title>Employee Management System</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f6f9;
}

.login-container {
    width: 430px;

    margin: 80px auto;

    background: white;

    padding: 35px;

    border-radius: 12px;

    box-shadow: 0 4px 20px #ccc;
}

h1 {
    text-align: center;

    color: #2c3e50;

    margin-bottom: 10px;
}

.subtitle {
    text-align: center;

    color: #777;

    margin-bottom: 30px;
}

label {
    display: block;

    margin-top: 15px;

    margin-bottom: 7px;

    font-weight: bold;

    color: #34495e;
}

select,
input {
    width: 100%;

    padding: 12px;

    border: 1px solid #ccc;

    border-radius: 6px;

    font-size: 15px;
}

button {
    width: 100%;

    padding: 13px;

    margin-top: 25px;

    background: #2c3e50;

    color: white;

    border: none;

    border-radius: 6px;

    font-size: 16px;

    cursor: pointer;
}

button:hover {
    background: #1f2d3a;
}

.message {
    text-align: center;

    color: red;

    margin-bottom: 15px;
}

</style>

</head>


<body>


<div class="login-container">

    <h1>Employee Management System</h1>

    <div class="subtitle">
        Login to continue
    </div>


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


<form action="CommonLoginServlet" method="post">


    <label>Select Login Type</label>

    <select name="role" required>

        <option value="">
            -- Select Login Type --
        </option>

        <option value="ADMIN">
            Admin Login
        </option>

        <option value="MANAGER">
            Manager Login
        </option>

        <option value="EMPLOYEE">
            Employee Login
        </option>

    </select>


    <label>ID</label>

    <input type="text"
           name="id"
           placeholder="Enter ID"
           required>


    <label>Password</label>

    <input type="password"
           name="password"
           placeholder="Enter Password"
           required>


    <button type="submit">
        Login
    </button>


</form>


</div>


</body>

</html>