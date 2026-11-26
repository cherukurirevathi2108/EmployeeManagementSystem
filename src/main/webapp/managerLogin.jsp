<!DOCTYPE html>
<html>

<head>

    <title>Manager Login</title>

    <style>

        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #f4f6f8;
        }

        .login-box {
            width: 400px;
            margin: 100px auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 15px #ccc;
        }

        h2 {
            text-align: center;
            color: #2c3e50;
        }

        input {
            width: 100%;
            padding: 12px;
            margin-top: 10px;
            margin-bottom: 15px;
            box-sizing: border-box;
        }

        button {
            width: 100%;
            padding: 12px;
            background: #2c3e50;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }

        button:hover {
            background: #1a252f;
        }

        .message {
            color: red;
            text-align: center;
            margin-bottom: 10px;
        }

    </style>

</head>

<body>

<div class="login-box">

    <h2>Manager Login</h2>

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

    <form
        action="ManagerLoginServlet"
        method="post">

        <input
            type="text"
            name="managerId"
            placeholder="Manager ID"
            required>

        <input
            type="password"
            name="password"
            placeholder="Password"
            required>

        <button type="submit">
            Login
        </button>

    </form>

</div>

</body>

</html>