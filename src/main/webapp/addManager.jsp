<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<!DOCTYPE html>
<html>
<head>

    <meta charset="UTF-8">
    <title>Add Manager</title>

    <style>

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            font-family: "Segoe UI", Arial, sans-serif;
            background:
                linear-gradient(135deg, #eef2ff, #f8f9ff, #eef7ff);
            color: #1f2937;
        }

        /* Main Wrapper */
        .page-wrapper {
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 40px 20px;
        }

        /* Form Card */
        .container {
            width: 100%;
            max-width: 620px;
            background: rgba(255, 255, 255, 0.96);
            padding: 38px 42px;
            border-radius: 20px;
            box-shadow:
                0 15px 40px rgba(31, 41, 55, 0.12),
                0 3px 10px rgba(31, 41, 55, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.8);
        }

        /* Header */
        .header {
            text-align: center;
            margin-bottom: 30px;
        }

        .icon {
            width: 58px;
            height: 58px;
            margin: 0 auto 14px;
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #4f46e5, #7c3aed);
            color: white;
            font-size: 27px;
            box-shadow: 0 8px 20px rgba(79, 70, 229, 0.25);
        }

        h2 {
            margin: 0;
            font-size: 27px;
            color: #111827;
            font-weight: 700;
        }

        .subtitle {
            margin-top: 7px;
            color: #6b7280;
            font-size: 14px;
        }

        /* Messages */
        .message {
            padding: 13px 15px;
            margin-bottom: 20px;
            border-radius: 10px;
            background: #ecfdf5;
            border: 1px solid #a7f3d0;
            color: #047857;
            text-align: center;
            font-size: 14px;
            font-weight: 600;
        }

        .error {
            background: #fef2f2;
            border: 1px solid #fecaca;
            color: #dc2626;
        }

        /* Form */
        .form-group {
            margin-bottom: 18px;
        }

        label {
            display: block;
            margin-bottom: 7px;
            font-size: 14px;
            font-weight: 600;
            color: #374151;
        }

        input,
        select {
            width: 100%;
            height: 46px;
            padding: 0 14px;
            border: 1px solid #d1d5db;
            border-radius: 10px;
            background: #ffffff;
            color: #1f2937;
            font-size: 14px;
            outline: none;
            transition: all 0.2s ease;
        }

        input::placeholder {
            color: #9ca3af;
        }

        input:focus,
        select:focus {
            border-color: #6366f1;
            box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.10);
        }

        /* Generated ID */
        .generated-id {
            background: #f1f5ff;
            border: 1px solid #c7d2fe;
            color: #4f46e5;
            font-weight: 600;
            cursor: not-allowed;
        }

        /* Two Columns */
        .row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
        }

        /* Button */
        button {
            width: 100%;
            height: 49px;
            margin-top: 8px;
            border: none;
            border-radius: 11px;
            background: linear-gradient(135deg, #4f46e5, #7c3aed);
            color: white;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            box-shadow: 0 8px 18px rgba(79, 70, 229, 0.22);
            transition: all 0.2s ease;
        }

        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 12px 24px rgba(79, 70, 229, 0.30);
        }

        button:active {
            transform: translateY(0);
        }

        /* Back Link */
        .back {
            display: block;
            text-align: center;
            margin-top: 20px;
            color: #4f46e5;
            text-decoration: none;
            font-size: 14px;
            font-weight: 600;
        }

        .back:hover {
            color: #3730a3;
        }

        /* Mobile */
        @media (max-width: 600px) {

            .page-wrapper {
                padding: 20px 12px;
            }

            .container {
                padding: 28px 22px;
                border-radius: 16px;
            }

            .row {
                grid-template-columns: 1fr;
                gap: 0;
            }

            h2 {
                font-size: 24px;
            }
        }

    </style>

</head>

<body>

<div class="page-wrapper">

    <div class="container">

        <div class="header">

            <div class="icon">
                👨‍💼
            </div>

            <h2>Add Manager</h2>

            <div class="subtitle">
                Create a new manager account
            </div>

        </div>


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

            <div class="message error">
                <%= error %>
            </div>

        <%
            }
        %>


        <form action="AddManagerServlet" method="post">


            <!-- Manager ID -->

            <div class="form-group">

                <label>Manager ID</label>

                <input
                    type="text"
                    value="Will be generated automatically"
                    class="generated-id"
                    readonly>

            </div>


            <!-- Name + Email -->

            <div class="row">

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
                        placeholder="Enter manager email"
                        required>

                </div>

            </div>


            <!-- Phone + Department -->

            <div class="row">

                <div class="form-group">

                    <label>Phone</label>

                    <input
                        type="text"
                        name="phone"
                        placeholder="Enter phone number"
                        required>

                </div>


                <div class="form-group">

                    <label>Department</label>

                    <input
                        type="text"
                        name="department"
                        placeholder="Enter department"
                        required>

                </div>

            </div>


            <!-- Designation + Salary -->

            <div class="row">

                <div class="form-group">

                    <label>Designation</label>

                    <input
                        type="text"
                        name="designation"
                        placeholder="Enter designation"
                        value="Manager"
                        required>

                </div>


                <div class="form-group">

                    <label>Salary</label>

                    <input
                        type="number"
                        name="salary"
                        placeholder="Enter salary"
                        required>

                </div>

            </div>


            <!-- Password + Status -->

            <div class="row">

                <div class="form-group">

                    <label>Password</label>

                    <input
                        type="password"
                        name="password"
                        placeholder="Enter manager password"
                        required>

                </div>


                <div class="form-group">

                    <label>Status</label>

                    <select name="status" required>

                        <option value="ACTIVE">
                            ACTIVE
                        </option>

                        <option value="INACTIVE">
                            INACTIVE
                        </option>

                    </select>

                </div>

            </div>


            <button type="submit">
                Add Manager
            </button>


        </form>


        <% boolean hrUser = "HR".equalsIgnoreCase(String.valueOf(session.getAttribute("role"))); %>
        <a href="<%= hrUser ? "hr" : "admin_dashbaord.jsp" %>" class="back">
            ← Back to <%= hrUser ? "HR" : "Admin" %> Dashboard
        </a>

    </div>

</div>

</body>
</html>