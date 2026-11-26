<%@ page contentType="text/html;charset=UTF-8" %>

<%@ page import="java.util.ArrayList" %>
<%@ page import="model.LeaveRequest" %>
<%@ page import="jakarta.servlet.http.HttpSession" %>

<!DOCTYPE html>
<html>

<head>

    <meta charset="UTF-8">

    <meta name="viewport"
          content="width=device-width, initial-scale=1.0">

    <title>Leave Management</title>

    <style>

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: Arial, sans-serif;
        }

        body {
            background-color: #f4f6f8;
            color: #333;
        }

        .container {
            width: 90%;
            max-width: 1100px;
            margin: 30px auto;
        }

        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 25px;
        }

        .header h1 {
            margin-bottom: 5px;
        }

        .header p {
            color: #d5dfe8;
        }

        .section {
            background-color: white;
            padding: 25px;
            border-radius: 8px;
            margin-bottom: 25px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        }

        .section h2 {
            color: #2c3e50;
            margin-bottom: 20px;
        }

        .form-group {
            margin-bottom: 15px;
        }

        .form-group label {
            display: block;
            margin-bottom: 7px;
            font-weight: bold;
            color: #495057;
        }

        .form-group input,
        .form-group select,
        .form-group textarea {
            width: 100%;
            padding: 11px;
            border: 1px solid #ccc;
            border-radius: 5px;
            font-size: 14px;
        }

        .form-group textarea {
            min-height: 100px;
            resize: vertical;
        }

        .button {
            background-color: #3498db;
            color: white;
            border: none;
            padding: 11px 20px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 14px;
        }

        .button:hover {
            background-color: #2980b9;
        }

        .success {
            background-color: #d4edda;
            color: #155724;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            font-weight: bold;
        }

        .error {
            background-color: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            font-weight: bold;
        }

        .table-container {
            width: 100%;
            overflow-x: auto;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th {
            background-color: #2c3e50;
            color: white;
            padding: 12px;
            text-align: left;
        }

        td {
            padding: 12px;
            border-bottom: 1px solid #ddd;
        }

        .status {
            padding: 6px 12px;
            border-radius: 15px;
            font-size: 12px;
            font-weight: bold;
            display: inline-block;
        }

        .pending {
            background-color: #fff3cd;
            color: #856404;
        }

        .approved {
            background-color: #d4edda;
            color: #155724;
        }

        .rejected {
            background-color: #f8d7da;
            color: #721c24;
        }

        .empty {
            text-align: center;
            padding: 30px;
            color: #777;
        }

        .back-button {
            display: inline-block;
            background-color: #6c757d;
            color: white;
            text-decoration: none;
            padding: 10px 18px;
            border-radius: 5px;
            margin-bottom: 20px;
        }

        .back-button:hover {
            background-color: #5a6268;
        }

        @media (max-width: 600px) {

            .container {
                width: 95%;
            }

            .section {
                padding: 18px;
            }

            th,
            td {
                font-size: 12px;
                padding: 8px;
            }
        }

    </style>

</head>

<body>

<%

    HttpSession sessionObject =
            request.getSession(false);

    String employeeId = "";

    if (sessionObject != null) {

        Object id =
                sessionObject.getAttribute("employeeId");

        if (id != null) {
            employeeId = id.toString();
        }
    }

    String success =
            (String) request.getAttribute("success");

    String error =
            (String) request.getAttribute("error");

    ArrayList<LeaveRequest> leaves =
            (ArrayList<LeaveRequest>)
                    request.getAttribute("leaves");

%>


<div class="container">


    <div class="header">

        <h1>Leave Management</h1>

        <p>
            Employee Leave Request and Status
        </p>

    </div>


    <a href="employee_dashboard.jsp"
       class="back-button">

        ← Back to Dashboard

    </a>


    <%
        if (success != null) {
    %>

        <div class="success">

            <%= success %>

        </div>

    <%
        }
    %>


    <%
        if (error != null) {
    %>

        <div class="error">

            <%= error %>

        </div>

    <%
        }
    %>


    <!-- ================================================= -->
    <!-- APPLY LEAVE FORM -->
    <!-- ================================================= -->

    <%
        /*
         * Show Apply Leave form only when there is
         * no successful submission in the current request.
         */
        if (success == null) {
    %>


    <div class="section">

        <h2>Apply Leave</h2>

        <form action="<%=request.getContextPath()%>/leave"
              method="post">

            <input type="hidden"
                   name="action"
                   value="applyLeave">


            <div class="form-group">

                <label>
                    Leave Type
                </label>

                <select name="leaveType"
                        required>

                    <option value="">
                        Select Leave Type
                    </option>

                    <option value="Sick Leave">
                        Sick Leave
                    </option>

                    <option value="Casual Leave">
                        Casual Leave
                    </option>

                    <option value="Emergency Leave">
                        Emergency Leave
                    </option>

                    <option value="Personal Leave">
                        Personal Leave
                    </option>

                    <option value="Other">
                        Other
                    </option>

                </select>

            </div>


            <div class="form-group">

                <label>
                    From Date
                </label>

                <input type="date"
                       name="fromDate"
                       required>

            </div>


            <div class="form-group">

                <label>
                    To Date
                </label>

                <input type="date"
                       name="toDate"
                       required>

            </div>


            <div class="form-group">

                <label>
                    Reason
                </label>

                <textarea name="reason"
                          placeholder="Enter reason for leave"
                          required></textarea>

            </div>


            <button type="submit"
                    class="button">

                Apply Leave

            </button>

        </form>

    </div>


    <%
        }
    %>


    <!-- ================================================= -->
    <!-- LEAVE STATUS -->
    <!-- ================================================= -->

    <div class="section">

        <h2>My Leave Status</h2>


        <%
            if (leaves == null ||
                leaves.isEmpty()) {
        %>

            <div class="empty">

                No leave requests found.

            </div>

        <%
            } else {
        %>


        <div class="table-container">

            <table>

                <thead>

                    <tr>

                        <th>Leave ID</th>

                        <th>Leave Type</th>

                        <th>From Date</th>

                        <th>To Date</th>

                        <th>Reason</th>

                        <th>Applied Date</th>

                        <th>Status</th>

                    </tr>

                </thead>


                <tbody>


                <%
                    for (LeaveRequest leave : leaves) {

                        String status =
                                leave.getStatus();

                        if (status == null ||
                            status.trim().isEmpty()) {

                            status = "PENDING";
                        }

                        String statusClass =
                                "pending";

                        if ("APPROVED".equalsIgnoreCase(status)) {

                            statusClass = "approved";

                        } else if ("REJECTED".equalsIgnoreCase(status)) {

                            statusClass = "rejected";
                        }
                %>


                    <tr>

                        <td>
                            <%=leave.getLeaveId()%>
                        </td>

                        <td>
                            <%=leave.getLeaveType()%>
                        </td>

                        <td>
                            <%=leave.getFromDate()%>
                        </td>

                        <td>
                            <%=leave.getToDate()%>
                        </td>

                        <td>
                            <%=leave.getReason()%>
                        </td>

                        <td>
                            <%=leave.getAppliedDate()%>
                        </td>

                        <td>

                            <span class="status <%=statusClass%>">

                                <%=status%>

                            </span>

                        </td>

                    </tr>


                <%
                    }
                %>


                </tbody>

            </table>

        </div>


        <%
            }
        %>


    </div>


</div>

</body>

</html>