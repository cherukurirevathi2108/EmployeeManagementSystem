<!DOCTYPE html>
<html>

<head>

    <title>Admin Login</title>

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
            width: 400px;
            margin: 100px auto;
            background: white;
            padding: 35px;
            border-radius: 10px;
            box-shadow: 0 0 15px #ccc;
        }

        h2 {
            text-align: center;
            color: #2c3e50;
            margin-bottom: 25px;
        }

        label {
            display: block;
            margin-bottom: 6px;
            font-weight: bold;
        }

        input {
            width: 100%;
            padding: 12px;
            margin-bottom: 18px;
            border: 1px solid #ccc;
            border-radius: 5px;
        }

        button {
            width: 100%;
            padding: 12px;
            background: #2c3e50;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
        }

        button:hover {
            background: #1f2d3a;
        }

        .error {
            color: #e74c3c;
            text-align: center;
            margin-bottom: 15px;
        }

    </style>

</head>


<body>


<div class="login-container">

    <h2>
        Admin Login
    </h2>


<%

    String message =
        request.getParameter("message");

    if (message != null) {

%>

    <div class="error">
        <%= message %>
    </div>

<%

    }

%>


    <form
        action="AdminLoginServlet"
        method="post">


        <label>
            Username
        </label>

        <input
            type="text"
            name="username"
            placeholder="Enter Admin Username"
            required>


        <label>
            Password
        </label>

        <input
            type="password"
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