<%@ page contentType="text/html;charset=UTF-8" %>

<!DOCTYPE html>
<html>

<head>

    <meta charset="UTF-8">

    <title>Employee Registration</title>

    <style>

        body {
            margin: 0;
            padding: 0;
            font-family: Arial, sans-serif;
            background: #f4f6f8;
        }

        .container {
            width: 400px;
            margin: 50px auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        h2 {
            text-align: center;
            color: #2c3e50;
        }

        input {
            width: 100%;
            padding: 12px;
            margin: 8px 0;
            box-sizing: border-box;
            border: 1px solid #ccc;
            border-radius: 5px;
        }

        button {
            width: 100%;
            padding: 12px;
            margin-top: 15px;
            background: #3498db;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }

        button:hover {
            background: #2980b9;
        }

        .success {
            background: #d4edda;
            color: #155724;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 5px;
            text-align: center;
            font-weight: bold;
        }

        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 5px;
            text-align: center;
        }

        .employee-id {
            font-size: 22px;
            color: #27ae60;
            margin-top: 10px;
        }

        .login-link {
            text-align: center;
            margin-top: 20px;
        }

        .login-link a {
            color: #3498db;
            text-decoration: none;
        }

    </style>

</head>


<body>


<div class="container">

    <h2>Employee Registration</h2>


    <!-- SUCCESS MESSAGE -->

    <%
    String success =
            (String) request.getAttribute(
                    "success"
            );

    if (success != null) {
    %>

        <div class="success">

            <%=success%>

            <div class="employee-id">

                Employee ID:
                <%=request.getAttribute("employeeId")%>

            </div>

        </div>

    <%
    }
    %>


    <!-- ERROR MESSAGE -->

    <%
    String error =
            (String) request.getAttribute(
                    "error"
            );

    if (error != null) {
    %>

        <div class="error">

            <%=error%>

        </div>

    <%
    }
    %>


    <!-- REGISTRATION FORM -->

    <form action="<%=request.getContextPath()%>/register"
          method="post">


        <input type="text"
               name="name"
               placeholder="Full Name"
               required>


        <input type="email"
               name="email"
               placeholder="Email"
               required>


        <input type="text"
               name="phone"
               placeholder="Phone Number"
               required>


        <input type="text"
               name="department"
               placeholder="Department"
               required>


        <input type="text"
               name="designation"
               placeholder="Designation"
               required>


        <input type="number"
               name="salary"
               placeholder="Salary"
               step="0.01"
               required>


        <input type="password"
               name="password"
               placeholder="Password"
               required>


        <input type="password"
               name="confirmPassword"
               placeholder="Confirm Password"
               required>


        <button type="submit">

            Register Employee

        </button>

    </form>


    <div class="login-link">

        Already registered?

        <a href="login.html">
            Login
        </a>

    </div>

</div>


</body>

</html>