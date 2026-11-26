<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<!DOCTYPE html>
<html>

<head>

    <title>View Employees</title>

    <style>

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: "Segoe UI", Arial, sans-serif;
            background: #f4f6fb;
            color: #1f2937;
        }

        /* ================= HEADER ================= */

        .header {
            background: linear-gradient(135deg, #4338ca, #6d28d9);
            color: white;
            padding: 22px 45px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            box-shadow: 0 4px 18px rgba(67, 56, 202, 0.25);
        }

        .header h2 {
            margin: 0;
            font-size: 25px;
            font-weight: 700;
        }

        .header p {
            margin: 5px 0 0;
            font-size: 13px;
            opacity: 0.85;
        }

        .back-top {
            background: rgba(255,255,255,0.15);
            color: white;
            text-decoration: none;
            padding: 10px 18px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            border: 1px solid rgba(255,255,255,0.3);
            transition: 0.3s;
        }

        .back-top:hover {
            background: white;
            color: #4338ca;
        }

        /* ================= CONTAINER ================= */

        .container {
            width: 94%;
            max-width: 1450px;
            margin: 35px auto;
        }

        .box {
            background: white;
            padding: 30px;
            border-radius: 16px;
            box-shadow: 0 8px 30px rgba(15, 23, 42, 0.08);
            border: 1px solid #e5e7eb;
        }

        .box-title {
            margin-bottom: 25px;
        }

        .box-title h2 {
            margin: 0;
            font-size: 23px;
            color: #111827;
        }

        .box-title p {
            margin: 6px 0 0;
            color: #6b7280;
            font-size: 13px;
        }

        /* ================= TABLE ================= */

        .table-wrapper {
            width: 100%;
            overflow-x: auto;
            border: 1px solid #e5e7eb;
            border-radius: 12px;
        }

        table {
            width: 100%;
            min-width: 1000px;
            border-collapse: collapse;
        }

        th {
            background: #eef2ff;
            color: #3730a3;
            padding: 16px 12px;
            text-align: center;
            font-size: 13px;
            font-weight: 700;
            border-bottom: 2px solid #c7d2fe;
            white-space: nowrap;
        }

        td {
            padding: 15px 12px;
            text-align: center;
            font-size: 14px;
            color: #4b5563;
            border-bottom: 1px solid #edf0f5;
        }

        tbody tr {
            transition: 0.2s;
        }

        tbody tr:hover {
            background: #f8faff;
        }

        tbody tr:last-child td {
            border-bottom: none;
        }

        /* ================= EMPLOYEE ID ================= */

        .employee-id {
            display: inline-block;
            background: #eef2ff;
            color: #4338ca;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 700;
        }

        /* ================= NAME ================= */

        .employee-name {
            color: #111827;
            font-weight: 600;
        }

        /* ================= EMAIL ================= */

        .email {
            color: #2563eb;
            font-size: 13px;
        }

        /* ================= PHONE ================= */

        .phone {
            color: #4b5563;
        }

        /* ================= DEPARTMENT ================= */

        .department {
            color: #6b7280;
            font-weight: 500;
        }

        /* ================= DESIGNATION ================= */

        .designation {
            display: inline-block;
            background: #f3e8ff;
            color: #7e22ce;
            padding: 6px 10px;
            border-radius: 6px;
            font-size: 12px;
            font-weight: 600;
        }

        /* ================= SALARY ================= */

        .salary {
            color: #047857;
            font-weight: 600;
        }

        /* ================= STATUS ================= */

        .status {
            display: inline-block;
            padding: 6px 13px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: 700;
            letter-spacing: 0.4px;
        }

        .status-active {
            background: #dcfce7;
            color: #15803d;
        }

        .status-inactive {
            background: #fee2e2;
            color: #dc2626;
        }

        /* ================= BACK BUTTON ================= */

        .back {
            display: inline-block;
            margin-top: 25px;
            padding: 11px 20px;
            background: #4338ca;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            transition: 0.3s;
        }

        .back:hover {
            background: #3730a3;
            transform: translateY(-1px);
            box-shadow: 0 5px 12px rgba(67, 56, 202, 0.25);
        }

        /* ================= ERROR ================= */

        .error {
            color: #dc2626;
            text-align: center;
            padding: 30px;
            font-weight: 600;
        }

        /* ================= RESPONSIVE ================= */

        @media (max-width: 768px) {

            .header {
                padding: 20px;
                flex-direction: column;
                align-items: flex-start;
                gap: 15px;
            }

            .back-top {
                width: 100%;
                text-align: center;
            }

            .container {
                width: 96%;
                margin: 20px auto;
            }

            .box {
                padding: 20px;
            }

        }

    </style>

</head>

<body>


<!-- ================= HEADER ================= -->

<div class="header">

    <div>

        <h2>Employee Management System</h2>

        <p>Employee Directory</p>

    </div>

    <a href="admin_dashbaord.jsp" class="back-top">
        Admin Dashboard
    </a>

</div>


<!-- ================= MAIN CONTAINER ================= -->

<div class="container">

    <div class="box">

        <div class="box-title">

            <h2>All Employees</h2>

            <p>
                View all registered employees and their details
            </p>

        </div>


        <!-- ================= TABLE ================= -->

        <div class="table-wrapper">

        <table>

            <thead>

                <tr>

                    <th>Employee ID</th>

                    <th>Name</th>

                    <th>Email</th>

                    <th>Phone</th>

                    <th>Department</th>

                    <th>Designation</th>

                    <th>Salary</th>

                    <th>Status</th>

                </tr>

            </thead>


            <tbody>


            <%

                Connection con = null;

                PreparedStatement ps = null;

                ResultSet rs = null;

                try {

                    con = DBcConnection.getConnection();

                    String sql =
                        "SELECT employee_id, name, email, phone, " +
                        "department, designation, salary, status " +
                        "FROM employees " +
                        "ORDER BY employee_id";

                    ps = con.prepareStatement(sql);

                    rs = ps.executeQuery();


                    while (rs.next()) {

            %>


                <tr>

                    <!-- Employee ID -->

                    <td>

                        <span class="employee-id">
                            <%= rs.getString("employee_id") %>
                        </span>

                    </td>


                    <!-- Name -->

                    <td>

                        <span class="employee-name">
                            <%= rs.getString("name") %>
                        </span>

                    </td>


                    <!-- Email -->

                    <td>

                        <span class="email">
                            <%= rs.getString("email") %>
                        </span>

                    </td>


                    <!-- Phone -->

                    <td>

                        <span class="phone">
                            <%= rs.getString("phone") %>
                        </span>

                    </td>


                    <!-- Department -->

                    <td>

                        <span class="department">
                            <%= rs.getString("department") %>
                        </span>

                    </td>


                    <!-- Designation -->

                    <td>

                        <span class="designation">
                            <%= rs.getString("designation") %>
                        </span>

                    </td>


                    <!-- Salary -->

                    <td>

                        <span class="salary">
                            <%= rs.getString("salary") %>
                        </span>

                    </td>


                    <!-- Status -->

                    <td>

                        <%

                            String status =
                                rs.getString("status");

                            if ("ACTIVE".equalsIgnoreCase(status)) {

                        %>

                            <span class="status status-active">
                                ACTIVE
                            </span>

                        <%

                            } else {

                        %>

                            <span class="status status-inactive">
                                <%= status %>
                            </span>

                        <%

                            }

                        %>

                    </td>

                </tr>


            <%

                    }

                }

                catch (Exception e) {

                    e.printStackTrace();

            %>


                <tr>

                    <td colspan="8" class="error">

                        Error loading employees

                    </td>

                </tr>


            <%

                }

                finally {

                    try {

                        if (rs != null)
                            rs.close();

                    } catch (Exception e) {}


                    try {

                        if (ps != null)
                            ps.close();

                    } catch (Exception e) {}


                    try {

                        if (con != null)
                            con.close();

                    } catch (Exception e) {}

                }

            %>


            </tbody>

        </table>

        </div>


        <!-- BACK BUTTON -->

        <a href="admin_dashbaord.jsp" class="back">
            Back to Admin Dashboard
        </a>


    </div>

</div>


</body>

</html>